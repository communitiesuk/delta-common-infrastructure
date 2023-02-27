output "required_dns_records" {
  value = flatten([for base_domain in var.base_domains :
    [
      {
        record_name  = "delta.${base_domain}."
        record_type  = "CNAME"
        record_value = "${module.delta_cloudfront.cloudfront_domain_name}."
      },
      {
        record_name  = "api.delta.${base_domain}."
        record_type  = "CNAME"
        record_value = "${module.api_cloudfront.cloudfront_domain_name}."
      },
      {
        record_name  = "auth.delta.${base_domain}."
        record_type  = "CNAME"
        record_value = "${module.keycloak_cloudfront.cloudfront_domain_name}."
      },
      {
        record_name  = "cpm.${base_domain}."
        record_type  = "CNAME"
        record_value = "${module.cpm_cloudfront.cloudfront_domain_name}."
      },
      {
        record_name  = "reporting.delta.${base_domain}."
        record_type  = "CNAME"
        record_value = "${module.jaspersoft_cloudfront.cloudfront_domain_name}."
      },
    ]
  ])
}

output "delta_cloudfront_domain" {
  value = module.delta_cloudfront.cloudfront_domain_name
}

output "delta_cloudfront_distribution_id" {
  value = module.delta_cloudfront.cloudfront_distribution_id
}

output "delta_cloudfront_alarms" {
  value = module.delta_cloudfront.cloudfront_alarms
}

output "api_cloudfront_domain" {
  value = module.api_cloudfront.cloudfront_domain_name
}

output "api_cloudfront_distribution_id" {
  value = module.api_cloudfront.cloudfront_distribution_id
}

output "api_cloudfront_alarms" {
  value = module.api_cloudfront.cloudfront_alarms
}

output "keycloak_cloudfront_domain" {
  value = module.keycloak_cloudfront.cloudfront_domain_name
}

output "cpm_cloudfront_domain" {
  value = module.cpm_cloudfront.cloudfront_domain_name
}

output "jaspersoft_cloudfront_domain" {
  value = module.jaspersoft_cloudfront.cloudfront_domain_name
}
