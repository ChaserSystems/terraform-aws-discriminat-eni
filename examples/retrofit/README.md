# DiscrimiNAT, ENI architecture, retrofit example

Demonstrates how to retrofit DiscrimiNAT egress filtering in a pre-existing VPC, for chosen zones.

## Example

See file `example.tf` in the _Source Code_ link above.

## Elastic IPs

Elastic IPs for the NAT function have been defined in a separate file, `eip.tf`, to encourage independent allocation and handling. Although the contents of `eip.tf` will be allocated if `terraform` is run in this directory, users should ensure Elastic IPs are managed separately so they are not accidentally deleted.

## Considerations

1. Public Subnets with routing to the Internet via an [Internet Gateway](https://docs.aws.amazon.com/vpc/latest/userguide/VPC_Internet_Gateway.html) must already exist.
