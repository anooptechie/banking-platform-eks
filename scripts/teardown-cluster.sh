#!/usr/bin/env bash
# Run BEFORE `terraform destroy`. Removes workloads and EBS-backed PVCs so no
# volumes or load balancers are orphaned (they would keep billing).
set -uo pipefail

echo ">> deleting ArgoCD applications (cascade)"
kubectl -n argocd delete application root --wait=true --timeout=300s
kubectl -n argocd delete applications --all --wait=true --timeout=300s

echo ">> deleting PVCs so the EBS volumes are removed"
kubectl -n banking delete pvc --all --wait=true --timeout=300s

echo ">> load balancer services (should be none):"
kubectl get svc -A | grep -i LoadBalancer || echo "none"

echo ">> remaining PVs (should be empty):"
kubectl get pv
echo "If the list above is empty, run: cd terraform/ephemeral && terraform destroy"
