#!/usr/bin/env bash
# Core library for the `pcf` launcher (macOS / Linux).
# Sourced by ./pcf — not meant to be run directly.
set -euo pipefail

# --- Paths --------------------------------------------------------------------
PCF_ROOT="${PCF_ROOT:?PCF_ROOT must be set by the launcher}"
SCRIPTS_DIR="$PCF_ROOT/scripts"
DATA_DIR="$PCF_ROOT/data"
PLAY_DIR="$PCF_ROOT/.play"          # local docroot (git-ignored)
DISKS_DIR="$PLAY_DIR/disks"
ORIGIN="https://online.dinamicmultimedia.es"
DISCOS="https://discos.dinamicmultimedia.es"
PORT="${PCF_PORT:-8782}"

# Runtime / front-end files mirrored from the official site (small).
RUNTIME_FILES=(
  "index.html"
  "kiosk.html"
  "games.js"
  "libv86.js"
  "v86.wasm"
  "bios/seabios.bin"
  "bios/vgabios.bin"
  "assets/dinamic.png"
  "assets/fonts/lato.css"
)

# --- Pretty output ------------------------------------------------------------
if [ -t 1 ]; then
  c_bold=$'\033[1m'; c_dim=$'\033[2m'; c_grn=$'\033[32m'; c_red=$'\033[31m'
  c_ylw=$'\033[33m'; c_cya=$'\033[36m'; c_rst=$'\033[0m'
else
  c_bold=""; c_dim=""; c_grn=""; c_red=""; c_ylw=""; c_cya=""; c_rst=""
fi
log()  { printf "%s\n" "$*"; }
info() { printf "%s▸%s %s\n" "$c_cya" "$c_rst" "$*"; }
ok()   { printf "%s✓%s %s\n" "$c_grn" "$c_rst" "$*"; }
warn() { printf "%s!%s %s\n" "$c_ylw" "$c_rst" "$*" >&2; }
die()  { printf "%s✗%s %s\n" "$c_red" "$c_rst" "$*" >&2; exit 1; }

# --- Tools --------------------------------------------------------------------
PY=""
pick_python() {
  for c in python3 python; do
    if command -v "$c" >/dev/null 2>&1; then PY="$c"; return 0; fi
  done
  return 1
}

require_tools() {
  command -v curl >/dev/null 2>&1 || die "curl is required but not found."
  pick_python || die "Python 3 is required but not found. Install it and retry."
}

open_url() {
  local url="$1"
  if command -v open >/dev/null 2>&1; then open "$url"
  elif command -v xdg-open >/dev/null 2>&1; then xdg-open "$url" >/dev/null 2>&1 &
  else info "Open your browser at: $url"; fi
}

game_vars() { eval "$("$PY" "$SCRIPTS_DIR/_game.py" "$1")" || die "Unknown game: $1"; }
human()     { "$PY" "$SCRIPTS_DIR/_game.py" --human "$1"; }

# --- Download helpers ---------------------------------------------------------
# Resumable download with progress. Skips when the file already has the
# expected size (so re-runs are cheap and safe).
fetch() {
  local url="$1" dest="$2" expected="${3:-}"
  mkdir -p "$(dirname "$dest")"
  if [ -n "$expected" ] && [ -f "$dest" ]; then
    local have; have=$(wc -c < "$dest" | tr -d ' ')
    if [ "$have" = "$expected" ]; then return 0; fi
  fi
  curl -fL --retry 3 --retry-delay 2 -C - -o "$dest" "$url" \
    || die "Download failed: $url"
}

fetch_quiet() {
  local url="$1" dest="$2"
  mkdir -p "$(dirname "$dest")"
  curl -fsSL -o "$dest" "$url" || return 1
}

# --- Mirror the v86 runtime + front-end (one-time, small) ---------------------
mirror_runtime() {
  if [ -f "$PLAY_DIR/.runtime-ok" ]; then return 0; fi
  info "Setting up the local emulator (one-time)…"
  mkdir -p "$PLAY_DIR/bios" "$PLAY_DIR/assets/fonts" "$DISKS_DIR" "$PLAY_DIR/papi"

  local f
  for f in "${RUNTIME_FILES[@]}"; do
    fetch_quiet "$ORIGIN/$f" "$PLAY_DIR/$f" || warn "could not fetch $f (continuing)"
  done

  # Point the disk URLs at our local /disks instead of the remote host.
  if [ -f "$PLAY_DIR/games.js" ]; then
    sed -i.bak "s#$DISCOS/#disks/#g" "$PLAY_DIR/games.js" && rm -f "$PLAY_DIR/games.js.bak"
    # Best-effort: mirror every game logo referenced in games.js.
    grep -oE '/assets/[A-Za-z0-9_-]+\.(png|jpg|svg)' "$PLAY_DIR/games.js" | sort -u | while read -r a; do
      [ -f "$PLAY_DIR$a" ] || fetch_quiet "$ORIGIN$a" "$PLAY_DIR$a" || true
    done
  fi

  # Stub the small backend endpoints so the kiosk runs fully offline.
  printf '%s' '{"maintenance":false}'         > "$PLAY_DIR/papi/config.json"
  printf '%s' '{}'                            > "$PLAY_DIR/papi/names.json"

  touch "$PLAY_DIR/.runtime-ok"
  ok "Emulator ready."
}

# --- Download a single game (disks + savestate) -------------------------------
game_present() {
  local id="$1"; game_vars "$id"
  local d
  for d in $GDISKS; do
    [ -f "$DISKS_DIR/$d" ] || return 1
  done
  [ -f "$PLAY_DIR/$GSTATE" ] || return 1
  return 0
}

download_game() {
  local id="$1"; game_vars "$id"
  mirror_runtime
  info "Downloading ${c_bold}$GNAME${c_rst} ($GYEAR) — about ${c_bold}$GTOTAL_H${c_rst}"
  log  "${c_dim}Source: official free servers (Dinamic Multimedia / FX Interactive).${c_rst}"

  local d
  for d in $GDISKS; do
    info "→ $d"
    # size lookup from the manifest for skip-if-complete behaviour
    local sz; sz=$("$PY" -c "import json,sys;d=json.load(open('$DATA_DIR/games.json'));
print(next(x['size'] for g in d['games'] if g['id']=='$id' for x in g['disks'] if x['file']=='$d'))")
    fetch "$DISCOS/$d" "$DISKS_DIR/$d" "$sz"
  done

  info "→ $GSTATE (savestate)"
  fetch "$ORIGIN/$GSTATE" "$PLAY_DIR/$GSTATE"
  ok "$GNAME is ready to play."
}

# --- Serve + open the browser -------------------------------------------------
SERVER_PID=""
cleanup() { [ -n "$SERVER_PID" ] && kill "$SERVER_PID" >/dev/null 2>&1 || true; }

serve_and_play() {
  local id="$1"; game_vars "$id"
  trap cleanup EXIT INT TERM

  "$PY" "$SCRIPTS_DIR/serve.py" --root "$PLAY_DIR" --port "$PORT" --host 127.0.0.1 &
  SERVER_PID=$!
  sleep 1
  kill -0 "$SERVER_PID" 2>/dev/null || die "Local server failed to start (port $PORT busy? set PCF_PORT)."

  local url="http://127.0.0.1:$PORT/kiosk.html?game=$id"
  ok "Now playing: ${c_bold}$GNAME${c_rst}"
  log "  $url"
  log "  ${c_dim}Press ▶ JUGAR / PLAY in the browser. Saved games persist in this browser.${c_rst}"
  log "  ${c_dim}Press Ctrl+C here to stop the server.${c_rst}"
  open_url "$url"
  wait "$SERVER_PID"
}

# --- Commands -----------------------------------------------------------------
cmd_list() {
  log "${c_bold}Available games:${c_rst}"
  "$PY" "$SCRIPTS_DIR/_game.py" --list | while IFS=$'\t' read -r id year name; do
    local mark="  "
    game_present "$id" >/dev/null 2>&1 && mark="${c_grn}●${c_rst} "
    printf "  %b%-11s %s  %s%s%s\n" "$mark" "$id" "$year" "$c_dim" "$name" "$c_rst"
  done
  log ""
  log "${c_dim}● = already downloaded for offline play${c_rst}"
}

cmd_get()  { [ $# -ge 1 ] || die "usage: pcf get <id>";  download_game "$1"; }

cmd_play() {
  [ $# -ge 1 ] || die "usage: pcf play <id>   (see: pcf list)"
  local id="$1"
  game_vars "$id"
  mirror_runtime
  if ! game_present "$id"; then
    download_game "$id"
  fi
  serve_and_play "$id"
}

cmd_doctor() {
  log "${c_bold}Environment check${c_rst}"
  printf "  OS        : %s %s\n" "$(uname -s)" "$(uname -m)"
  if command -v curl >/dev/null 2>&1; then ok "curl found"; else warn "curl MISSING"; fi
  if pick_python; then ok "python found ($PY $($PY -c 'import sys;print(".".join(map(str,sys.version_info[:3])))'))"; else warn "python3 MISSING"; fi
  if [ -d "$PLAY_DIR" ]; then ok "local data dir: $PLAY_DIR"; else info "no data downloaded yet"; fi
  [ -f "$PLAY_DIR/.runtime-ok" ] && ok "emulator runtime installed" || info "emulator runtime not installed yet"
}

cmd_clean() {
  read -r -p "Remove ALL downloaded games and the local emulator ($PLAY_DIR)? [y/N] " a
  case "$a" in [yY]*) rm -rf "$PLAY_DIR"; ok "Removed.";; *) log "Cancelled.";; esac
}
