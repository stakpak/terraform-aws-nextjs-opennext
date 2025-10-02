################################################################################
# CloudFront Distribution
################################################################################

resource "aws_cloudfront_distribution" "main" {
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "${var.app_name} Next.js distribution"
  default_root_object = var.cloudfront_default_root_object
  aliases             = local.cloudfront_aliases
  price_class         = var.cloudfront_price_class

  # S3 Origin for static assets
  origin {
    domain_name              = aws_s3_bucket.assets.bucket_regional_domain_name
    origin_id                = "s3-assets"
    origin_access_control_id = aws_cloudfront_origin_access_control.main.id
  }

  # Lambda Function URL Origin for server function
  origin {
    domain_name              = replace(replace(aws_lambda_function_url.server.function_url, "https://", ""), "/", "")
    origin_id                = "lambda-server"
    origin_access_control_id = aws_cloudfront_origin_access_control.lambda.id

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  # Lambda Function URL Origin for image optimization
  origin {
    domain_name              = replace(replace(aws_lambda_function_url.image_optimization.function_url, "https://", ""), "/", "")
    origin_id                = "lambda-image-optimization"
    origin_access_control_id = aws_cloudfront_origin_access_control.lambda.id

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  # Default cache behavior - server function
  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "lambda-server"

    forwarded_values {
      query_string = true
      headers      = ["Accept", "Accept-Language", "Authorization", "CloudFront-Viewer-Country", "x-forwarded-host"]

      cookies {
        forward = "all"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 0
    max_ttl                = 31536000
    compress               = true

    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.set_forwarded_host.arn
    }
  }

  # Static assets from S3 - hashed files with long cache
  ordered_cache_behavior {
    path_pattern     = "/_next/static/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "s3-assets"

    forwarded_values {
      query_string = false
      headers      = []

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 31536000
    max_ttl                = 31536000
    compress               = true
  }

  # Public assets from S3
  ordered_cache_behavior {
    path_pattern     = "/*.*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "s3-assets"

    forwarded_values {
      query_string = false
      headers      = []

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 86400
    max_ttl                = 31536000
    compress               = true
  }

  # Image optimization
  ordered_cache_behavior {
    path_pattern     = "/_next/image*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "lambda-image-optimization"

    forwarded_values {
      query_string = true
      headers      = ["Accept"]

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 86400
    max_ttl                = 31536000
    compress               = true
  }

  # Data requests
  ordered_cache_behavior {
    path_pattern     = "/_next/data/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "lambda-server"

    forwarded_values {
      query_string = true
      headers      = ["x-forwarded-host"]

      cookies {
        forward = "all"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 0
    max_ttl                = 31536000
    compress               = true

    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.set_forwarded_host.arn
    }
  }

  # API routes
  ordered_cache_behavior {
    path_pattern     = "/api/*"
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "lambda-server"

    forwarded_values {
      query_string = true
      headers      = ["Accept", "Accept-Language", "Authorization", "CloudFront-Viewer-Country", "x-forwarded-host"]

      cookies {
        forward = "all"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 0
    max_ttl                = 31536000
    compress               = true

    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.set_forwarded_host.arn
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = var.cloudfront_geo_restriction_type
      locations        = var.cloudfront_geo_restriction_locations
    }
  }

  viewer_certificate {
    # Use custom certificate if domain is configured
    acm_certificate_arn      = local.use_custom_domain ? local.validated_cert_arn : null
    ssl_support_method       = local.use_custom_domain ? "sni-only" : null
    minimum_protocol_version = local.use_custom_domain ? var.cloudfront_minimum_protocol_version : "TLSv1"

    # Use default CloudFront certificate if no custom domain
    cloudfront_default_certificate = !local.use_custom_domain
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${var.app_name}-distribution"
    }
  )

  depends_on = [
    aws_acm_certificate_validation.main
  ]
}

################################################################################
# Route53 Record (only when using Route53)
################################################################################

resource "aws_route53_record" "main" {
  count   = local.manage_route53 ? 1 : 0
  zone_id = var.route53_zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.main.domain_name
    zone_id                = aws_cloudfront_distribution.main.hosted_zone_id
    evaluate_target_health = false
  }
}
