variable "region" {
  description = "The region to deploy the resources"
  type        = string
  default     = "us-east-1"
}

variable "destination_arn" {
  description = "The ARN of the destination to deliver the log events to"
  type        = string
  default     = "arn:aws:logs:us-east-1:194722401531:destination:kinesis-log-destination"
}

variable "log_group_ignore_list" {
  description = "List of log groups to ignore"
  type        = list(string)
  default     = ["test"]

}
