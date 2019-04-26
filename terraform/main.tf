provider "aws" {
  region = "${var.region}"
}

terraform {
  backend "s3" {
    key = "terraform.tfstate"
  }
}

# Base `serverless` IAM support.
module "serverless" {
  source = "../../terraform-aws-serverless" // DEV ONLY

  // TODO source = "FormidableLabs/serverless/aws"

  region       = "${var.region}"
  service_name = "${var.service_name}"
  stage        = "${var.stage}"

  # (Default values)
  # iam_region          = `*`
  # iam_partition       = `*`
  # iam_account_id      = `AWS_CALLER account`
  # tf_service_name     = `tf-SERVICE_NAME`
  # sls_service_name    = `sls-SERVICE_NAME`
  # role_admin_name     = `admin`
  # role_developer_name = `developer`
  # role_ci_name        = `ci`
  # opt_many_lambdas    = false
}

# OPTION(Xray): Add X-ray support to lambda execution roles.
module "serverless_xray" {
  source = "../../terraform-aws-serverless/modules/xray" // DEV ONLY

  // TODO source = "FormidableLabs/serverless/aws//modules/xray"

  # Same variables as for `serverless` module.
  region       = "${var.region}"
  service_name = "${var.service_name}"
  stage        = "${var.stage}"
}

data "aws_availability_zones" "available" {}

# OPTION(VPC): Instantiate an actual VPC
#
# ## Available ranges
#
# - 10.0.0.0 - 10.255.255.255 (10/8 prefix)
# - 172.16.0.0 - 172.31.255.255 (172.16/12 prefix)
# - 192.168.0.0 - 192.168.255.255 (192.168/16 prefix)
#
# - `10.0.0.0/8` is reserved for ClassicLink VPC. Don't use if need that.
#   https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/vpc-classiclink.html
# - `172.31.0.0/16` is usually the default VPC group.
#
# ## Addressing
#
# Param                   CIDR            Start       End           Hosts
# ======================= =============== =========== ============= ======
# Private Subnet A        10.1.0.0/20     10.1.0.0    10.1.15.255   4096
# Private Subnet B        10.1.16.0/20    10.1.16.0   10.1.31.255   4096
# <Private Spare> C       10.1.32.0/20
# <Private Spare> D       10.1.48.0/20
#
# Public Subnet A         10.1.64.0/20    10.1.64.0   10.1.79.255   4096
# Public Subnet B         10.1.80.0/20    10.1.80.0   10.1.95.255   4096
# <Public Spare> C        10.1.96.0/20
# <Public Spare> D        10.1.112.0/20
#
# VPC CIDR Block          10.1.0.0/17     10.1.0.0    10.1.127.255  32768
module "vpc" "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "tf-${var.service_name}-${var.stage}"

  # Dynamically get 2 availabile AZs for failover.
  azs = [
    "${data.aws_availability_zones.available.names[0]}",
    "${data.aws_availability_zones.available.names[1]}",
  ]

  # Features
  enable_dns_hostnames = true
  enable_dns_support   = true
  enable_nat_gateway   = true

  # Networking
  cidr            = "10.1.0.0/17"
  private_subnets = ["10.1.0.0/20", "10.1.16.0/20"]
  public_subnets  = ["10.1.64.0/20", "10.1.80.0/20"]

  tags = "${local.tags}"
}

# OPTION(VPC): Use a custom, honed SG.
resource "aws_security_group" "vpc" {
  name        = "tf-${var.service_name}-${var.stage}"
  description = "Allow Serverless Lambda networking"
  vpc_id      = "${module.vpc.vpc_id}"

  egress {
    description = "Egress: tf-${var.service_name}-${var.stage}"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = "${merge(local.tags, map(
    "Name", "tf-${var.service_name}-${var.stage}",
  ))}"
}
