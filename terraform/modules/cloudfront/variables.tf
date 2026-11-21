variable "name" { type = string }
variable "enabled" {
  type    = bool
  default = true
}
variable "frontend_buckets" {
  type = map(object({
    bucket               = string
    arn                  = string
    regional_domain_name = string
  }))
}
variable "media_bucket" {
  type = object({
    bucket               = string
    arn                  = string
    regional_domain_name = string
  })
}
variable "cors_allowed_origins" {
  type    = list(string)
  default = []
}

variable "api_origin_domain" {
  type    = string
  default = ""
}
variable "faro_enabled" {
  type    = bool
  default = false
}
variable "faro_origin_domain" {
  type    = string
  default = ""
}
variable "faro_origin_http_port" {
  type    = number
  default = 8080
}
variable "waf_web_acl_arn" {
  type    = string
  default = ""
}
variable "api_origin_protocol_policy" {
  type    = string
  default = "https-only"
}
variable "aliases" {
  type    = list(string)
  default = []
}
variable "certificate_arn" {
  type    = string
  default = ""
}
variable "default_root_object" {
  type    = string
  default = "index.html"
}
variable "price_class" {
  type    = string
  default = "PriceClass_100"
}
variable "tags" {
  type    = map(string)
  default = {}
}
