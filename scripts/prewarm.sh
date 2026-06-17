#!/usr/bin/env bash
#
# Pre-warm the community mirror's edge cache. It sends a tiny ranged GET for
# every disk image so the edge fetches + caches each object once; the first
# real user in that region then gets a cache HIT instead of a cold-miss 403
# from the origin. Nothing is written to disk.
#
# A single run only warms the Cloudflare PoP nearest to wherever it runs, so
# for global coverage schedule it from CI (or several regions). See
# .github/workflows/mirror-health.yml and mirror/cloudflare/.
#
# Usage:
#   MIRROR=https://pcf-mirror.ifuentes.workers.dev scripts/prewarm.sh [id ...]
#   PCF_MIRROR=… scripts/prewarm.sh           # honours the launcher's env vars
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PY="python3"; command -v python3 >/dev/null 2>&1 || PY="python"

MIRROR="${MIRROR:-${PCF_MIRROR:-${PCF_DISKS_BASE:-}}}"
if [ -z "$MIRROR" ]; then
  echo "set MIRROR=https://your-mirror (or PCF_MIRROR / PCF_DISKS_BASE)" >&2
  exit 2
fi
MIRROR="${MIRROR%/}"
UA="${PCF_UA:-pc-futbol-local prewarm (+https://github.com/i10s/pc-futbol-local)}"

ids="${*:-$("$PY" "$ROOT/scripts/_game.py" --ids)}"
echo "Pre-warming $MIRROR"

warmed=0; failed=0
for id in $ids; do
  while IFS=$'\t' read -r kind file _size _sha; do
    [ "$kind" = "disk" ] || continue
    out=$(curl -s -A "$UA" -r 0-1023 -o /dev/null -D - -w '\nCODE=%{http_code}\n' "$MIRROR/$file" || true)
    code=$(printf '%s\n' "$out" | sed -n 's/^CODE=//p' | tail -1)
    hit=$(printf '%s\n' "$out" | tr -d '\r' | awk -F': ' 'tolower($1)=="cf-cache-status"{print $2}')
    case "$code" in
      200|206) printf '  ok  %-28s %s %s\n' "$file" "$code" "${hit:-?}"; warmed=$((warmed + 1));;
      *)       printf '  ERR %-28s %s\n'    "$file" "${code:-000}";       failed=$((failed + 1));;
    esac
  done < <("$PY" "$ROOT/scripts/_game.py" --checkspec "$id")
done

echo "prewarm: $warmed warmed, $failed failed"
[ "$failed" -eq 0 ]
