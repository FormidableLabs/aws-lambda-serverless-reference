############################################################################
# OPTION(custom_roles): Create and use a custom Lambda role in Serverless. #
# This entire file can be commented out if you do not need a custom role.  #
############################################################################

# Example of how to use policies from terraform-aws-serverless to create
# a developer/CI role that any user in the developer group can assume.
#
# Useful for:
# - Delegating permissions to another AWS account.
# - Testing permissions without creating a new user and switching to it.
#   - Group permissions are _additive_: if a user in the developer group
#     has extra permissions outside of the policies attached to the group,
#     that user can execute actions that aren't defined in the group policy.
#     This means that the user can't test group policy in isolation. They
#     must create a new user without additional permissions and attach the
#     developer group to it.
#   - Assuming a role is _subtractive_: it limits your access to the role's
#     IAM statements. This means that a superuser testing group IAM policies
#     won't be affected by any other IAM permissions attached to their account.
#
# We're investigating how best to integrate the assume role policies/principals
# into terraform-aws-serverless here:
# https://github.com/FormidableLabs/terraform-aws-serverless/issues/53
data "aws_caller_identity" "current" {
}

resource "aws_iam_role" "ci" {
  name               = "tf-${var.service_name}-${var.stage}-role-ci"
  assume_role_policy = data.aws_iam_policy_document.ci_assume.json
  tags               = local.tags
}

data "aws_iam_policy_document" "ci_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type = "Service"

      # TODO: investigate the best way to build this into terraform-aws-serverless.
      # Maybe each module can export the principals it allows IAM permissions to.
      identifiers = [
        "lambda.amazonaws.com",
        "apigateway.amazonaws.com",
        "codedeploy.amazonaws.com",
        "cloudformation.amazonaws.com",
        "ec2.amazonaws.com",
        "xray.amazonaws.com",
        "s3.amazonaws.com",
        "logs.amazonaws.com",
        "iam.amazonaws.com",
      ]
    }
  }

  # Allow this account to use policies that grant assume role access to principals.
  # https://stackoverflow.com/a/34943188
  # "Also, attach a Trust Policy on the Role. The sample policy (below) trusts any user in the account,
  # but they would also need sts:AssumeRole permissions (above) to assume the role."
  # "trusting sts:AssumeRole to ..:root user only POTENTIALLY allows any user to assume the role in
  # question. Unless you also grant the permission to some user or group to assume the role, it
  # will not be allowed.
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
  }
}

# Attach policies from main and child modules to this role
resource "aws_iam_role_policy_attachment" "ci" {
  role       = aws_iam_role.ci.name
  policy_arn = module.serverless.iam_policy_ci_arn
}

resource "aws_iam_role_policy_attachment" "ci_cd_lambdas" {
  role       = aws_iam_role.ci.name
  policy_arn = module.serverless.iam_policy_cd_lambdas_arn
}

# OPTION(vpc)
resource "aws_iam_role_policy_attachment" "ci_vpc" {
  role       = aws_iam_role.ci.name
  policy_arn = module.serverless_vpc.iam_policy_ci_arn
}

# OPTION(canary)
resource "aws_iam_role_policy_attachment" "ci_canary" {
  role       = aws_iam_role.ci.name
  policy_arn = module.serverless_canary.iam_policy_ci_arn
}

resource "aws_iam_group_policy_attachment" "ci_role" {
  group      = module.serverless.iam_group_ci_name
  policy_arn = aws_iam_policy.ci_role.arn
}

resource "aws_iam_policy" "ci_role" {
  name   = "tf-${var.service_name}-${var.stage}-policy-ci-role"
  policy = data.aws_iam_policy_document.ci_role.json
}

# Allow a principal to assume this role.
data "aws_iam_policy_document" "ci_role" {
  statement {
    actions   = ["sts:AssumeRole"]
    resources = [aws_iam_role.ci.arn]
  }
}

