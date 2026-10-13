terraform {
  required_providers {
    aws  = { source = "hashicorp/aws", version = "~> 6.0" }
    helm = { source = "hashicorp/helm", version = "~> 2.17" }
  }
}

variable "cluster_name" { type = string }
variable "region" { type = string }
variable "vpc_id" { type = string }
variable "db_secret_arn" {
  type        = string
  description = "Secrets Manager secret External Secrets may read"
}

data "aws_iam_policy_document" "pod_identity_assume" {
  statement {
    actions = ["sts:AssumeRole", "sts:TagSession"]
    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
  }
}

# ---------------- AWS Load Balancer Controller ----------------
resource "aws_iam_role" "lbc" {
  name               = "${var.cluster_name}-lbc"
  assume_role_policy = data.aws_iam_policy_document.pod_identity_assume.json
}
resource "aws_iam_role_policy" "lbc" {
  name   = "lbc"
  role   = aws_iam_role.lbc.id
  policy = file("${path.module}/lbc-iam-policy.json") # official policy from the controller repo
}
resource "aws_eks_pod_identity_association" "lbc" {
  cluster_name    = var.cluster_name
  namespace       = "kube-system"
  service_account = "aws-load-balancer-controller"
  role_arn        = aws_iam_role.lbc.arn
}
resource "helm_release" "lbc" {
  name       = "aws-load-balancer-controller"
  namespace  = "kube-system"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = "1.13.3" # verify: helm search repo eks/aws-load-balancer-controller --versions
  wait       = true

  set {
    name  = "clusterName"
    value = var.cluster_name
  }
  set {
    name  = "region"
    value = var.region
  }
  set {
    name  = "vpcId"
    value = var.vpc_id
  }
  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }
  depends_on = [aws_eks_pod_identity_association.lbc]
}

# ---------------- External Secrets Operator ----------------
resource "aws_iam_role" "eso" {
  name               = "${var.cluster_name}-external-secrets"
  assume_role_policy = data.aws_iam_policy_document.pod_identity_assume.json
}
data "aws_iam_policy_document" "eso" {
  statement {
    actions   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
    resources = [var.db_secret_arn]
  }
}
resource "aws_iam_role_policy" "eso" {
  name   = "read-db-secret"
  role   = aws_iam_role.eso.id
  policy = data.aws_iam_policy_document.eso.json
}
resource "aws_eks_pod_identity_association" "eso" {
  cluster_name    = var.cluster_name
  namespace       = "external-secrets"
  service_account = "external-secrets"
  role_arn        = aws_iam_role.eso.arn
}
resource "helm_release" "eso" {
  name             = "external-secrets"
  namespace        = "external-secrets"
  create_namespace = true
  repository       = "https://charts.external-secrets.io"
  chart            = "external-secrets"
  version          = "0.18.2" # verify: helm search repo external-secrets/external-secrets --versions
  wait             = true

  set {
    name  = "serviceAccount.name"
    value = "external-secrets"
  }
  depends_on = [aws_eks_pod_identity_association.eso]
}
