################################################################################
# IAM Roles and Policies
################################################################################

# Server Lambda Role
resource "aws_iam_role" "server_lambda" {
  name = "${var.app_name}-server-lambda"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "server_lambda_basic" {
  role       = aws_iam_role.server_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "server_lambda" {
  name = "${var.app_name}-server-lambda-policy"
  role = aws_iam_role.server_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.cache.arn,
          "${aws_s3_bucket.cache.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "sqs:SendMessage"
        ]
        Resource = aws_sqs_queue.revalidation.arn
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Resource = [
          aws_dynamodb_table.revalidation.arn,
          "${aws_dynamodb_table.revalidation.arn}/index/*"
        ]
      }
    ]
  })
}

# Image Optimization Lambda Role
resource "aws_iam_role" "image_optimization_lambda" {
  name = "${var.app_name}-image-lambda"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "image_optimization_lambda_basic" {
  role       = aws_iam_role.image_optimization_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "image_optimization_lambda" {
  name = "${var.app_name}-image-lambda-policy"
  role = aws_iam_role.image_optimization_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject"
        ]
        Resource = [
          "${aws_s3_bucket.assets.arn}/*"
        ]
      }
    ]
  })
}

# Revalidation Lambda Role
resource "aws_iam_role" "revalidation_lambda" {
  name = "${var.app_name}-revalidation-lambda"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "revalidation_lambda_basic" {
  role       = aws_iam_role.revalidation_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "revalidation_lambda" {
  name = "${var.app_name}-revalidation-lambda-policy"
  role = aws_iam_role.revalidation_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ]
        Resource = aws_sqs_queue.revalidation.arn
      }
    ]
  })
}

# Warmer Lambda Role
resource "aws_iam_role" "warmer_lambda" {
  count = var.warmer_enabled ? 1 : 0
  name  = "${var.app_name}-warmer-lambda"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "warmer_lambda_basic" {
  count      = var.warmer_enabled ? 1 : 0
  role       = aws_iam_role.warmer_lambda[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "warmer_lambda" {
  count = var.warmer_enabled ? 1 : 0
  name  = "${var.app_name}-warmer-lambda-policy"
  role  = aws_iam_role.warmer_lambda[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction"
        ]
        Resource = aws_lambda_function.server.arn
      }
    ]
  })
}

################################################################################
# Lambda Functions
################################################################################

# Package Lambda functions
data "archive_file" "server" {
  type        = "zip"
  source_dir  = "${var.opennext_build_path}/server-functions/default"
  output_path = "${path.module}/.terraform/tmp/server-function.zip"
}

data "archive_file" "image_optimization" {
  type        = "zip"
  source_dir  = "${var.opennext_build_path}/image-optimization-function"
  output_path = "${path.module}/.terraform/tmp/image-optimization-function.zip"
}

data "archive_file" "revalidation" {
  type        = "zip"
  source_dir  = "${var.opennext_build_path}/revalidation-function"
  output_path = "${path.module}/.terraform/tmp/revalidation-function.zip"
}

data "archive_file" "warmer" {
  count       = var.warmer_enabled ? 1 : 0
  type        = "zip"
  source_dir  = "${var.opennext_build_path}/warmer-function"
  output_path = "${path.module}/.terraform/tmp/warmer-function.zip"
}

# Server Lambda Function
resource "aws_lambda_function" "server" {
  filename         = data.archive_file.server.output_path
  function_name    = "${var.app_name}-server"
  role             = aws_iam_role.server_lambda.arn
  handler          = "index.handler"
  source_code_hash = data.archive_file.server.output_base64sha256
  runtime          = "nodejs20.x"
  architectures    = [var.lambda_architecture]
  memory_size      = var.lambda_memory_size
  timeout          = var.lambda_timeout

  environment {
    variables = {
      CACHE_BUCKET_NAME         = aws_s3_bucket.cache.id
      CACHE_BUCKET_REGION       = data.aws_region.current.name
      REVALIDATION_QUEUE_URL    = aws_sqs_queue.revalidation.url
      REVALIDATION_QUEUE_REGION = data.aws_region.current.name
      CACHE_DYNAMO_TABLE        = aws_dynamodb_table.revalidation.name
    }
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${var.app_name}-server"
    }
  )
}

resource "aws_lambda_function_url" "server" {
  function_name      = aws_lambda_function.server.function_name
  authorization_type = "AWS_IAM"

  cors {
    allow_origins  = ["*"]
    allow_methods  = ["*"]
    allow_headers  = ["*"]
    expose_headers = ["*"]
    max_age        = 86400
  }
}

# Image Optimization Lambda Function
resource "aws_lambda_function" "image_optimization" {
  filename         = data.archive_file.image_optimization.output_path
  function_name    = "${var.app_name}-image-optimization"
  role             = aws_iam_role.image_optimization_lambda.arn
  handler          = "index.handler"
  source_code_hash = data.archive_file.image_optimization.output_base64sha256
  runtime          = "nodejs20.x"
  architectures    = [var.lambda_architecture]
  memory_size      = var.image_optimization_memory
  timeout          = var.image_optimization_timeout

  environment {
    variables = {
      BUCKET_NAME = aws_s3_bucket.assets.id
    }
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${var.app_name}-image-optimization"
    }
  )
}

resource "aws_lambda_function_url" "image_optimization" {
  function_name      = aws_lambda_function.image_optimization.function_name
  authorization_type = "AWS_IAM"

  cors {
    allow_origins  = ["*"]
    allow_methods  = ["*"]
    allow_headers  = ["*"]
    expose_headers = ["*"]
    max_age        = 86400
  }
}

# Revalidation Lambda Function
resource "aws_lambda_function" "revalidation" {
  filename         = data.archive_file.revalidation.output_path
  function_name    = "${var.app_name}-revalidation"
  role             = aws_iam_role.revalidation_lambda.arn
  handler          = "index.handler"
  source_code_hash = data.archive_file.revalidation.output_base64sha256
  runtime          = "nodejs20.x"
  architectures    = [var.lambda_architecture]
  memory_size      = 512
  timeout          = 30

  tags = merge(
    local.common_tags,
    {
      Name = "${var.app_name}-revalidation"
    }
  )
}

resource "aws_lambda_event_source_mapping" "revalidation" {
  event_source_arn = aws_sqs_queue.revalidation.arn
  function_name    = aws_lambda_function.revalidation.arn
  batch_size       = 5
}

# Warmer Lambda Function
resource "aws_lambda_function" "warmer" {
  count            = var.warmer_enabled ? 1 : 0
  filename         = data.archive_file.warmer[0].output_path
  function_name    = "${var.app_name}-warmer"
  role             = aws_iam_role.warmer_lambda[0].arn
  handler          = "index.handler"
  source_code_hash = data.archive_file.warmer[0].output_base64sha256
  runtime          = "nodejs20.x"
  architectures    = [var.lambda_architecture]
  memory_size      = 512
  timeout          = 30

  environment {
    variables = {
      FUNCTION_NAME = aws_lambda_function.server.function_name
      CONCURRENCY   = var.warmer_concurrency
    }
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${var.app_name}-warmer"
    }
  )
}

# EventBridge rule to invoke warmer
resource "aws_cloudwatch_event_rule" "warmer" {
  count               = var.warmer_enabled ? 1 : 0
  name                = "${var.app_name}-warmer"
  description         = "Trigger warmer function periodically"
  schedule_expression = var.warmer_schedule

  tags = local.common_tags
}

resource "aws_cloudwatch_event_target" "warmer" {
  count     = var.warmer_enabled ? 1 : 0
  rule      = aws_cloudwatch_event_rule.warmer[0].name
  target_id = "warmer-lambda"
  arn       = aws_lambda_function.warmer[0].arn
}

resource "aws_lambda_permission" "warmer_eventbridge" {
  count         = var.warmer_enabled ? 1 : 0
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.warmer[0].function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.warmer[0].arn
}

# Lambda permissions for CloudFront OAC to invoke Function URLs
resource "aws_lambda_permission" "server_cloudfront" {
  statement_id  = "AllowCloudFrontServicePrincipal"
  action        = "lambda:InvokeFunctionUrl"
  function_name = aws_lambda_function.server.function_name
  principal     = "cloudfront.amazonaws.com"
  source_arn    = "arn:aws:cloudfront::${data.aws_caller_identity.current.account_id}:distribution/${aws_cloudfront_distribution.main.id}"
}

resource "aws_lambda_permission" "image_optimization_cloudfront" {
  statement_id  = "AllowCloudFrontServicePrincipal"
  action        = "lambda:InvokeFunctionUrl"
  function_name = aws_lambda_function.image_optimization.function_name
  principal     = "cloudfront.amazonaws.com"
  source_arn    = "arn:aws:cloudfront::${data.aws_caller_identity.current.account_id}:distribution/${aws_cloudfront_distribution.main.id}"
}
