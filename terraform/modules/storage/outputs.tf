output "media_bucket" {
  value = {
    bucket               = aws_s3_bucket.media.bucket
    arn                  = aws_s3_bucket.media.arn
    regional_domain_name = aws_s3_bucket.media.bucket_regional_domain_name
  }
}

output "frontend_buckets" {
  value = {
    for site, bucket in aws_s3_bucket.frontend : site => {
      bucket               = bucket.bucket
      arn                  = bucket.arn
      regional_domain_name = bucket.bucket_regional_domain_name
    }
  }
}
