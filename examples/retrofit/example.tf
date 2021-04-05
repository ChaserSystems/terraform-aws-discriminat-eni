module "discriminat" {
  source = "ChaserSystems/discriminat-eni/aws"

  public_subnets = ["subnet-1a3c5e7g", "subnet-2b4d6f8h"]

  tags = {
    "x"   = "y"
    "foo" = "bar"
  }
}

output "target_network_interfaces" {
  value       = module.discriminat.target_network_interfaces
  description = "Map of zones to ENI IDs suitable for setting as targets in routing tables of Private Subnets."
}
