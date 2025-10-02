################################################################################
# CloudFront Outputs
################################################################################

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID"
  value       = aws_cloudfront_distribution.main.id
}

output "cloudfront_distribution_arn" {
  description = "CloudFront distribution ARN"
  value       = aws_cloudfront_distribution.main.arn
}

output "cloudfront_domain_name" {
  description = "CloudFront distribution domain name (use this if no custom domain)"
  value       = aws_cloudfront_distribution.main.domain_name
}

output "website_url" {
  description = "Website URL (custom domain if configured, otherwise CloudFront domain)"
  value       = local.use_custom_domain ? "https://${var.domain_name}" : "https://${aws_cloudfront_distribution.main.domain_name}"
}

################################################################################
# S3 Outputs
################################################################################

output "assets_bucket_name" {
  description = "S3 bucket name for static assets"
  value       = aws_s3_bucket.assets.id
}

output "assets_bucket_arn" {
  description = "S3 bucket ARN for static assets"
  value       = aws_s3_bucket.assets.arn
}

output "cache_bucket_name" {
  description = "S3 bucket name for cache"
  value       = aws_s3_bucket.cache.id
}

output "cache_bucket_arn" {
  description = "S3 bucket ARN for cache"
  value       = aws_s3_bucket.cache.arn
}

################################################################################
# Lambda Outputs
################################################################################

output "server_function_name" {
  description = "Server Lambda function name"
  value       = aws_lambda_function.server.function_name
}

output "server_function_arn" {
  description = "Server Lambda function ARN"
  value       = aws_lambda_function.server.arn
}

output "server_function_url" {
  description = "Server Lambda function URL"
  value       = aws_lambda_function_url.server.function_url
}

output "image_optimization_function_name" {
  description = "Image optimization Lambda function name"
  value       = aws_lambda_function.image_optimization.function_name
}

output "image_optimization_function_arn" {
  description = "Image optimization Lambda function ARN"
  value       = aws_lambda_function.image_optimization.arn
}

output "revalidation_function_name" {
  description = "Revalidation Lambda function name"
  value       = aws_lambda_function.revalidation.function_name
}

output "warmer_function_name" {
  description = "Warmer Lambda function name (if enabled)"
  value       = var.warmer_enabled ? aws_lambda_function.warmer[0].function_name : null
}

################################################################################
# DynamoDB & SQS Outputs
################################################################################

output "revalidation_queue_url" {
  description = "SQS revalidation queue URL"
  value       = aws_sqs_queue.revalidation.url
}

output "revalidation_queue_arn" {
  description = "SQS revalidation queue ARN"
  value       = aws_sqs_queue.revalidation.arn
}

output "revalidation_table_name" {
  description = "DynamoDB revalidation table name"
  value       = aws_dynamodb_table.revalidation.name
}

output "revalidation_table_arn" {
  description = "DynamoDB revalidation table ARN"
  value       = aws_dynamodb_table.revalidation.arn
}

################################################################################
# Certificate Outputs
################################################################################

output "acm_certificate_arn" {
  description = "ACM certificate ARN (if created by this module)"
  value       = local.create_certificate ? aws_acm_certificate.main[0].arn : null
}

output "acm_certificate_domain_validation_options" {
  description = "Certificate domain validation options (for external DNS providers)"
  value       = local.create_certificate && !local.manage_route53 ? aws_acm_certificate.main[0].domain_validation_options : null
}

################################################################################
# DNS Outputs
################################################################################

output "route53_record_fqdn" {
  description = "Route53 record FQDN (if managed by this module)"
  value       = local.manage_route53 ? aws_route53_record.main[0].fqdn : null
}

output "dns_configuration_required" {
  description = "Instructions for DNS configuration (when using external DNS)"
  value = local.use_external_dns ? {
    type   = "A"
    name   = var.domain_name
    target = aws_cloudfront_distribution.main.domain_name
    note   = "Create an ALIAS/CNAME record pointing to the CloudFront domain"
  } : null
}
