#!/usr/bin/env bash
# Run before bringing up a cluster that should restore the latest data.
# Reads the newest archive generation in S3 (banking-pg, banking-pg-g1, g2, ...), restores from it,
# and archives the new cluster under the next generation. Commits and pushes the change.
set -euo pipefail
ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
BUCKET="banking-platform-pg-backups-$ACCOUNT"
FILE=platform/postgres-recovery/cluster.yaml

max=-1
for p in $(aws s3 ls "s3://$BUCKET/" | awk '{print $2}' | tr -d '/'); do
  case "$p" in
    banking-pg)         n=0 ;;
    banking-pg-g[0-9]*) n=${p#banking-pg-g} ;;
    *) continue ;;
  esac
  [ "$n" -gt "$max" ] && max=$n
done
[ "$max" -ge 0 ] || { echo "no backups found in s3://$BUCKET"; exit 1; }

if [ "$max" -eq 0 ]; then src=banking-pg; else src="banking-pg-g$max"; fi
dst="banking-pg-g$((max+1))"

python3 - "$FILE" "$src" "$dst" <<'PY'
import re, sys
f, src, dst = sys.argv[1:4]
t = open(f).read()
h = list(re.finditer(r'serverName: \S+', t))
assert len(h) == 2, "expected exactly two serverName lines"
t = t[:h[0].start()] + f'serverName: {src}' + t[h[0].end():h[1].start()] + f'serverName: {dst}' + t[h[1].end():]
open(f, 'w').write(t)
PY
echo "restore from: $src   archive to: $dst"
git add "$FILE" && git commit -q -m "Postgres generation: restore from $src, archive to $dst" && git push -q
