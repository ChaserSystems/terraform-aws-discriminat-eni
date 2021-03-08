# discrimiNAT, ENI architecture

[discrimiNAT firewall](https://chasersystems.com/discrimiNAT/) for egress filtering by FQDNs on AWS. Just specify the allowed destination hostnames in the applications' native Security Groups and the firewall will take care of the rest.

**Architecture with [ENIs](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/using-eni.html) in VPCs for Private Subnets' route table entries to the Internet.**

[Demo Videos](https://chasersystems.com/discrimiNAT/demo/) | [discrimiNAT FAQ](https://chasersystems.com/discrimiNAT/faq/)

## Highlights

* Creates ENIs, backed by instances in an Auto-Scaling group for high availability, for use as targets in route tables' destination `0.0.0.0/0` (i.e. the Internet) entries.
* Can accommodate pre-allocated Elastic IPs for use with the NAT function. Making use of this is of course, optional.
* VMs _without_ public IPs will need Security Groups with rules specifying what egress FQDNs and protocols are to be allowed. Default behaviour is to deny everything.

## Considerations

* A deployment per zone is advised.
* VMs _without_ public IPs will need to be in a subnet (typically the Private Subnet) with routing through the ENIs created by this module to access the Internet at all.
* You must be subscribed to the [discrimiNAT firewall from the AWS Marketplace](https://aws.amazon.com/marketplace/pp/B07YLBH34R?ref=_ptnr_gthb).

## Next Steps

* [Understand how to configure the enhanced Security Groups](https://chasersystems.com/discrimiNAT/aws/quick-start/#vii-security-groups) after deployment, from our main documentation.
* Contact our DevSecOps at devsecops@chasersystems.com for queries at any stage of your journey.
