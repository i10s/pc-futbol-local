# Changelog

All notable changes to this project are documented here.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added
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
