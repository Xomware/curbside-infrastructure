locals {
  auth_domain_name = "auth.${local.web_domain_name}"
}

# Cognito takes custom-domain certs from us-east-1 only, which is the
# provider's region here.
resource "aws_acm_certificate" "auth" {
  domain_name       = local.auth_domain_name
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "auth_cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.auth.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  zone_id = data.aws_route53_zone.main.zone_id
  name    = each.value.name
  type    = each.value.type
  records = [each.value.record]
  ttl     = 60
}

resource "aws_acm_certificate_validation" "auth" {
  certificate_arn         = aws_acm_certificate.auth.arn
  validation_record_fqdns = [for r in aws_route53_record.auth_cert_validation : r.fqdn]
}

# Sits beside the prefix domain, which keeps working: clients and the IdP
# consoles stay on it until they're switched over. With both present the
# pool's discovery document advertises only this one, but no client or the
# API authorizer reads it for endpoints.
#
# Cognito refuses a custom domain whose parent has no A record; the web
# module owns curbside.xomware.com's.
resource "aws_cognito_user_pool_domain" "custom" {
  domain          = local.auth_domain_name
  certificate_arn = aws_acm_certificate_validation.auth.certificate_arn
  user_pool_id    = aws_cognito_user_pool.main.id

  depends_on = [module.web]
}

resource "aws_route53_record" "auth" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = local.auth_domain_name
  type    = "A"

  alias {
    name                   = aws_cognito_user_pool_domain.custom.cloudfront_distribution
    zone_id                = aws_cognito_user_pool_domain.custom.cloudfront_distribution_zone_id
    evaluate_target_health = false
  }
}
