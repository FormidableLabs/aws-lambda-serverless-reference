variable "region" {
  description = "The deploy target region in AWS"
  default     = "us-east-1"
}

variable "stage" {
  description = "The stage/environment to deploy to. Suggest: `sandbox`, `development`, `staging`, `production`."
  default     = "sandbox"
}

variable "service_name" {
  description = "Name of service / application"
}

locals {
  tags = {
    "Service" = var.service_name
    "Stage"   = var.stage
  }
}

