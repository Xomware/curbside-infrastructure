resource "aws_apigatewayv2_api" "main" {
  name          = var.app_name
  protocol_type = "HTTP"

  # Clients go through api.curbside.xomware.com/v1 only.
  disable_execute_api_endpoint = true

  # API Gateway answers preflights and overrides CORS headers from handlers,
  # so the backend sets none. iOS ignores CORS; this is for the web client.
  cors_configuration {
    allow_origins = var.cors_allow_origins
    allow_methods = ["GET", "POST", "PATCH", "DELETE"]
    allow_headers = ["authorization", "content-type"]
    max_age       = 3600
  }
}

# Cognito access tokens carry client_id instead of aud; the JWT authorizer
# matches either against the audience list.
resource "aws_apigatewayv2_authorizer" "cognito" {
  api_id           = aws_apigatewayv2_api.main.id
  name             = "cognito"
  authorizer_type  = "JWT"
  identity_sources = ["$request.header.Authorization"]

  jwt_configuration {
    issuer   = "https://${aws_cognito_user_pool.main.endpoint}"
    audience = [aws_cognito_user_pool_client.ios.id, aws_cognito_user_pool_client.web.id]
  }
}

resource "aws_cloudwatch_log_group" "api" {
  name              = "/aws/apigateway/${var.app_name}"
  retention_in_days = 30
}

resource "aws_apigatewayv2_stage" "v1" {
  api_id      = aws_apigatewayv2_api.main.id
  name        = "v1"
  auto_deploy = true

  # Request metadata only: no bodies, headers, query strings or source IPs.
  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api.arn
    format = jsonencode({
      requestId        = "$context.requestId"
      requestTime      = "$context.requestTime"
      routeKey         = "$context.routeKey"
      status           = "$context.status"
      latencyMs        = "$context.responseLatency"
      authorizerError  = "$context.authorizer.error"
      integrationError = "$context.integrationErrorMessage"
    })
  }
}

locals {
  api = {
    id            = aws_apigatewayv2_api.main.id
    execution_arn = aws_apigatewayv2_api.main.execution_arn
    authorizer_id = aws_apigatewayv2_authorizer.cognito.id
  }
}
