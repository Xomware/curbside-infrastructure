locals {
  capture_lambdas = {
    capture_parse = {
      route_key   = "POST /maps/{mapId}/capture/parse"
      description = "Parse a transcript into proposed operations with Claude Haiku; persists nothing"
      timeout     = 29
    }
    capture_apply = {
      route_key   = "POST /maps/{mapId}/capture/apply"
      description = "Apply confirmed operations in one version-checked transaction"
      timeout     = 10
    }
  }

  capture_env = {
    capture_parse = { ANTHROPIC_API_KEY_PARAM = aws_ssm_parameter.anthropic_api_key.name }
  }
}

# Read-only on the table except its own daily QUOTA# counter, whose attribute
# names B9 must match. Only parse can read the API key.
data "aws_iam_policy_document" "capture_parse" {
  source_policy_documents = [data.aws_iam_policy_document.table_key.json]

  statement {
    sid       = "Read"
    actions   = ["dynamodb:GetItem", "dynamodb:Query"]
    resources = [aws_dynamodb_table.main.arn]
  }

  statement {
    sid       = "Quota"
    actions   = ["dynamodb:UpdateItem"]
    resources = [aws_dynamodb_table.main.arn]

    condition {
      test     = "ForAllValues:StringLike"
      variable = "dynamodb:LeadingKeys"
      values   = ["ACCT#*"]
    }

    condition {
      test     = "ForAllValues:StringEquals"
      variable = "dynamodb:Attributes"
      values   = ["pk", "sk", "counter", "ttl"]
    }

    condition {
      test     = "StringEqualsIfExists"
      variable = "dynamodb:ReturnValues"
      values   = ["NONE", "UPDATED_OLD", "UPDATED_NEW"]
    }
  }

  statement {
    sid       = "AnthropicKey"
    actions   = ["ssm:GetParameter"]
    resources = [aws_ssm_parameter.anthropic_api_key.arn]
  }
}

data "aws_iam_policy_document" "capture_apply" {
  source_policy_documents = [data.aws_iam_policy_document.table_key.json]

  statement {
    sid = "Table"
    actions = [
      "dynamodb:GetItem",
      "dynamodb:Query",
      "dynamodb:PutItem",
      "dynamodb:UpdateItem",
      "dynamodb:ConditionCheckItem",
    ]
    resources = [aws_dynamodb_table.main.arn]
  }
}

module "capture" {
  source   = "./modules/api_lambda"
  for_each = local.capture_lambdas

  app_name    = var.app_name
  name        = each.key
  description = each.value.description
  route_key   = each.value.route_key
  timeout     = each.value.timeout
  api         = local.api
  runtime     = var.lambda_runtime
  layer_arn   = aws_lambda_layer_version.shared.arn
  policy_json = each.key == "capture_parse" ? data.aws_iam_policy_document.capture_parse.json : data.aws_iam_policy_document.capture_apply.json
  environment = merge(local.lambda_env, try(local.capture_env[each.key], {}))
}
