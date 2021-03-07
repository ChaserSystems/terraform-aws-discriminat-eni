# discrimiNAT, ENI architecture, retrofit example

Demonstrates how to retrofit discrimiNAT egress filtering in a pre-existing VPC, for chosen zones.

## Example

See file `example.tf` in the _Source Code_ link above.

## Considerations

1. Public Subnets with routing to the Internet via an [Internet Gateway](https://docs.aws.amazon.com/vpc/latest/userguide/VPC_Internet_Gateway.html) must already exist.
