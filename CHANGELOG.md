# Changelog

All notable changes to this project are documented here.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added
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

## [0.1.0] — 2026-06-16

### Added
- Initial release: one-command local launcher for the classic **PC Fútbol**
  games (and PC Basket / PC Calcio) for **macOS, Linux and Windows**.
- Downloads the official free disk images on demand and runs them in the browser
  via the **v86** emulator, served locally with HTTP Range support.
- Bilingual documentation (English / Español). No game data is bundled.
