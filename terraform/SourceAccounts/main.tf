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
  profile                  = "security"
}

data "aws_cloudwatch_log_groups" "log_groups" {}


resource "aws_cloudwatch_log_subscription_filter" "kinesis_sub_filter" {
  for_each        = { for index, name in setsubtract(data.aws_cloudwatch_log_groups.log_groups.log_group_names, var.log_group_ignore_list) : index => name }
  name            = "kinesis-logging-sub"
  log_group_name  = each.value
  filter_pattern  = ""
  destination_arn = var.destination_arn
  distribution    = "ByLogStream"
}
