locals {
  lt_demo_web_app_frontend_common_tags = merge(local.tags, {
    "Name" : "Web application"
  })
  lt_demo_web_app_static_files_storage_bucket_name = "com.leaptalk.${local.env}.web-app.website.public"
  lt_demo_web_app_url                              = local.env == "prod" ? "leaptalk.lf.binayabaral.com.np" : "leaptalk-dev.lf.binayabaral.com.np"
  lt_demo_web_app_cloudfront_aliases               = [local.lt_demo_web_app_url]
}

############################################################################################
### Create S3 bucket to store static files for the web application
############################################################################################
/**
 * Create a S3 bucket to store static files for web application
 */
resource "aws_s3_bucket" "lt_demo_web_app_static_files_storage_bucket" {
  bucket = local.lt_demo_web_app_static_files_storage_bucket_name
  tags   = local.lt_demo_web_app_frontend_common_tags
}

/**
 * Set s3 bucket ownership
 */
resource "aws_s3_bucket_ownership_controls" "lt_demo_web_app_static_files_storage_bucket_ownership_controls" {
  bucket = aws_s3_bucket.lt_demo_web_app_static_files_storage_bucket.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

/**
 * Allow public access to s3 bucket
 */
#tfsec:ignore:aws-s3-block-public-acls tfsec:ignore:aws-s3-block-public-policy tfsec:ignore:aws-s3-ignore-public-acls tfsec:ignore:aws-s3-no-public-buckets
resource "aws_s3_bucket_public_access_block" "lt_demo_web_app_static_files_storage_bucket_public_access" {
  bucket = aws_s3_bucket.lt_demo_web_app_static_files_storage_bucket.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

/**
 * Make the s3 bucket public
 */
#tfsec:ignore:aws-s3-no-public-access-with-acl
resource "aws_s3_bucket_acl" "lt_demo_web_app_website_bucket_acl" {
  depends_on = [
    aws_s3_bucket_ownership_controls.lt_demo_web_app_static_files_storage_bucket_ownership_controls,
    aws_s3_bucket_public_access_block.lt_demo_web_app_static_files_storage_bucket_public_access,
  ]
  bucket = aws_s3_bucket.lt_demo_web_app_static_files_storage_bucket.id
  acl    = "public-read"
}

/**
 * Create a policy to provide access to the bucket from all aws services
*/
data "aws_iam_policy_document" "lt_demo_allow_access_to_web_app_bucket" {
  version = "2012-10-17"

  statement {
    sid       = "AllowAccessToWebAppBucket"
    effect    = "Allow"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.lt_demo_web_app_static_files_storage_bucket.arn}/*"]
    principals {
      identifiers = ["*"]
      type        = "AWS"
    }
  }
}

/**
 * Add the policy to the bucket
 */
resource "aws_s3_bucket_policy" "lt_demo_web_app_website_bucket_policy" {
  bucket = aws_s3_bucket.lt_demo_web_app_static_files_storage_bucket.id
  policy = data.aws_iam_policy_document.lt_demo_allow_access_to_web_app_bucket.json
}

/**
 * Add configurations for S3 bucket to add index and error document for static site hosting
 */
resource "aws_s3_bucket_website_configuration" "lt_demo_web_app_s3_bucket_website_config" {
  bucket = aws_s3_bucket.lt_demo_web_app_static_files_storage_bucket.id
  index_document {
    suffix = "index.html"
  }
  error_document {
    key = "index.html"
  }
}

data "aws_acm_certificate" "binaya_lf_certificate" {
  domain = "lf.binayabaral.com.np"
}

data "aws_route53_zone" "lf_binayabaral_com_np" {
  name = "lf.binayabaral.com.np"
}

############################################################################################
### Create Cloudfront distribution
############################################################################################
resource "aws_cloudfront_distribution" "lt_demo_web_app_cloudfront_distribution" {
  enabled             = true
  wait_for_deployment = false
  default_root_object = "index.html"
  aliases             = local.lt_demo_web_app_cloudfront_aliases

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = local.lt_demo_web_app_static_files_storage_bucket_name
    viewer_protocol_policy = "redirect-to-https"
    compress               = true

    cache_policy_id = aws_cloudfront_cache_policy.lt_demo_web_app_cloudfront_cache_policy.id
  }

  origin {
    domain_name = aws_s3_bucket_website_configuration.lt_demo_web_app_s3_bucket_website_config.website_endpoint
    origin_id   = local.lt_demo_web_app_static_files_storage_bucket_name
    custom_origin_config {
      http_port              = "80"
      https_port             = "443"
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }

    custom_header {
      name  = "Strict-Transport-Security"
      value = "max-age=31536000; includeSubDomains"
    }
    custom_header {
      name  = "X-Frame-Options"
      value = "SAMEORIGIN"
    }
    custom_header {
      name  = "X-XSS-Protection"
      value = "1; mode=block"
    }
    custom_header {
      name  = "X-Content-Type-Options"
      value = "nosniff"
    }
    custom_header {
      name  = "Content-Security-Policy"
      value = "default-src 'self';"
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = data.aws_acm_certificate.binaya_lf_certificate.arn
    minimum_protocol_version = "TLSv1.2_2021"
    ssl_support_method       = "sni-only"
  }

  custom_error_response {
    error_code            = 404
    response_code         = 200
    error_caching_min_ttl = 10
    response_page_path    = "/index.html"
  }

  tags = local.lt_demo_web_app_frontend_common_tags
}

/**
 * Cache policy for cloudfront distribution with compression enabled.
 */
resource "aws_cloudfront_cache_policy" "lt_demo_web_app_cloudfront_cache_policy" {
  name = "lt-demo-web-app-cloudfront-cache-policy-${local.env}"

  min_ttl     = 2
  default_ttl = 2
  max_ttl     = 300

  parameters_in_cache_key_and_forwarded_to_origin {
    cookies_config {
      cookie_behavior = "none"
    }

    headers_config {
      header_behavior = "none"
    }

    query_strings_config {
      query_string_behavior = "none"
    }

    enable_accept_encoding_gzip   = true
    enable_accept_encoding_brotli = true
  }
}

############################################################################################
### Add a route53 record for web application
############################################################################################
resource "aws_route53_record" "web_application_route53_record" {
  name    = local.lt_demo_web_app_url
  type    = "A"
  zone_id = data.aws_route53_zone.lf_binayabaral_com_np.zone_id

  alias {
    evaluate_target_health = false
    name                   = aws_cloudfront_distribution.lt_demo_web_app_cloudfront_distribution.domain_name
    zone_id                = aws_cloudfront_distribution.lt_demo_web_app_cloudfront_distribution.hosted_zone_id
  }
}
