# Web-only admin. The is_admin check lives in the handlers (require_admin);
# the stats and lists Scan the whole table, which nothing else is allowed to do.
locals {
  admin_lambdas = {
    admin_stats = {
      route_key     = "GET /admin/stats"
      description   = "Count accounts, streets and their contents"
      table_actions = ["dynamodb:GetItem", "dynamodb:Scan"]
    }
    admin_accounts_list = {
      route_key     = "GET /admin/accounts"
      description   = "List every account, newest first"
      table_actions = ["dynamodb:GetItem", "dynamodb:Scan", "dynamodb:Query", "dynamodb:BatchGetItem"]
    }
    admin_maps_list = {
      route_key     = "GET /admin/maps"
      description   = "List every street, newest first"
      table_actions = ["dynamodb:GetItem", "dynamodb:Scan", "dynamodb:Query", "dynamodb:BatchGetItem"]
    }
    admin_maps_delete = {
      route_key     = "DELETE /admin/maps/{mapId}"
      description   = "Delete any street, everything in it and its footprint files"
      table_actions = ["dynamodb:GetItem", "dynamodb:Query", "dynamodb:DeleteItem", "dynamodb:BatchWriteItem"]
    }
  }
}

data "aws_iam_policy_document" "admin" {
  for_each = local.admin_lambdas

  source_policy_documents = concat(
    [data.aws_iam_policy_document.table_key.json],
    each.key == "admin_maps_delete" ? [data.aws_iam_policy_document.footprints_delete.json] : [],
  )

  statement {
    sid       = "Table"
    actions   = each.value.table_actions
    resources = [aws_dynamodb_table.main.arn, "${aws_dynamodb_table.main.arn}/index/gsi1"]
  }
}

module "admin" {
  source   = "./modules/api_lambda"
  for_each = local.admin_lambdas

  app_name    = var.app_name
  name        = each.key
  description = each.value.description
  route_key   = each.value.route_key
  timeout     = 29
  api         = local.api
  runtime     = var.lambda_runtime
  layer_arn   = aws_lambda_layer_version.shared.arn
  environment = merge(local.lambda_env, each.key == "admin_maps_delete" ? { FOOTPRINTS_BUCKET = aws_s3_bucket.footprints.id } : {})
  policy_json = data.aws_iam_policy_document.admin[each.key].json
}
