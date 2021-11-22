module "aws_vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "> 2, < 3"

  name = "discrimiNATed"

  cidr = "172.16.0.0/16"

  azs             = ["eu-west-2a", "eu-west-2b"]
  public_subnets  = ["172.16.11.0/24", "172.16.21.0/24"]
  private_subnets = ["172.16.12.0/24", "172.16.22.0/24"]
}

module "discriminat" {
  source = "ChaserSystems/discriminat-eni/aws"

  public_subnets = module.aws_vpc.public_subnets
}

resource "aws_route" "discriminat" {
  count = length(module.discriminat.target_network_interfaces)

  destination_cidr_block = "0.0.0.0/0"

  route_table_id       = module.aws_vpc.private_route_table_ids[count.index]
  network_interface_id = module.discriminat.target_network_interfaces[module.aws_vpc.azs[count.index]]
}
