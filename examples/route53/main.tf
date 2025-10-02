terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"

  default_tags {
    tags = {
      Environment = "production"
      ManagedBy   = "Terraform"
      Example     = "nextjs-opennext-route53"
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
      Example     = "nextjs-opennext-route53"
    }
  }
}

################################################################################
# Route53 Deployment with Custom Domain
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

  # Custom domain with Route53
  domain_name     = "app.example.com" # Change this to your domain
  dns_provider    = "route53"
  route53_zone_id = "Z1234567890ABC" # Change this to your hosted zone ID

  # Certificate will be created automatically
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
  warmer_concurrency = 2 # Keep 2 instances warm for production

  # CloudFront configuration
  cloudfront_price_class = "PriceClass_200" # US, Europe, Asia

  # S3 configuration
  enable_s3_versioning  = true
  cache_expiration_days = 30

  tags = {
    Project = "Next.js Production App"
    Owner   = "DevOps Team"
  }
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

output "route53_record_fqdn" {
  description = "Route53 record FQDN"
  value       = module.nextjs_app.route53_record_fqdn
}

output "acm_certificate_arn" {
  description = "ACM certificate ARN"
  value       = module.nextjs_app.acm_certificate_arn
}

output "assets_bucket_name" {
  description = "S3 bucket name for assets"
  value       = module.nextjs_app.assets_bucket_name
}

output "cache_bucket_name" {
  description = "S3 bucket name for cache"
  value       = module.nextjs_app.cache_bucket_name
}
