resource "aws_s3_bucket" "lake" {
  bucket = var.lake_bucket_name
}

resource "aws_s3_bucket_public_access_block" "lake" {
  bucket = aws_s3_bucket.lake.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Placeholder object so `terraform plan` shows the Hive-style prefix exists.
resource "aws_s3_object" "lake_raw_prefix_marker" {
  bucket  = aws_s3_bucket.lake.id
  key     = "${var.lake_raw_prefix}/.keep"
  content = "managed-by-terraform-localstack"
}
