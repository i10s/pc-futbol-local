# Changelog

All notable changes to this project are documented here.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Fixed
- **Disk downloads through the mirror work again.** The official disk host
  (`discos.dinamicmultimedia.es`) is now behind a Cloudflare WAF that 403s plain
  automated requests. The mirror Worker now signs each disk transparently: it
  fetches the short-lived token from `/papi/sign`, appends it as `?k=…`, and
  replays the kiosk browser's full request fingerprint (UA + `Accept*` +
  `Referer`/`Origin` + `Sec-Fetch-*`). The same browser headers are now sent for
  savestates and runtime too. Disks are cached under the token-less URL so the
  rotating token never fragments the edge cache. No launcher changes required.

### Added
- **Shareable career saves.** A new in-kiosk "💾 Partidas" menu lets you export
  your saved career to a small `.pcfsave` file and import it later (fully
  offline), or — optionally — **share it to the cloud** and get a short 10-char
  code a friend can use to download it. Cloud sharing is backed by a Cloudflare
  Worker + R2 bucket (`pcf-saves`), with strict validation (magic bytes, 4 MB
  cap, unguessable codes, 90-day expiry) and is feature-flagged: remove the
  `SAVES` binding to disable it (endpoints then return 503).
- **CLI access to shared saves:** `pcf saves share <file.pcfsave>` uploads a
  save and prints a share code; `pcf saves get <code>` downloads one. Works in
  both the bash and PowerShell launchers.
- **`web/pcf-saves.js`** companion script, injected into the mirrored kiosk by
  the launcher, plus `papi/saves.json` pointing the kiosk at the share endpoint.
- **Config:** `PCF_SAVES_BASE` env var and a `saves` key in `data/mirror.json`
  override the share endpoint (defaults to the community Worker).

## [0.2.0] - 2026-06-19

### Added
- **5 new games** mirrored from the official catalog (now 16 total): PC Fútbol
  5.0 Apertura '97 (`pcf5arg`), PC Fútbol 6.0 Apertura '98 (`pcf6arg`), PC Barça
  '99 (`pcbarca99`), PC Real Madrid 99 (`pcrm`) and PC Atlético de Madrid 2000
  (`atm2000`). Sizes verified against origin; the community mirror serves them
  transparently (no Worker change needed).
- **Automated releases** (`.github/workflows/release.yml`): pushing a `vX.Y.Z`
  tag publishes the GitHub Release (notes from `CHANGELOG.md`) and pins the
  Homebrew formula's `url` + `sha256` to the tag automatically.
- **Formula guard in CI**: `ruby -c` + `brew style` on `Formula/` so the
  Homebrew formula can't drift.

### Fixed
- **Mirror 404 on savestates**: the Cloudflare Worker matched every `*.bin`
  filename as a disk image and proxied it to the disk host, where savestates
  don't exist. `*_state.bin` files are now routed to the runtime origin (where
  they live) and cached with revalidation, so they're served correctly through
  the mirror (`https://pcf-mirror.ifuentes.workers.dev/<id>_state.bin` → `206`).

## [0.1.0] - 2026-06-17

First tagged release — gives the Homebrew formula a stable `url` + `sha256`
(`brew install` without `--HEAD`).

### Added
- **Homebrew install** (`Formula/pc-futbol-local.rb`): `brew tap` +
  `brew install --HEAD pc-futbol-local`. Packaged installs store game data in
  `~/.pc-futbol-local` via the new `PCF_PLAY_DIR` override (bash + PowerShell).
- **Public status page** (GitHub Pages, `docs/index.html`): live, client-side
  probes of the community mirror (health, HTTP Range, CORS) — no backend, the
  Worker's CORS lets the browser check the edge directly.
- **`pcf verify`**: checks downloaded files against the manifest (byte size
  always, SHA-256 when recorded), with `--record` to print checksums a
  maintainer can paste into `data/games.json`. Optional `sha256` / `state_sha256`
  fields are now validated by CI. Mirrored on `pcf.ps1`.
- **`pcf doctor --json`**: machine-readable environment/offline-readiness output
  (bash + PowerShell).
- **Mirror pre-warm** (`scripts/prewarm.sh`, `make prewarm`): sends a tiny
  ranged GET for every disk so the edge caches it, avoiding cold-miss 403s for
  the first user in a region.
- **Hardened server & agent**: `serve.py` now survives macOS `ENOBUFS` (retries
  with backoff) and benign client disconnects; the agent maker enforces
  file/byte caps and refuses to edit CI workflows or its own driver; new
  `serve.py` concurrency/disconnect self-tests and agent parser unit tests run
  in CI.
- **Code-agent loop** (loop engineering) under `.github/agent/`: community
  issues are auto-triaged, and behind a maintainer-only `agent:go` label a
  maker/checker pair drafts a **draft PR** for human review. Powered by
  `@cf/moonshotai/kimi-k2.7-code` on Cloudflare Workers AI. New workflows:
  `agent-triage.yml`, `agent-implement.yml`, and `agent-deploy.yml`
  (approval-gated `production` environment). The loop only proposes — humans
  merge and ship.
- **Cloudflare community mirror** under `mirror/cloudflare/`: a Worker that
  reverse-proxies + edge-caches the disk images (adds CORS + HTTP Range), an
  optional **R2** zero-egress mode, and a `sync-to-r2.sh` populate script.
- **Cache-only mirror, kept in sync**: the Worker now serves both the disk
  images (immutable, ~1 year) and the kiosk runtime (short cache +
  revalidation) from the edge, storing nothing permanently. The launchers fetch
  the kiosk through the mirror too (with automatic fallback to the official
  origin), so the origin is hit ~once per region instead of per user.
  `mirror-health.yml` probes the live mirror every 6 h.
- **Origin-friendly downloads**: configurable mirror/CDN (`PCF_MIRROR`,
  `PCF_DISKS_BASE`, `PCF_ORIGIN_BASE`), optional repo-shipped default via
  `data/mirror.json`, bandwidth throttling (`PCF_RATE_LIMIT`), exponential
  retry/backoff and an identifiable User-Agent (`PCF_UA`) — on both `pcf`
  (bash) and `pcf.ps1` (Windows). `pcf doctor` now shows the active disk source,
  rate limit and an **offline-readiness** summary.
- **First-class Linux support**: package-manager-aware install hints
  (`apt`/`dnf`/`pacman`/`zypper`/`apk`/`brew`), broader browser launching
  (`xdg-open`, `gio`, `sensible-browser`, `$BROWSER`) and **WSL** support
  (`wslview` / `powershell.exe`).
- New commands: `pcf menu` (open the game menu), `pcf update` (refresh the
  emulator runtime), and `pcf install-desktop` (Linux app launcher).
- Automatic **free-port** selection so several games can run side by side, plus
  `PCF_NO_OPEN` to skip auto-opening the browser.
- Improved `pcf doctor`: distro detection, browser-launcher check and `.play`
  disk-usage report.
- **Continuous Integration** (GitHub Actions): ShellCheck, Python syntax,
  `games.json` validation, a hermetic HTTP **Range** self-test, and a PowerShell
  parse check on Windows.
- Developer tooling: `Makefile`, `scripts/check-games.py`, `scripts/selftest.sh`,
  `.editorconfig`.
- Community health files: `CONTRIBUTING.md` (EN/ES), `CODE_OF_CONDUCT.md`,
  `SECURITY.md`, issue forms and a pull-request template.
- One-command local launcher for the classic **PC Fútbol** games (and PC Basket
  / PC Calcio) for **macOS, Linux and Windows**, downloading the official free
  disk images on demand and running them in the browser via the **v86**
  emulator, served locally with HTTP Range support. Bilingual documentation
  (English / Español). No game data is bundled.
