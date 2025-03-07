provider "aws" {
  region                   = "us-east-1"
  shared_config_files      = ["~/.aws/config"]
  shared_credentials_files = ["~/.aws/credentials"]
  profile                  = "logging" # Sandbox1

  default_tags {
    tags = {
      Environment = "dev"
      ManagedBy   = "Terraform"
    }
  }
}

# Build Security Group for Lambda
resource "aws_security_group" "lambda_sg" {
  name        = "lambda_sg"
  description = "Allow inbound traffic"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


# Create a Lambda function that subscribes to a CloudWatch log group
# and forwards log events to a CloudWatch Logs destination.
# The Lambda function is triggered by a CloudWatch Events rule that
# runs on a schedule.

resource "aws_iam_role" "lambda_role" {
  name = "cloudwatch_lambda_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_policy" "lambda_policy" {
  name = "cloudwatch_lambda_policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:DescribeLogGroups",
          "logs:DescribeSubscriptionFilters",
          "logs:PutSubscriptionFilter",
          "logs:DeleteSubscriptionFilter",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_policy_attach" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}

resource "aws_iam_role_policy_attachment" "AWSLambdaENIManagementAccess" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaENIManagementAccess"
}

resource "aws_lambda_function" "cloudwatch_lambda" {
  filename      = "lambda.zip"
  function_name = "cloudwatch-log-subscription"
  role          = aws_iam_role.lambda_role.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.13"
  timeout       = 900 # 15 minutes

  vpc_config {
    subnet_ids         = var.subnet_ids
    security_group_ids = [aws_security_group.lambda_sg.id]
  }

  environment {
    variables = {
      TARGET_SUBSCRIPTION_FILTER = var.subscription_filter_name
      DESTINATION_ARN            = var.destination_arn
      LOG_GROUP_NAME             = var.log_group_name
    }
  }
}

resource "aws_cloudwatch_event_rule" "lambda_schedule" {
  name                = "lambda-cloudwatch-log-checker"
  schedule_expression = "rate(1 hour)"
}

resource "aws_cloudwatch_event_target" "lambda_target" {
  rule      = aws_cloudwatch_event_rule.lambda_schedule.name
  target_id = "cloudwatch_lambda"
  arn       = aws_lambda_function.cloudwatch_lambda.arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.cloudwatch_lambda.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.lambda_schedule.arn
}

resource "aws_cloudwatch_log_group" "log_group" {
  name = var.log_group_name
}

module "vpce" {
  source               = "./modules/vpc-endpoints"
  environment          = "dev"
  region               = var.region
  vpc_id               = var.vpc_id
  deploy_default_vpces = false
  vpce_list = [
    {
      service_name        = "logs"
      description         = "logs"
      interface_type      = "Interface"
      private_dns_enabled = true
    },
    {
      service_name        = "lambda"
      description         = "lambda"
      interface_type      = "Interface"
      private_dns_enabled = true
    }
  ]
}
