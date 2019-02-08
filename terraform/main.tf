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
  // TODO(Registry): UPDATE FROM REGISTRY
  source = "../../serverless-iam-terraform/modules/iam"

  region       = "${var.region}"
  service_name = "${var.service_name}"
  stage        = "${var.stage}"
}
