terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
      configuration_aliases = [
        aws.us_east_1
      ]
    }
    archive = {
      source  = "hashicorp/archive"
      version = ">= 2.0"
    }
  }
}

locals {
  # Common tags
  common_tags = merge(
    var.tags,
    {
      Application = var.app_name
      ManagedBy   = "Terraform"
      Module      = "terraform-aws-nextjs-opennext"
    }
  )

  # S3 bucket names (must be globally unique)
  assets_bucket_name = var.assets_bucket_name != "" ? var.assets_bucket_name : "${var.app_name}-assets-${data.aws_caller_identity.current.account_id}"
  cache_bucket_name  = var.cache_bucket_name != "" ? var.cache_bucket_name : "${var.app_name}-cache-${data.aws_caller_identity.current.account_id}"

  # DNS configuration
  use_custom_domain = var.domain_name != "" && var.dns_provider != "none"
  manage_route53    = var.dns_provider == "route53"
  use_external_dns  = var.dns_provider == "external"

  # Certificate configuration
  create_certificate = local.use_custom_domain && var.create_certificate && var.certificate_arn == ""
  use_existing_cert  = local.use_custom_domain && var.certificate_arn != ""
  certificate_arn    = local.use_existing_cert ? var.certificate_arn : (local.create_certificate ? aws_acm_certificate.main[0].arn : "")
  validated_cert_arn = local.create_certificate ? aws_acm_certificate_validation.main[0].certificate_arn : local.certificate_arn
  cloudfront_aliases = local.use_custom_domain ? [var.domain_name] : []
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

################################################################################
# S3 Buckets
################################################################################

# Assets bucket for static files
resource "aws_s3_bucket" "assets" {
  bucket = local.assets_bucket_name

  tags = merge(
    local.common_tags,
    {
      Name = "${var.app_name}-assets"
      Type = "assets"
    }
  )
}

resource "aws_s3_bucket_public_access_block" "assets" {
  bucket = aws_s3_bucket.assets.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "assets" {
  count  = var.enable_s3_versioning ? 1 : 0
  bucket = aws_s3_bucket.assets.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Cache bucket for ISR/SSG
resource "aws_s3_bucket" "cache" {
  bucket = local.cache_bucket_name

  tags = merge(
    local.common_tags,
    {
      Name = "${var.app_name}-cache"
      Type = "cache"
    }
  )
}

resource "aws_s3_bucket_public_access_block" "cache" {
  bucket = aws_s3_bucket.cache.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "cache" {
  count  = var.cache_expiration_days > 0 ? 1 : 0
  bucket = aws_s3_bucket.cache.id

  rule {
    id     = "expire-old-cache"
    status = "Enabled"

    filter {
      prefix = ""
    }

    expiration {
      days = var.cache_expiration_days
    }
  }
}

# Bucket policy for CloudFront OAC
resource "aws_s3_bucket_policy" "assets" {
  bucket = aws_s3_bucket.assets.id
  policy = data.aws_iam_policy_document.assets_bucket_policy.json
}

data "aws_iam_policy_document" "assets_bucket_policy" {
  statement {
    sid    = "AllowCloudFrontServicePrincipal"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    actions = [
      "s3:GetObject"
    ]

    resources = [
      "${aws_s3_bucket.assets.arn}/*"
    ]

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.main.arn]
    }
  }
}

################################################################################
# DynamoDB Table for Revalidation
################################################################################

resource "aws_dynamodb_table" "revalidation" {
  name         = "${var.app_name}-revalidation"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "tag"
  range_key    = "path"

  attribute {
    name = "tag"
    type = "S"
  }

  attribute {
    name = "path"
    type = "S"
  }

  attribute {
    name = "revalidatedAt"
    type = "N"
  }

  global_secondary_index {
    name            = "revalidate"
    hash_key        = "path"
    range_key       = "revalidatedAt"
    projection_type = "ALL"
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${var.app_name}-revalidation"
    }
  )
}

################################################################################
# SQS Queue for Revalidation
################################################################################

resource "aws_sqs_queue" "revalidation" {
  name                        = "${var.app_name}-revalidation.fifo"
  fifo_queue                  = true
  content_based_deduplication = true
  visibility_timeout_seconds  = 30

  tags = merge(
    local.common_tags,
    {
      Name = "${var.app_name}-revalidation"
    }
  )
}

################################################################################
# ACM Certificate (us-east-1 for CloudFront)
################################################################################

resource "aws_acm_certificate" "main" {
  count    = local.create_certificate ? 1 : 0
  provider = aws.us_east_1

  domain_name       = var.domain_name
  validation_method = local.manage_route53 ? "DNS" : "EMAIL"

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(
    local.common_tags,
    {
      Name = var.domain_name
    }
  )
}

# Route53 DNS validation records (only when using Route53)
resource "aws_route53_record" "cert_validation" {
  for_each = local.create_certificate && local.manage_route53 ? {
    for dvo in aws_acm_certificate.main[0].domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  } : {}

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = var.route53_zone_id
}

resource "aws_acm_certificate_validation" "main" {
  count    = local.create_certificate && local.manage_route53 ? 1 : 0
  provider = aws.us_east_1

  certificate_arn         = aws_acm_certificate.main[0].arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}

################################################################################
# CloudFront Origin Access Control
################################################################################

resource "aws_cloudfront_origin_access_control" "main" {
  name                              = "${var.app_name}-oac"
  description                       = "OAC for ${var.app_name} S3"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_origin_access_control" "lambda" {
  name                              = "${var.app_name}-lambda-oac"
  description                       = "OAC for ${var.app_name} Lambda Function URLs"
  origin_access_control_origin_type = "lambda"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

################################################################################
# CloudFront Function for x-forwarded-host header
################################################################################

resource "aws_cloudfront_function" "set_forwarded_host" {
  name    = "${var.app_name}-set-forwarded-host"
  runtime = "cloudfront-js-2.0"
  comment = "Set x-forwarded-host header for Next.js"
  publish = true
  code    = <<-EOT
    function handler(event) {
      var request = event.request;
      request.headers['x-forwarded-host'] = {value: request.headers.host.value};
      return request;
    }
  EOT
}
