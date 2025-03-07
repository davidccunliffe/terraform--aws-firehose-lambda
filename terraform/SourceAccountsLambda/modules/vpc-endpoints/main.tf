# locals {
#   filtered_subnets = [for subnet in data.aws_subnets.all.ids : subnet
#     if can(regex(var.target_subnet_name, subnet))
#   ]
# }

data "aws_vpc" "selected" {
  id = var.vpc_id
}

data "aws_subnets" "selected" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.selected.id]
  }

  filter {
    name   = "tag:Name"
    values = ["*private*"]
  }
}


resource "aws_security_group" "vpc_cidr" {
  vpc_id = data.aws_vpc.selected.id

  name = "${var.environment}-cidr-endpoint-sg"

  tags = {
    Name = "${var.environment}-cidr-endpoint-sg"
  }
}

resource "aws_security_group_rule" "vpc_cidr_ingress" {
  security_group_id = aws_security_group.vpc_cidr.id
  type              = "ingress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = [data.aws_vpc.selected.cidr_block]
}

resource "aws_security_group_rule" "vpc_cidr_egress" {
  security_group_id = aws_security_group.vpc_cidr.id
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = [data.aws_vpc.selected.cidr_block]
}

resource "aws_vpc_endpoint" "default_this" {
  for_each = var.deploy_default_vpces ? { for vpce in var.default_vpce_list : vpce.service_name => vpce } : {}

  vpc_id            = data.aws_vpc.selected.id
  service_name      = "com.amazonaws.${var.region}.${each.value.service_name}"
  vpc_endpoint_type = each.value.interface_type
  security_group_ids = each.value.interface_type == "Interface" ? concat(
    [aws_security_group.vpc_cidr.id],
    each.value.additional_security_group_ids == null ? [] : each.value.additional_security_group_ids
  ) : null
  private_dns_enabled = each.value.interface_type == "Interface" ? each.value.private_dns_enabled : null
  subnet_ids          = each.value.interface_type == "Interface" ? data.aws_subnets.selected.ids : null

  policy = each.value.policy_override != "" ? each.value.policy_override : null

  tags = data.aws_vpc.selected.tags.Name != null ? {
    Name = "${data.aws_vpc.selected.tags.Name}-${var.environment}-${each.value.service_name}"
    } : {
    Name = "${var.environment}-${each.value.service_name}"
  }
}

resource "aws_vpc_endpoint" "this" {
  for_each = { for vpce in var.vpce_list : vpce.service_name => vpce }

  vpc_id            = data.aws_vpc.selected.id
  service_name      = "com.amazonaws.${var.region}.${each.value.service_name}"
  vpc_endpoint_type = each.value.interface_type
  security_group_ids = each.value.interface_type == "Interface" ? concat(
    [aws_security_group.vpc_cidr.id],
    each.value.additional_security_group_ids == null ? [] : each.value.additional_security_group_ids
  ) : null
  private_dns_enabled = each.value.interface_type == "Interface" ? each.value.private_dns_enabled : null
  subnet_ids          = each.value.interface_type == "Interface" ? data.aws_subnets.selected.ids : null

  policy = each.value.policy_override != "" ? each.value.policy_override : null

  tags = data.aws_vpc.selected.tags.Name != null ? {
    Name = "${data.aws_vpc.selected.tags.Name}-${var.environment}-${each.value.service_name}-endpoint"
    } : {
    Name = "${var.environment}-${each.value.service_name}-endpoint"
  }
}
