variable "environment" {
  description = "The environment name"
  type        = string
}

variable "region" {
  description = "The region"
  type        = string
}

variable "vpc_id" {
  description = "The VPC ID"
  type        = string
}

variable "deploy_default_vpces" {
  description = "Deploy default VPC endpoints"
  type        = bool
  default     = false
}

variable "default_vpce_list" {
  description = "The default VPC endpoint list"
  type = list(object({
    service_name                  = string
    description                   = string
    additional_security_group_ids = optional(list(string))
    policy_override               = optional(string)
    interface_type                = string
    private_dns_enabled           = optional(bool)
  }))

  default = [
    {
      service_name                  = "s3"
      description                   = "S3"
      additional_security_group_ids = []
      policy_override               = ""
      interface_type                = "Gateway"
      private_dns_enabled           = true
    },
    {
      service_name                  = "ec2"
      description                   = "ec2"
      additional_security_group_ids = []
      policy_override               = ""
      interface_type                = "Interface"
      private_dns_enabled           = true
    },
    {
      service_name                  = "execute-api"
      description                   = "API Gateway"
      additional_security_group_ids = []
      policy_override               = ""
      interface_type                = "Interface"
      private_dns_enabled           = true
    },
    {
      service_name                  = "lambda"
      description                   = "lambda"
      additional_security_group_ids = []
      policy_override               = ""
      interface_type                = "Interface"
      private_dns_enabled           = true
    },
  ]
}

variable "vpce_list" {
  description = "The default VPC endpoint list"
  type = list(object({
    service_name                  = string
    description                   = string
    additional_security_group_ids = optional(list(string))
    policy_override               = optional(string)
    interface_type                = string
    private_dns_enabled           = optional(bool)
  }))

  default = []
}
