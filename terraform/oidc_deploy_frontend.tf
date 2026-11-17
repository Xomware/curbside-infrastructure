# Deploy role for curbside-frontend's call to deploy-frontend-s3.yml. Separate
# from the backend's role so the frontend repo can't touch the Lambdas.

locals {
  frontend_deploy_subjects = [
    "repo:Xomware/curbside-frontend",
    "repo:Xomware@263047999/curbside-frontend@1460745999",
  ]
}

data "aws_iam_policy_document" "deploy_frontend_trust" {
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
      values   = [for s in local.frontend_deploy_subjects : "${s}:ref:refs/heads/main"]
    }
  }
}

resource "aws_iam_role" "deploy_frontend" {
  name               = "${var.app_name}-github-actions-deploy-frontend"
  assume_role_policy = data.aws_iam_policy_document.deploy_frontend_trust.json
}

data "aws_iam_policy_document" "deploy_frontend" {
  statement {
    sid       = "PublishSite"
    actions   = ["s3:ListBucket", "s3:PutObject", "s3:DeleteObject"]
    resources = [module.web.s3_bucket_arn, "${module.web.s3_bucket_arn}/*"]
  }

  # No resource-level form. The workflow finds the distribution by alias; the
  # invalidation itself is scoped below.
  statement {
    sid       = "FindDistribution"
    actions   = ["cloudfront:ListDistributions"]
    resources = ["*"]
  }

  statement {
    sid       = "InvalidateCache"
    actions   = ["cloudfront:CreateInvalidation"]
    resources = [module.web.cloudfront_distribution_arn]
  }

  # The workflow's `ssm` input bakes these into the bundle.
  statement {
    sid     = "ReadBuildConfig"
    actions = ["ssm:GetParameter"]
    resources = [
      aws_ssm_parameter.cognito_user_pool_id.arn,
      aws_ssm_parameter.cognito_web_client_id.arn,
      aws_ssm_parameter.cognito_domain.arn,
      aws_ssm_parameter.api_url.arn,
    ]
  }
}

resource "aws_iam_role_policy" "deploy_frontend" {
  name   = "deploy-frontend"
  role   = aws_iam_role.deploy_frontend.id
  policy = data.aws_iam_policy_document.deploy_frontend.json
}

output "frontend_deploy_role_arn" {
  description = "Goes into Infisical /curbside as AWS_FRONTEND_ROLE_ARN."
  value       = aws_iam_role.deploy_frontend.arn
}

output "web_bucket_name" {
  description = "deploy-frontend-s3.yml `bucket` input."
  value       = module.web.s3_bucket_id
}

output "web_distribution_id" {
  description = "For manual invalidations; the workflow finds it by alias."
  value       = module.web.cloudfront_distribution_id
}
