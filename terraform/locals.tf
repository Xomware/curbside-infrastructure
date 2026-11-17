locals {
  standard_tags = {
    source      = "terraform"
    project     = var.app_name
    environment = var.environment
    owner       = var.owner
  }

  account_id      = data.aws_caller_identity.current.account_id
  api_domain_name = "api.${var.app_name}.${var.route53_zone_name}"

  lambda_env = {
    TABLE_NAME = aws_dynamodb_table.main.name
  }
}
