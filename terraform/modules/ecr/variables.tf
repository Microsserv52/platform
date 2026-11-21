variable "repository_names" { type = list(string) }
variable "image_tag_mutability" {
  type    = string
  default = "MUTABLE"
}
variable "force_delete" {
  type    = bool
  default = false
}
variable "tags" {
  type    = map(string)
  default = {}
}
