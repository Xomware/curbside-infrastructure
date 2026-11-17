# TransactWriteItems has no IAM action of its own: each item in it is
# authorized as PutItem, UpdateItem, DeleteItem or ConditionCheckItem.
locals {
  me_lambdas = {
    me_get = {
      route_key     = "GET /me"
      description   = "Return the caller's account and its identities"
      table_actions = ["dynamodb:GetItem", "dynamodb:Query"]
    }
    me_create = {
      route_key     = "POST /me"
      description   = "Create the caller's account, idempotent per sub"
      table_actions = ["dynamodb:GetItem", "dynamodb:PutItem"]
    }
  }
}

data "aws_iam_policy_document" "me" {
  for_each                = local.me_lambdas
  source_policy_documents = [data.aws_iam_policy_document.table_key.json]

  statement {
    sid       = "Table"
    actions   = each.value.table_actions
    resources = [aws_dynamodb_table.main.arn]
  }
}

module "me" {
  source   = "./modules/api_lambda"
  for_each = local.me_lambdas

  app_name    = var.app_name
  name        = each.key
  description = each.value.description
  route_key   = each.value.route_key
  api         = local.api
  runtime     = var.lambda_runtime
  layer_arn   = aws_lambda_layer_version.shared.arn
  environment = local.lambda_env
  policy_json = data.aws_iam_policy_document.me[each.key].json
}
