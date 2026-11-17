resource "aws_ssm_parameter" "cognito_user_pool_id" {
  name  = "/${var.app_name}/cognito/user-pool-id"
  type  = "String"
  value = aws_cognito_user_pool.main.id
}

resource "aws_ssm_parameter" "cognito_ios_client_id" {
  name  = "/${var.app_name}/cognito/ios-client-id"
  type  = "String"
  value = aws_cognito_user_pool_client.ios.id
}

resource "aws_ssm_parameter" "cognito_web_client_id" {
  name  = "/${var.app_name}/cognito/web-client-id"
  type  = "String"
  value = aws_cognito_user_pool_client.web.id
}

resource "aws_ssm_parameter" "cognito_domain" {
  name  = "/${var.app_name}/cognito/domain"
  type  = "String"
  value = "${aws_cognito_user_pool_domain.main.domain}.auth.${var.aws_region}.amazoncognito.com"
}

resource "aws_ssm_parameter" "api_url" {
  name  = "/${var.app_name}/api/url"
  type  = "String"
  value = "https://${local.api_domain_name}/${aws_apigatewayv2_api_mapping.v1.api_mapping_key}"
}

# me_delete signs Apple's /auth/revoke client secret with the same .p8 the IdP
# uses (RESEARCH.md §6).
resource "aws_ssm_parameter" "apple_private_key" {
  name  = "/${var.app_name}/apple/private-key"
  type  = "SecureString"
  value = var.apple_private_key
}

resource "aws_ssm_parameter" "anthropic_api_key" {
  name  = "/${var.app_name}/anthropic/api-key"
  type  = "SecureString"
  value = var.anthropic_api_key
}
