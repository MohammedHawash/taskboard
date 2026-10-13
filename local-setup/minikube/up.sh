#!/usr/bin/env bash
# Usage: ./up.sh          -> helm install + helm test
#        ./up.sh argocd   -> Argo CD installs the app from Git
set -euo pipefail
MODE="${1:-helm}"
PROFILE=taskboard
IMAGE=taskboard-backend:local
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

if ! minikube status -p "$PROFILE" >/dev/null 2>&1; then
  minikube start -p "$PROFILE" --cpus 2 --memory 4096
fi
kubectl config use-context "$PROFILE" >/dev/null

docker build --pull --build-arg APP_VERSION=local -t "$IMAGE" "$ROOT/app/backend"
minikube -p "$PROFILE" image load "$IMAGE"

if [ "$MODE" = "argocd" ]; then
  "$ROOT/gitops/install-argocd.sh" "$ROOT/gitops/applications/taskboard-local.yaml"
  echo "Argo CD UI: kubectl -n argocd port-forward svc/argocd-server 8080:443"
  echo "Password:   kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d; echo"
else
  helm upgrade --install taskboard "$ROOT/deploy/helm/taskboard" \
    -n taskboard --create-namespace \
    -f "$ROOT/deploy/helm/taskboard/values-local.yaml" --wait --timeout 5m
  helm test taskboard -n taskboard --logs
fi
