variable "cluster_name" { type = string }
variable "kubernetes_version" {
  type    = string
  default = "1.35"
}
variable "vpc_id" { type = string }
variable "subnet_ids" { type = list(string) }
variable "endpoint_public_access" {
  type    = bool
  default = true
}
variable "create_node_group" {
  type    = bool
  default = true
}
variable "node_instance_types" {
  type    = list(string)
  default = ["t3.small"]
}
variable "node_capacity_type" {
  type    = string
  default = "ON_DEMAND"
}
variable "node_desired_size" {
  type    = number
  default = 2
}
variable "node_min_size" {
  type    = number
  default = 1
}
variable "node_max_size" {
  type    = number
  default = 4
}
variable "create_oidc_provider" {
  type    = bool
  default = true
}
variable "create_irsa" {
  type    = bool
  default = true
}
variable "namespace" {
  type    = string
  default = "platform"
}
variable "service_account" {
  type    = string
  default = "product"
}
variable "media_bucket_arn" {
  type    = string
  default = ""
}
variable "admin_principal_arn" {
  type    = string
  default = ""
}
variable "tags" {
  type    = map(string)
  default = {}
}

variable "create_cluster_autoscaler" {
  type        = bool
  default     = false
  description = "Create the IRSA role used by Cluster Autoscaler."
}

variable "cluster_autoscaler_namespace" {
  type    = string
  default = "kube-system"
}

variable "cluster_autoscaler_service_account" {
  type    = string
  default = "cluster-autoscaler"
}
