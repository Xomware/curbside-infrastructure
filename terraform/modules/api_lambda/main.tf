# One API route backed by its own function, role and log group. Terraform owns
# the configuration; curbside-backend's deploy workflow owns code and layers.

variable "app_name" {
  description = "Function name prefix."
  type        = string
}

variable "name" {
  description = "Handler folder under curbside-backend lambdas/, e.g. me_get."
  type        = string
}

variable "description" {
  description = "Function description."
  type        = string
}

variable "route_key" {
  description = "HTTP API route, e.g. \"GET /me\"."
  type        = string
}

variable "api" {
  description = "The HTTP API and its JWT authorizer."
  type = object({
    id            = string
    execution_arn = string
    authorizer_id = string
  })
}

variable "runtime" {
  description = "Lambda runtime; must match the layer's."
  type        = string
}

variable "layer_arn" {
  description = "Initial shared layer. The deploy workflow swaps it afterwards."
  type        = string
}

variable "environment" {
  description = "Function environment variables."
  type        = map(string)
}

variable "policy_json" {
  description = "Grants beyond writing to its own log group."
  type        = string
}

locals {
  # The deploy workflow maps folder me_get to function curbside-me-get.
  function_name = "${var.app_name}-${replace(var.name, "_", "-")}"
}

resource "aws_cloudwatch_log_group" "this" {
  name              = "/aws/lambda/${local.function_name}"
  retention_in_days = 30
}

data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "this" {
  name               = "${local.function_name}-exec"
  assume_role_policy = data.aws_iam_policy_document.assume.json
}

data "aws_iam_policy_document" "this" {
  source_policy_documents = [var.policy_json]

  statement {
    sid       = "Logs"
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["${aws_cloudwatch_log_group.this.arn}:*"]
  }
}

resource "aws_iam_role_policy" "this" {
  name   = "api"
  role   = aws_iam_role.this.id
  policy = data.aws_iam_policy_document.this.json
}

resource "aws_lambda_function" "this" {
  function_name = local.function_name
  description   = var.description
  role          = aws_iam_role.this.arn
  handler       = "handler.handler"
  runtime       = var.runtime
  memory_size   = 1024 # CPU scales with memory; pickem saw ~2 s cold starts at 256 MB
  timeout       = 10
  layers        = [var.layer_arn]

  filename         = "${path.root}/templates/lambda_stub.zip"
  source_code_hash = filebase64sha256("${path.root}/templates/lambda_stub.zip")

  environment {
    variables = var.environment
  }

  # The backend logs with extra={...}; JSON format turns those into fields.
  logging_config {
    log_format = "JSON"
    log_group  = aws_cloudwatch_log_group.this.name
  }

  lifecycle {
    ignore_changes = [filename, source_code_hash, layers]
  }
}

resource "aws_apigatewayv2_integration" "this" {
  api_id                 = var.api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.this.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "this" {
  api_id             = var.api.id
  route_key          = var.route_key
  target             = "integrations/${aws_apigatewayv2_integration.this.id}"
  authorization_type = "JWT"
  authorizer_id      = var.api.authorizer_id
}

resource "aws_lambda_permission" "this" {
  statement_id  = "AllowApiGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.this.function_name
  principal     = "apigateway.amazonaws.com"
  # Scoped to this route; path parameters such as {mapId} become *.
  source_arn = "${var.api.execution_arn}/*/${replace(replace(var.route_key, " ", ""), "/\\{[^}]+\\}/", "*")}"
}
