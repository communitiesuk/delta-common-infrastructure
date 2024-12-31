resource "aws_route53_record" "dns_record" {
  count = var.dns_config != null ? length(local.dns_record_types) : 0

  name    = var.dns_config.domain
  zone_id = var.dns_config.zone_id
  type    = local.dns_record_types[count.index]

  alias {
    evaluate_target_health = true
    name                   = aws_lb.bastion.dns_name
    zone_id                = aws_lb.bastion.zone_id
  }
}
