## Inputs

variable "public_subnets" {
  type        = list(string)
  description = "The IDs of the Public Subnets to deploy the discrimiNAT firewall instances in. These must have routing to the Internet via an Internet Gateway already."
}

##

## Defaults

variable "elastic_ips" {
  type        = list(string)
  description = "Specific, pre-allocated Elastic IP addresses if you wish to use these for egress, NATed traffic. If none specified, ephemeral public IP addressess will be allocated automatically. If specifed, should be equal to the number of public subnets and NOT be associated with other instances or NAT Gateways. For example: [\"198.51.100.5\", \"203.0.113.2\"]"
  default     = []
}

variable "tags" {
  type        = map(any)
  description = "Map of key-value tag pairs to apply to resources created by this module. See examples for use."
  default     = {}
}

variable "instance_size" {
  type        = string
  description = "The default of t3.small should suffice for light to medium levels of usage. Anything less than 2 CPU cores and 2 GB of RAM is not recommended. For faster access to the Internet and for accounts with a large number of VMs, you may want to choose a machine type with more CPU cores. Valid values are t3.small , t3.xlarge , c5.large , c5.xlarge , c5.2xlarge and c5.4xlarge ."
  default     = "t3.small"
}

variable "key_pair_name" {
  type        = string
  description = "Strongly suggested to leave this to the default, that is to NOT associate any key-pair with the instances. In case SSH access is desired, provide the name of a valid EC2 Key Pair."
  default     = ""
}

variable "startup_script_base64" {
  type        = string
  description = "Strongly suggested to NOT run custom, startup scripts on the firewall instances. But if you had to, supply a base64 encoded version here."
  default     = ""
}

##

## Lookups

data "aws_eip" "elastic_ip" {
  count = length(var.elastic_ips)

  public_ip = var.elastic_ips[count.index]
}

data "aws_subnet" "public_subnet" {
  count = length(var.public_subnets)

  id = var.public_subnets[count.index]
}

data "aws_vpc" "context" {
  id = data.aws_subnet.public_subnet[0].vpc_id
}

data "aws_ami" "discriminat" {
  owners      = ["aws-marketplace"]
  most_recent = true

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "product-code"
    values = ["a83las5cq95zkg3x8i17x6wyy"]
  }
}

##

## Compute

resource "aws_network_interface" "static_egress" {
  count = length(var.public_subnets)

  subnet_id         = var.public_subnets[count.index]
  source_dest_check = false

  security_groups = [aws_security_group.discriminat.id]

  tags = local.tags
}

resource "aws_eip_association" "static_egress" {
  count = length(data.aws_eip.elastic_ip)

  network_interface_id = aws_network_interface.static_egress[count.index].id
  allocation_id        = data.aws_eip.elastic_ip[count.index].id
}

resource "aws_security_group" "discriminat" {
  name_prefix = "discriminat-"
  lifecycle {
    create_before_destroy = true
  }

  vpc_id = data.aws_vpc.context.id

  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.context.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.tags
}

resource "aws_launch_template" "discriminat" {
  count = length(aws_network_interface.static_egress)

  name_prefix = "discriminat-${local.zones[count.index]}-"
  lifecycle {
    create_before_destroy = true
  }

  update_default_version = true
  image_id               = data.aws_ami.discriminat.id
  instance_type          = var.instance_size

  iam_instance_profile {
    name = aws_iam_instance_profile.discriminat.name
  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  network_interfaces {
    network_interface_id = aws_network_interface.static_egress[count.index].id
  }

  tag_specifications {
    resource_type = "instance"
    tags          = local.tags
  }
  tag_specifications {
    resource_type = "volume"
    tags          = local.tags
  }

  key_name  = var.key_pair_name == "" ? null : var.key_pair_name
  user_data = var.startup_script_base64 == "" ? null : var.startup_script_base64

  tags = local.tags
}

resource "aws_autoscaling_group" "discriminat" {
  count = length(aws_launch_template.discriminat)

  name_prefix = "discriminat-${local.zones[count.index]}-"
  lifecycle {
    create_before_destroy = true
  }

  availability_zones = [data.aws_subnet.public_subnet[count.index].availability_zone]

  max_size         = 1
  min_size         = 1
  desired_capacity = 1

  default_cooldown          = 1
  health_check_grace_period = 1
  health_check_type         = "EC2"

  launch_template {
    name    = aws_launch_template.discriminat[count.index].name
    version = aws_launch_template.discriminat[count.index].latest_version
  }

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 0
    }
  }
}

##

## IAM

resource "aws_iam_policy" "discriminat" {
  name_prefix = "discriminat-"
  lifecycle {
    create_before_destroy = true
  }

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:PutLogEvents",
                "logs:DescribeLogStreams"
            ],
            "Resource": [
                "arn:aws:logs:*:*:log-group:discrimiNAT:log-stream:*"
            ]
        },
        {
            "Effect": "Allow",
            "Action": "autoscaling:SetInstanceHealth",
            "Resource": "arn:aws:autoscaling:*:*:autoScalingGroup:*:autoScalingGroupName/discriminat-*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "ec2:DescribeNetworkInterfaces",
                "ec2:DescribeSecurityGroups"
            ],
            "Resource": "*"
        }
    ]
}
EOF
}

resource "aws_iam_role" "discriminat" {
  name_prefix = "discriminat-"
  lifecycle {
    create_before_destroy = true
  }

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow"
    }
  ]
}
EOF

  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "discriminat" {
  role       = aws_iam_role.discriminat.name
  policy_arn = aws_iam_policy.discriminat.arn
}

resource "aws_iam_instance_profile" "discriminat" {
  name_prefix = "discriminat-"
  lifecycle {
    create_before_destroy = true
  }

  role = aws_iam_role.discriminat.name
}

##

## Locals

locals {
  tags = merge(
    {
      "Name" : "discrimiNAT",
      "documentation" : "https://chasersystems.com/discrimiNAT/aws/"
    },
    var.tags
  )
}

locals {
  zones = [for z in data.aws_subnet.public_subnet : substr(z.availability_zone, -1, 1)]
}

##

## Constraints

terraform {
  required_version = "> 1, < 2"

  required_providers {
    google = {
      source  = "hashicorp/aws"
      version = "> 3, < 4"
    }
  }
}

##

## Outputs

output "target_network_interfaces" {
  value = { for i, z in data.aws_subnet.public_subnet :
  z.availability_zone => aws_network_interface.static_egress[i].id }
  description = "Map of zones to ENI IDs suitable for setting as Network Interface targets in routing tables of Private Subnets. A Terraform example of using these in an \"aws_route\" resource can be found at https://github.com/ChaserSystems/terraform-aws-discriminat-eni/blob/main/examples/aws_vpc/example.tf#L20-L27"
}

##
