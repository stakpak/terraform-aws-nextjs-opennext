terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"

  default_tags {
    tags = {
      Environment = "production"
      ManagedBy   = "Terraform"
      Example     = "nextjs-opennext-cloudflare"
    }
  }
}

# Provider alias for us-east-1 (required for ACM certificates)
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"

  default_tags {
    tags = {
      Environment = "production"
      ManagedBy   = "Terraform"
      Example     = "nextjs-opennext-cloudflare"
    }
  }
}

# Cloudflare provider for DNS management
provider "cloudflare" {
  # Configure via environment variables:
  # CLOUDFLARE_API_TOKEN or CLOUDFLARE_EMAIL + CLOUDFLARE_API_KEY
}

################################################################################
# Data Sources
################################################################################

data "cloudflare_zone" "main" {
  name = "example.com" # Change to your domain
}

################################################################################
# Next.js Deployment with External DNS
################################################################################

module "nextjs_app" {
  source = "../../"

  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
  }

  # Required
  app_name            = "my-nextjs-app"
  opennext_build_path = "${path.module}/../../../portfolio-app/.open-next"

  # Custom domain with external DNS (Cloudflare)
  domain_name  = "app.example.com" # Change this to your domain
  dns_provider = "external"

  # Certificate will be created, but validation must be done manually
  create_certificate = true

  # Lambda configuration
  lambda_architecture = "arm64"
  lambda_memory_size  = 1024
  lambda_timeout      = 10

  # Image optimization
  image_optimization_memory  = 1536
  image_optimization_timeout = 30

  # Warmer configuration
  warmer_enabled     = true
  warmer_concurrency = 2

  # CloudFront configuration
  cloudfront_price_class = "PriceClass_200"

  # S3 configuration
  enable_s3_versioning  = true
  cache_expiration_days = 30

  tags = {
    Project = "Next.js Production App"
    Owner   = "DevOps Team"
  }
}

################################################################################
# Cloudflare DNS Records
################################################################################

# Certificate validation records
resource "cloudflare_record" "cert_validation" {
  for_each = {
    for dvo in module.nextjs_app.acm_certificate_domain_validation_options : dvo.domain_name => {
      name  = trimsuffix(dvo.resource_record_name, ".${data.cloudflare_zone.main.name}.")
      value = trimsuffix(dvo.resource_record_value, ".")
      type  = dvo.resource_record_type
    }
  }

  zone_id = data.cloudflare_zone.main.id
  name    = each.value.name
  value   = each.value.value
  type    = each.value.type
  ttl     = 60
  comment = "ACM certificate validation for Next.js app"
}

# Application DNS record (CNAME to CloudFront)
resource "cloudflare_record" "app" {
  zone_id = data.cloudflare_zone.main.id
  name    = "app" # Creates app.example.com
  value   = module.nextjs_app.cloudfront_domain_name
  type    = "CNAME"
  ttl     = 1     # Auto TTL
  proxied = false # Must be false for CloudFront

  comment = "Next.js application on AWS CloudFront"

  depends_on = [
    cloudflare_record.cert_validation
  ]
}

################################################################################
# Outputs
################################################################################

output "website_url" {
  description = "Website URL (custom domain)"
  value       = module.nextjs_app.website_url
}

output "cloudfront_domain_name" {
  description = "CloudFront distribution domain name"
  value       = module.nextjs_app.cloudfront_domain_name
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID"
  value       = module.nextjs_app.cloudfront_distribution_id
}

output "acm_certificate_arn" {
  description = "ACM certificate ARN"
  value       = module.nextjs_app.acm_certificate_arn
}

output "cloudflare_dns_record" {
  description = "Cloudflare DNS record details"
  value = {
    name  = cloudflare_record.app.hostname
    value = cloudflare_record.app.value
    type  = cloudflare_record.app.type
  }
}

output "assets_bucket_name" {
  description = "S3 bucket name for assets"
  value       = module.nextjs_app.assets_bucket_name
}

output "cache_bucket_name" {
  description = "S3 bucket name for cache"
  value       = module.nextjs_app.cache_bucket_name
}
