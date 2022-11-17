variable "prefix" {
  description = "Name prefix for all resources"
  type        = string
}

variable "access_logs_bucket_domain_name" {
  type = string
}

variable "access_logs_prefix" {
  type = string
}

variable "waf_acl_arn" {
  type = string
}

variable "cloudfront_key" {
  type      = string
  sensitive = true
}

variable "origin_domain" {
  type = string
}

variable "cloudfront_domain" {
  type = object({
    aliases             = list(string),
    acm_certificate_arn = string
  })
  default = null
}
