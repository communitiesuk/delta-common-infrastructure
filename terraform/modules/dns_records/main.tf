# Create a set of DNS records from a hosted zone we manage

variable "records" {
  type = list(object({
    record_name  = string
    record_type  = string
    record_value = string
  }))
}

variable "hosted_zone_id" {
  type = string
}

variable "ttl" {
  type    = number
  default = 60
}

resource "aws_route53_record" "records" {
  for_each = { for r in var.records : "${r.record_type}_${r.record_name}" => r }
  zone_id  = var.hosted_zone_id
  name     = each.value.record_name
  type     = each.value.record_type
  ttl      = var.ttl
  records  = [each.value.record_value]
}
