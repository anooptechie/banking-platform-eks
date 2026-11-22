#!/usr/bin/env bash
# Run BEFORE `terraform destroy`. Removes workloads, the NLB and EBS-backed PVCs so
# nothing is orphaned (orphaned volumes and load balancers keep billing and block VPC deletion).
set -uo pipefail
REGION="${AWS_REGION:-us-east-1}"

echo ">> final backup before teardown"
B=final-$(date +%s)
kubectl -n banking exec $(kubectl -n banking get cluster banking-pg -o jsonpath="{.status.currentPrimary}") -c postgres -- psql -U postgres -d banking -qc "SELECT pg_switch_wal();" || true
cat <<EOB | kubectl apply -f -
apiVersion: postgresql.cnpg.io/v1
kind: Backup
metadata:
  name: $B
  namespace: banking
spec:
  cluster:
    name: banking-pg
  method: plugin
  pluginConfiguration:
    name: barman-cloud.cloudnative-pg.io
EOB
kubectl -n banking wait --for=jsonpath="{.status.phase}"=completed backup/$B --timeout=300s || echo "WARNING: final backup did not complete"

echo ">> deleting ArgoCD applications (cascade)"
kubectl -n argocd delete application root --wait=true --timeout=300s
kubectl -n argocd delete applications --all --wait=true --timeout=300s

echo ">> deleting PVCs so the EBS volumes are removed"
kubectl -n banking delete pvc --all --wait=true --timeout=300s

echo ">> waiting for the NLB to be deleted by the load balancer controller"
for i in $(seq 1 18); do
  n=$(aws elbv2 describe-load-balancers --region "$REGION" --query 'length(LoadBalancers)' --output text 2>/dev/null || echo 0)
  [ "$n" = "0" ] && break
  echo "   load balancers left: $n (waiting 10s)"; sleep 10
done

echo ">> removing the load balancer controller"
helm uninstall aws-load-balancer-controller -n kube-system 2>/dev/null || true

echo ">> LoadBalancer services (should be none):"
kubectl get svc -A | grep -i LoadBalancer || echo "none"
echo ">> remaining PVs (should be empty):"
kubectl get pv
echo "If both lists are empty, run: cd terraform/ephemeral && terraform destroy"
