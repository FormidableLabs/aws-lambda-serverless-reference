provider "aws" {
  region  = "${var.region}"
  version = "~> 1.19"
}

terraform {
  backend "s3" {
    key = "terraform.tfstate"
  }
}

# Base `serverless` IAM support.
module "serverless" {
  # TODO(Registry): UPDATE FROM REGISTRY
  source = "../../serverless-iam-terraform"

  region       = "${var.region}"
  service_name = "${var.service_name}"
  stage        = "${var.stage}"

  # (Default values)
  # partition         = `AWS_CALLER`
  # account_id        = `AWS_CALLER`
  # iam_region        = `*`
  # tf_service_name   = `tf-SERVICE_NAME`
  # sls_service_name  = `sls-SERVICE_NAME`
}

# OPTION(Xray): Add X-ray support to lambda execution roles.
module "serverless_xray" {
  # TODO(Registry): UPDATE FROM REGISTRY
  source = "../../serverless-iam-terraform/modules/xray"

  # Same variables as for `serverless` module.
  region       = "${var.region}"
  service_name = "${var.service_name}"
  stage        = "${var.stage}"
}
