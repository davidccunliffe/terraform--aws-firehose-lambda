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


resource "aws_s3_bucket" "logging_bucket" {
  bucket_prefix = var.s3_backup_bucket_prefix
  force_destroy = true
}


module "kinesis_stream" {
  source             = "../../terraform/modules/splunk-kinesis-firehose"
  region             = "us-east-1"
  environment        = "dev"
  logging_account_id = var.logging_account_id
  source_account_ids = var.source_account_ids
  s3_backup_bucket   = aws_s3_bucket.logging_bucket.bucket
}


output "destination_arn" {
  description = "Source account Cloudwatch Logs Destination ARN"
  value       = module.kinesis_stream.destination_arn
}

module "vpce" {
  source               = "../../terraform/modules/vpc-endpoints"
  environment          = var.environment
  region               = var.region
  vpc_id               = var.vpc_id
  deploy_default_vpces = false
  vpce_list = [
    {
      service_name   = "s3"
      description    = "S3"
      interface_type = "Gateway"
    },
    {
      service_name        = "logs"
      description         = "logs"
      interface_type      = "Interface"
      private_dns_enabled = true
    },
    {
      service_name        = "kinesis-streams"
      description         = "kinesis-streams"
      interface_type      = "Interface"
      private_dns_enabled = true
    },
    {
      service_name        = "kinesis-firehose"
      description         = "kinesis-firehose"
      interface_type      = "Interface"
      private_dns_enabled = true
    }
  ]
}
