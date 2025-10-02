# Route53 Example - Full AWS Integration

This example demonstrates a complete production deployment with Route53 DNS management and automatic SSL certificate provisioning.

## Features

- ✅ Custom domain with Route53
- ✅ Automatic ACM certificate creation
- ✅ Automatic DNS record creation
- ✅ Automatic certificate validation
- ✅ Production-ready configuration
- ✅ Fully managed by Terraform

## Prerequisites

1. **Route53 Hosted Zone**: You must have a hosted zone in Route53 for your domain
2. **Domain**: Your domain's nameservers must point to Route53

## Usage

1. **Update the configuration:**

Edit `main.tf` and change:
```hcl
domain_name     = "app.example.com"  # Your subdomain
route53_zone_id = "Z1234567890ABC"   # Your hosted zone ID
```

To find your hosted zone ID:
```bash
aws route53 list-hosted-zones
```

2. **Build your Next.js app:**

```bash
cd ../../../portfolio-app
npm run build
npx open-next@latest build
```

3. **Deploy:**

```bash
cd examples/route53
terraform init
terraform apply
```

The module will:
- Create an ACM certificate
- Create DNS validation records
- Wait for certificate validation
- Create CloudFront distribution
- Create A record pointing to CloudFront

4. **Upload assets:**

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

5. **Access your application:**

```bash
terraform output website_url
```

Your app will be available at `https://app.example.com`

## Configuration Highlights

### Production Settings

- **PriceClass_200**: Covers US, Europe, and Asia
- **2 warm instances**: Better performance for production traffic
- **ARM64 architecture**: 20% cost savings
- **S3 versioning enabled**: Rollback capability

### Security

- ✅ HTTPS enforced
- ✅ TLS 1.2+ minimum
- ✅ Private S3 buckets
- ✅ CloudFront OAC
- ✅ Least-privilege IAM roles

## DNS Propagation

After `terraform apply`, DNS changes may take 5-60 minutes to propagate globally. You can check propagation status:

```bash
# Check DNS resolution
dig app.example.com

# Check certificate status
aws acm describe-certificate \
  --certificate-arn $(terraform output -raw acm_certificate_arn) \
  --region us-east-1
```

## Monitoring

### CloudWatch Logs

```bash
# Server function logs
aws logs tail /aws/lambda/my-nextjs-app-server --follow

# Image optimization logs
aws logs tail /aws/lambda/my-nextjs-app-image-optimization --follow
```

### CloudFront Metrics

View in AWS Console → CloudFront → Your Distribution → Monitoring

## Cost Estimation

For moderate traffic (1M requests/month):

| Service | Monthly Cost |
|---------|--------------|
| Lambda | $1-3 |
| CloudFront | $1-2 |
| S3 | $0-1 |
| Route53 | $0.50 |
| Other | $0 |

**Total: ~$3-7/month**

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

Note: The Route53 hosted zone is not managed by this module and won't be deleted.

## Troubleshooting

### Certificate Validation Stuck

If certificate validation takes more than 30 minutes:

1. Check validation records exist:
```bash
aws route53 list-resource-record-sets \
  --hosted-zone-id Z1234567890ABC \
  --query "ResourceRecordSets[?Type=='CNAME']"
```

2. Verify domain ownership in Route53

### 403 Errors

Check:
1. Assets are uploaded to S3
2. CloudFront distribution is deployed (status: Deployed)
3. DNS is resolving correctly

## Next Steps

- Set up CloudWatch alarms for errors
- Configure CloudFront logging
- Add WAF rules for security
- Set up CI/CD pipeline for deployments
