variable "aws_region" {
  type    = string
  default = "us-east-1"
}
variable "project" {
  type    = string
  default = "platform"
}
variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}
variable "az_count" {
  type    = number
  default = 2
}
variable "kubernetes_version" {
  type    = string
  default = "1.35"
}
variable "node_instance_types" {
  type    = list(string)
  default = ["t3.medium"]
}
variable "node_capacity_type" {
  type        = string
  default     = "ON_DEMAND"
  description = "ON_DEMAND or SPOT for the managed node group."
  validation {
    condition     = contains(["ON_DEMAND", "SPOT"], var.node_capacity_type)
    error_message = "node_capacity_type must be ON_DEMAND or SPOT."
  }
}
variable "node_desired_size" {
  type    = number
  default = 2
}
variable "node_min_size" {
  type    = number
  default = 2
}
variable "node_max_size" {
  type    = number
  default = 6
}
variable "rds_instance_class" {
  type    = string
  default = "db.t4g.micro"
}
variable "rds_allocated_storage" {
  type    = number
  default = 20
}
variable "redis_node_type" {
  type    = string
  default = "cache.t4g.micro"
}
variable "domain_name" {
  type    = string
  default = ""
}
variable "api_domain_name" {
  type    = string
  default = ""
}
variable "hosted_zone_id" {
  type    = string
  default = ""
}
variable "cloudfront_api_origin_domain" {
  type    = string
  default = ""
}

variable "cloudfront_api_origin_protocol_policy" {
  type    = string
  default = "http-only"
}

variable "create_dns" {
  type    = bool
  default = false
}
variable "acm_certificate_arn" {
  type    = string
  default = ""
}
variable "admin_principal_arn" {
  type    = string
  default = ""
}
variable "cors_allowed_origins" {
  type    = list(string)
  default = []
}
variable "enable_cloudfront" {
  type    = bool
  default = true
}
variable "protect_state" {
  type        = bool
  default     = true
  description = "Keep RDS deletion protection, the final snapshot, S3 object versions and ECR images. Apply with false before destroying the stack."
}

variable "enable_observability" {
  type        = bool
  default     = false
  description = "Prepare EBS CSI and Secrets Manager containers for the Grafana stack. Does not deploy Grafana."
}
