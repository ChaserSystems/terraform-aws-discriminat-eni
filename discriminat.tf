## Inputs

variable "public_subnets" {
  type        = list(string)
  description = "The IDs of the Public Subnets to deploy the DiscrimiNAT Firewall instances in. These must have routing to the Internet via an Internet Gateway already."
}

##

## Defaults

variable "tags" {
  type        = map(any)
  description = "Map of key-value tag pairs to apply to resources created by this module. See examples for use."
  default     = {}
}

variable "instance_size" {
  type        = string
  description = "The default of t3.small should suffice for light to medium levels of usage. Anything less than 2 CPU cores and 2 GB of RAM is not recommended. For faster access to the Internet and for accounts with a large number of VMs, you may want to choose a machine type with dedicated CPU cores. Valid values are t3.small , c6i.large , c6i.xlarge , c6a.large , c6a.xlarge ."
  default     = "t3.small"
}

variable "key_pair_name" {
  type        = string
  description = "Strongly suggested to leave this to the default, that is to NOT associate any key-pair with the instances. In case SSH access is desired, provide the name of a valid EC2 Key Pair."
  default     = null
}

variable "user_data_base64" {
  type        = string
  description = "Strongly suggested to NOT run custom, startup scripts on the firewall instances. But if you had to, supply a base64 encoded version here."
  default     = null
}

variable "ami_owner" {
  type        = string
  description = "Reserved for use with Chaser support. Allows overriding the source AMI account for DiscrimiNAT."
  default     = null
}

variable "ami_name" {
  type        = string
  description = "Reserved for use with Chaser support. Allows overriding the source AMI version for DiscrimiNAT."
  default     = null
}

variable "byol" {
  type        = string
  sensitive   = true
  default     = null
  description = "If using the BYOL version from the marketplace, supply the licence key as supplied by Chaser Systems here."
}

variable "ashr" {
  type        = bool
  default     = true
  description = "Automated System Health Reporting. See note in README to learn more. Set to false to disable. Default is true and hence enabled."
}

##

## Lookups

data "aws_subnet" "public_subnet" {
  count = length(var.public_subnets)

  id = var.public_subnets[count.index]
}

data "aws_vpc" "context" {
  id = data.aws_subnet.public_subnet[0].vpc_id
}

data "aws_ami" "discriminat" {
  owners      = [var.ami_owner == null ? "aws-marketplace" : var.ami_owner]
  most_recent = true

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = var.ami_owner == null ? "product-code" : "owner-id"
    values = [var.ami_owner == null ? var.byol == null ? "bz1yq0sc5ta99w5j7jjwzym8g" : "a7z5gi2mkpzvo93r2e8csl2ld" : var.ami_owner]
  }

  filter {
    name   = "name"
    values = var.ami_name == null ? ["DiscrimiNAT-2.8.*"] : [var.ami_name]
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

  block_device_mappings {
    device_name = data.aws_ami.discriminat.root_device_name
    ebs {
      encrypted   = true
      volume_size = tolist(data.aws_ami.discriminat.block_device_mappings)[0].ebs.volume_size
      volume_type = "gp3"
    }
  }

  network_interfaces {
    network_interface_id = aws_network_interface.static_egress[count.index].id
  }

  tag_specifications {
    resource_type = "instance"
    tags          = merge(local.tags, { "discriminat" : "self-manage" })
  }

  tag_specifications {
    resource_type = "volume"
    tags          = local.tags
  }

  key_name  = var.key_pair_name
  user_data = var.user_data_base64 != null ? var.user_data_base64 : local.cloud_config == "" ? null : base64encode(local.cloud_config)

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
  health_check_grace_period = 0
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

  dynamic "tag" {
    for_each = local.tags
    iterator = i
    content {
      key                 = i.key
      value               = i.value
      propagate_at_launch = false
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
                "arn:aws:logs:*:*:log-group:DiscrimiNAT:log-stream:*"
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
                "ec2:DescribeSecurityGroups",
                "ec2:DescribeAddresses"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "ec2:AssociateAddress"
            ],
            "Resource": "*",
            "Condition": {
                "Null": {
                    "aws:ResourceTag/discriminat": false
                }
            }
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
      "Name" : "DiscrimiNAT",
      "documentation" : "https://chasersystems.com/docs/"
    },
    var.tags
  )
}

locals {
  zones = [for z in data.aws_subnet.public_subnet : substr(z.availability_zone, -1, 1)]
}

locals {
  cc_byol = var.byol == null ? "" : "- encoding: base64\n  path: /etc/chaser/licence-key.der\n  permissions: 0404\n  content: ${var.byol}\n"
  cc_ashr = var.ashr == true ? "" : "- path: /etc/chaser/disable_automated-system-health-reporting\n  permissions: 0404\n"
}

locals {
  cc_write_files = "${local.cc_byol}${local.cc_ashr}"
}

locals {
  cloud_config = local.cc_write_files == "" ? "" : "#cloud-config\nwrite_files:\n${local.cc_write_files}"
}

##

## Constraints

terraform {
  required_version = "> 1, < 2"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "> 3, < 6"
    }
  }
}

##

## Outputs

output "cloudwatch_log_group_name" {
  value       = "DiscrimiNAT"
  description = "Name of the CloudWatch Log Group where DiscrimiNAT instances will log traffic flow and configuration changes. Useful for automating any logging routing configuration."
}

output "target_network_interfaces" {
  value = { for i, z in data.aws_subnet.public_subnet :
  z.availability_zone => aws_network_interface.static_egress[i].id }
  description = "Map of zones to ENI IDs suitable for setting as Network Interface targets in routing tables of Private Subnets. A Terraform example of using these in an \"aws_route\" resource can be found at https://github.com/ChaserSystems/terraform-aws-discriminat-eni/blob/main/examples/aws_vpc/example.tf"
}

##
