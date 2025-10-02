# Quick Start Guide

## Installation

### From Local Path

```hcl
module "nextjs_app" {
  source = "./path/to/terraform-aws-nextjs-opennext"
  
  # ... configuration
}
```

### From Git Repository

```hcl
module "nextjs_app" {
  source = "git::https://github.com/your-org/terraform-aws-nextjs-opennext.git?ref=v1.0.0"
  
  # ... configuration
}
```

## Common Use Cases

### 1. Quick Test (No Domain)

Perfect for testing and development:

```hcl
module "nextjs_app" {
  source = "./terraform-aws-nextjs-opennext"

  app_name            = "my-app"
  opennext_build_path = "../my-app/.open-next"
}

# Access via: https://d1234567890.cloudfront.net
```

### 2. Production with Route53

Full AWS integration:

```hcl
provider "aws" {
  region = "us-east-1"
}

provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

module "nextjs_app" {
  source = "./terraform-aws-nextjs-opennext"

  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
  }

  app_name            = "my-app"
  domain_name         = "app.example.com"
  dns_provider        = "route53"
  route53_zone_id     = "Z1234567890ABC"
  opennext_build_path = "../my-app/.open-next"
}

# Access via: https://app.example.com
```

### 3. Production with Cloudflare

Use Cloudflare for DNS:

```hcl
provider "aws" {
  region = "us-east-1"
}

provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

module "nextjs_app" {
  source = "./terraform-aws-nextjs-opennext"

  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
  }

  app_name            = "my-app"
  domain_name         = "app.example.com"
  dns_provider        = "external"
  opennext_build_path = "../my-app/.open-next"
}

# Then create DNS record in Cloudflare:
# Type: CNAME
# Name: app
# Target: module.nextjs_app.cloudfront_domain_name
```

### 4. Bring Your Own Certificate

Use existing ACM certificate:

```hcl
module "nextjs_app" {
  source = "./terraform-aws-nextjs-opennext"

  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
  }

  app_name            = "my-app"
  domain_name         = "app.example.com"
  dns_provider        = "external"
  certificate_arn     = "arn:aws:acm:us-east-1:123456789012:certificate/abc-123"
  create_certificate  = false
  opennext_build_path = "../my-app/.open-next"
}
```

## Complete Deployment Workflow

### Step 1: Build Next.js App

```bash
cd your-nextjs-app
npm run build
npx open-next@latest build
```

### Step 2: Deploy Infrastructure

```bash
cd terraform
terraform init
terraform apply
```

### Step 3: Upload Assets

```bash
# Get bucket names
ASSETS_BUCKET=$(terraform output -raw assets_bucket_name)
CACHE_BUCKET=$(terraform output -raw cache_bucket_name)

# Upload static assets with long cache
aws s3 sync ../your-nextjs-app/.open-next/assets s3://$ASSETS_BUCKET/ \
  --cache-control "public,max-age=31536000,immutable" \
  --exclude "*" \
  --include "_next/static/*"

# Upload public assets with shorter cache
aws s3 sync ../your-nextjs-app/.open-next/assets s3://$ASSETS_BUCKET/ \
  --cache-control "public,max-age=0,s-maxage=31536000,must-revalidate" \
  --exclude "_next/*"

# Upload cache files
aws s3 sync ../your-nextjs-app/.open-next/cache s3://$CACHE_BUCKET/
```

### Step 4: Access Application

```bash
terraform output website_url
```

## Configuration Examples

### High-Performance Setup

```hcl
module "nextjs_app" {
  source = "./terraform-aws-nextjs-opennext"

  app_name            = "my-app"
  opennext_build_path = "../my-app/.open-next"

  # More memory = faster execution
  lambda_memory_size         = 2048
  image_optimization_memory  = 3008
  
  # Keep more instances warm
  warmer_enabled     = true
  warmer_concurrency = 5
  
  # Global distribution
  cloudfront_price_class = "PriceClass_All"
}
```

### Cost-Optimized Setup

```hcl
module "nextjs_app" {
  source = "./terraform-aws-nextjs-opennext"

  app_name            = "my-app"
  opennext_build_path = "../my-app/.open-next"

  # Minimum memory
  lambda_memory_size         = 512
  image_optimization_memory  = 1024
  
  # Disable warmer (accept cold starts)
  warmer_enabled = false
  
  # US/Canada/Europe only
  cloudfront_price_class = "PriceClass_100"
  
  # Shorter cache retention
  cache_expiration_days = 7
}
```

### Geo-Restricted Setup

```hcl
module "nextjs_app" {
  source = "./terraform-aws-nextjs-opennext"

  app_name            = "my-app"
  opennext_build_path = "../my-app/.open-next"

  # Only allow specific countries
  cloudfront_geo_restriction_type      = "whitelist"
  cloudfront_geo_restriction_locations = ["US", "CA", "GB", "DE", "FR"]
}
```

## Updating Your Application

### Code Changes Only

```bash
# 1. Rebuild app
cd your-nextjs-app
npm run build
npx open-next@latest build

# 2. Update Lambda functions
cd ../terraform
terraform apply

# 3. Sync assets
ASSETS_BUCKET=$(terraform output -raw assets_bucket_name)
aws s3 sync ../your-nextjs-app/.open-next/assets s3://$ASSETS_BUCKET/ --delete

# 4. Invalidate cache
DISTRIBUTION_ID=$(terraform output -raw cloudfront_distribution_id)
aws cloudfront create-invalidation --distribution-id $DISTRIBUTION_ID --paths "/*"
```

### Infrastructure Changes

```bash
# Modify your Terraform configuration
# Then apply changes
terraform plan
terraform apply
```

## Outputs Reference

All available outputs:

```hcl
output "website_url" {
  value = module.nextjs_app.website_url
}

output "cloudfront_distribution_id" {
  value = module.nextjs_app.cloudfront_distribution_id
}

output "cloudfront_domain_name" {
  value = module.nextjs_app.cloudfront_domain_name
}

output "assets_bucket_name" {
  value = module.nextjs_app.assets_bucket_name
}

output "cache_bucket_name" {
  value = module.nextjs_app.cache_bucket_name
}

output "server_function_name" {
  value = module.nextjs_app.server_function_name
}

output "acm_certificate_arn" {
  value = module.nextjs_app.acm_certificate_arn
}
```

## Troubleshooting

### Module Not Found

```bash
# Ensure you're using the correct source path
terraform init -upgrade
```

### Certificate Validation Timeout

```bash
# Check certificate status
aws acm describe-certificate \
  --certificate-arn $(terraform output -raw acm_certificate_arn) \
  --region us-east-1
```

### Lambda Function Errors

```bash
# View logs
aws logs tail /aws/lambda/$(terraform output -raw server_function_name) --follow
```

### CloudFront 403 Errors

```bash
# Verify assets are uploaded
aws s3 ls s3://$(terraform output -raw assets_bucket_name)/_next/static/
```

## Best Practices

1. **Use Remote State**: Store Terraform state in S3 with DynamoDB locking
2. **Version Pin**: Pin module version in production
3. **Separate Environments**: Use workspaces or separate state files
4. **Monitor Costs**: Set up AWS Budgets alerts
5. **Enable Logging**: Configure CloudFront access logs
6. **Backup State**: Regular backups of Terraform state
7. **Test Changes**: Use `terraform plan` before `apply`
8. **Tag Resources**: Use consistent tagging strategy

## Support

For issues and questions:
- Check the [README.md](README.md) for detailed documentation
- Review [examples/](examples/) for working configurations
- Open an issue on GitHub
