#!/usr/bin/env bash
# Usage: HOST=<nlb-hostname> TOKEN=<access token> ./scripts/failover-probe.sh [seconds]
set -euo pipefail
: "${HOST:?}"; : "${TOKEN:?}"
end=$((SECONDS + ${1:-90}))
while [ "$SECONDS" -lt "$end" ]; do
  code=$(curl -s -o /dev/null -m 2 -w "%{http_code}" "http://$HOST/api/v1/accounts" -H "Authorization: Bearer $TOKEN" || echo 000)
  echo "$(date -u +%H:%M:%S.%3N) $code"
  sleep 0.2
done
