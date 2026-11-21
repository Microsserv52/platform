variable "cluster_id" { type = string }
variable "vpc_id" { type = string }
variable "subnet_ids" { type = list(string) }
variable "allowed_cidr_blocks" {
  type    = list(string)
  default = ["10.0.0.0/16"]
}
variable "engine_version" {
  type    = string
  default = "7.1"
}
variable "node_type" {
  type    = string
  default = "cache.t4g.micro"
}
variable "parameter_group_name" {
  type    = string
  default = "default.redis7"
}
variable "tags" {
  type    = map(string)
  default = {}
}
