terraform {
  required_version = ">= 1.6.0"
  required_providers {
    null = {
      source = "hashicorp/null"
    }

    local = {
      source = "hashicorp/local"
    }
  }
}

provider "null" {}
provider "local" {}

locals {
  cluster_name = "canary-deployment"
  project_dir  = abspath("${path.module}/..")

  kind_config = templatefile(
    "${local.project_dir}/kind.yaml.tftpl",
    {
      server_ip = var.server_ip
    }
  )

  grafana_values = templatefile(
    "${local.project_dir}/grafana/values.yaml.tftpl", {
      grafana_admin          = var.grafana_admin
      grafana_admin_password = var.grafana_admin_password
    }
  )
}

resource "local_file" "kind_config" {
  filename = "${path.module}/kind.yaml"
  content  = local.kind_config
}

resource "local_file" "grafana_values" {
  filename = "${path.module}/grafana-values.yaml"
  content  = local.grafana_values
}

resource "null_resource" "kind_cluster" {
  depends_on = [local_file.kind_config]

  triggers = {
    kind_config = sha256(local.kind_config)
    cluster     = local.cluster_name
  }

  provisioner "local-exec" {
    command = <<-EOT
    kind delete cluster --name '${local.cluster_name}' 2>/dev/null || true

    kind create cluster \
      --name '${local.cluster_name}' \
      --config '${path.module}/kind.yaml'

    kubectl config set-cluster kind-${local.cluster_name} \
      --server=https://${var.server_ip}:6443
  EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = "kind delete cluster --name 'canary-deployment' 2>/dev/null || true"
  }
}

resource "null_resource" "gateway_api" {
  depends_on = [null_resource.kind_cluster]
  provisioner "local-exec" {
    command = <<-EOT
        kubectl apply \
        -f https://github.com/kubernetes-sigs/gateway-api/releases/latest/download/standard-install.yaml
      EOT
  }
}

resource "null_resource" "namespace" {
  depends_on = [null_resource.kind_cluster]
  provisioner "local-exec" {
    command = "kubectl apply -f '${local.project_dir}/namespace.yaml'"
  }
}

resource "null_resource" "traefik" {
  depends_on = [null_resource.kind_cluster, null_resource.gateway_api]

  triggers = {
    values = filesha256("${local.project_dir}/traefik/values.yaml")
  }

  provisioner "local-exec" {
    command = <<-EOT
      helm repo add traefik https://traefik.github.io/charts --force-update
      helm repo update

      helm upgrade --install traefik traefik/traefik \
        --namespace traefik \
        --create-namespace \
        --values '${local.project_dir}/traefik/values.yaml' \
        --wait \
        --timeout 5m
    EOT
  }
}

resource "null_resource" "prometheus" {
  depends_on = [null_resource.kind_cluster, null_resource.namespace
  ]

  triggers = {
    values = filesha256("${local.project_dir}/prometheus/values.yaml")
  }

  provisioner "local-exec" {
    command = <<-EOT
      helm repo add prometheus-community https://prometheus-community.github.io/helm-charts --force-update
      helm repo update

      helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
        --namespace observability \
        --create-namespace \
        --values '${local.project_dir}/prometheus/values.yaml' \
        --wait \
        --timeout 10m
    EOT
  }
}

resource "null_resource" "grafana" {
  depends_on = [
    null_resource.namespace,
    null_resource.prometheus,
    local_file.grafana_values
  ]

  triggers = {
    chart  = filesha256("${local.project_dir}/grafana/Chart.yaml")
    values = sha256(local.grafana_values)
  }

  provisioner "local-exec" {
    command = <<-EOT
      helm upgrade --install grafana '${local.project_dir}/grafana' \
        --namespace observability \
        --values '${path.module}/grafana-values.yaml' \
        --wait \
        --timeout 10m
    EOT
  }
}

resource "null_resource" "jaeger" {
  depends_on = [null_resource.namespace]

  triggers = {
    values = filesha256("${local.project_dir}/jaeger/values.yaml")
  }

  provisioner "local-exec" {
    command = <<-EOT
      helm repo add jaegertracing https://jaegertracing.github.io/helm-charts --force-update
      helm repo update

      helm upgrade --install jaeger jaegertracing/jaeger \
        --namespace observability \
        --values '${local.project_dir}/jaeger/values.yaml' \
        --wait \
        --timeout 10m
    EOT
  }
}

resource "null_resource" "otel_collector" {
  depends_on = [
    null_resource.namespace,
    null_resource.jaeger
  ]

  triggers = {
    values = filesha256("${local.project_dir}/otel-collector/values.yaml")
  }

  provisioner "local-exec" {
    command = <<-EOT
      helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts --force-update
      helm repo update

      helm upgrade --install otel-collector open-telemetry/opentelemetry-collector \
        --namespace observability \
        --values '${local.project_dir}/otel-collector/values.yaml' \
        --wait \
        --timeout 10m
    EOT
  }
}

resource "null_resource" "argocd" {
  depends_on = [null_resource.namespace, null_resource.kind_cluster, null_resource.gateway_api]

  triggers = {
    values = filesha256("${local.project_dir}/argo-cd/values.yaml")
  }

  provisioner "local-exec" {
    command = <<-EOT
      helm repo add argo https://argoproj.github.io/argo-helm --force-update
      helm repo update

      helm upgrade --install argocd argo/argo-cd \
        --namespace argocd \
        --create-namespace \
        --values '${local.project_dir}/argo-cd/values.yaml' \
        --wait \
        --timeout 10m
    EOT
  }
}

resource "null_resource" "networking" {
  depends_on = [
    null_resource.traefik,
    null_resource.grafana,
    null_resource.otel_collector,
    null_resource.jaeger,
    null_resource.argocd
  ]

  triggers = {
    gateway       = filesha256("${local.project_dir}/traefik/gateway.yaml")
    grafana_route = filesha256("${local.project_dir}/traefik/routes/grafana-route.yaml")
    otel_route    = filesha256("${local.project_dir}/traefik/routes/otel-route.yaml")
    argocd_route  = filesha256("${local.project_dir}/traefik/routes/argocd-route.yaml")
    jaeger_route  = filesha256("${local.project_dir}/traefik/routes/jaeger-route.yaml")
  }

  provisioner "local-exec" {
    command = <<-EOT
      kubectl apply -f '${local.project_dir}/traefik/gateway.yaml'
      kubectl apply -f '${local.project_dir}/traefik/routes/grafana-route.yaml'
      kubectl apply -f '${local.project_dir}/traefik/routes/otel-route.yaml'
      kubectl apply -f '${local.project_dir}/traefik/routes/jaeger-route.yaml'
      kubectl apply -f '${local.project_dir}/traefik/routes/argocd-route.yaml'
    EOT
  }
}
