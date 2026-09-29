# Progressive Delivery Canary Kubernetes

![Kubernetes](https://img.shields.io/badge/Kubernetes-326CE5?style=for-the-badge&logo=kubernetes&logoColor=white)
![Terraform](https://img.shields.io/badge/Terraform-844FBA?style=for-the-badge&logo=terraform&logoColor=white)
![Argo CD](https://img.shields.io/badge/Argo%20CD-EF7B4D?style=for-the-badge&logo=argo&logoColor=white)
![Traefik](https://img.shields.io/badge/Traefik-24A1C1?style=for-the-badge&logo=traefikproxy&logoColor=white)
![Prometheus](https://img.shields.io/badge/Prometheus-E6522C?style=for-the-badge&logo=prometheus&logoColor=white)
![Grafana](https://img.shields.io/badge/Grafana-F46800?style=for-the-badge&logo=grafana&logoColor=white)
![Jaeger](https://img.shields.io/badge/Jaeger-66CFE3?style=for-the-badge&logo=jaeger&logoColor=white)
![OpenTelemetry](https://img.shields.io/badge/OpenTelemetry-000000?style=for-the-badge&logo=opentelemetry&logoColor=white)

Infrastructure for a Kubernetes-based **progressive delivery and canary deployment** demonstration.

The project deploys a sample application alongside an observability stack that allows stable and canary deployments to be compared through request traffic, latency, errors, metrics, and traces.

## Architecture

                         Incoming traffic
                               │
                               ▼
                       ┌──────────────┐
                       │    Traefik   │
                       │ Gateway API  │
                       └───────┬──────┘
                               │
                  ┌────────────┴────────────┐
                  │                         │
                  ▼                         ▼
           ┌─────────────┐           ┌─────────────┐
           │   Stable    │           │   Canary    │
           │ Deployment  │           │ Deployment  │
           └──────┬──────┘           └──────┬──────┘
                  │                         │
                  └────────────┬────────────┘
                               │
                               ▼
                      ┌─────────────────┐
                      │  OpenTelemetry  │
                      │    Collector    │
                      └────────┬────────┘
                               │
                  ┌────────────┴────────────┐
                  │                         │
                  ▼                         ▼
             ┌─────────┐              ┌────────────┐
             │  Jaeger │              │ Prometheus │
             └─────────┘              └──────┬─────┘
                                             │
                                             ▼
                                        ┌─────────┐
                                        │ Grafana │
                                        └─────────┘

Argo CD manages the application deployment while Traefik handles HTTP traffic through the Kubernetes Gateway API.

## Components

| Component                   | Purpose                                               |
| --------------------------- | ----------------------------------------------------- |
| **Kind**                    | Local Kubernetes cluster                              |
| **Terraform**               | Infrastructure provisioning                           |
| **Argo CD**                 | GitOps application deployment                         |
| **Traefik**                 | Gateway API and traffic routing                       |
| **Prometheus**              | Metrics collection                                    |
| **Grafana**                 | Metrics visualisation                                 |
| **Jaeger**                  | Distributed tracing                                   |
| **OpenTelemetry Collector** | Telemetry collection and forwarding                   |
| **Cloudflare Tunnel**       | External access without exposing the cluster directly |

## Repository Structure

```text
.
├── app/                         # Git submodule
├── observability/
│   ├── argo-cd/
│   │   └── values.yaml
│   │
│   ├── grafana/
│   │   ├── Chart.lock
│   │   ├── Chart.yaml
│   │   ├── charts/
│   │   ├── provisioning/
│   │   ├── templates/
│   │   └── values.yaml.tftpl
│   │
│   ├── jaeger/
│   │   └── values.yaml
│   │
│   ├── kind.yaml.tftpl
│   ├── namespace.yaml
│   │
│   ├── otel-collector/
│   │   └── values.yaml
│   │
│   ├── prometheus/
│   │   └── values.yaml
│   │
│   ├── terraform/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── ...
│   │
│   └── traefik/
│       ├── gateway.yaml
│       ├── routes/
│       │   ├── argocd-route.yaml
│       │   ├── grafana-route.yaml
│       │   ├── jaeger-route.yaml
│       │   └── otel-route.yaml
│       └── values.yaml
│
└── README.md
```

## Application

The application is maintained as a separate Git repository and included here as a Git submodule.

**[progressive-delivery-canary-app](https://github.com/rubencosta13/progressive-delivery-canary-app)**

It is a Fastify application with endpoints specifically designed to generate:

- Normal requests
- HTTP 404 and 500 responses
- Application errors
- Random 503 failures
- Artificial latency
- Redirects

The `DEPLOYMENT_TRACK` environment variable identifies whether a request was handled by the stable or canary deployment.

## Progressive Delivery - TO BE DONE

The application can run as separate stable and canary deployments.

For example:

```text
             Incoming traffic
                    │
                    ▼
              ┌───────────┐
              │  Traefik  │
              └─────┬─────┘
                    │
           ┌────────┴────────┐
           │                 │
           ▼                 ▼
       ┌────────┐        ┌────────┐
       │ Stable │        │ Canary │
       │  90%   │        │  10%   │
       └────────┘        └────────┘
```

Traffic can be adjusted during a rollout to observe how the canary behaves under real application traffic.

The application exposes intentionally problematic endpoints so changes in:

- Request rate
- Error rate
- Response latency
- p95/p99 latency
- Distributed traces

can be observed in the monitoring stack.

## Observability

### Prometheus

Prometheus collects application and Kubernetes metrics.

### Grafana

Grafana provides dashboards for monitoring the deployment.

The dashboards include metrics such as:

- Request rate
- Error rate
- Response latency
- p50 latency
- p95 latency
- p99 latency
- Stable vs canary traffic

### OpenTelemetry

The application sends telemetry to the OpenTelemetry Collector.

The Collector forwards:

```text
Application
     │
     ▼
OpenTelemetry Collector
     │
     └──────► Jaeger
```

This allows individual requests to be inspected through distributed traces.

### Jaeger

Jaeger provides distributed tracing for investigating individual requests and latency.

## Infrastructure

The infrastructure is provisioned using Terraform.

The main infrastructure configuration is located at:

```text
observability/terraform/
```

Terraform manages:

- Kind cluster creation
- Kubernetes configuration
- Gateway API
- Traefik
- Prometheus
- Grafana
- Jaeger
- OpenTelemetry Collector
- Argo CD
- HTTP routes

## Requirements

Install the following tools:

- [Docker](https://www.docker.com/)
- [Kind](https://kind.sigs.k8s.io/)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [Helm](https://helm.sh/)
- [Terraform](https://developer.hashicorp.com/terraform)

## Getting Started

Clone the repository including the application submodule:

```bash
git clone --recurse-submodules https://github.com/rubencosta13/progressive-delivery-canary-k8s.git
cd progressive-delivery-canary-k8s
```

If the repository was already cloned:

```bash
git submodule update --init --recursive
```

Navigate to the Terraform configuration:

```bash
cd observability/terraform
```

Initialise Terraform:

```bash
terraform init
```

Review the planned changes:

```bash
terraform plan
```

Apply the infrastructure:

```bash
terraform apply
```

## Updating the Application

The application is tracked as a Git submodule, meaning this repository references a specific commit of the application repository.

To update it to the latest commit:

```bash
cd app
git pull origin main
cd ..

git add app
git commit -m "chore: update app submodule"
git push
```

This allows the infrastructure repository to explicitly track which application version is being deployed.

## Traffic Simulation

The traffic generation scripts are available through the application submodule:

```bash
cd app
```

Normal traffic:

```bash
./scripts/normal-payload.sh
```

Error traffic:

```bash
./scripts/error-traffic.sh
```

Load testing:

```bash
./scripts/load-test.sh
```

Simulated users:

```bash
./scripts/user-simulation.sh
```

Run all scenarios:

```bash
./scripts/all.sh
```

The scripts can be configured using environment variables such as `BASE_URL`.

## Goals

This project is intended to provide a practical demonstration of:

- Kubernetes deployments
- GitOps with Argo CD
- Progressive delivery
- Canary deployments
- Gateway API
- Traffic management
- Application observability
- Metrics with Prometheus
- Dashboards with Grafana
- Distributed tracing with OpenTelemetry and Jaeger
- Infrastructure as code with Terraform
