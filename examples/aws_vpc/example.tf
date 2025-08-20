# Deploying a new VPC in two AZs with Public and Private Subnets.
module "aws_vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "> 3, < 6"

  name = "discriminat-example"

  cidr = "172.16.0.0/16"

  enable_dns_support   = true
  enable_dns_hostnames = true

  azs             = ["eu-west-2a", "eu-west-2b"]
  public_subnets  = ["172.16.11.0/24", "172.16.21.0/24"]
  private_subnets = ["172.16.12.0/24", "172.16.22.0/24"]

  map_public_ip_on_launch = false

  manage_default_security_group  = true
  default_security_group_ingress = []
  default_security_group_egress  = []
}

# Deploying an EC2 VPC Endpoint.
module "aws_vpc_endpoints" {
  source  = "terraform-aws-modules/vpc/aws//modules/vpc-endpoints"
  version = "> 3, < 6"

  vpc_id = module.aws_vpc.vpc_id

  endpoints = {
    ec2 = {
      service             = "ec2"
      private_dns_enabled = true
      security_group_ids  = [aws_security_group.vpce_ec2.id]
      subnet_ids          = module.aws_vpc.private_subnets
    }
  }

  tags = {
    "Name" : "ec2"
  }
}

# A Security Group that allows the entire VPC to use the EC2 VPC Endpoint.
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

  tags = {
    "Name" : "vpce-ec2"
  }
}

# Deploying DiscrimiNAT.
module "discriminat" {
  source = "ChaserSystems/discriminat-eni/aws"

  public_subnets = module.aws_vpc.public_subnets

  # iam_get_additional_ssm_params = [
  #   "arn:aws:ssm:eu-west-2:000000000000:parameter/team1-list",
  #   "arn:aws:ssm:eu-west-2:111111111111:parameter/service1-list"
  # ]
  # iam_get_additional_secrets = [
  #   "arn:aws:secretsmanager:eu-west-2:000000000000:secret:service-a-allowed-egress-fqdns",
  #   "arn:aws:secretsmanager:eu-west-2:111111111111:secret:service-b-allowed-egress-fqdns"
  # ]

  preferences = <<EOF
  {
    "%default": {
      "flow_log_verbosity": "full",
      "see_thru": "2026-01-19"
    }
  }
  EOF
}

# Updating route tables of Private Subnets with ENIs of DiscrimiNAT(s) for Internet access.
resource "aws_route" "discriminat" {
  count = length(module.aws_vpc.azs)

  destination_cidr_block = "0.0.0.0/0"

  route_table_id       = module.aws_vpc.private_route_table_ids[count.index]
  network_interface_id = module.discriminat.target_network_interfaces[module.aws_vpc.azs[count.index]]
}
