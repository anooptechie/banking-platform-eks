#!/usr/bin/env bash
# Run after `terraform apply` and `aws eks update-kubeconfig`.
# Usage: ARGOCD_CHART_VERSION=<version> ./scripts/bootstrap-cluster.sh
set -euo pipefail
: "${ARGOCD_CHART_VERSION:?set ARGOCD_CHART_VERSION (see: helm search repo argo/argo-cd)}"

helm repo add argo https://argoproj.github.io/argo-helm >/dev/null
helm repo update >/dev/null

# Namespace and secrets are created out-of-band so no secret ever lands in Git.
kubectl create namespace banking --dry-run=client -o yaml | kubectl apply -f -
if ! kubectl -n banking get secret banking-secrets >/dev/null 2>&1; then
  kubectl -n banking create secret generic banking-secrets \
    --from-literal=POSTGRES_PASSWORD="$(openssl rand -hex 16)" \
    --from-literal=JWT_SECRET="$(openssl rand -hex 32)"
fi

helm upgrade --install argocd argo/argo-cd --version "$ARGOCD_CHART_VERSION" \
  --namespace argocd --create-namespace --wait

kubectl apply -f argocd/bootstrap/root-app.yaml
echo "Bootstrapped. Watch with: kubectl -n argocd get applications -w"
