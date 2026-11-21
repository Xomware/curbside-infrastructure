# push_send turns ACTIVITY# inserts on the table stream into APNs pushes. The
# filter keeps every other write from invoking it at all.

data "aws_iam_policy_document" "push_send" {
  source_policy_documents = [data.aws_iam_policy_document.table_key.json]

  statement {
    sid       = "Devices"
    actions   = ["dynamodb:GetItem", "dynamodb:Query", "dynamodb:DeleteItem"]
    resources = [aws_dynamodb_table.main.arn]
  }

  statement {
    sid       = "Stream"
    actions   = ["dynamodb:DescribeStream", "dynamodb:GetRecords", "dynamodb:GetShardIterator", "dynamodb:ListStreams"]
    resources = ["${aws_dynamodb_table.main.arn}/stream/*"]
  }

  statement {
    sid     = "ApnsConfig"
    actions = ["ssm:GetParameter", "ssm:GetParameters"]
    resources = [
      aws_ssm_parameter.apns_key_id.arn,
      aws_ssm_parameter.apns_team_id.arn,
      aws_ssm_parameter.apns_private_key.arn,
    ]
  }

  statement {
    sid       = "FailureQueue"
    actions   = ["sqs:SendMessage"]
    resources = [aws_sqs_queue.push_send_failures.arn]
  }
}

module "push_send" {
  source = "./modules/api_lambda"

  app_name    = var.app_name
  name        = "push_send"
  description = "Send APNs pushes for new activity items"
  timeout     = 60
  api         = local.api
  runtime     = var.lambda_runtime
  layer_arn   = aws_lambda_layer_version.shared.arn
  environment = merge(local.lambda_env, {
    APNS_BUNDLE_ID         = "com.Xomware.Curbside"
    APNS_KEY_ID_PARAM      = aws_ssm_parameter.apns_key_id.name
    APNS_TEAM_ID_PARAM     = aws_ssm_parameter.apns_team_id.name
    APNS_PRIVATE_KEY_PARAM = aws_ssm_parameter.apns_private_key.name
  })
  policy_json = data.aws_iam_policy_document.push_send.json
}

# A batch that keeps failing would block its shard. After two retries it is
# split, and whatever still fails lands here instead of stalling later pushes.
resource "aws_sqs_queue" "push_send_failures" {
  name                      = "${var.app_name}-push-send-failures"
  message_retention_seconds = 1209600
  sqs_managed_sse_enabled   = true
}

resource "aws_lambda_event_source_mapping" "push_send" {
  event_source_arn               = aws_dynamodb_table.main.stream_arn
  function_name                  = module.push_send.function_arn
  starting_position              = "LATEST"
  batch_size                     = 25
  maximum_retry_attempts         = 2
  maximum_record_age_in_seconds  = 3600
  bisect_batch_on_function_error = true

  filter_criteria {
    filter {
      pattern = jsonencode({
        eventName = ["INSERT"]
        dynamodb  = { Keys = { sk = { S = [{ prefix = "ACTIVITY#" }] } } }
      })
    }
  }

  destination_config {
    on_failure {
      destination_arn = aws_sqs_queue.push_send_failures.arn
    }
  }

  # Lambda checks the role can read the stream when the mapping is created.
  depends_on = [module.push_send]
}
