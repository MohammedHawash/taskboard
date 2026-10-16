terraform {
  required_version = ">= 1.10"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 6.0" }
  }
}

provider "aws" { region = var.region }

variable "region" {
  type    = string
  default = "eu-west-1"
}
variable "github_repository" {
  type        = string
  description = "owner/repo, e.g. mohammed/taskboard"
}
variable "state_bucket_name" {
  type        = string
  description = "Globally unique S3 bucket name for Terraform state"
}

# ---- state bucket ----
resource "aws_s3_bucket" "state" {
  bucket = var.state_bucket_name
}
resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id
  versioning_configuration { status = "Enabled" }
}
resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id
  rule {
    apply_server_side_encryption_by_default { sse_algorithm = "AES256" }
  }
}
resource "aws_s3_bucket_public_access_block" "state" {
  bucket                  = aws_s3_bucket.state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ---- GitHub OIDC provider (only ONE per account: import it if it already exists) ----
resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
}

# ---- role used by the infra workflow ----
module "infra_role" {
  source = "../modules/github-oidc-role"

  name              = "taskboard-github-infra"
  oidc_provider_arn = aws_iam_openid_connect_provider.github.arn
  github_repository = var.github_repository
  subs              = ["pull_request", "ref:refs/heads/main", "environment:infrastructure"]
  # Terraform creates VPC/EKS/IAM/... -> broad rights. Trade-off documented in README.
  managed_policy_arns = ["arn:aws:iam::aws:policy/AdministratorAccess"]
}

output "state_bucket" { value = aws_s3_bucket.state.bucket }
output "infra_role_arn" { value = module.infra_role.role_arn }
output "oidc_provider_arn" { value = aws_iam_openid_connect_provider.github.arn }
