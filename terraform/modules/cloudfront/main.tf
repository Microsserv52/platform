locals {
  landing_origin = "s3-landing"
  api_enabled    = var.api_origin_domain != ""
  faro_enabled   = var.faro_enabled && var.faro_origin_domain != ""
  # AWS-managed cache policy IDs are global and stable across accounts.
  cache_optimized = "658327ea-f89d-4fab-a63d-7e88639e58f6"
  cache_disabled  = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad"
  all_viewer      = "216adef6-5c7f-47e4-b989-5492eafa07d3"
}

resource "aws_cloudfront_origin_access_control" "frontend" {
  for_each                          = var.frontend_buckets
  name                              = "${var.name}-${each.key}"
  description                       = "OAC for the ${each.key} frontend bucket"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_origin_access_control" "media" {
  name                              = "${var.name}-media"
  description                       = "OAC for the product media bucket"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_cache_policy" "site" {
  name        = "${var.name}-site"
  comment     = "Separate frontend sites by x-site header"
  default_ttl = 86400
  max_ttl     = 31536000
  min_ttl     = 0

  parameters_in_cache_key_and_forwarded_to_origin {
    cookies_config {
      cookie_behavior = "none"
    }
    headers_config {
      header_behavior = "whitelist"
      headers {
        items = ["x-site"]
      }
    }
    query_strings_config {
      query_string_behavior = "none"
    }
    enable_accept_encoding_brotli = true
    enable_accept_encoding_gzip   = true
  }
}

resource "aws_cloudfront_function" "rewrite" {
  name    = "${var.name}-rewrite"
  runtime = "cloudfront-js-2.0"
  comment = "Strip microfrontend prefixes and resolve directory indexes"
  publish = true
  code    = file("${path.module}/function.js")
}

resource "aws_cloudfront_distribution" "this" {
  enabled             = var.enabled
  is_ipv6_enabled     = true
  comment             = "${var.name} frontend and media"
  web_acl_id          = var.waf_web_acl_arn != "" ? var.waf_web_acl_arn : null
  default_root_object = var.default_root_object
  aliases             = var.aliases
  price_class         = var.price_class
  tags                = merge(var.tags, { ManagedBy = "terraform" })

  origin {
    domain_name              = var.frontend_buckets["landing"].regional_domain_name
    origin_id                = local.landing_origin
    origin_access_control_id = aws_cloudfront_origin_access_control.frontend["landing"].id
  }

  dynamic "origin" {
    for_each = { for site, bucket in var.frontend_buckets : site => bucket if site != "landing" }
    content {
      domain_name              = origin.value.regional_domain_name
      origin_id                = "s3-${origin.key}"
      origin_access_control_id = aws_cloudfront_origin_access_control.frontend[origin.key].id
    }
  }

  origin {
    domain_name              = var.media_bucket.regional_domain_name
    origin_id                = "s3-media"
    origin_access_control_id = aws_cloudfront_origin_access_control.media.id
  }

  dynamic "origin" {
    for_each = local.api_enabled ? [1] : []
    content {
      domain_name = var.api_origin_domain
      origin_id   = "api-gateway"
      custom_origin_config {
        http_port              = 80
        https_port             = 443
        origin_protocol_policy = var.api_origin_protocol_policy
        origin_ssl_protocols   = ["TLSv1.2"]
      }
    }
  }

  dynamic "origin" {
    for_each = local.faro_enabled ? [1] : []
    content {
      domain_name = var.faro_origin_domain
      origin_id   = "faro-gateway"
      custom_origin_config {
        http_port              = var.faro_origin_http_port
        https_port             = 443
        origin_protocol_policy = "http-only"
        origin_ssl_protocols   = ["TLSv1.2"]
      }
    }
  }

  default_cache_behavior {
    target_origin_id       = local.landing_origin
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true
    cache_policy_id        = aws_cloudfront_cache_policy.site.id

    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.rewrite.arn
    }
  }

  dynamic "ordered_cache_behavior" {
    for_each = { for site, bucket in var.frontend_buckets : site => bucket if site != "landing" }
    content {
      path_pattern           = "/${ordered_cache_behavior.key}/*"
      target_origin_id       = "s3-${ordered_cache_behavior.key}"
      viewer_protocol_policy = "redirect-to-https"
      allowed_methods        = ["GET", "HEAD", "OPTIONS"]
      cached_methods         = ["GET", "HEAD"]
      compress               = true
      cache_policy_id        = aws_cloudfront_cache_policy.site.id

      function_association {
        event_type   = "viewer-request"
        function_arn = aws_cloudfront_function.rewrite.arn
      }
    }
  }

  ordered_cache_behavior {
    path_pattern           = "/media/*"
    target_origin_id       = "s3-media"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true
    cache_policy_id        = local.cache_optimized
  }

  dynamic "ordered_cache_behavior" {
    for_each = local.api_enabled ? [1] : []
    content {
      path_pattern             = "/api/*"
      target_origin_id         = "api-gateway"
      viewer_protocol_policy   = "redirect-to-https"
      allowed_methods          = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
      cached_methods           = ["GET", "HEAD"]
      compress                 = true
      cache_policy_id          = local.cache_disabled
      origin_request_policy_id = local.all_viewer

      function_association {
        event_type   = "viewer-request"
        function_arn = aws_cloudfront_function.rewrite.arn
      }
    }
  }

  dynamic "ordered_cache_behavior" {
    for_each = local.faro_enabled ? [1] : []
    content {
      path_pattern             = "/faro/*"
      target_origin_id         = "faro-gateway"
      viewer_protocol_policy   = "redirect-to-https"
      allowed_methods          = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
      cached_methods           = ["GET", "HEAD"]
      compress                 = true
      cache_policy_id          = local.cache_disabled
      origin_request_policy_id = local.all_viewer

      function_association {
        event_type   = "viewer-request"
        function_arn = aws_cloudfront_function.rewrite.arn
      }
    }
  }

  restrictions {
    geo_restriction { restriction_type = "none" }
  }

  viewer_certificate {
    cloudfront_default_certificate = var.certificate_arn == ""
    acm_certificate_arn            = var.certificate_arn != "" ? var.certificate_arn : null
    ssl_support_method             = var.certificate_arn != "" ? "sni-only" : null
    minimum_protocol_version       = var.certificate_arn != "" ? "TLSv1.2_2021" : null
  }
}

resource "aws_s3_bucket_cors_configuration" "media" {
  bucket = var.media_bucket.bucket

  cors_rule {
    allowed_headers = ["Content-Type", "If-None-Match"]
    allowed_methods = ["GET", "PUT", "HEAD"]
    allowed_origins = distinct(concat(
      var.cors_allowed_origins,
      [for alias in var.aliases : "https://${alias}"],
      ["https://${aws_cloudfront_distribution.this.domain_name}"],
    ))
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}

data "aws_iam_policy_document" "frontend" {
  for_each = var.frontend_buckets
  statement {
    sid       = "AllowCloudFrontOac"
    actions   = ["s3:GetObject"]
    resources = ["${each.value.arn}/*"]
    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.this.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "frontend" {
  for_each = var.frontend_buckets
  bucket   = each.value.bucket
  policy   = data.aws_iam_policy_document.frontend[each.key].json
}

data "aws_iam_policy_document" "media" {
  statement {
    sid       = "AllowCloudFrontOac"
    actions   = ["s3:GetObject"]
    resources = ["${var.media_bucket.arn}/*"]
    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.this.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "media" {
  bucket = var.media_bucket.bucket
  policy = data.aws_iam_policy_document.media.json
}
