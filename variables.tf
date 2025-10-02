################################################################################
# Required Variables
################################################################################

variable "app_name" {
  description = "Name of the application (used for resource naming). Must be lowercase alphanumeric with hyphens only."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.app_name))
    error_message = "app_name must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "opennext_build_path" {
  description = "Path to the .open-next build output directory (e.g., '../my-app/.open-next')"
  type        = string

  validation {
    condition     = can(regex(".*\\.open-next$", var.opennext_build_path))
    error_message = "opennext_build_path must point to a .open-next directory."
  }
}

################################################################################
# DNS & Certificate Configuration
################################################################################

variable "domain_name" {
  description = "Custom domain name for the application (e.g., 'app.example.com'). Leave empty to use CloudFront domain only."
  type        = string
  default     = ""
}

variable "dns_provider" {
  description = "DNS provider to use: 'route53' (managed by this module), 'external' (you manage DNS), or 'none' (no custom domain)"
  type        = string
  default     = "none"

  validation {
    condition     = contains(["route53", "external", "none"], var.dns_provider)
    error_message = "dns_provider must be one of: route53, external, none."
  }
}

variable "route53_zone_id" {
  description = "Route53 hosted zone ID (required only when dns_provider = 'route53')"
  type        = string
  default     = ""
}

variable "certificate_arn" {
  description = "Existing ACM certificate ARN in us-east-1 (required when dns_provider = 'external'). Leave empty to create a new certificate."
  type        = string
  default     = ""
}

variable "create_certificate" {
  description = "Whether to create a new ACM certificate. Set to false if providing certificate_arn."
  type        = bool
  default     = true
}

################################################################################
# Lambda Configuration
################################################################################

variable "lambda_architecture" {
  description = "Lambda function architecture: 'arm64' (recommended, cheaper) or 'x86_64'"
  type        = string
  default     = "arm64"

  validation {
    condition     = contains(["arm64", "x86_64"], var.lambda_architecture)
    error_message = "lambda_architecture must be either 'arm64' or 'x86_64'."
  }
}

variable "lambda_memory_size" {
  description = "Memory size for server Lambda function in MB (128-10240)"
  type        = number
  default     = 1024

  validation {
    condition     = var.lambda_memory_size >= 128 && var.lambda_memory_size <= 10240
    error_message = "lambda_memory_size must be between 128 and 10240 MB."
  }
}

variable "lambda_timeout" {
  description = "Timeout for server Lambda function in seconds (1-900)"
  type        = number
  default     = 10

  validation {
    condition     = var.lambda_timeout >= 1 && var.lambda_timeout <= 900
    error_message = "lambda_timeout must be between 1 and 900 seconds."
  }
}

variable "image_optimization_memory" {
  description = "Memory size for image optimization Lambda in MB (128-10240)"
  type        = number
  default     = 1536

  validation {
    condition     = var.image_optimization_memory >= 128 && var.image_optimization_memory <= 10240
    error_message = "image_optimization_memory must be between 128 and 10240 MB."
  }
}

variable "image_optimization_timeout" {
  description = "Timeout for image optimization Lambda in seconds (1-900)"
  type        = number
  default     = 30

  validation {
    condition     = var.image_optimization_timeout >= 1 && var.image_optimization_timeout <= 900
    error_message = "image_optimization_timeout must be between 1 and 900 seconds."
  }
}

variable "warmer_enabled" {
  description = "Enable Lambda warmer to reduce cold starts"
  type        = bool
  default     = true
}

variable "warmer_concurrency" {
  description = "Number of server function instances to keep warm (0-10)"
  type        = number
  default     = 1

  validation {
    condition     = var.warmer_concurrency >= 0 && var.warmer_concurrency <= 10
    error_message = "warmer_concurrency must be between 0 and 10."
  }
}

variable "warmer_schedule" {
  description = "EventBridge schedule expression for warmer (e.g., 'rate(5 minutes)')"
  type        = string
  default     = "rate(5 minutes)"
}

################################################################################
# CloudFront Configuration
################################################################################

variable "cloudfront_price_class" {
  description = "CloudFront distribution price class: PriceClass_All, PriceClass_200, or PriceClass_100"
  type        = string
  default     = "PriceClass_100"

  validation {
    condition     = contains(["PriceClass_All", "PriceClass_200", "PriceClass_100"], var.cloudfront_price_class)
    error_message = "cloudfront_price_class must be one of: PriceClass_All, PriceClass_200, PriceClass_100."
  }
}

variable "cloudfront_default_root_object" {
  description = "Default root object for CloudFront (leave empty for Next.js)"
  type        = string
  default     = ""
}

variable "cloudfront_geo_restriction_type" {
  description = "Geo restriction type: 'none', 'whitelist', or 'blacklist'"
  type        = string
  default     = "none"

  validation {
    condition     = contains(["none", "whitelist", "blacklist"], var.cloudfront_geo_restriction_type)
    error_message = "cloudfront_geo_restriction_type must be one of: none, whitelist, blacklist."
  }
}

variable "cloudfront_geo_restriction_locations" {
  description = "List of country codes for geo restriction (ISO 3166-1-alpha-2 codes)"
  type        = list(string)
  default     = []
}

variable "cloudfront_minimum_protocol_version" {
  description = "Minimum TLS protocol version for CloudFront"
  type        = string
  default     = "TLSv1.2_2021"
}

################################################################################
# S3 Configuration
################################################################################

variable "assets_bucket_name" {
  description = "Custom name for assets S3 bucket (leave empty for auto-generated name)"
  type        = string
  default     = ""
}

variable "cache_bucket_name" {
  description = "Custom name for cache S3 bucket (leave empty for auto-generated name)"
  type        = string
  default     = ""
}

variable "enable_s3_versioning" {
  description = "Enable versioning on assets S3 bucket"
  type        = bool
  default     = true
}

variable "cache_expiration_days" {
  description = "Number of days before cache objects expire (0 to disable)"
  type        = number
  default     = 30

  validation {
    condition     = var.cache_expiration_days >= 0
    error_message = "cache_expiration_days must be 0 or greater."
  }
}

################################################################################
# Tags
################################################################################

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}
