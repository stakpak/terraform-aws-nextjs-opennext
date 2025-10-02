# Basic Example - No Custom Domain

This example demonstrates the simplest deployment of a Next.js application using this module without a custom domain. The application will be accessible via the CloudFront distribution domain.

## Features

- ✅ No custom domain required
- ✅ No DNS configuration needed
- ✅ No SSL certificate management
- ✅ Instant deployment
- ✅ Perfect for testing and development

## Usage

1. **Build your Next.js app with OpenNext:**

```bash
cd ../../../portfolio-app
npm run build
npx open-next@latest build
```

2. **Initialize Terraform:**

```bash
cd examples/basic
terraform init
```

3. **Apply the configuration:**

```bash
terraform apply
```

4. **Upload static assets:**

```bash
ASSETS_BUCKET=$(terraform output -raw assets_bucket_name)

aws s3 sync ../../../portfolio-app/.open-next/assets s3://$ASSETS_BUCKET/ \
  --cache-control "public,max-age=31536000,immutable" \
  --exclude "*" \
  --include "_next/static/*"

aws s3 sync ../../../portfolio-app/.open-next/assets s3://$ASSETS_BUCKET/ \
  --cache-control "public,max-age=0,s-maxage=31536000,must-revalidate" \
  --exclude "_next/*"
```

5. **Upload cache files:**

```bash
CACHE_BUCKET=$(terraform output -raw cache_bucket_name)
aws s3 sync ../../../portfolio-app/.open-next/cache s3://$CACHE_BUCKET/
```

6. **Access your application:**

```bash
terraform output website_url
```

The output will be something like: `https://d1234567890.cloudfront.net`

## Configuration

This example uses minimal configuration:

- **No custom domain**: Uses CloudFront's default domain
- **ARM64 Lambda**: Cost-optimized architecture
- **1024 MB memory**: Suitable for most Next.js apps
- **Lambda warmer enabled**: Reduces cold starts
- **PriceClass_100**: US, Canada, and Europe edge locations

## Cost

Estimated monthly cost: **$0-2** (mostly covered by AWS free tier)

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

## Next Steps

Once you've tested this basic setup, you can:

1. Add a custom domain (see `examples/route53/` or `examples/cloudflare/`)
2. Increase Lambda memory for better performance
3. Enable geo-restriction for specific regions
4. Add custom CloudFront behaviors
