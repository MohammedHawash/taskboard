#!/usr/bin/env bash
# Usage: ./gitops/install-argocd.sh gitops/applications/taskboard-<env>.yaml
# Same script for minikube and EKS (it uses the current kubectl context).
set -euo pipefail
APP_FILE="${1:?usage: $0 <application-file>}"
helm repo add argo https://argoproj.github.io/argo-helm >/dev/null 2>&1 || true
helm repo update argo
helm upgrade --install argocd argo/argo-cd -n argocd --create-namespace --wait
kubectl apply -f "$APP_FILE"
