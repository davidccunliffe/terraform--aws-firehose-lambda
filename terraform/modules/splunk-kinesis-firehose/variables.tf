variable "region" {
  description = "The AWS region in which the resources are deployed"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "The environment in which the resources are deployed"
  type        = string
  default     = "dev"

}

variable "logging_account_id" {
  description = "The AWS account ID of the current account"
  type        = string
}

variable "source_account_ids" {
  description = "The AWS account IDs for all the source accounts"
  type        = list(string)
}

variable "python_runtime" {
  description = "Runtime version of python for Lambda function"
  type        = string
  default     = "python3.9"
}

variable "s3_backup_bucket" {
  description = "The name of the S3 bucket to store the backup logs"
  type        = string
}

variable "splunk_hec_token" {
  description = "The Splunk HEC token"
  type        = string
  default     = "00000000-0000-0000-0000-000000000000"
}

variable "splunk_hec_endpoint" {
  description = "The Splunk HEC endpoint"
  type        = string
  default     = "https://splunk.example.com:8088"
}
