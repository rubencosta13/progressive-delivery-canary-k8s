variable "server_ip" {
  description = "IP address of the Debian host"
  type        = string
}

variable "grafana_admin" {
  description = "Admin username for Grafana"
  type        = string
  sensitive   = true
}

variable "grafana_admin_password" {
  description = "Admin password for Grafana"
  type        = string
  sensitive   = true
}
