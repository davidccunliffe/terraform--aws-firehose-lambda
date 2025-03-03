terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

provider "aws" {
  region                   = var.region
  shared_config_files      = ["~/.aws/config"]
  shared_credentials_files = ["~/.aws/credentials"]
  profile                  = "logging"
}

provider "aws" {
  alias                    = "source_accounts"
  region                   = var.region
  shared_config_files      = ["~/.aws/config"]
  shared_credentials_files = ["~/.aws/credentials"]
  profile                  = "security"
}


data "aws_caller_identity" "logging" {}

data "aws_caller_identity" "source" {
  provider = aws.source_accounts
}

resource "aws_s3_bucket" "logging_bucket" {
  bucket_prefix = "dcc-kinesis-firehose-backup-bucket"
  force_destroy = true
}


module "kinesis_stream" {
  source             = "../../terraform/modules/splunk-kinesis-firehose"
  region             = "us-east-1"
  environment        = "dev"
  logging_account_id = data.aws_caller_identity.logging.account_id
  source_account_ids = [
    data.aws_caller_identity.source.account_id, # 123456789012
  ]

  s3_backup_bucket = aws_s3_bucket.logging_bucket.bucket
}


output "destination_arn" {
  description = "Source account Cloudwatch Logs Destination ARN"
  value       = module.kinesis_stream.destination_arn
}
