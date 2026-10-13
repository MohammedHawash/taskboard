terraform {
  required_version = ">= 1.10"

  backend "s3" {
    # bucket + region are passed with -backend-config (see infra.yml)
    key          = "prod/terraform.tfstate"
    encrypt      = true
    use_lockfile = true # S3 native state locking
  }

  required_providers {
    aws    = { source = "hashicorp/aws", version = "~> 6.0" }
    helm   = { source = "hashicorp/helm", version = "~> 2.17" }
    random = { source = "hashicorp/random", version = "~> 3.7" }
  }
}

variable "region" {
  type    = string
  default = "eu-west-1"
}
variable "github_repository" {
  type        = string
  description = "owner/repo"
}
variable "eks_admin_principal_arns" {
  type        = list(string)
  description = "IAM users/roles with cluster-admin, e.g. [\"arn:aws:iam::123456789012:user/you\"]"
}

provider "aws" { region = var.region }

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_ca)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", local.name, "--region", var.region]
    }
  }
}

locals {
  name = "taskboard-prod"
}

data "aws_availability_zones" "available" { state = "available" }
data "aws_caller_identity" "current" {}
data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

# ---------------- secrets (never in Git) ----------------
resource "random_password" "db" {
  length  = 24
  special = false
}
resource "random_password" "origin_verify" {
  length  = 40
  special = false
}
resource "aws_secretsmanager_secret" "db" {
  name                    = "${local.name}/db-password"
  recovery_window_in_days = 0 # lab: allows destroy + recreate with the same name
}
resource "aws_secretsmanager_secret_version" "db" {
  secret_id     = aws_secretsmanager_secret.db.id
  secret_string = jsonencode({ password = random_password.db.result })
}

# ---------------- modules ----------------
module "network" {
  source = "../../modules/network"
  name   = local.name
  azs    = slice(data.aws_availability_zones.available.names, 0, 2)
}

module "eks" {
  source             = "../../modules/eks"
  name               = local.name
  private_subnet_ids = module.network.private_subnet_ids
  # the infra role needs access too: Terraform's Helm provider talks to the cluster
  admin_principal_arns = concat(
    var.eks_admin_principal_arns,
    ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/taskboard-github-infra"]
  )
}

module "ecr" {
  source = "../../modules/ecr"
  name   = "taskboard-backend"
}

module "backend_alb" {
  source               = "../../modules/backend-alb"
  name                 = local.name
  vpc_id               = module.network.vpc_id
  vpc_cidr             = module.network.vpc_cidr
  public_subnet_ids    = module.network.public_subnet_ids
  origin_verify_secret = random_password.origin_verify.result
}

module "static_site" {
  source               = "../../modules/static-site"
  name                 = local.name
  alb_dns_name         = module.backend_alb.dns_name
  origin_verify_secret = random_password.origin_verify.result
}

module "platform" {
  source        = "../../modules/platform"
  cluster_name  = module.eks.cluster_name
  region        = var.region
  vpc_id        = module.network.vpc_id
  db_secret_arn = aws_secretsmanager_secret.db.arn
}

# ALB -> pods on 8000 (target type ip: traffic goes straight to the pod, which has the node/cluster SG)
resource "aws_vpc_security_group_ingress_rule" "alb_to_pods" {
  security_group_id            = module.eks.node_security_group_id
  referenced_security_group_id = module.backend_alb.security_group_id
  description                  = "ALB to backend pods"
  ip_protocol                  = "tcp"
  from_port                    = 8000
  to_port                      = 8000
}

# ---------------- least-privilege deploy role for GitHub Actions ----------------
data "aws_iam_policy_document" "deploy" {
  statement {
    sid       = "EcrLogin"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }
  statement {
    sid = "EcrPushPromote"
    actions = [
      "ecr:BatchCheckLayerAvailability", "ecr:InitiateLayerUpload", "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload", "ecr:PutImage", "ecr:BatchGetImage", "ecr:GetDownloadUrlForLayer",
    ]
    resources = [module.ecr.repository_arn]
  }
  statement {
    sid       = "S3Frontend"
    actions   = ["s3:PutObject", "s3:DeleteObject", "s3:GetObject"]
    resources = ["${module.static_site.bucket_arn}/*"]
  }
  statement {
    sid       = "S3FrontendList"
    actions   = ["s3:ListBucket"]
    resources = [module.static_site.bucket_arn]
  }
  statement {
    sid       = "Invalidate"
    actions   = ["cloudfront:CreateInvalidation"]
    resources = [module.static_site.distribution_arn]
  }
}

module "github_deploy_role" {
  source             = "../../modules/github-oidc-role"
  name               = "taskboard-prod-github-deploy"
  oidc_provider_arn  = data.aws_iam_openid_connect_provider.github.arn
  github_repository  = var.github_repository
  subs               = ["ref:refs/heads/main", "ref:refs/tags/v*", "environment:production"]
  inline_policy_json = data.aws_iam_policy_document.deploy.json
}

# ---------------- outputs = GitHub Actions variables ----------------
output "github_deploy_role_arn" { value = module.github_deploy_role.role_arn }
output "ecr_repository_url" { value = module.ecr.repository_url }
output "frontend_bucket" { value = module.static_site.bucket_name }
output "cloudfront_distribution_id" { value = module.static_site.distribution_id }
output "app_url" { value = "https://${module.static_site.domain_name}" }
output "backend_target_group_arn" { value = module.backend_alb.target_group_arn }
output "alb_dns_name" { value = module.backend_alb.dns_name }
