locals {
  web_domain_name = "${var.app_name}.${var.route53_zone_name}"
}

# Shared org-wide ACL, owned by xomware-infrastructure (waf.tf).
data "aws_ssm_parameter" "shared_cloudfront_waf_arn" {
  name = "/xomware/shared/cloudfront-waf-acl-arn"
}

# S3 + CloudFront + ACM + alias record. CloudFront only takes certs from
# us-east-1, and the module issues it in the provider's region.
#
# The SPA fallback maps 403 only. That covers unknown routes: OAC grants
# GetObject without ListBucket, so S3 answers a missing key with 403.
#
# SSE-S3: the bucket holds only the public bundle, so the CMK would add grants
# without protecting anything.
module "web" {
  source = "git::https://github.com/domgiordano/web-hosting.git?ref=v1.8.0"

  app_name            = var.app_name
  domain_name         = local.web_domain_name
  zone_id             = data.aws_route53_zone.main.zone_id
  waf_acl_arn         = data.aws_ssm_parameter.shared_cloudfront_waf_arn.value
  minimum_tls_version = "TLSv1.2_2021"
}
