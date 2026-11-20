#!/usr/bin/env bash
# Run after `terraform apply` and `aws eks update-kubeconfig`.
# Usage: ARGOCD_CHART_VERSION=<version> ./scripts/bootstrap-cluster.sh
set -euo pipefail
: "${ARGOCD_CHART_VERSION:?set ARGOCD_CHART_VERSION (see: helm search repo argo/argo-cd)}"
CLUSTER_NAME="${CLUSTER_NAME:-banking-platform}"
AWS_REGION="${AWS_REGION:-us-east-1}"
LBC_CHART_VERSION="${LBC_CHART_VERSION:-3.6.3}"
VPC_ID="${VPC_ID:-$(terraform -chdir=terraform/ephemeral output -raw vpc_id)}"
DB_PARAM="/banking-platform/db-password"

helm repo add argo https://argoproj.github.io/argo-helm >/dev/null
helm repo add eks https://aws.github.io/eks-charts >/dev/null
helm repo update >/dev/null

# The DB password lives in SSM so it survives cluster teardown: a database restored from a
# backup keeps the old password, so the new cluster must use the same one.
if ! DB_PASSWORD=$(aws ssm get-parameter --region "$AWS_REGION" --name "$DB_PARAM" --with-decryption \
      --query Parameter.Value --output text 2>/dev/null); then
  DB_PASSWORD=$(openssl rand -hex 16)
  aws ssm put-parameter --region "$AWS_REGION" --name "$DB_PARAM" --type SecureString \
    --value "$DB_PASSWORD" >/dev/null
  echo "Generated and stored a new DB password in SSM ($DB_PARAM)."
fi

# Namespace and secrets are created out-of-band so no secret ever lands in Git.
kubectl create namespace banking --dry-run=client -o yaml | kubectl apply -f -
kubectl -n banking create secret generic banking-secrets \
  --from-literal=POSTGRES_PASSWORD="$DB_PASSWORD" \
  --from-literal=JWT_SECRET="$(openssl rand -hex 32)" \
  --dry-run=client -o yaml | kubectl apply -f -
kubectl -n banking create secret generic banking-db-credentials \
  --type=kubernetes.io/basic-auth \
  --from-literal=username=banking --from-literal=password="$DB_PASSWORD" \
  --dry-run=client -o yaml | kubectl apply -f -

# AWS Load Balancer Controller: needs this cluster's VPC ID, so it is installed here, not via Git.
helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
  --version "$LBC_CHART_VERSION" --namespace kube-system \
  --set clusterName="$CLUSTER_NAME" --set vpcId="$VPC_ID" --set region="$AWS_REGION" \
  --set serviceAccount.create=true --set serviceAccount.name=aws-load-balancer-controller \
  --wait

helm upgrade --install argocd argo/argo-cd --version "$ARGOCD_CHART_VERSION" \
  -f argocd/argocd-values.yaml \
  --namespace argocd --create-namespace --wait

kubectl apply -f argocd/bootstrap/root-app.yaml
echo "Bootstrapped. Watch with: kubectl -n argocd get applications -w"
