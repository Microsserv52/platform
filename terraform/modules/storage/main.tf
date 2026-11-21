data "aws_caller_identity" "current" {}

locals {
  account_suffix = data.aws_caller_identity.current.account_id
  tags           = merge(var.tags, { ManagedBy = "terraform" })
  media_bucket   = "${var.name_prefix}-media-${local.account_suffix}"
  frontend_buckets = {
    for site in var.frontend_sites : site => "${var.name_prefix}-${site}-${local.account_suffix}"
  }
}

resource "aws_s3_bucket" "media" {
  bucket        = local.media_bucket
  force_destroy = var.force_destroy
  tags          = merge(local.tags, { Name = local.media_bucket, Purpose = "product-media" })
}

resource "aws_s3_bucket_versioning" "media" {
  bucket = aws_s3_bucket.media.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "media" {
  bucket = aws_s3_bucket.media.id
  rule {
    apply_server_side_encryption_by_default { sse_algorithm = "AES256" }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "media" {
  bucket                  = aws_s3_bucket.media.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_cors_configuration" "media" {
  bucket = aws_s3_bucket.media.id

  cors_rule {
    allowed_headers = ["Content-Type", "If-None-Match"]
    allowed_methods = ["GET", "PUT", "HEAD"]
    allowed_origins = var.cors_allowed_origins
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "media" {
  bucket = aws_s3_bucket.media.id

  rule {
    id     = "abort-incomplete-multipart"
    status = "Enabled"
    filter {}
    abort_incomplete_multipart_upload { days_after_initiation = 7 }
  }

  rule {
    id     = "expire-pending-uploads"
    status = "Enabled"
    filter { prefix = "pending/" }
    expiration { days = 1 }
  }

  rule {
    id     = "expire-noncurrent-versions"
    status = "Enabled"
    filter {}
    noncurrent_version_expiration { noncurrent_days = 30 }
  }
}

resource "aws_s3_bucket" "frontend" {
  for_each      = local.frontend_buckets
  bucket        = each.value
  force_destroy = var.force_destroy
  tags          = merge(local.tags, { Name = each.value, Purpose = "frontend-${each.key}" })
}

resource "aws_s3_bucket_versioning" "frontend" {
  for_each = aws_s3_bucket.frontend
  bucket   = each.value.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "frontend" {
  for_each = aws_s3_bucket.frontend
  bucket   = each.value.id
  rule {
    apply_server_side_encryption_by_default { sse_algorithm = "AES256" }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "frontend" {
  for_each                = aws_s3_bucket.frontend
  bucket                  = each.value.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
