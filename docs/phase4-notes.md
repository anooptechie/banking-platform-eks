# Phase 4 notes: Helm chart, data stores and ArgoCD on EKS

- One generic Helm chart (helm/banking-platform) renders 32 Deployments and 32 Services from a `services:` map
  in values.yaml; the image tag (global.image.tag) is a single field, which is what CI bumps.
- Data stores (Postgres, Redis, Kafka KRaft) are separate StatefulSets on a default gp3 StorageClass, managed by
  their own ArgoCD app. They run as single pods for now; Postgres goes HA in Phase 8.
- ArgoCD App-of-Apps: root -> storage (wave 0), data-stores (wave 1), banking-platform (wave 2).
- Secrets: banking-secrets (DB password, JWT secret) is generated per cluster by scripts/bootstrap-cluster.sh
  and never committed. External Secrets or sealed secrets come in Phase 9.
- Result: 35 pods Running (32 app + postgres, redis, kafka), 3 PVCs Bound on gp3, all 4 ArgoCD apps Healthy/Synced.
  Smoke test through the gateway: login, /auth/me and /accounts all succeed against the EKS Postgres.
- Teardown: scripts/teardown-cluster.sh deletes the ArgoCD apps and the PVCs first so no EBS volumes are orphaned,
  then terraform destroy: 63 resources in 12m21s. Verified no cluster, NAT gateway or load balancer left.
- Lesson 1: Kubernetes injects <SERVICE>_PORT-style env vars for every Service into every pod, which collides with
  POSTGRES_PORT and KAFKA_PORT; fixed with enableServiceLinks: false.
- Lesson 2: services restarted about 3 times on first start while Postgres and Kafka came up. ArgoCD sync waves ordered
  the Application objects but did not wait for the previous app to be Healthy; a custom health check for Application
  resources (argocd/argocd-values.yaml) is the fix, to be verified next session.
- Lesson 3: the frontend nginx config proxies /api to an in-cluster hostname that only exists in the reference setup,
  so the UI needs ingress routing (Phase 5); the backend was tested through a gateway port-forward.
- Apply time: <fill in>. ArgoCD time to all Healthy: <fill in>.
