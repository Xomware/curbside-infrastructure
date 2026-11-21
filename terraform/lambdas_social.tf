# Activity feed, push devices and friends. Activity items (ACCT#<a>/ACTIVITY#...)
# are written by whichever handler caused them; push_send fans them out to
# devices from the table stream. Friend edges are written both ways in one
# transaction, so the friend handlers carry every transaction action.
locals {
  social_lambdas = {
    activity_list = {
      route_key     = "GET /activity"
      description   = "List the caller's newest activity with an unread count"
      table_actions = ["dynamodb:GetItem", "dynamodb:Query"]
    }
    activity_seen = {
      route_key     = "POST /activity/seen"
      description   = "Mark the caller's activity seen"
      table_actions = ["dynamodb:PutItem", "dynamodb:UpdateItem"]
    }
    devices_put = {
      route_key   = "PUT /devices/{token}"
      description = "Register a push token, re-homing it if another account had it"
      # Transaction: Put both device items, Delete the previous owner's.
      table_actions = ["dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:UpdateItem", "dynamodb:DeleteItem", "dynamodb:ConditionCheckItem"]
    }
    devices_delete = {
      route_key     = "DELETE /devices/{token}"
      description   = "Unregister a push token"
      table_actions = ["dynamodb:GetItem", "dynamodb:DeleteItem", "dynamodb:ConditionCheckItem"]
    }
    friends_list = {
      route_key     = "GET /friends"
      description   = "List the caller's friends with the streets they share"
      table_actions = ["dynamodb:GetItem", "dynamodb:Query", "dynamodb:BatchGetItem"]
    }
    friends_delete = {
      route_key     = "DELETE /friends/{accountId}"
      description   = "Remove a friend, both edges"
      table_actions = ["dynamodb:GetItem", "dynamodb:DeleteItem", "dynamodb:ConditionCheckItem"]
    }
    friend_invites_create = {
      route_key     = "POST /friends/invites"
      description   = "Create a single-use friend link"
      table_actions = ["dynamodb:GetItem", "dynamodb:PutItem"]
    }
    friend_invites_get = {
      route_key     = "GET /friends/invites/{code}"
      description   = "Describe a friend link for the accept screen"
      table_actions = ["dynamodb:GetItem"]
    }
    friend_invites_accept = {
      route_key   = "POST /friends/invites/{code}/accept"
      description = "Accept a friend link: both edges, spend the link, notify the creator"
      table_actions = [
        "dynamodb:GetItem", "dynamodb:Query", "dynamodb:BatchGetItem", "dynamodb:PutItem",
        "dynamodb:UpdateItem", "dynamodb:DeleteItem", "dynamodb:ConditionCheckItem",
      ]
    }
    members_create = {
      route_key   = "POST /maps/{mapId}/members"
      description = "Add a friend to a street and notify its members"
      table_actions = [
        "dynamodb:GetItem", "dynamodb:Query", "dynamodb:BatchGetItem", "dynamodb:PutItem",
        "dynamodb:UpdateItem", "dynamodb:ConditionCheckItem", "dynamodb:BatchWriteItem",
      ]
    }
  }
}

data "aws_iam_policy_document" "social" {
  for_each                = local.social_lambdas
  source_policy_documents = [data.aws_iam_policy_document.table_key.json]

  statement {
    sid       = "Table"
    actions   = each.value.table_actions
    resources = [aws_dynamodb_table.main.arn, "${aws_dynamodb_table.main.arn}/index/gsi1"]
  }
}

module "social" {
  source   = "./modules/api_lambda"
  for_each = local.social_lambdas

  app_name    = var.app_name
  name        = each.key
  description = each.value.description
  route_key   = each.value.route_key
  api         = local.api
  runtime     = var.lambda_runtime
  layer_arn   = aws_lambda_layer_version.shared.arn
  environment = local.lambda_env
  policy_json = data.aws_iam_policy_document.social[each.key].json
}
