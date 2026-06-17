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

# Origin hosts. Override these to point at a community mirror / CDN and take
# load off the official servers (be a good neighbour):
#   PCF_DISKS_BASE  — heavy disk images   (default: discos.dinamicmultimedia.es)
#   PCF_MIRROR      — shortcut for PCF_DISKS_BASE
#   PCF_ORIGIN_BASE — runtime + savestate (default: online.dinamicmultimedia.es)
# A maintainer can also ship data/mirror.json so the whole community downloads
# from a CDN by default (env vars still win). See mirror/cloudflare/.
DISCOS_OFFICIAL="https://discos.dinamicmultimedia.es"
ORIGIN_OFFICIAL="https://online.dinamicmultimedia.es"

# Tiny extractor for a single string key from our own (trusted) mirror.json.
json_get() {
  grep -oE "\"$1\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" "$2" 2>/dev/null \
    | head -1 | sed -E 's/.*:[[:space:]]*"([^"]*)"/\1/' || true
}

discos_default="$DISCOS_OFFICIAL"; origin_default="$ORIGIN_OFFICIAL"
if [ -f "$DATA_DIR/mirror.json" ]; then
  m="$(json_get disks  "$DATA_DIR/mirror.json")"; [ -n "$m" ] && discos_default="$m"
  m="$(json_get origin "$DATA_DIR/mirror.json")"; [ -n "$m" ] && origin_default="$m"
fi

ORIGIN="${PCF_ORIGIN_BASE:-$origin_default}"
DISCOS="${PCF_DISKS_BASE:-${PCF_MIRROR:-$discos_default}}"
PORT="${PCF_PORT:-8782}"

# Be gentle with the origin server:
#   PCF_RATE_LIMIT — cap download speed, e.g. "3M" or "800k" (default: unlimited)
#   PCF_UA         — override the (identifiable) User-Agent string
PCF_RATE_LIMIT="${PCF_RATE_LIMIT:-}"
PCF_UA="${PCF_UA:-pc-futbol-local (+https://github.com/i10s/pc-futbol-local)}"

# Shared, polite curl options: one connection, identifiable UA, exponential
# backoff on transient errors. No parallel/segmented downloads on purpose.
CURL_COMMON=( --location --fail
  --user-agent "$PCF_UA"
  --retry 5 --retry-delay 3 --retry-connrefused --retry-max-time 120 )
[ -n "$PCF_RATE_LIMIT" ] && CURL_COMMON+=( --limit-rate "$PCF_RATE_LIMIT" )

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

# --- OS / distro detection ----------------------------------------------------
os_kind() {
  case "$(uname -s)" in
    Darwin) echo macos;;
    Linux)  if grep -qi microsoft /proc/version 2>/dev/null; then echo wsl; else echo linux; fi;;
    *)      echo other;;
  esac
}
linux_distro() { ( . /etc/os-release 2>/dev/null && echo "${PRETTY_NAME:-Linux}" ) || echo Linux; }

# Suggest the right install command for the current package manager.
pkg_hint() {
  local tool="$1"
  if   command -v apt-get >/dev/null 2>&1; then echo "sudo apt install -y $tool"
  elif command -v dnf     >/dev/null 2>&1; then echo "sudo dnf install -y $tool"
  elif command -v pacman  >/dev/null 2>&1; then echo "sudo pacman -S --noconfirm $tool"
  elif command -v zypper  >/dev/null 2>&1; then echo "sudo zypper install -y $tool"
  elif command -v apk     >/dev/null 2>&1; then echo "sudo apk add $tool"
  elif command -v brew    >/dev/null 2>&1; then echo "brew install $tool"
  else echo "install '$tool' with your package manager"; fi
}

# --- Tools --------------------------------------------------------------------
PY=""
pick_python() {
  for c in python3 python; do
    if command -v "$c" >/dev/null 2>&1; then PY="$c"; return 0; fi
  done
  return 1
}

require_tools() {
  command -v curl >/dev/null 2>&1 || die "curl is required. Install it with:  $(pkg_hint curl)"
  pick_python || die "Python 3 is required. Install it with:  $(pkg_hint python3)"
}

# Open a URL in the default browser across macOS, Linux, WSL and *BSD.
open_url() {
  local url="$1"
  if [ -n "${PCF_NO_OPEN:-}" ]; then info "Open your browser at: $url"; return; fi
  if   command -v open       >/dev/null 2>&1; then open "$url"                              # macOS
  elif command -v wslview    >/dev/null 2>&1; then wslview "$url" >/dev/null 2>&1 &          # WSL (wslu)
  elif command -v powershell.exe >/dev/null 2>&1 && grep -qi microsoft /proc/version 2>/dev/null; then
       powershell.exe -NoProfile -Command "Start-Process '$url'" >/dev/null 2>&1 &           # WSL fallback
  elif command -v xdg-open   >/dev/null 2>&1; then xdg-open "$url" >/dev/null 2>&1 &         # freedesktop
  elif command -v gio        >/dev/null 2>&1; then gio open "$url" >/dev/null 2>&1 &         # GNOME
  elif command -v sensible-browser >/dev/null 2>&1; then sensible-browser "$url" >/dev/null 2>&1 &
  elif [ -n "${BROWSER:-}" ]; then "$BROWSER" "$url" >/dev/null 2>&1 &
  else info "Open your browser at: $url"; fi
}

# Find a free TCP port starting at $PORT (so two games can run side by side).
find_free_port() {
  "$PY" - "$PORT" <<'PY'
import socket, sys
start = int(sys.argv[1])
for p in range(start, start + 50):
    s = socket.socket()
    try:
        s.bind(("127.0.0.1", p)); s.close(); print(p); break
    except OSError:
        continue
else:
    print(start)
PY
}

game_vars() { eval "$("$PY" "$SCRIPTS_DIR/_game.py" "$1")" || die "Unknown game: $1"; }
human()     { "$PY" "$SCRIPTS_DIR/_game.py" --human "$1"; }

# --- Download helpers ---------------------------------------------------------
# Resumable download. Skips when the file already has the expected size (so
# re-runs are cheap and safe). Returns non-zero on failure instead of aborting.
fetch_try() {
  local url="$1" dest="$2" expected="${3:-}"
  mkdir -p "$(dirname "$dest")"
  if [ -n "$expected" ] && [ -f "$dest" ]; then
    local have; have=$(wc -c < "$dest" | tr -d ' ')
    if [ "$have" = "$expected" ]; then return 0; fi
  fi
  # Resume (-C -) so an interrupted run never re-downloads from scratch.
  curl "${CURL_COMMON[@]}" -C - -o "$dest" "$url"
}

# Try the configured source first, then fall back to the official origin so a
# down/blocked mirror never leaves users stuck.
fetch_mirrored() {
  local path="$1" dest="$2" expected="${3:-}" primary="$4" official="$5"
  if fetch_try "$primary/$path" "$dest" "$expected"; then return 0; fi
  if [ "$primary" != "$official" ]; then
    warn "mirror failed for $path — falling back to the official origin"
    fetch_try "$official/$path" "$dest" "$expected" && return 0
  fi
  die "Download failed: $path"
}

fetch_quiet() {
  local url="$1" dest="$2"
  mkdir -p "$(dirname "$dest")"
  curl "${CURL_COMMON[@]}" --silent --show-error -o "$dest" "$url" || return 1
}

# Print the SHA-256 of a file (portable across Linux/macOS); empty if no tool.
sha256_file() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | awk '{print $1}'
  elif command -v shasum  >/dev/null 2>&1; then shasum -a 256 "$1" | awk '{print $1}'
  else return 1; fi
}

# --- Mirror the v86 runtime + front-end (one-time, small) ---------------------
mirror_runtime() {
  if [ -f "$PLAY_DIR/.runtime-ok" ]; then return 0; fi
  info "Setting up the local emulator (one-time)…"
  mkdir -p "$PLAY_DIR/bios" "$PLAY_DIR/assets/fonts" "$DISKS_DIR" "$PLAY_DIR/papi"

  local f
  for f in "${RUNTIME_FILES[@]}"; do
    # Prefer the cached mirror so the origin is hit ~once per PoP, not per user;
    # fall back to the official host if the mirror can't serve it.
    if ! fetch_quiet "$DISKS/$f" "$PLAY_DIR/$f"; then
      fetch_quiet "$ORIGIN_OFFICIAL/$f" "$PLAY_DIR/$f" || warn "could not fetch $f (continuing)"
    fi
  done

  # Point the disk URLs at our local /disks instead of the remote host.
  if [ -f "$PLAY_DIR/games.js" ]; then
    sed -i.bak "s#$DISCOS_OFFICIAL/#disks/#g" "$PLAY_DIR/games.js" && rm -f "$PLAY_DIR/games.js.bak"
    # Best-effort: mirror every game logo referenced in games.js.
    grep -oE '/assets/[A-Za-z0-9_-]+\.(png|jpg|svg)' "$PLAY_DIR/games.js" | sort -u | while read -r a; do
      [ -f "$PLAY_DIR$a" ] || fetch_quiet "$DISKS$a" "$PLAY_DIR$a" || fetch_quiet "$ORIGIN_OFFICIAL$a" "$PLAY_DIR$a" || true
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
    fetch_mirrored "$d" "$DISKS_DIR/$d" "$sz" "$DISCOS" "$DISCOS_OFFICIAL"
  done

  info "→ $GSTATE (savestate)"
  fetch_mirrored "$GSTATE" "$PLAY_DIR/$GSTATE" "" "$ORIGIN" "$ORIGIN_OFFICIAL"
  ok "$GNAME is ready to play."
}

# --- Serve + open the browser -------------------------------------------------
SERVER_PID=""
cleanup() {
  if [ -n "$SERVER_PID" ]; then kill "$SERVER_PID" >/dev/null 2>&1 || true; fi
}

start_server() {
  trap cleanup EXIT INT TERM
  PORT="$(find_free_port)"
  "$PY" "$SCRIPTS_DIR/serve.py" --root "$PLAY_DIR" --port "$PORT" --host 127.0.0.1 &
  SERVER_PID=$!
  sleep 1
  kill -0 "$SERVER_PID" 2>/dev/null || die "Local server failed to start on port $PORT."
}

# Serve $PLAY_DIR and open the browser at $path; blocks until Ctrl+C.
serve_path() {
  local path="$1" label="$2"
  start_server
  local url="http://127.0.0.1:$PORT/$path"
  ok "$label"
  log "  $url"
  log "  ${c_dim}Saved games persist in this browser. Press Ctrl+C here to stop.${c_rst}"
  open_url "$url"
  wait "$SERVER_PID"
}

serve_and_play() {
  local id="$1"; game_vars "$id"
  serve_path "kiosk.html?game=$id" "Now playing: ${c_bold}$GNAME${c_rst}"
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

# Emit the environment/offline status as JSON (machine-readable diagnostics).
doctor_json() {
  local os arch distro pyver runtime total n curl_ok mirror
  os="$(os_kind)"; arch="$(uname -m)"
  distro=""; { [ "$os" = linux ] || [ "$os" = wsl ]; } && distro="$(linux_distro)"
  pyver=""; [ -n "${PY:-}" ] && pyver="$("$PY" -c 'import sys;print(".".join(map(str,sys.version_info[:3])))' 2>/dev/null || true)"
  runtime=false; [ -f "$PLAY_DIR/.runtime-ok" ] && runtime=true
  total="$("$PY" "$SCRIPTS_DIR/_game.py" --ids | wc -w | tr -d ' ')"
  n=0
  if [ -f "$PLAY_DIR/.runtime-ok" ]; then
    local id
    while IFS=$'\t' read -r id _; do game_present "$id" >/dev/null 2>&1 && n=$((n+1)); done \
      < <("$PY" "$SCRIPTS_DIR/_game.py" --list 2>/dev/null)
  fi
  curl_ok=false; command -v curl >/dev/null 2>&1 && curl_ok=true
  mirror=false; [ "$DISCOS" != "$DISCOS_OFFICIAL" ] && mirror=true
  OSV="$os" ARCHV="$arch" DISTRO="$distro" PYVER="$pyver" RUNTIME="$runtime" \
  CURL_OK="$curl_ok" DISKS_SRC="$DISCOS" MIRROR="$mirror" RATE="${PCF_RATE_LIMIT:-}" \
  TOTAL="$total" LOCAL_N="$n" PLAYDIR="$PLAY_DIR" \
  "$PY" - <<'PY'
import json, os
def b(x): return x == "true"
print(json.dumps({
    "os": os.environ["OSV"],
    "arch": os.environ["ARCHV"],
    "distro": os.environ.get("DISTRO") or None,
    "curl": b(os.environ["CURL_OK"]),
    "python": os.environ.get("PYVER") or None,
    "runtime_installed": b(os.environ["RUNTIME"]),
    "disks_source": os.environ["DISKS_SRC"],
    "using_mirror": b(os.environ["MIRROR"]),
    "rate_limit": os.environ.get("RATE") or None,
    "games_total": int(os.environ["TOTAL"]),
    "games_local": int(os.environ["LOCAL_N"]),
    "play_dir": os.environ["PLAYDIR"],
}, indent=2))
PY
}

cmd_doctor() {
  if [ "${1:-}" = "--json" ]; then doctor_json; return; fi
  local os; os="$(os_kind)"
  log "${c_bold}Environment check${c_rst}"
  printf "  OS        : %s (%s %s)\n" "$os" "$(uname -s)" "$(uname -m)"
  if [ "$os" = linux ] || [ "$os" = wsl ]; then printf "  Distro    : %s\n" "$(linux_distro)"; fi
  if command -v curl >/dev/null 2>&1; then ok "curl found"; else warn "curl MISSING → $(pkg_hint curl)"; fi
  if pick_python; then ok "python found ($PY $($PY -c 'import sys;print(".".join(map(str,sys.version_info[:3])))'))"; else warn "python MISSING → $(pkg_hint python3)"; fi
  if [ -n "${PCF_NO_OPEN:-}" ]; then info "browser auto-open disabled (PCF_NO_OPEN set)"
  elif command -v open >/dev/null 2>&1 || command -v xdg-open >/dev/null 2>&1 || command -v wslview >/dev/null 2>&1 || command -v gio >/dev/null 2>&1 || [ -n "${BROWSER:-}" ]; then ok "a browser launcher is available"
  else warn "no browser launcher found (the URL will be printed so you can open it manually)"; fi
  if [ -d "$PLAY_DIR" ]; then
    local used; used=$(du -sh "$PLAY_DIR" 2>/dev/null | cut -f1)
    ok "local data dir: $PLAY_DIR (${used:-?} used)"
  else info "no data downloaded yet"; fi
  if [ -f "$PLAY_DIR/.runtime-ok" ]; then ok "emulator runtime installed"; else info "emulator runtime not installed yet"; fi
  log "${c_bold}Download settings${c_rst}"
  if [ "$DISCOS" = "$DISCOS_OFFICIAL" ]; then printf "  Disks src : official servers\n"
  else printf "  Disks src : %s%s%s (mirror)\n" "$c_cya" "$DISCOS" "$c_rst"; fi
  printf "  Rate limit: %s\n" "${PCF_RATE_LIMIT:-unlimited (tip: PCF_RATE_LIMIT=3M)}"
  log "${c_bold}Offline readiness${c_rst}"
  if [ -f "$PLAY_DIR/.runtime-ok" ]; then
    local n=0 id
    while IFS=$'\t' read -r id _; do game_present "$id" >/dev/null 2>&1 && n=$((n+1)); done \
      < <("$PY" "$SCRIPTS_DIR/_game.py" --list 2>/dev/null)
    if [ "$n" -gt 0 ]; then
      ok "$n game(s) fully local — server, kiosk, ISOs & savestate all on disk"
      printf "  %sYou can unplug the network and play.%s\n" "$c_dim" "$c_rst"
    else
      info "runtime ready; download one game to play fully offline"
    fi
  else
    info "first download fetches the runtime once; after that everything runs locally"
  fi
}

# Verify downloaded files against the manifest: size always, SHA-256 when the
# manifest records one. With --record, print the SHA-256 of present files so a
# maintainer can paste them back into data/games.json.
#   pcf verify [id]            verify one game (or every downloaded game)
#   pcf verify --record [id]   print checksums of present files
cmd_verify() {
  local record="" target=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --record) record=1;;
      -*)       die "usage: pcf verify [--record] [id]";;
      *)        target="$1";;
    esac
    shift
  done

  local ids
  if [ -n "$target" ]; then ids="$target"; else ids="$("$PY" "$SCRIPTS_DIR/_game.py" --ids)"; fi

  local fail=0 checked=0 id
  for id in $ids; do
    game_vars "$id"
    # Skip games that aren't downloaded unless the user asked for one by name.
    if [ -z "$target" ] && ! game_present "$id" >/dev/null 2>&1; then continue; fi
    log "${c_bold}$GNAME${c_rst} (${c_dim}$id${c_rst})"
    local kind file size sha path
    while IFS=$'\t' read -r kind file size sha; do
      case "$kind" in
        disk)  path="$DISKS_DIR/$file";;
        state) path="$PLAY_DIR/$file";;
        *)     continue;;
      esac
      if [ ! -f "$path" ]; then
        printf "  %s✗%s missing: %s\n" "$c_red" "$c_rst" "$file"; fail=1; continue
      fi
      if [ -n "$record" ]; then
        printf "  %s  %s\n" "$(sha256_file "$path" 2>/dev/null || echo '?')" "$file"
        checked=$((checked+1)); continue
      fi
      if [ -n "$size" ]; then
        local have; have=$(wc -c < "$path" | tr -d ' ')
        if [ "$have" != "$size" ]; then
          printf "  %s✗%s size mismatch: %s (%s, expected %s)\n" "$c_red" "$c_rst" "$file" "$have" "$size"
          fail=1; continue
        fi
      fi
      if [ -n "$sha" ]; then
        local got; got="$(sha256_file "$path" 2>/dev/null || echo '')"
        if [ -z "$got" ]; then
          warn "  no sha256 tool available; checksum skipped for $file"
        elif [ "$got" != "$sha" ]; then
          printf "  %s✗%s checksum FAIL: %s\n" "$c_red" "$c_rst" "$file"; fail=1; continue
        else
          ok "  $file (size + sha256)"
        fi
      else
        ok "  $file (size ok; no checksum recorded)"
      fi
      checked=$((checked+1))
    done < <("$PY" "$SCRIPTS_DIR/_game.py" --checkspec "$id")
  done

  if [ -n "$record" ]; then return 0; fi
  if [ "$checked" -eq 0 ]; then info "nothing downloaded to verify (try: pcf get <id>)"; return 0; fi
  if [ "$fail" -ne 0 ]; then die "verification found problems — re-run 'pcf get <id>' to repair"; fi
  ok "all good — $checked file(s) match the manifest"
}

cmd_menu() {
  mirror_runtime
  serve_path "index.html" "Game menu — pick a downloaded title in the browser"
}

cmd_update() {
  info "Refreshing the local emulator runtime…"
  rm -f "$PLAY_DIR/.runtime-ok"
  mirror_runtime
  ok "Runtime updated. Your downloaded games are kept."
}

cmd_install_desktop() {
  case "$(os_kind)" in linux|wsl) ;; *) die "install-desktop is only available on Linux.";; esac
  mirror_runtime
  local apps="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
  mkdir -p "$apps"
  local icon="$PLAY_DIR/assets/dinamic.png"; [ -f "$icon" ] || icon="applications-games"
  local dest="$apps/pc-futbol-local.desktop"
  cat > "$dest" <<EOF
[Desktop Entry]
Type=Application
Name=PC Fútbol Local
Comment=Play the classic PC Fútbol games locally
Exec=$PCF_ROOT/pcf menu
Icon=$icon
Terminal=true
Categories=Game;Emulator;
Keywords=futbol;football;manager;dinamic;retro;
EOF
  chmod +x "$dest" 2>/dev/null || true
  ok "Desktop entry installed: $dest"
  log "  ${c_dim}It will appear in your applications menu (runs 'pcf menu').${c_rst}"
}

cmd_clean() {
  read -r -p "Remove ALL downloaded games and the local emulator ($PLAY_DIR)? [y/N] " a
  case "$a" in [yY]*) rm -rf "$PLAY_DIR"; ok "Removed.";; *) log "Cancelled.";; esac
}
