# Attribution

The application code in `app/` (Go services, shared packages, protos, frontend and the
local docker-compose files) comes from the Banking Platform reference project and is used
with the author's permission.

- Source: https://github.com/vijaygiduthuri/banking_application_eks
- Upstream commit: f48631532c867456fa24868ff25cd9a13487d178

Everything outside `app/` (Terraform, Helm, ArgoCD, CI, docs) is my own work.
`docker-compose.local.yaml` and `frontend/nginx.compose.conf` are my additions to run the
frontend under Docker Compose.
