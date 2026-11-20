# Street sharing: single-use invites (INVITE#<code>) and map membership. A map
# has one owner; invited accounts join as "member" and can edit but not delete.
# Role checks live in the handlers; IAM can't express them.
locals {
  invites_lambdas = {
    invites_create = {
      route_key     = "POST /maps/{mapId}/invites"
      description   = "Create a single-use invite to co-edit a map, owner only"
      table_actions = ["dynamodb:GetItem", "dynamodb:PutItem"]
    }
    invites_get = {
      route_key     = "GET /invites/{code}"
      description   = "Describe an invite for the accept screen"
      table_actions = ["dynamodb:GetItem"]
    }
    invites_accept = {
      route_key   = "POST /invites/{code}/accept"
      description = "Join a map as a member and spend the invite"
      # One transaction: Delete invite, Put MEMBER, ConditionCheck META.
      table_actions = ["dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:DeleteItem", "dynamodb:ConditionCheckItem"]
    }
    members_list = {
      route_key     = "GET /maps/{mapId}/members"
      description   = "List a map's members with display names, owner first"
      table_actions = ["dynamodb:GetItem", "dynamodb:Query", "dynamodb:BatchGetItem"]
    }
    members_delete = {
      route_key     = "DELETE /maps/{mapId}/members/{accountId}"
      description   = "Remove a member from a map, or leave it"
      table_actions = ["dynamodb:GetItem", "dynamodb:DeleteItem"]
    }
  }
}

data "aws_iam_policy_document" "invites" {
  for_each                = local.invites_lambdas
  source_policy_documents = [data.aws_iam_policy_document.table_key.json]

  statement {
    sid       = "Table"
    actions   = each.value.table_actions
    resources = [aws_dynamodb_table.main.arn]
  }
}

module "invites" {
  source   = "./modules/api_lambda"
  for_each = local.invites_lambdas

  app_name    = var.app_name
  name        = each.key
  description = each.value.description
  route_key   = each.value.route_key
  api         = local.api
  runtime     = var.lambda_runtime
  layer_arn   = aws_lambda_layer_version.shared.arn
  environment = local.lambda_env
  policy_json = data.aws_iam_policy_document.invites[each.key].json
}
