# modules/vpc-endpoints — optional AWS PrivateLink / gateway endpoints
#
# NOT required for Scopify lab if NAT Gateway provides private outbound.
# Useful later to cut NAT data costs / keep AWS API traffic on the AWS network.
#
# Gateway endpoints (S3, DynamoDB): no hourly charge
# Interface endpoints (ECR, SSM, EC2, …): hourly + data — enable only what you need

locals {
  interface_services = var.enable_interface_endpoints ? var.interface_services : []
  gateway_services   = var.enable_gateway_endpoints ? var.gateway_services : toset([])
}

resource "aws_security_group" "endpoints" {
  count = length(local.interface_services) > 0 ? 1 : 0

  name        = "${var.name}-vpce-sg"
  description = "Interface VPC endpoints"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTPS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.name}-vpce-sg"
  })
}

resource "aws_vpc_endpoint" "interface" {
  for_each = toset(local.interface_services)

  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.${each.value}"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.subnet_ids
  security_group_ids  = [aws_security_group.endpoints[0].id]
  private_dns_enabled = var.private_dns_enabled

  tags = merge(var.tags, {
    Name = "${var.name}-vpce-${replace(each.value, ".", "-")}"
  })

  depends_on = [aws_security_group.endpoints]
}

resource "aws_vpc_endpoint" "gateway" {
  for_each = local.gateway_services

  vpc_id            = var.vpc_id
  service_name      = "com.amazonaws.${var.aws_region}.${each.value}"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = var.route_table_ids

  tags = merge(var.tags, {
    Name = "${var.name}-vpce-${each.value}"
  })
}
