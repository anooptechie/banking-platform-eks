# Phase 3 notes: CI with GitHub Actions, OIDC, Trivy and ECR

- Workflow: .github/workflows/ci.yaml. A discover job lists app/services plus the frontend (32 images),
  a build matrix runs 8 at a time: buildx build, Trivy report (HIGH/CRITICAL), Trivy gate (CRITICAL fails),
  push to ECR only from main. Pull requests build and scan but never touch AWS.
- Images: one ECR repo (banking-platform), immutable tags <image>-<git-sha12>; a push is skipped if the tag exists.
- AWS auth: GitHub OIDC, no stored keys. The role trusts only this repo's main branch and can only push to this ECR repo.
- Lesson 1: new GitHub repos (created after 15 Jul 2026) issue OIDC tokens whose sub includes the owner and repo IDs
  (repo:<owner>@<owner-id>/<repo>@<repo-id>:ref:...). A trust policy with the classic name-only sub fails with
  "Not authorized to perform sts:AssumeRoleWithWebIdentity". Fixed by reading the real sub from a debug workflow.
- Lesson 2: all actions are pinned to full commit SHAs (after the March 2026 trivy-action tag compromise).
  For annotated tags, use the ^{} commit SHA, not the tag-object SHA.
- Lesson 3: the Trivy gate caught CRITICAL findings in nginx:1.27-alpine (old Alpine layer); fixed by bumping to nginx:1.30-alpine.
- Result: 32 images in ECR from a green run. Dependabot keeps action pins current.
- Not done yet: the commit that bumps image tags in Helm values (needs the chart, Phase 4).
