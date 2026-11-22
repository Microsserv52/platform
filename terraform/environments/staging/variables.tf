variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "project" {
  type        = string
  default     = "platform-staging"
  description = "Resource name prefix. Keeps staging separate from the platform production resources."
}

variable "vpc_cidr" {
  type    = string
  default = "10.30.0.0/16"
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
  default = ["t3.xlarge"]
}

variable "node_capacity_type" {
  type        = string
  default     = "SPOT"
  description = "ON_DEMAND or SPOT for the single staging node."

  validation {
    condition     = contains(["ON_DEMAND", "SPOT"], var.node_capacity_type)
    error_message = "node_capacity_type must be ON_DEMAND or SPOT."
  }
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

variable "enable_nat_gateway" {
  type        = bool
  default     = true
  description = "Private nodes need outbound access for image pulls and AWS APIs."
}

variable "admin_principal_arn" {
  type        = string
  default     = ""
  description = "Optional IAM principal granted EKS cluster admin access."
}
