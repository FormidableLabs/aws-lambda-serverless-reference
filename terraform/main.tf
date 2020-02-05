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
}
