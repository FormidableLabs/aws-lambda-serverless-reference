# TODO TODO TODO

# Allowing defaults for:
# - `partition` (caller)
# - `account_id` (caller)
# - `iam_region` (`*`)

variable "region" {
  description = "The deploy target region in AWS"
  default     = "us-east-1"
}

variable "stage" {
  description = "The stage/environment to deploy to. Suggest: `sandbox`, `development`, `staging`, `production`."
  default     = "development"
}

variable "service_name" {
  description = "Name of service / application"
}
