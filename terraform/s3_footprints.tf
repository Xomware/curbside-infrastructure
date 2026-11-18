# Building footprint GeoJSON per map, written by footprints_fetch and served by
# presigned URL. Keys carry a version (v<n>) and every object can be refetched
# from Overpass, so no versioning or prevent_destroy.
resource "aws_s3_bucket" "footprints" {
  bucket = "${var.app_name}-footprints-${local.account_id}"
}

resource "aws_s3_bucket_public_access_block" "footprints" {
  bucket                  = aws_s3_bucket.footprints.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "footprints" {
  bucket = aws_s3_bucket.footprints.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.main.arn
    }
    bucket_key_enabled = true
  }
}

# The web client fetches the presigned footprint URL from the browser.
resource "aws_s3_bucket_cors_configuration" "footprints" {
  bucket = aws_s3_bucket.footprints.id

  cors_rule {
    allowed_methods = ["GET"]
    allowed_origins = var.cors_allow_origins
    max_age_seconds = 3600
  }
}

# Deleting a map, alone or with its account, takes its footprint files with it.
data "aws_iam_policy_document" "footprints_delete" {
  statement {
    sid       = "ListFootprints"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.footprints.arn]

    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values   = ["footprints/*"]
    }
  }

  statement {
    sid       = "DeleteFootprints"
    actions   = ["s3:DeleteObject"]
    resources = ["${aws_s3_bucket.footprints.arn}/footprints/*"]
  }
}
