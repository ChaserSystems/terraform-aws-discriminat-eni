variable "public_subnets" {
  type        = list(any)
  description = "List of public subnets to deploy the DiscrimiNAT Firewall in. These would be the same as where a NAT Gateway/Instance would normally be placed in your design and should have their default route set to an Internet Gateway."
}

module "discriminat" {
  source = "ChaserSystems/discriminat-eni/aws"

  public_subnets = var.public_subnets

  tags = {
    "x"   = "y"
    "foo" = "bar"
  }
}

data "aws_subnet" "public" {
  id = var.public_subnets[0]
}

data "aws_vpc" "this" {
  id = data.aws_subnet.public.vpc_id
}

data "aws_region" "this" {}

resource "aws_vpc_endpoint" "ec2" {
  vpc_id              = data.aws_subnet.public.vpc_id
  service_name        = "com.amazonaws.${data.aws_region.this.name}.ec2"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  security_group_ids  = [aws_security_group.vpce_ec2.id]
  subnet_ids          = var.public_subnets
}

resource "aws_security_group" "vpce_ec2" {
  name        = "vpce-ec2"
  description = "ingress from entire vpc to ec2 endpoint for connectivity to it without public ips"

  vpc_id = data.aws_subnet.public.vpc_id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.this.cidr_block]

    description = "only https standard port needed for ec2 api"
  }
}

output "target_network_interfaces" {
  value       = module.discriminat.target_network_interfaces
  description = "Map of zones to ENI IDs suitable for setting as targets in routing tables of Private Subnets."
}
