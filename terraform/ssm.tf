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
