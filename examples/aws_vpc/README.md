# DiscrimiNAT, ENI architecture, alongside "terraform-aws-modules/vpc/aws" example

Demonstrates how to install DiscrimiNAT egress filtering in a VPC provisioned with the [terraform-aws-modules/vpc/aws](https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws) module from the Terraform Registry.

## Elastic IPs

Elastic IPs for the NAT function have been defined in a separate file, `eip.tf`, to encourage independent allocation and handling. Although the contents of `eip.tf` will be allocated if `terraform` is run in this directory, users should ensure Elastic IPs are managed separately so they are not accidentally deleted.

## Example

See file `example.tf` in the _Source Code_ link above.
