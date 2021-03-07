module "discriminat" {
  source = "ChaserSystems/discriminat-eni/aws"

  public_subnets = ["subnet-1a3c5e7g", "subnet-2b4d6f8h"]

  tags = {
    "x"   = "y"
    "foo" = "bar"
  }
}
