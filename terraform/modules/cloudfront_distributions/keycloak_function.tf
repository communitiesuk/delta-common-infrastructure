resource "aws_cloudfront_function" "keycloak_request" {
  name    = "Remove-keycloak-auth-path-prefix-${var.environment}"
  runtime = "cloudfront-js-1.0"
  comment = "Support API users sending auth requests to e.g. <domain>/auth/realms/delta instead of <domain>/delta-api/oauth/token"
  publish = true
  code    = <<-EOT
  function handler(event) {
    var request = event.request;

    if (request.uri.includes('/realms/delta/protocol/openid-connect/token')) {
      request.uri = `/delta-api/oauth/token`
    }

    return request;
  }
  EOT
}
