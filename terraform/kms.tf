# One key for the table and the footprints bucket: a single place to audit
# access in CloudTrail, and a single switch to cut the operator off from the
# data. Destroying it makes both unreadable, hence prevent_destroy.
resource "aws_kms_key" "main" {
  description             = "${var.app_name} data at rest (DynamoDB, S3)"
  enable_key_rotation     = true
  deletion_window_in_days = 30

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_kms_alias" "main" {
  name          = "alias/${var.app_name}"
  target_key_id = aws_kms_key.main.key_id
}
