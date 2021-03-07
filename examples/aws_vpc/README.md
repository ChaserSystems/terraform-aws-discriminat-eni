# discrimiNAT, ENI architecture, alongside "terraform-aws-modules/vpc/aws" example

Demonstrates how to install discrimiNAT egress filtering in a VPC provisioned with the [terraform-aws-modules/vpc/aws](https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws) module from the Terraform Registry.

## Example

See file `example.tf` in the _Source Code_ link above.

## Considerations

If creating the VPC and a discrimiNAT deployment at the same time, it may be useful to create just the VPC first so the discrimiNAT module has a clear idea of the setup. The following sequence of commands are specific to this example in order to resolve a `Invalid count argument` error message, should you encounter it.

1. `terraform apply -target=module.aws_vpc`
1. `terraform apply`
