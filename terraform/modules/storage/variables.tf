variable "name_prefix" { type = string }
variable "frontend_sites" {
  type    = list(string)
  default = ["landing", "store", "admin"]
}
variable "cors_allowed_origins" { type = list(string) }
variable "force_destroy" {
  type    = bool
  default = false
}
variable "tags" {
  type    = map(string)
  default = {}
}
