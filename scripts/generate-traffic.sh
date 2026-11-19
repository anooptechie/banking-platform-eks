#!/usr/bin/env bash
# Usage: HOST=<nlb-hostname> ./scripts/generate-traffic.sh [seconds]
set -euo pipefail
: "${HOST:?set HOST to the NLB hostname}"
DURATION="${1:-120}"
BASE="http://${HOST}/api/v1"
EMAIL="traffic$(date +%s)@test.com"

curl -s -X POST "$BASE/auth/register" -H 'Content-Type: application/json' \
  -d "{\"email\":\"$EMAIL\",\"password\":\"Passw0rd!\",\"full_name\":\"Traffic\"}" >/dev/null
TOKEN=$(curl -s -X POST "$BASE/auth/login" -H 'Content-Type: application/json' \
  -d "{\"email\":\"$EMAIL\",\"password\":\"Passw0rd!\"}" | jq -r .access_token)

end=$((SECONDS + DURATION))
while [ "$SECONDS" -lt "$end" ]; do
  curl -s -o /dev/null -w "%{http_code} " "$BASE/accounts" -H "Authorization: Bearer $TOKEN"
  curl -s -o /dev/null -w "%{http_code} " -X POST "$BASE/auth/login" \
    -H 'Content-Type: application/json' -d '{"email":"nobody@test.com","password":"wrong"}'
  curl -s -o /dev/null -w "%{http_code}\n" "$BASE/auth/me" -H "Authorization: Bearer $TOKEN"
  sleep 0.5
done
