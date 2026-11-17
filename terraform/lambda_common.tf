# Terraform creates version 1 from the stub. curbside-backend's deploy workflow
# publishes every later version under this exact name and moves functions onto it.
resource "aws_lambda_layer_version" "shared" {
  layer_name          = "${var.app_name}-shared-packages"
  filename            = "templates/lambda_stub.zip"
  compatible_runtimes = [var.lambda_runtime]

  lifecycle {
    ignore_changes = [filename, source_code_hash]
  }
}

# The table is under the CMK, and DynamoDB uses it with the caller's
# permissions. ViaService stops the role calling KMS directly.
data "aws_iam_policy_document" "table_key" {
  statement {
    sid       = "TableKey"
    actions   = ["kms:Decrypt", "kms:Encrypt", "kms:GenerateDataKey", "kms:DescribeKey"]
    resources = [aws_kms_key.main.arn]

    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["dynamodb.${var.aws_region}.amazonaws.com"]
    }
  }
}
