variable "region" {
  description = "The AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "The environment"
  type        = string
  default     = "dev"
}

variable "vpc_id" {
  description = "The VPC ID"
  type        = string
  default     = "vpc-099ec65dc18684cb0"
}

variable "target_subnet_name" {
  description = "The target subnet name"
  type        = string
  default     = "*private*"
}

variable "s3_backup_bucket_prefix" {
  description = "The S3 bucket to store backup data"
  type        = string
  default     = "kinesis-firehose-backup-bucket-"
}

variable "logging_account_id" {
  description = "The logging account ID"
  type        = string
  default     = "961341521017"
}

variable "source_account_ids" {
  description = "The source account IDs"
  type        = list(string)
  default     = ["961341521017"]
}

variable "splunk_hec_endpoint" {
  description = "The Splunk HEC endpoint"
  type        = string
  default     = "https://10.0.0.1:443"
}

variable "splunk_hec_token" {
  description = "The Splunk HEC token"
  type        = string
  default     = "12345678-1234-1234-1234-123456789012"
}
