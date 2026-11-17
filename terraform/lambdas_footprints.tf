# Footprints Lambdas must never read household data, and IAM can't scope a
# sort key, so MAP#*/META can't be granted exactly. LeadingKeys keeps them to
# IDENT# and MAP# partitions; dynamodb:Attributes keeps what they can see in a
# map to the names listed below. A read of a household, person, pet or note
# item yields keys at most. The catch: every MAP# read must pass a
# ProjectionExpression within the list (require_member included), or it's denied.

data "aws_iam_policy_document" "caller_identity" {
  statement {
    sid       = "Identity"
    actions   = ["dynamodb:GetItem"]
    resources = [aws_dynamodb_table.main.arn]

    condition {
      test     = "ForAllValues:StringLike"
      variable = "dynamodb:LeadingKeys"
      values   = ["IDENT#*"]
    }
  }
}

data "aws_iam_policy_document" "invoke_fetch" {
  statement {
    sid       = "InvokeFetch"
    actions   = ["lambda:InvokeFunction"]
    resources = [module.footprints_fetch.function_arn]
  }
}

locals {
  footprints_lambdas = {
    footprints_get = {
      route_key   = "GET /maps/{mapId}/footprints"
      description = "Presigned URL and version of a map's footprint file"
      extra_policies = [
        data.aws_iam_policy_document.caller_identity.json,
        data.aws_iam_policy_document.footprints_read.json,
      ]
    }
    footprints_refresh = {
      route_key   = "POST /maps/{mapId}/footprints/refresh"
      description = "Mark a map's footprints pending and refetch them"
      extra_policies = [
        data.aws_iam_policy_document.caller_identity.json,
        data.aws_iam_policy_document.invoke_fetch.json,
      ]
    }
  }

  footprints_map_access = {
    footprints_fetch = {
      actions    = ["dynamodb:GetItem", "dynamodb:UpdateItem"]
      attributes = ["pk", "sk", "center", "radius_m", "footprint"]
    }
    footprints_get = {
      actions    = ["dynamodb:GetItem"]
      attributes = ["pk", "sk", "role", "footprint"]
    }
    footprints_refresh = {
      actions    = ["dynamodb:GetItem", "dynamodb:UpdateItem"]
      attributes = ["pk", "sk", "role", "footprint"]
    }
  }

  footprints_env = merge(local.lambda_env, {
    FOOTPRINTS_BUCKET         = aws_s3_bucket.footprints.id
    FOOTPRINTS_FETCH_FUNCTION = module.footprints_fetch.function_name
  })
}

data "aws_iam_policy_document" "footprints_map" {
  for_each = local.footprints_map_access

  source_policy_documents = [data.aws_iam_policy_document.table_key.json]

  statement {
    sid       = "MapMeta"
    actions   = each.value.actions
    resources = [aws_dynamodb_table.main.arn]

    condition {
      test     = "ForAllValues:StringLike"
      variable = "dynamodb:LeadingKeys"
      values   = ["MAP#*"]
    }

    condition {
      test     = "ForAllValues:StringEquals"
      variable = "dynamodb:Attributes"
      values   = each.value.attributes
    }

    condition {
      test     = "StringEqualsIfExists"
      variable = "dynamodb:Select"
      values   = ["SPECIFIC_ATTRIBUTES"]
    }

    condition {
      test     = "StringEqualsIfExists"
      variable = "dynamodb:ReturnValues"
      values   = ["NONE", "UPDATED_OLD", "UPDATED_NEW"]
    }
  }
}

data "aws_iam_policy_document" "footprints_read" {
  statement {
    sid       = "ReadFootprints"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.footprints.arn}/footprints/*"]
  }

  statement {
    sid       = "BucketKeyDecrypt"
    actions   = ["kms:Decrypt"]
    resources = [aws_kms_key.main.arn]

    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["s3.${var.aws_region}.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "footprints_fetch" {
  source_policy_documents = [data.aws_iam_policy_document.footprints_map["footprints_fetch"].json]

  statement {
    sid       = "WriteFootprints"
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.footprints.arn}/footprints/*"]
  }

  statement {
    sid       = "BucketKeyEncrypt"
    actions   = ["kms:GenerateDataKey", "kms:Decrypt"]
    resources = [aws_kms_key.main.arn]

    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["s3.${var.aws_region}.amazonaws.com"]
    }
  }

  statement {
    sid       = "FailureQueue"
    actions   = ["sqs:SendMessage"]
    resources = [aws_sqs_queue.footprints_fetch_failures.arn]
  }
}

# Async only: maps_create and footprints_refresh invoke it with {map_id}.
# 120 s covers an Overpass timeout, the 30 s 429 backoff and one retry.
module "footprints_fetch" {
  source = "./modules/api_lambda"

  app_name    = var.app_name
  name        = "footprints_fetch"
  description = "Fetch a map's building footprints from Overpass into S3"
  timeout     = 120
  api         = local.api
  runtime     = var.lambda_runtime
  layer_arn   = aws_lambda_layer_version.shared.arn
  environment = merge(local.lambda_env, { FOOTPRINTS_BUCKET = aws_s3_bucket.footprints.id })
  policy_json = data.aws_iam_policy_document.footprints_fetch.json
}

# Lambda's own retries would each re-query Overpass, and the handler already
# falls back to a second instance. A crash or timeout lands here instead,
# leaving META pending until the user refreshes.
resource "aws_sqs_queue" "footprints_fetch_failures" {
  name                      = "${var.app_name}-footprints-fetch-failures"
  message_retention_seconds = 1209600
  sqs_managed_sse_enabled   = true
}

resource "aws_lambda_function_event_invoke_config" "footprints_fetch" {
  function_name          = module.footprints_fetch.function_name
  maximum_retry_attempts = 0

  destination_config {
    on_failure {
      destination = aws_sqs_queue.footprints_fetch_failures.arn
    }
  }

  # Lambda checks the role can send to the queue when this is created.
  depends_on = [module.footprints_fetch]
}

resource "aws_iam_role_policy" "maps_create_invoke_fetch" {
  name   = "invoke-footprints-fetch"
  role   = module.maps["maps_create"].role_name
  policy = data.aws_iam_policy_document.invoke_fetch.json
}

module "footprints" {
  source   = "./modules/api_lambda"
  for_each = local.footprints_lambdas

  app_name    = var.app_name
  name        = each.key
  description = each.value.description
  route_key   = each.value.route_key
  api         = local.api
  runtime     = var.lambda_runtime
  layer_arn   = aws_lambda_layer_version.shared.arn
  environment = local.footprints_env
  policy_json = data.aws_iam_policy_document.footprints[each.key].json
}

data "aws_iam_policy_document" "footprints" {
  for_each = local.footprints_lambdas

  source_policy_documents = concat(
    [data.aws_iam_policy_document.footprints_map[each.key].json],
    each.value.extra_policies,
  )
}
