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
