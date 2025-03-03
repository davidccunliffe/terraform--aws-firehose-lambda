
# Kinesis Stream
resource "aws_kinesis_stream" "log_stream" {
  name = "kinesis-logging-stream-${var.environment}"


  shard_count      = 2
  retention_period = 24


  shard_level_metrics = [
    "IncomingBytes",
    "OutgoingBytes",
    "IncomingRecords",
    "OutgoingRecords",
    "IteratorAgeMilliseconds"
  ]


  stream_mode_details {
    stream_mode = "PROVISIONED"
  }
}

# Log Destination and IAM Roles/Policies
resource "aws_cloudwatch_log_destination" "kinesis_log_destination" {
  name       = "kinesis-log-destination"
  role_arn   = aws_iam_role.logs_kinesis_role.arn
  target_arn = aws_kinesis_stream.log_stream.arn
}

resource "aws_cloudwatch_log_destination_policy" "kinesis_log_destination_policy" {
  destination_name = aws_cloudwatch_log_destination.kinesis_log_destination.name
  access_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "LoggingAccount"
        Effect = "Allow"
        Principal = {
          AWS = var.logging_account_id
        }
        Action   = "logs:PutSubscriptionFilter"
        Resource = aws_cloudwatch_log_destination.kinesis_log_destination.arn
      },
      {
        Sid    = "SourceAccounts"
        Effect = "Allow"
        Principal = {
          AWS = var.source_account_ids
        }
        Action   = "logs:PutSubscriptionFilter"
        Resource = aws_cloudwatch_log_destination.kinesis_log_destination.arn
      }
    ]
  })
}


resource "aws_iam_role" "logs_kinesis_role" {
  name = "kinesis-cloudwatch-logs-producer-role"
  assume_role_policy = jsonencode({
    Version = "2008-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = [
            "logs.amazonaws.com",
            "firehose.amazonaws.com"
          ]
        }
        Action = "sts:AssumeRole"
        Condition = {
          StringLike = {
            "aws:SourceArn" = concat(
              [
                "arn:aws:logs:${var.region}:${var.logging_account_id}:*"
              ],
              [for account in var.source_account_ids : "arn:aws:logs:${var.region}:${account}:*"]
            )
          }
        }
      }
    ]
  })
}


resource "aws_iam_policy" "logs_kinesis_policy" {
  name        = "kinesis-cloudwatch-logs-producer-policy"
  path        = "/"
  description = "IAM policy for CloudWatch Logs to put records to Kinesis on another account."


  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "kinesis:PutRecord",
        "kinesis:PutRecords",
        "kinesis:GetShardIterator",
        "kinesis:GetRecords",
        "kinesis:DescribeStream",
        "kinesis:ListStreams"
      ],
      "Resource": "${aws_kinesis_stream.log_stream.arn}"
    }
  ]
}
EOF
}


resource "aws_iam_role_policy_attachment" "kinesis_role_policy_attachment" {
  role       = aws_iam_role.logs_kinesis_role.name
  policy_arn = aws_iam_policy.logs_kinesis_policy.arn
}

# Lambda Function and Alert Deployments
locals {
  lambda_function_handler = "kinesis-firehose-cloudwatch-logs-processor.lambda_handler"
  archive_path            = "${path.module}/lambda_code/kinesis_stream_code/kinesis_stream_code.zip"
  // Provide the time in hours from where you need to start picking up logs (e.g Lambda runs every 6 hours and picks up all the incoming logs from 6 hours to the past)
  hours_from_start = 6
}


resource "aws_lambda_function" "kinesis_lambda" {
  function_name = "kinesis-data-lambda"
  description   = "Lambda for retrieving logs from Kinesis Data Stream"
  handler       = local.lambda_function_handler
  filename      = local.archive_path
  role          = aws_iam_role.kinesis_lambda_role.arn
  runtime       = var.python_runtime
  timeout       = 900


  environment {
    variables = {
      KINESIS_STREAM_NAME = "kinesis-logging-stream-${var.environment}"
      HOURS_FROM_START    = local.hours_from_start
    }
  }
}

# Give lambda role access to create vpc configuration
resource "aws_iam_policy_attachment" "lambda_to_vpc" {
  name       = "kinesis-data-lambda-policy-vpc-attach"
  roles      = [aws_iam_role.kinesis_lambda_role.name]
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}


resource "aws_iam_role" "kinesis_lambda_role" {
  name = "kinesis-data-lambda-role"


  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}


resource "aws_iam_policy_attachment" "kinesis_lambda_policy_attachment_cloudwatch" {
  name       = "kinesis-data-lambda-policy-attachment-cloudwatch"
  roles      = [aws_iam_role.kinesis_lambda_role.name]
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentAdminPolicy"
}


resource "aws_iam_policy_attachment" "kinesis_lambda_policy_attachment_get_records" {
  name       = "kinesis-data-lambda-policy-kinesis-get-records"
  roles      = [aws_iam_role.kinesis_lambda_role.name]
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaKinesisExecutionRole"
}


resource "aws_cloudwatch_event_rule" "lambda_schedule" {
  name                = "kinesis-data-lambda-schedule-rule"
  description         = "Rule to trigger Kinesis Lambda every ${local.hours_from_start} hours"
  schedule_expression = "rate(${local.hours_from_start} hours)"
}


resource "aws_cloudwatch_event_target" "lambda_target" {
  rule      = aws_cloudwatch_event_rule.lambda_schedule.name
  target_id = "lambda-target"
  arn       = aws_lambda_function.kinesis_lambda.arn
}


resource "aws_lambda_permission" "eventbridge_lambda_permission" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.kinesis_lambda.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.lambda_schedule.arn
}


# resource "aws_cloudwatch_metric_alarm" "kinesis_lambda_alarm" {
#   alarm_name          = "kinesis-lambda-alarm"
#   comparison_operator = "GreaterThanOrEqualToThreshold"
#   evaluation_periods  = 1
#   metric_name         = "Duration"
#   namespace           = "AWS/Lambda"
#   period              = 60
#   statistic           = "Sum"
#   threshold           = 600000
#   alarm_description   = "Kinesis Lambda function Duration exceeded 10 minutes"
#   treat_missing_data  = "notBreaching"
#   alarm_actions       = [aws_sns_topic.alerts_notifications_topic.arn]
#   dimensions = {
#     FunctionName = aws_lambda_function.kinesis_lambda.function_name
#   }
# }


# resource "aws_sns_topic" "alerts_notifications_topic" {
#   name = "alerts-notifications"
# }


# resource "aws_sns_topic_subscription" "alerts_notifications_sub" {
#   topic_arn = aws_sns_topic.alerts_notifications_topic.arn
#   protocol  = "https"
#   // We are using AWS Chatbot for sending messages to Slack, choose your own approach here
#   endpoint = var.aws_chatbot_url
# }


resource "aws_iam_role" "firehose_role" {
  name = "firehose-kinesis-to-splunk-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "firehose.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_policy" "firehose_policy" {
  name        = "firehose-kinesis-to-splunk-policy"
  description = "Policy for Firehose to read from Kinesis and send to Splunk"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "kinesis:GetRecords",
        "kinesis:GetShardIterator",
        "kinesis:DescribeStream",
        "kinesis:ListStreams"
      ],
      "Resource": "${aws_kinesis_stream.log_stream.arn}"
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:GetObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::${var.s3_backup_bucket}",
        "arn:aws:s3:::${var.s3_backup_bucket}/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:${var.region}:${var.logging_account_id}:log-group:/aws/kinesisfirehose/*"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "firehose_role_attachment" {
  role       = aws_iam_role.firehose_role.name
  policy_arn = aws_iam_policy.firehose_policy.arn
}

resource "aws_kinesis_firehose_delivery_stream" "kinesis_to_splunk" {
  name        = "kinesis-firehose-splunk-${var.environment}"
  destination = "splunk"

  splunk_configuration {
    hec_endpoint               = var.splunk_hec_endpoint
    hec_token                  = var.splunk_hec_token
    hec_acknowledgment_timeout = 300
    s3_backup_mode             = "AllEvents"
    s3_configuration {
      role_arn           = aws_iam_role.firehose_role.arn
      bucket_arn         = "arn:aws:s3:::${var.s3_backup_bucket}"
      compression_format = "GZIP"
      buffering_interval = 60
      buffering_size     = 5
    }
    cloudwatch_logging_options {
      enabled         = true
      log_group_name  = "/aws/kinesisfirehose/kinesis-to-splunk"
      log_stream_name = "splunk-delivery"
    }
  }

  kinesis_source_configuration {
    kinesis_stream_arn = aws_kinesis_stream.log_stream.arn
    role_arn           = aws_iam_role.firehose_role.arn
  }
}
