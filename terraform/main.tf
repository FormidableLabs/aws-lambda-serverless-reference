provider "aws" {
  region = var.region
}

terraform {
  backend "s3" {
    key = "terraform.tfstate"
  }
}

# A resource group is an optional, but very nice thing to have, especially
# when managing resources across CF + TF + SLS.
#
# This RG aggregates all of CF + TF + SLS together by `Service` + `Stage`.
resource "aws_resourcegroups_group" "resources_stage" {
  name = "tf-${var.service_name}-${var.stage}"

  resource_query {
    query = <<JSON
{
  "ResourceTypeFilters": [
    "AWS::AllSupported"
  ],
  "TagFilters": [
    {
      "Key": "Service",
      "Values": ["${var.service_name}"]
    },
    {
      "Key": "Stage",
      "Values": ["${var.stage}"]
    }
  ]
}
JSON

  }
}

###############################################################################
# Base `serverless` IAM support
###############################################################################
module "serverless" {
  source  = "FormidableLabs/serverless/aws"
  version = "1.0.0"

  region       = var.region
  service_name = var.service_name
  stage        = var.stage
  # OPTION(custom_role): override the Lambda execution role that
  # terraform-aws-serverless creates by default.
  # lambda_role_name = "${aws_iam_role.lambda_execution_custom.name}"

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

###############################################################################
# OPTIONAL STUFF BELOW!!!
# =======================
# Everything below here provides specific features and enhancements that you
# may wish to investigate in a serverless app, such as:
# - `xray`: Set up AWS Xray tracing
# - `vpc`: Deploy Lambda in AWS VPC
# - `layers`: Deploy Lambda Layers alongside Lambda Functions
###############################################################################

###############################################################################
# OPTION(xray): Add X-ray support to lambda execution roles.
###############################################################################
module "serverless_xray" {
  source  = "FormidableLabs/serverless/aws//modules/xray"
  version = "1.0.0"

  # Same variables as for `serverless` module.
  region       = var.region
  service_name = var.service_name
  stage        = var.stage
  # OPTION(custom_role): override the Lambda execution role that
  # terraform-aws-serverless creates by default.
  # lambda_role_name = "${aws_iam_role.lambda_execution_custom.name}"
}

###############################################################################
# OPTION(vpc): Create VPC resources and expose to Serverless stack.
###############################################################################
data "aws_availability_zones" "available" {
}

# OPTION(vpc): Instantiate an actual VPC
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
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "2.21.0"

  name = "tf-${var.service_name}-${var.stage}"

  # Dynamically get 2 availabile AZs for failover.
  azs = [
    data.aws_availability_zones.available.names[0],
    data.aws_availability_zones.available.names[1],
  ]

  # Features
  enable_dns_hostnames = true
  enable_dns_support   = true
  enable_nat_gateway   = true

  # Networking
  cidr            = "10.1.0.0/17"
  private_subnets = ["10.1.0.0/20", "10.1.16.0/20"]
  public_subnets  = ["10.1.64.0/20", "10.1.80.0/20"]

  tags = local.tags
}

# OPTION(vpc): Use a custom, honed SG.
resource "aws_security_group" "vpc" {
  name        = "tf-${var.service_name}-${var.stage}"
  description = "Allow Serverless Lambda networking"
  vpc_id      = module.vpc.vpc_id

  egress {
    description = "Egress: tf-${var.service_name}-${var.stage}"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    local.tags,
    {
      "Name" = "tf-${var.service_name}-${var.stage}"
    },
  )
}

# OPTION(vpc): Use a small CloudFormation stack to expose outputs for
# consumption in Serverless. (There are _many_ ways to do this, we just
# like this as there's no local disk state needed to deploy.)
#
# _Note_: CF **requires** 1+ `Resources`, so we throw in the SSM param of the
# VPC SG because it's small and we need "something". It's otherwise unused.
#
# See: https://theburningmonk.com/2019/03/making-terraform-and-serverless-framework-work-together/
resource "aws_cloudformation_stack" "outputs_vpc" {
  name = "tf-${var.service_name}-${var.stage}-outputs-vpc"

  template_body = <<STACK
Resources:
  VPCSecurityGroupId:
    Type: AWS::SSM::Parameter
    Properties:
      Name: "tf-${var.service_name}-${var.stage}-VPCSecurityGroupId"
      Value: "${aws_security_group.vpc.id}"
      Type: String

Outputs:
  VPCSecurityGroupId:
    Description: "VPC SG GID"
    Value: "${aws_security_group.vpc.id}"
    Export:
      Name: "tf-${var.service_name}-${var.stage}-VPCSecurityGroupId"

  VPCPrivateSubnetA:
    Description: "VPC Private Subnet A"
    Value: "${module.vpc.private_subnets[0]}"
    Export:
      Name: "tf-${var.service_name}-${var.stage}-VPCPrivateSubnetA"

  VPCPrivateSubnetB:
    Description: "VPC Private Subnet B"
    Value: "${module.vpc.private_subnets[1]}"
    Export:
      Name: "tf-${var.service_name}-${var.stage}-VPCPrivateSubnetB"

STACK


  tags = local.tags
}

# OPTION(vpc): Add in IAM permissions to humans + lambda execution role.
module "serverless_vpc" {
  source  = "FormidableLabs/serverless/aws//modules/vpc"
  version = "1.0.0"

  # Same variables as for `serverless` module.
  region       = var.region
  service_name = var.service_name
  stage        = var.stage
  # OPTION(custom_role): override the Lambda execution role that
  # terraform-aws-serverless creates by default.
  # lambda_role_name = "${aws_iam_role.lambda_execution_custom.name}"
}

###############################################################################
# OPTION(custom_roles): Create and use a custom Lambda role in Serverless.
###############################################################################
data "aws_partition" "current" {
}

resource "aws_iam_role" "lambda_execution_custom" {
  name               = "tf-${var.service_name}-${var.stage}-lambda-execution-custom"
  assume_role_policy = data.aws_iam_policy_document.lambda_execution_custom_assume.json
  tags               = local.tags
}

# OPTION(custom_roles): Allow Lambda to assume the custom role.
data "aws_iam_policy_document" "lambda_execution_custom_assume" {
  statement {
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

# OPTION(custom_roles): Use a small CloudFormation stack to expose outputs for
# consumption in Serverless. (There are _many_ ways to do this, we just
# like this as there's no local disk state needed to deploy.)
#
# _Note_: CF **requires** 1+ `Resources`, so we throw in the SSM param of the
# role ARN because it's small and we need "something". It's otherwise unused.
#
# See: https://theburningmonk.com/2019/03/making-terraform-and-serverless-framework-work-together/
resource "aws_cloudformation_stack" "outputs_custom_role" {
  name = "tf-${var.service_name}-${var.stage}-outputs-custom-role"

  template_body = <<STACK
Resources:
  LambdaExecutionRoleArn:
    Type: AWS::SSM::Parameter
    Properties:
      Name: "tf-${var.service_name}-${var.stage}-LambdaExecutionRoleCustomArn"
      Value: "${aws_iam_role.lambda_execution_custom.arn}"
      Type: String

Outputs:
  LambdaExecutionRoleArn:
    Description: "The ARN of the lambda execution role for Serverless to apply"
    Value: "${aws_iam_role.lambda_execution_custom.arn}"
    Export:
      Name: "tf-${var.service_name}-${var.stage}-LambdaExecutionRoleCustomArn"

STACK


  tags = local.tags
}

# OPTION(canary): Add serverless-plugin-canary-deployments to lambda execution roles.
module "serverless_canary" {
  source  = "FormidableLabs/serverless/aws//modules/canary"
  version = "1.0.0"

  # Same variables as for `serverless` module.
  region       = var.region
  service_name = var.service_name
  stage        = var.stage
}

