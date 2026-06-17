#!/usr/bin/env bash
#
# Hermetic smoke test for scripts/serve.py: verifies HTTP Range support, which
# v86 relies on to stream the disk images. Does NOT touch the network or any
# game data. Used by CI and `make test`.
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PY="python3"; command -v python3 >/dev/null 2>&1 || PY="python"
PORT="${PCF_TEST_PORT:-8911}"

tmp="$(mktemp -d)"
pid=""
cleanup() {
  if [ -n "$pid" ]; then kill "$pid" >/dev/null 2>&1 || true; fi
  rm -rf "$tmp"
}
trap cleanup EXIT

# Build a tiny docroot: a 1 MiB blob + an index.
head -c 1048576 /dev/urandom > "$tmp/blob.bin"
printf '<!doctype html><title>ok</title>ok' > "$tmp/index.html"

"$PY" "$ROOT/scripts/serve.py" --root "$tmp" --port "$PORT" --host 127.0.0.1 >/dev/null 2>&1 &
pid=$!
disown "$pid" 2>/dev/null || true
sleep 1
kill -0 "$pid" 2>/dev/null || { echo "FAIL: server did not start"; exit 1; }

fail() { echo "FAIL: $1"; exit 1; }

# 1) Full GET returns 200.
code=$(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:$PORT/index.html")
[ "$code" = "200" ] || fail "index.html expected 200, got $code"

# 2) Range request returns 206 with correct Content-Range.
hdr=$(curl -s -D - -o /dev/null -r 100-199 "http://127.0.0.1:$PORT/blob.bin")
echo "$hdr" | grep -q "206" || fail "Range request did not return 206"
echo "$hdr" | grep -qi "content-range: bytes 100-199/1048576" \
  || { echo "$hdr"; fail "wrong Content-Range header"; }

# 3) Range body has exactly the requested length.
len=$(curl -s -r 100-199 "http://127.0.0.1:$PORT/blob.bin" | wc -c | tr -d ' ')
[ "$len" = "100" ] || fail "Range body length expected 100, got $len"

# 4) Query strings (cache busters) are ignored when resolving paths.
code=$(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:$PORT/index.html?v=2")
[ "$code" = "200" ] || fail "query-string path expected 200, got $code"

# 5) Path traversal is rejected.
code=$(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:$PORT/../../etc/passwd")
[ "$code" = "404" ] || fail "path traversal should be blocked, got $code"

# 6) Concurrent Range requests all succeed (threaded server, no buffer crashes).
pids=""
for i in $(seq 1 12); do
  ( curl -s -r 0-65535 "http://127.0.0.1:$PORT/blob.bin" | wc -c | tr -d ' ' > "$tmp/c$i" ) &
  pids="$pids $!"
done
# shellcheck disable=SC2086
wait $pids
for i in $(seq 1 12); do
  [ "$(cat "$tmp/c$i")" = "65536" ] || fail "concurrent range #$i wrong length: $(cat "$tmp/c$i")"
done

# 7) An abrupt client disconnect (RST mid-stream) must not crash the server.
"$PY" - "$PORT" <<'PY'
import socket, struct, sys
port = int(sys.argv[1])
s = socket.create_connection(("127.0.0.1", port))
s.sendall(b"GET /blob.bin HTTP/1.1\r\nHost: x\r\nRange: bytes=0-1048575\r\n\r\n")
s.recv(64)                                   # read a little, then bail out
s.setsockopt(socket.SOL_SOCKET, socket.SO_LINGER, struct.pack("ii", 1, 0))  # force RST
s.close()
PY
kill -0 "$pid" 2>/dev/null || fail "server died after a client disconnect"
code=$(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:$PORT/index.html")
[ "$code" = "200" ] || fail "server unhealthy after disconnect, got $code"

echo "serve.py self-test PASSED (Range + security + concurrency OK)"
