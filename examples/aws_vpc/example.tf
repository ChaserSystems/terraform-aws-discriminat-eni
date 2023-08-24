module "aws_vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "> 2, < 3"

  name = "discriminat-example"

  cidr = "172.16.0.0/16"

  enable_dns_support   = true
  enable_dns_hostnames = true

  azs             = ["eu-west-3a", "eu-west-3b"]
  public_subnets  = ["172.16.11.0/24", "172.16.21.0/24"]
  private_subnets = ["172.16.12.0/24", "172.16.22.0/24"]

  map_public_ip_on_launch = false

  manage_default_security_group  = true
  default_security_group_ingress = []
  default_security_group_egress  = []

  enable_ec2_endpoint              = true
  ec2_endpoint_private_dns_enabled = true
  ec2_endpoint_security_group_ids  = [aws_security_group.vpce_ec2.id]
}

resource "aws_security_group" "vpce_ec2" {
  name        = "vpce-ec2"
  description = "ingress from entire vpc to ec2 endpoint for connectivity to it without public ips"

  vpc_id = module.aws_vpc.vpc_id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [module.aws_vpc.vpc_cidr_block]

    description = "only https standard port needed for ec2 api"
  }
}

module "discriminat" {
  source = "ChaserSystems/discriminat-eni/aws"

  public_subnets = module.aws_vpc.public_subnets
}

resource "aws_route" "discriminat" {
  count = length(module.aws_vpc.azs)

  destination_cidr_block = "0.0.0.0/0"

  route_table_id       = module.aws_vpc.private_route_table_ids[count.index]
  network_interface_id = module.discriminat.target_network_interfaces[module.aws_vpc.azs[count.index]]
}
