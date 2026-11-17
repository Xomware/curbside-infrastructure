# Deploy role for curbside-backend's deploy.yml. It lives here because this
# stack owns the functions; the plan/apply roles live in xomware-infrastructure
# because a stack can't create the roles its own pipeline assumes.

locals {
  # Both subject forms: the org emits the numeric one, and the plain form
  # alone fails AssumeRoleWithWebIdentity.
  deploy_subjects = [
    "repo:Xomware/curbside-backend",
    "repo:Xomware@263047999/curbside-backend@1460745906",
  ]
}

data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

data "aws_iam_policy_document" "deploy_trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = [for s in local.deploy_subjects : "${s}:ref:refs/heads/main"]
    }
  }
}

resource "aws_iam_role" "deploy" {
  name               = "${var.app_name}-github-actions-deploy"
  assume_role_policy = data.aws_iam_policy_document.deploy_trust.json
}

data "aws_iam_policy_document" "deploy" {
  statement {
    sid = "DeployFunctions"
    actions = [
      "lambda:UpdateFunctionCode",
      "lambda:UpdateFunctionConfiguration",
      "lambda:GetFunction",
      "lambda:GetFunctionConfiguration",
      "lambda:PublishLayerVersion",
      "lambda:ListLayerVersions",
      "lambda:GetLayerVersion",
    ]
    resources = [
      "arn:aws:lambda:${var.aws_region}:${local.account_id}:function:${var.app_name}-*",
      "arn:aws:lambda:${var.aws_region}:${local.account_id}:layer:${var.app_name}-*",
    ]
  }

  # Neither action has a resource-level form.
  statement {
    sid       = "EnumerateLambdas"
    actions   = ["lambda:ListFunctions", "lambda:ListLayers"]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "deploy" {
  name   = "deploy"
  role   = aws_iam_role.deploy.id
  policy = data.aws_iam_policy_document.deploy.json
}

output "deploy_role_arn" {
  description = "Goes into Infisical /curbside as AWS_BACKEND_ROLE_ARN."
  value       = aws_iam_role.deploy.arn
}
