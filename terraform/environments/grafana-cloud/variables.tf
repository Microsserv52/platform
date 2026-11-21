variable "grafana_url" {
  type        = string
  description = "Grafana Cloud stack URL, for example https://example.grafana.net."
}

variable "grafana_auth" {
  type        = string
  sensitive   = true
  description = "Grafana service-account token. Use GRAFANA_AUTH rather than a tfvars file."
}

variable "grafana_sm_access_token" {
  type        = string
  sensitive   = true
  default     = ""
  description = "Synthetic Monitoring access token from the Grafana Cloud stack."
}

variable "grafana_sm_url" {
  type        = string
  default     = ""
  description = "Synthetic Monitoring API URL for the stack region."
}

variable "folder_name" {
  type    = string
  default = "Platform"
}

variable "prometheus_datasource_uid" {
  type        = string
  default     = "prometheus"
  description = "UID of the Grafana Cloud Prometheus datasource used by alert rules."
}

variable "alert_email" {
  type        = string
  default     = "ops@example.invalid"
  description = "Default alert recipient. Keep the real value in a secure variable store."
}

variable "public_base_url" {
  type        = string
  default     = "https://d15ogksm4jp6sl.cloudfront.net"
  description = "Public application origin used by synthetic checks."
}

variable "probe_names" {
  type        = list(string)
  default     = ["Frankfurt", "San Francisco"]
  description = "Grafana Cloud Synthetic Monitoring probe names to run checks from."
}

variable "enable_synthetic_checks" {
  type        = bool
  default     = true
  description = "Create Synthetic Monitoring HTTP checks for the public URLs."
}
