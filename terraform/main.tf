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
