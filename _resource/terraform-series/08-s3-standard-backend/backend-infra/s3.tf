resource "aws_s3_bucket" "s3_bucket" {
  bucket        = "${var.project}-s3-backend"
  force_destroy = false

  tags = local.tags
}

# New buckets are private by default (ACLs are disabled), so no aws_s3_bucket_acl
# is needed. Lock it down further by blocking all public access.
resource "aws_s3_bucket_public_access_block" "s3_bucket" {
  bucket = aws_s3_bucket.s3_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Versioning is REQUIRED for a state bucket so you can recover previous states.
resource "aws_s3_bucket_versioning" "s3_bucket" {
  bucket = aws_s3_bucket.s3_bucket.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_kms_key" "kms_key" {
  description         = "KMS key for the ${var.project} Terraform state bucket"
  enable_key_rotation = true

  tags = local.tags
}

resource "aws_s3_bucket_server_side_encryption_configuration" "s3_bucket" {
  bucket = aws_s3_bucket.s3_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.kms_key.arn
    }
  }
}
