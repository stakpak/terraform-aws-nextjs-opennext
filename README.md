# AWS Next.js OpenNext Terraform Module

Production-ready Terraform module for deploying Next.js applications to AWS using the OpenNext architecture. This module creates a serverless infrastructure with CloudFront, Lambda, S3, and other AWS services optimized for Next.js applications.

## Features

- ✅ **Flexible DNS Configuration**: Support for Route53, external DNS providers (Cloudflare, etc.), or CloudFront-only deployments
- ✅ **Certificate Management**: Create new ACM certificates or bring your own
- ✅ **Serverless Architecture**: Lambda functions for SSR, API routes, and image optimization
- ✅ **Global CDN**: CloudFront distribution with optimized caching strategies
- ✅ **ISR Support**: Full support for Incremental Static Regeneration with DynamoDB and SQS
- ✅ **Cold Start Mitigation**: Optional Lambda warmer to keep functions warm
- ✅ **Cost Optimized**: ARM64 Lambda support, intelligent caching, and pay-per-use pricing
- ✅ **Security Best Practices**: Private S3 buckets, CloudFront OAC, HTTPS enforcement
- ✅ **Production Ready**: Comprehensive monitoring, logging, and error handling

## Architecture

```
┌─────────────┐
│   Users     │
└──────┬──────┘
       │
       ▼
┌─────────────────────────────────────────┐
│         CloudFront CDN                  │
│  ┌──────────────────────────────────┐  │
│  │  Custom Domain (Optional)        │  │
│  │  SSL/TLS Certificate             │  │
│  └──────────────────────────────────┘  │
└────┬────────────┬──────────────┬────────┘
     │            │              │
     ▼            ▼              ▼
┌─────────┐  ┌─────────┐  ┌──────────────┐
│   S3    │  │ Lambda  │  │   Lambda     │
│ Assets  │  │ Server  │  │ Image Opt    │
└─────────┘  └────┬────┘  └──────────────┘
                  │
        ┌─────────┴─────────┐
        ▼                   ▼
   ┌─────────┐         ┌─────────┐
   │   S3    │         │DynamoDB │
   │  Cache  │         │  Table  │
   └─────────┘         └─────────┘
                            │
                            ▼
                       ┌─────────┐
                       │   SQS   │
                       │  Queue  │
                       └─────────┘
```

## Prerequisites

1. **AWS Account** with appropriate permissions
2. **Terraform** >= 1.5
3. **Next.js Application** built with OpenNext
4. **Node.js** >= 18.x (for building the app)

## Quick Start

### 1. Build Your Next.js App with OpenNext

```bash
cd your-nextjs-app
npm run build
npx open-next@latest build
```

This creates a `.open-next` directory with Lambda-ready bundles.

### 2. Use the Module

#### Option A: CloudFront-Only (No Custom Domain)

```hcl
module "nextjs_app" {
  source = "path/to/terraform-aws-nextjs-opennext"

  app_name            = "my-nextjs-app"
  opennext_build_path = "../my-nextjs-app/.open-next"

  # Lambda configuration
  lambda_architecture = "arm64"
  lambda_memory_size  = 1024
}
```

#### Option B: With Route53 DNS

```hcl
module "nextjs_app" {
  source = "path/to/terraform-aws-nextjs-opennext"

  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1  # Required for ACM certificate
  }

  app_name            = "my-nextjs-app"
  domain_name         = "app.example.com"
  dns_provider        = "route53"
  route53_zone_id     = "Z1234567890ABC"
  opennext_build_path = "../my-nextjs-app/.open-next"
}
```

#### Option C: With External DNS (Cloudflare, etc.)

```hcl
module "nextjs_app" {
  source = "path/to/terraform-aws-nextjs-opennext"

  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
  }

  app_name            = "my-nextjs-app"
  domain_name         = "app.example.com"
  dns_provider        = "external"
  opennext_build_path = "../my-nextjs-app/.open-next"
}

# After apply, create DNS record in your provider:
# Type: CNAME or ALIAS
# Name: app.example.com
# Target: module.nextjs_app.cloudfront_domain_name
```

#### Option D: With Existing ACM Certificate

```hcl
module "nextjs_app" {
  source = "path/to/terraform-aws-nextjs-opennext"

  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
  }

  app_name            = "my-nextjs-app"
  domain_name         = "app.example.com"
  dns_provider        = "external"
  certificate_arn     = "arn:aws:acm:us-east-1:123456789012:certificate/abc-123"
  create_certificate  = false
  opennext_build_path = "../my-nextjs-app/.open-next"
}
```

### 3. Initialize and Apply

```bash
terraform init
terraform plan
terraform apply
```

### 4. Upload Static Assets

```bash
# Get bucket name from output
ASSETS_BUCKET=$(terraform output -raw assets_bucket_name)

# Upload hashed static files (long cache)
aws s3 sync .open-next/assets s3://$ASSETS_BUCKET/ \
  --cache-control "public,max-age=31536000,immutable" \
  --exclude "*" \
  --include "_next/static/*"

# Upload public assets (shorter cache)
aws s3 sync .open-next/assets s3://$ASSETS_BUCKET/ \
  --cache-control "public,max-age=0,s-maxage=31536000,must-revalidate" \
  --exclude "_next/*"

# Upload cache files
CACHE_BUCKET=$(terraform output -raw cache_bucket_name)
aws s3 sync .open-next/cache s3://$CACHE_BUCKET/
```

### 5. Access Your Application

```bash
terraform output website_url
```

## Configuration

### Required Variables

| Variable | Type | Description |
|----------|------|-------------|
| `app_name` | `string` | Application name (used for resource naming) |
| `opennext_build_path` | `string` | Path to `.open-next` directory |

### DNS & Certificate Variables

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `domain_name` | `string` | `""` | Custom domain name |
| `dns_provider` | `string` | `"none"` | DNS provider: `route53`, `external`, or `none` |
| `route53_zone_id` | `string` | `""` | Route53 zone ID (required for `route53` provider) |
| `certificate_arn` | `string` | `""` | Existing ACM certificate ARN in us-east-1 |
| `create_certificate` | `bool` | `true` | Whether to create new certificate |

### Lambda Variables

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `lambda_architecture` | `string` | `"arm64"` | Lambda architecture: `arm64` or `x86_64` |
| `lambda_memory_size` | `number` | `1024` | Server Lambda memory (MB) |
| `lambda_timeout` | `number` | `10` | Server Lambda timeout (seconds) |
| `image_optimization_memory` | `number` | `1536` | Image Lambda memory (MB) |
| `image_optimization_timeout` | `number` | `30` | Image Lambda timeout (seconds) |
| `warmer_enabled` | `bool` | `true` | Enable Lambda warmer |
| `warmer_concurrency` | `number` | `1` | Number of instances to keep warm |
| `warmer_schedule` | `string` | `"rate(5 minutes)"` | Warmer schedule expression |

### CloudFront Variables

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `cloudfront_price_class` | `string` | `"PriceClass_100"` | Price class: `PriceClass_All`, `PriceClass_200`, `PriceClass_100` |
| `cloudfront_geo_restriction_type` | `string` | `"none"` | Geo restriction: `none`, `whitelist`, `blacklist` |
| `cloudfront_geo_restriction_locations` | `list(string)` | `[]` | Country codes for geo restriction |
| `cloudfront_minimum_protocol_version` | `string` | `"TLSv1.2_2021"` | Minimum TLS version |

### S3 Variables

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `assets_bucket_name` | `string` | `""` | Custom assets bucket name (auto-generated if empty) |
| `cache_bucket_name` | `string` | `""` | Custom cache bucket name (auto-generated if empty) |
| `enable_s3_versioning` | `bool` | `true` | Enable S3 versioning |
| `cache_expiration_days` | `number` | `30` | Cache expiration in days |

## Outputs

### CloudFront Outputs

- `cloudfront_distribution_id` - Distribution ID
- `cloudfront_distribution_arn` - Distribution ARN
- `cloudfront_domain_name` - CloudFront domain (use if no custom domain)
- `website_url` - Full website URL

### S3 Outputs

- `assets_bucket_name` - Assets bucket name
- `cache_bucket_name` - Cache bucket name

### Lambda Outputs

- `server_function_name` - Server Lambda name
- `server_function_arn` - Server Lambda ARN
- `image_optimization_function_name` - Image optimization Lambda name
- `revalidation_function_name` - Revalidation Lambda name

### Certificate & DNS Outputs

- `acm_certificate_arn` - Certificate ARN (if created)
- `acm_certificate_domain_validation_options` - Validation options for external DNS
- `route53_record_fqdn` - Route53 record FQDN (if managed)
- `dns_configuration_required` - DNS setup instructions for external providers

## DNS Provider Setup

### Route53 (Managed by Module)

```hcl
dns_provider    = "route53"
route53_zone_id = "Z1234567890ABC"
```

The module automatically creates DNS records and validates the certificate.

### External DNS (Cloudflare, Namecheap, etc.)

```hcl
dns_provider = "external"
domain_name  = "app.example.com"
```

After `terraform apply`, the module outputs validation records. You need to:

1. **For Certificate Validation** (if creating new cert):
   ```bash
   terraform output acm_certificate_domain_validation_options
   ```
   Create the CNAME records in your DNS provider.

2. **For Application Access**:
   ```bash
   terraform output dns_configuration_required
   ```
   Create an ALIAS or CNAME record pointing to the CloudFront domain.

### No Custom Domain (CloudFront Only)

```hcl
dns_provider = "none"
# domain_name is not required
```

Access your app via the CloudFront domain: `https://d1234567890.cloudfront.net`

## Cost Estimation

Based on moderate traffic (1M requests/month, 10GB transfer):

| Service | Monthly Cost |
|---------|--------------|
| Lambda (ARM64) | $0-2 (free tier covers most) |
| CloudFront | $0-1 (1TB + 10M requests free) |
| S3 Storage | $0-1 |
| DynamoDB | $0 (on-demand, low usage) |
| SQS | $0 (free tier) |
| ACM Certificate | $0 (free for CloudFront) |
| Route53 (optional) | $0.50 (hosted zone) |

**Total: ~$0-5/month** (mostly free tier)

## Deployment Updates

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

# 4. Invalidate CloudFront cache
DISTRIBUTION_ID=$(terraform output -raw cloudfront_distribution_id)
aws cloudfront create-invalidation --distribution-id $DISTRIBUTION_ID --paths "/*"
```

## Monitoring

### CloudWatch Logs

```bash
# Server function logs
aws logs tail /aws/lambda/my-app-server --follow

# Image optimization logs
aws logs tail /aws/lambda/my-app-image-optimization --follow
```

### CloudFront Metrics

View in AWS Console:
- Request count
- Error rates (4xx, 5xx)
- Cache hit ratio
- Data transfer

## Troubleshooting

### Certificate Validation Pending

If using external DNS and certificate validation is stuck:

1. Check validation records:
   ```bash
   terraform output acm_certificate_domain_validation_options
   ```

2. Verify DNS records are created correctly in your DNS provider

3. Wait up to 30 minutes for DNS propagation

### Lambda Function Errors

Check logs:
```bash
aws logs tail /aws/lambda/my-app-server --since 1h
```

Common issues:
- Missing environment variables
- S3 bucket permissions
- Memory/timeout limits

### CloudFront 403 Errors

Verify:
1. S3 bucket policy allows CloudFront OAC
2. Assets are uploaded to S3
3. Lambda function URLs are accessible

## Security Best Practices

✅ **Implemented by this module:**

- S3 buckets are private (no public access)
- CloudFront uses Origin Access Control (OAC)
- HTTPS enforced (HTTP redirects to HTTPS)
- TLS 1.2+ minimum
- Lambda functions use least-privilege IAM roles
- No hardcoded credentials
- S3 versioning enabled by default
- CloudWatch logging enabled

## Examples

See the `examples/` directory for complete working examples:

- `examples/basic/` - Simple deployment without custom domain
- `examples/route53/` - Full setup with Route53 DNS
- `examples/cloudflare/` - Using Cloudflare for DNS
- `examples/existing-certificate/` - Bring your own certificate
- `examples/multi-region/` - Multi-region deployment

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.5 |
| aws | >= 5.0 |
| archive | >= 2.0 |

## Providers

| Name | Version |
|------|---------|
| aws | >= 5.0 |
| aws.us_east_1 | >= 5.0 |
| archive | >= 2.0 |

## Resources Created

- CloudFront Distribution
- Lambda Functions (4): Server, Image Optimization, Revalidation, Warmer
- S3 Buckets (2): Assets, Cache
- DynamoDB Table: Revalidation metadata
- SQS Queue: Revalidation queue (FIFO)
- ACM Certificate (optional)
- Route53 Record (optional)
- IAM Roles and Policies
- CloudWatch Event Rules
- CloudFront Functions

## License

MIT

## Contributing

Contributions welcome! Please open an issue or PR.

## References

- [OpenNext Documentation](https://opennext.js.org/)
- [Next.js on AWS](https://opennext.js.org/aws/v2/advanced/architecture)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [AWS Lambda Best Practices](https://docs.aws.amazon.com/lambda/latest/dg/best-practices.html)
# terraform-aws-nextjs-opennext
