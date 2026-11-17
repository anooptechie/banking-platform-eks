# Phase 1 notes: running the app on EC2 with Docker Compose

- Host: EC2 t3.xlarge (Ubuntu 24.04), 60 GB gp3.
- All 30 services plus Postgres, Redis, Kafka and the frontend came up with no restarts.
- Memory: about 1 GB total for all containers (Go services use about 5-6 MiB each).
- Images: about 50 MB per service; 30 services build in a few minutes.
- Frontend nginx config targeted the in-cluster gateway DNS name, so under Compose /api returned 502.
  Fixed with a Compose-only override (docker-compose.local.yaml + nginx.compose.conf) pointing at api-gateway.
- All services share one Postgres database with prefixed tables.
- Dev secrets (DB password, JWT secret) are hardcoded in compose; they become Kubernetes Secrets later.
- Transfer feature returns "ledger service unavailable"; cause not investigated (the error is swallowed in
  the app). Deposits, accounts, cards and loans work. Skipped on purpose; this is a platform project.
