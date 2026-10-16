terraform {
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 6.0" }
  }
}

variable "name" { type = string }
variable "oidc_provider_arn" { type = string }
variable "github_repository" { type = string }
variable "subs" {
  type        = list(string)
  description = "sub-claim suffixes after repo:<owner/repo>: e.g. pull_request, ref:refs/heads/main, environment:production"
}
variable "managed_policy_arns" {
  type    = list(string)
  default = []
}
variable "create_inline_policy" {
  type        = bool
  default     = false
  description = "Set to true when inline_policy_json is passed (must be known at plan time, unlike the policy itself)"
}
variable "inline_policy_json" {
  type    = string
  default = null
}

data "aws_iam_policy_document" "trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = [for s in var.subs : "repo:${var.github_repository}:${s}"]
    }
  }
}

resource "aws_iam_role" "this" {
  name               = var.name
  assume_role_policy = data.aws_iam_policy_document.trust.json
}

resource "aws_iam_role_policy_attachment" "managed" {
  for_each   = toset(var.managed_policy_arns)
  role       = aws_iam_role.this.name
  policy_arn = each.value
}

resource "aws_iam_role_policy" "inline" {
  count  = var.create_inline_policy ? 1 : 0
  name   = "${var.name}-inline"
  role   = aws_iam_role.this.id
  policy = var.inline_policy_json
}

output "role_arn" { value = aws_iam_role.this.arn }