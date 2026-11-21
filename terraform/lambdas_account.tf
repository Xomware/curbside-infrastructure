# Sign-in linking, export and hard delete. App Store 5.1.1(v) needs the last two.
locals {
  account_lambdas = {
    me_link = {
      route_key     = "POST /me/identities"
      description   = "Link a second sign-in to the caller's account"
      table_actions = ["dynamodb:GetItem", "dynamodb:PutItem"]
      timeout       = 10
    }
    me_unlink = {
      route_key     = "DELETE /me/identities/{sub}"
      description   = "Unlink a sign-in, never the last one"
      table_actions = ["dynamodb:GetItem", "dynamodb:Query", "dynamodb:DeleteItem"]
      timeout       = 10
    }
    me_export = {
      route_key     = "GET /me/export"
      description   = "Export everything the caller's account owns as JSON"
      table_actions = ["dynamodb:GetItem", "dynamodb:Query"]
      timeout       = 29
    }
    me_delete = {
      route_key   = "DELETE /me"
      description = "Revoke Apple tokens, hand shared maps on, then hard-delete the account and its Cognito users"
      # UpdateItem: promoting the next member to owner when the owner leaves a shared map.
      # PutItem: ACTIVITY# for the heir. Friend and device edges go on both sides.
      table_actions = [
        "dynamodb:GetItem", "dynamodb:Query", "dynamodb:PutItem", "dynamodb:UpdateItem",
        "dynamodb:DeleteItem", "dynamodb:ConditionCheckItem", "dynamodb:BatchWriteItem",
      ]
      timeout = 29
    }
  }

  account_env = {
    # me_link verifies the second provider's ID token against the pool JWKS.
    # The web client's ID joins CLIENT_IDS when it exists.
    me_link = {
      USER_POOL_ID = aws_cognito_user_pool.main.id
      CLIENT_IDS   = aws_cognito_user_pool_client.ios.id
    }
    me_delete = {
      USER_POOL_ID            = aws_cognito_user_pool.main.id
      APPLE_SERVICES_ID       = var.apple_services_id
      APPLE_TEAM_ID           = var.apple_team_id
      APPLE_KEY_ID            = var.apple_key_id
      APPLE_PRIVATE_KEY_PARAM = aws_ssm_parameter.apple_private_key.name
      FOOTPRINTS_BUCKET       = aws_s3_bucket.footprints.id
    }
  }
}

data "aws_iam_policy_document" "me_delete" {
  # IDENT items hold the Cognito sub, but the Admin* calls take the username,
  # which for federated users is "<provider>_<IdP sub>". ListUsers with a sub
  # filter maps one to the other.
  statement {
    sid       = "CognitoUsers"
    actions   = ["cognito-idp:ListUsers", "cognito-idp:AdminGetUser", "cognito-idp:AdminDeleteUser"]
    resources = [aws_cognito_user_pool.main.arn]
  }

  statement {
    sid       = "AppleKey"
    actions   = ["ssm:GetParameter"]
    resources = [aws_ssm_parameter.apple_private_key.arn]
  }
}

data "aws_iam_policy_document" "account" {
  for_each = local.account_lambdas

  source_policy_documents = concat(
    [data.aws_iam_policy_document.table_key.json],
    each.key == "me_delete" ? [
      data.aws_iam_policy_document.me_delete.json,
      data.aws_iam_policy_document.footprints_delete.json,
    ] : [],
  )

  statement {
    sid       = "Table"
    actions   = each.value.table_actions
    resources = [aws_dynamodb_table.main.arn, "${aws_dynamodb_table.main.arn}/index/gsi1"]
  }
}

module "account" {
  source   = "./modules/api_lambda"
  for_each = local.account_lambdas

  app_name    = var.app_name
  name        = each.key
  description = each.value.description
  route_key   = each.value.route_key
  timeout     = each.value.timeout
  api         = local.api
  runtime     = var.lambda_runtime
  layer_arn   = aws_lambda_layer_version.shared.arn
  environment = merge(local.lambda_env, try(local.account_env[each.key], {}))
  policy_json = data.aws_iam_policy_document.account[each.key].json
}
