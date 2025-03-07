variable "region" {
  type    = string
  default = "us-east-1"

}

variable "subnet_ids" {
  type = list(string)
  default = [
    "subnet-0ac5ce8e6f2cece56",
    "subnet-032fc0b1384f54b72"
  ]
}

variable "vpc_id" {
  type    = string
  default = "vpc-099ec65dc18684cb0"
}

variable "destination_arn" {
  type    = string
  default = "arn:aws:logs:us-east-1:123456789012:destination:kinesis-log-destination"
}

variable "subscription_filter_name" {
  type    = string
  default = "my-subscription-filter"

}

variable "log_group_name" {
  type = string
  # default = "/aws/lambda/my-log-group"
  default = "/aws/lambda/lambda-aws-cloudwatch-log-subscription"

}
