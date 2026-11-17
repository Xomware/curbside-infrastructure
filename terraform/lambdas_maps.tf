# Map-scoped CRUD. Every handler but maps_list/maps_create runs require_member
# before touching the map's partition; IAM can't express that, the code does.
locals {
  maps_lambdas = {
    maps_list = {
      route_key     = "GET /maps"
      description   = "List the caller's maps"
      table_actions = ["dynamodb:GetItem", "dynamodb:Query", "dynamodb:BatchGetItem"]
    }
    maps_create = {
      route_key     = "POST /maps"
      description   = "Create a map and start its footprint fetch"
      table_actions = ["dynamodb:GetItem", "dynamodb:PutItem"]
    }
    maps_get = {
      route_key     = "GET /maps/{mapId}"
      description   = "Return a map with its households, people and pets"
      table_actions = ["dynamodb:GetItem", "dynamodb:Query"]
    }
    maps_update = {
      route_key     = "PATCH /maps/{mapId}"
      description   = "Update a map's name, center or radius"
      table_actions = ["dynamodb:GetItem", "dynamodb:UpdateItem"]
    }
    maps_delete = {
      route_key     = "DELETE /maps/{mapId}"
      description   = "Delete a map, everything in it and its footprint files"
      table_actions = ["dynamodb:GetItem", "dynamodb:Query", "dynamodb:DeleteItem", "dynamodb:BatchWriteItem"]
    }
    households_create = {
      route_key     = "POST /maps/{mapId}/households"
      description   = "Create a household"
      table_actions = ["dynamodb:GetItem", "dynamodb:PutItem"]
    }
    households_get = {
      route_key     = "GET /maps/{mapId}/households/{hhId}"
      description   = "Return a household, its people and pets, and recent notes"
      table_actions = ["dynamodb:GetItem", "dynamodb:Query"]
    }
    households_update = {
      route_key     = "PATCH /maps/{mapId}/households/{hhId}"
      description   = "Update a household"
      table_actions = ["dynamodb:GetItem", "dynamodb:UpdateItem"]
    }
    households_delete = {
      route_key     = "DELETE /maps/{mapId}/households/{hhId}"
      description   = "Delete a household and its people, pets and notes"
      table_actions = ["dynamodb:GetItem", "dynamodb:Query", "dynamodb:DeleteItem", "dynamodb:BatchWriteItem"]
    }
    people_create = {
      route_key     = "POST /maps/{mapId}/households/{hhId}/people"
      description   = "Add a person to a household"
      table_actions = ["dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:ConditionCheckItem"]
    }
    people_update = {
      route_key     = "PATCH /maps/{mapId}/households/{hhId}/people/{personId}"
      description   = "Update a person"
      table_actions = ["dynamodb:GetItem", "dynamodb:UpdateItem"]
    }
    people_delete = {
      route_key     = "DELETE /maps/{mapId}/households/{hhId}/people/{personId}"
      description   = "Remove a person"
      table_actions = ["dynamodb:GetItem", "dynamodb:DeleteItem"]
    }
    pets_create = {
      route_key     = "POST /maps/{mapId}/households/{hhId}/pets"
      description   = "Add a pet to a household"
      table_actions = ["dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:ConditionCheckItem"]
    }
    pets_update = {
      route_key     = "PATCH /maps/{mapId}/households/{hhId}/pets/{petId}"
      description   = "Update a pet"
      table_actions = ["dynamodb:GetItem", "dynamodb:UpdateItem"]
    }
    pets_delete = {
      route_key     = "DELETE /maps/{mapId}/households/{hhId}/pets/{petId}"
      description   = "Remove a pet"
      table_actions = ["dynamodb:GetItem", "dynamodb:DeleteItem"]
    }
    notes_create = {
      route_key     = "POST /maps/{mapId}/households/{hhId}/notes"
      description   = "Add a note and touch the household's last_talked_at"
      table_actions = ["dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:UpdateItem"]
    }
    notes_delete = {
      route_key     = "DELETE /maps/{mapId}/households/{hhId}/notes/{noteId}"
      description   = "Delete a note"
      table_actions = ["dynamodb:GetItem", "dynamodb:DeleteItem"]
    }
  }

  maps_env = {
    # Async-invoked; the function is in lambdas_footprints.tf.
    maps_create = { FOOTPRINTS_FETCH_FUNCTION = "${var.app_name}-footprints-fetch" }
    maps_delete = { FOOTPRINTS_BUCKET = aws_s3_bucket.footprints.id }
  }
}

data "aws_iam_policy_document" "maps" {
  for_each = local.maps_lambdas

  source_policy_documents = concat(
    [data.aws_iam_policy_document.table_key.json],
    each.key == "maps_delete" ? [data.aws_iam_policy_document.footprints_delete.json] : [],
  )

  statement {
    sid       = "Table"
    actions   = each.value.table_actions
    resources = [aws_dynamodb_table.main.arn, "${aws_dynamodb_table.main.arn}/index/gsi1"]
  }
}

module "maps" {
  source   = "./modules/api_lambda"
  for_each = local.maps_lambdas

  app_name    = var.app_name
  name        = each.key
  description = each.value.description
  route_key   = each.value.route_key
  api         = local.api
  runtime     = var.lambda_runtime
  layer_arn   = aws_lambda_layer_version.shared.arn
  environment = merge(local.lambda_env, try(local.maps_env[each.key], {}))
  policy_json = data.aws_iam_policy_document.maps[each.key].json
}
