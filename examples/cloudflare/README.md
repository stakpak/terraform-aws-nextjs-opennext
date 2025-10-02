# Cloudflare Example - External DNS Provider

This example demonstrates deploying a Next.js application with Cloudflare managing DNS while AWS hosts the infrastructure.

## Features

- ✅ Custom domain with Cloudflare DNS
- ✅ Automatic ACM certificate creation
- ✅ Automatic certificate validation via Cloudflare
- ✅ Automatic DNS record creation
- ✅ Cloudflare's global DNS network
- ✅ Fully managed by Terraform

## Prerequisites

1. **Cloudflare Account**: Domain must be managed by Cloudflare
2. **Cloudflare API Token**: With DNS edit permissions

## Setup

### 1. Create Cloudflare API Token

1. Go to Cloudflare Dashboard → My Profile → API Tokens
2. Click "Create Token"
3. Use "Edit zone DNS" template
4. Select your zone (domain)
5. Copy the token

### 2. Configure Cloudflare Provider

Set environment variable:
```bash
export CLOUDFLARE_API_TOKEN="your-token-here"
```

Or use email + API key:
```bash
export CLOUDFLARE_EMAIL="your-email@example.com"
export CLOUDFLARE_API_KEY="your-global-api-key"
```

### 3. Update Configuration

Edit `main.tf` and change:
```hcl
data "cloudflare_zone" "main" {
  name = "example.com"  # Your root domain
}

# In module block:
domain_name = "app.example.com"  # Your subdomain
```

## Usage

1. **Build your Next.js app:**

```bash
cd ../../../portfolio-app
npm run build
npx open-next@latest build
```

2. **Deploy:**

```bash
cd examples/cloudflare
terraform init
terraform apply
```

The module will:
- Create ACM certificate in AWS
- Create DNS validation records in Cloudflare
- Wait for certificate validation
- Create CloudFront distribution
- Create CNAME record in Cloudflare pointing to CloudFront

3. **Upload assets:**

```bash
ASSETS_BUCKET=$(terraform output -raw assets_bucket_name)

aws s3 sync ../../../portfolio-app/.open-next/assets s3://$ASSETS_BUCKET/ \
  --cache-control "public,max-age=31536000,immutable" \
  --exclude "*" \
  --include "_next/static/*"

aws s3 sync ../../../portfolio-app/.open-next/assets s3://$ASSETS_BUCKET/ \
  --cache-control "public,max-age=0,s-maxage=31536000,must-revalidate" \
  --exclude "_next/*"

CACHE_BUCKET=$(terraform output -raw cache_bucket_name)
aws s3 sync ../../../portfolio-app/.open-next/cache s3://$CACHE_BUCKET/
```

4. **Access your application:**

```bash
terraform output website_url
```

## Architecture

```
┌─────────────┐
│   Users     │
└──────┬──────┘
       │
       ▼
┌──────────────────┐
│  Cloudflare DNS  │  (DNS Resolution)
└──────┬───────────┘
       │
       ▼
┌──────────────────┐
│  AWS CloudFront  │  (CDN + SSL)
└──────┬───────────┘
       │
       ▼
┌──────────────────┐
│  Lambda + S3     │  (Application)
└──────────────────┘
```

## Why Cloudflare + AWS?

### Benefits

1. **Best of Both Worlds**:
   - Cloudflare's fast DNS resolution
   - AWS's powerful compute and storage

2. **Flexibility**:
   - Easy to add Cloudflare features (firewall, analytics)
   - Keep existing Cloudflare setup

3. **Cost**:
   - Cloudflare DNS is free
   - No Route53 hosted zone cost ($0.50/month saved)

### Important: Proxied vs DNS-Only

This example uses **DNS-only mode** (proxied = false):

```hcl
resource "cloudflare_record" "app" {
  proxied = false  # Must be false for CloudFront
}
```

**Why?** CloudFront already provides:
- Global CDN
- DDoS protection
- SSL/TLS termination
- Caching

Using Cloudflare proxy would create double-CDN, causing issues.

## DNS Propagation

DNS changes typically propagate within 1-5 minutes with Cloudflare. Check status:

```bash
# Check DNS resolution
dig app.example.com

# Check certificate status
aws acm describe-certificate \
  --certificate-arn $(terraform output -raw acm_certificate_arn) \
  --region us-east-1
```

## Monitoring

### Cloudflare Dashboard

View DNS analytics:
- Query volume
- Response times
- Geographic distribution

### AWS CloudWatch

```bash
# Server function logs
aws logs tail /aws/lambda/my-nextjs-app-server --follow

# Image optimization logs
aws logs tail /aws/lambda/my-nextjs-app-image-optimization --follow
```

## Cost Estimation

For moderate traffic (1M requests/month):

| Service | Monthly Cost |
|---------|--------------|
| Lambda | $1-3 |
| CloudFront | $1-2 |
| S3 | $0-1 |
| Cloudflare DNS | $0 (free) |
| Other | $0 |

**Total: ~$2-6/month** (saves $0.50 vs Route53)

## Advanced: Adding Cloudflare Features

### Page Rules

```hcl
resource "cloudflare_page_rule" "cache_everything" {
  zone_id = data.cloudflare_zone.main.id
  target  = "app.example.com/_next/static/*"
  
  actions {
    cache_level = "cache_everything"
  }
}
```

### Firewall Rules

```hcl
resource "cloudflare_firewall_rule" "block_bots" {
  zone_id     = data.cloudflare_zone.main.id
  description = "Block known bots"
  filter_id   = cloudflare_filter.bots.id
  action      = "block"
}
```

### Analytics

Enable in Cloudflare Dashboard → Analytics → Web Analytics

## Cleanup

```bash
# Empty S3 buckets
ASSETS_BUCKET=$(terraform output -raw assets_bucket_name)
CACHE_BUCKET=$(terraform output -raw cache_bucket_name)

aws s3 rm s3://$ASSETS_BUCKET --recursive
aws s3 rm s3://$CACHE_BUCKET --recursive

# Destroy infrastructure
terraform destroy
```

## Troubleshooting

### Certificate Validation Stuck

Check validation records in Cloudflare:
```bash
dig _acm-validation.app.example.com CNAME
```

### DNS Not Resolving

1. Verify record exists in Cloudflare Dashboard
2. Check proxied status (should be DNS-only)
3. Wait 5 minutes for propagation

### SSL Errors

Ensure:
1. Certificate is validated in ACM
2. CloudFront distribution is deployed
3. DNS points to CloudFront (not Cloudflare proxy)

## Comparison: Cloudflare vs Route53

| Feature | Cloudflare | Route53 |
|---------|------------|---------|
| DNS Speed | Very Fast | Fast |
| Cost | Free | $0.50/month |
| Integration | External | Native AWS |
| Setup | More steps | Automatic |
| Features | Firewall, Analytics | AWS-native |

Choose Cloudflare if:
- You already use Cloudflare
- You want free DNS
- You need Cloudflare-specific features

Choose Route53 if:
- You want full AWS integration
- You prefer simpler setup
- Cost difference doesn't matter

## Next Steps

- Enable Cloudflare Web Analytics
- Set up Cloudflare firewall rules
- Configure page rules for caching
- Add Cloudflare Workers for edge logic
