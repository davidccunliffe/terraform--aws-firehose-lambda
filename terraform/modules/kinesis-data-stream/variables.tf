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

variable "source_account_id" {
  description = "The AWS account ID of the source account"
  type        = string
}

variable "python_runtime" {
  description = "Runtime version of python for Lambda function"
  default     = "python3.9"
  type        = string
}
