#!/usr/bin/env bash
# Populate a Cloudflare R2 bucket with the official disk images, once.
# Streams each disk from the origin straight into R2 (no large temp files).
# Re-runnable: a local ledger (.synced) skips files already uploaded.
#
#   Usage:  ./sync-to-r2.sh            # uses bucket "pcf-disks"
#           PCF_R2_BUCKET=my-bucket ./sync-to-r2.sh
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
GAMES="$ROOT/data/games.json"
BUCKET="${PCF_R2_BUCKET:-pcf-disks}"
ORIGIN="${PCF_DISKS_BASE:-https://discos.dinamicmultimedia.es}"
LEDGER="$HERE/.synced"
UA="pc-futbol-local-sync (+https://github.com/i10s/pc-futbol-local)"

command -v curl >/dev/null 2>&1 || { echo "curl is required" >&2; exit 1; }
command -v npx  >/dev/null 2>&1 || { echo "Node.js/npx (for wrangler) is required" >&2; exit 1; }
PY=python3; command -v python3 >/dev/null 2>&1 || PY=python
command -v "$PY" >/dev/null 2>&1 || { echo "python3 is required" >&2; exit 1; }

touch "$LEDGER"

"$PY" -c "import json;d=json.load(open('$GAMES'));print(chr(10).join(sorted({x['file'] for g in d['games'] for x in g['disks']})))" \
| while IFS= read -r f; do
    [ -n "$f" ] || continue
    if grep -qxF "$f" "$LEDGER"; then
      echo "✓ skip   $f"
      continue
    fi
    echo "→ upload $f"
    curl -fL --retry 5 --retry-delay 3 --retry-connrefused --retry-max-time 120 \
         -A "$UA" "$ORIGIN/$f" \
      | npx wrangler r2 object put "$BUCKET/$f" --pipe --content-type application/octet-stream
    echo "$f" >> "$LEDGER"
  done

echo ""
echo "Sync complete. Next:"
echo "  1) Uncomment the [[r2_buckets]] binding in wrangler.toml"
echo "  2) npx wrangler deploy"
echo "  3) Point clients at your mirror (PCF_MIRROR or data/mirror.json)"
