# discrimiNAT, ENI architecture

[discrimiNAT firewall](https://chasersystems.com/discrimiNAT/) for egress filtering by FQDNs on AWS. Just specify the allowed destination hostnames in the respective applications' native Security Groups and the firewall will take care of the rest.

![](https://chasersystems.com/media/aws-protocol-tls.gif)

**Architecture with [ENIs](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/using-eni.html) in VPCs for Private Subnets' route table entries to the Internet.**

[Demo Videos](https://chasersystems.com/discrimiNAT/demo/) | [discrimiNAT FAQ](https://chasersystems.com/discrimiNAT/faq/)

## Pentest Ready

discrimiNAT enforces the use of contemporary encryption standards such as TLS 1.2+ and SSH v2 with bidirectional in-band checks. Anything older or insecure will be denied connection automatically. Also conducts out-of-band checks, such as DNS, for robust defence against sophisticated malware and insider threats. Gets your VPC ready for a proper pentest!

## Highlights

* Creates ENIs, backed by instances in an Auto-Scaling group for high availability, for use as targets in route tables' destination `0.0.0.0/0` (i.e. the Internet) entries.
* Can accommodate pre-allocated Elastic IPs for use with the NAT function. Making use of this is of course, optional.
* VMs _without_ public IPs will need Security Groups with rules specifying what egress FQDNs and protocols are to be allowed. Default behaviour is to deny everything.

## Considerations

* A deployment per zone is advised, just like the AWS NAT Gateways – which are not needed with discrimiNAT deployed.
* VMs _without_ public IPs will need to be in a subnet (typically the Private Subnet) with routing through the ENIs created by this module to access the Internet at all.
* You must be subscribed to the [discrimiNAT firewall from the AWS Marketplace](https://aws.amazon.com/marketplace/pp/B07YLBH34R?ref=_ptnr_gthb).

## Next Steps

* [Understand how to configure the enhanced Security Groups](https://chasersystems.com/discrimiNAT/aws/config-ref/) after deployment, from our main documentation.
* Contact our DevSecOps at devsecops@chasersystems.com for queries at any stage of your journey — even on the eve of a pentest!

## Discover

Perhaps use the `see-thru` mode to discover what needs to be in the allowlist for an application, by monitoring its outbound network activity first. Follow our [building an allowlist from scratch](https://chasersystems.com/discrimiNAT/aws/logs-ref/#building-an-allowlist-from-scratch) recipe for use with CloudWatch.

![](https://chasersystems.com/media/aws-see-thru.gif)

## Post-deployment Security Group Example

```hcl
# This Security Group must be associated with its intended, respective application - whether that is
# in EC2, Fargate or EKS, etc. as long as a Security Group can be associated with it.
resource "aws_security_group" "foo" {
  # You could use a data source or get a reference from another resource for the VPC ID.
  vpc_id = "vpc-1234example5678"
}

resource "aws_security_group_rule" "saas_monitoring" {
  security_group_id = aws_security_group.foo.id

  type      = "egress"
  from_port = 443
  to_port   = 443
  protocol  = "tcp"

  # The discrimiNAT firewall will apply its own checks anyway, so you could
  # choose to leave this wide open without worry.
  cidr_blocks = ["0.0.0.0/0"]

  # You could simply embed the allowed FQDNs, comma-separated, like below.
  # Full syntax at https://chasersystems.com/discrimiNAT/aws/quick-start/#vii-security-groups
  description = "discriminat:tls:app.datadoghq.com,collector.newrelic.com"
}

locals {
  # Or you could store allowed FQDNs as a list...
  fqdns_sftp_banks = [
    "sftp.bank1.com",
    "sftp.bank2.com"
  ]
  fqdns_saas_auth = [
    "foo.auth0.com",
    "mtls.okta.com"
  ]
}

locals {
  # ...and format them into the expected syntax.
  discriminat_sftp_banks = format("discriminat:ssh:%s", join(",", local.fqdns_sftp_banks))
  discriminat_saas_auth  = format("discriminat:tls:%s", join(",", local.fqdns_saas_auth))
}

resource "aws_security_group_rule" "saas_auth" {
  security_group_id = aws_security_group.foo.id

  type      = "egress"
  from_port = 443
  to_port   = 443
  protocol  = "tcp"

  # Note that AWS does not allow multiple Rules with the same protocol/port/cidr combination, so
  # we just choose a different network prefix to get around that. That is, if /0 had already been
  # used, we'll pick /1 or anything uptil /32 really.
  cidr_blocks = ["0.0.0.0/1"]

  # Use of FQDNs list formatted into the expected syntax.
  description = local.discriminat_saas_auth
}

resource "aws_security_group_rule" "sftp_banks" {
  security_group_id = aws_security_group.foo.id

  type        = "egress"
  from_port   = 22
  to_port     = 22
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]

  # Use of FQDNs list formatted into the expected syntax.
  description = local.discriminat_sftp_banks
}
```
