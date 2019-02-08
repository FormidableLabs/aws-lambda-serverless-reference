provider "aws" {
  region  = "${var.region}"
  version = "~> 1.19"
}

terraform {
  backend "s3" {
    key = "terraform.tfstate"
  }
}

module "serverless_iam" {
  # TODO(Registry): UPDATE FROM REGISTRY
  source = "../../serverless-iam-terraform/modules/iam"

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
