variable "aws_region" {
  type    = string
  default = "us-east-1"
}
variable "localstack_endpoint" {
  type    = string
  default = "http://localhost:4566"
}
variable "project" {
  type    = string
  default = "platform"
}
variable "enable_rds" {
  type    = bool
  default = true
}
variable "enable_elasticache" {
  type    = bool
  default = true
}
variable "enable_eks" {
  type    = bool
  default = true
}
variable "enable_cloudfront" {
  type    = bool
  default = true
}
