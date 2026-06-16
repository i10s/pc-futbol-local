# Security Policy

## Scope

This project is a set of **scripts** that download freely-distributed games from
the official servers and run them locally in your browser via the
[v86](https://github.com/copy/v86) emulator. It runs:

- a **local-only** web server bound to `127.0.0.1` (never exposed to the network),
- inside your browser's sandbox (the emulated machine cannot touch your real OS).

## What to report

Please report anything that could harm a user running these scripts, e.g.:

- a way for the local server to serve files outside its document root,
- a command-injection or arbitrary-code-execution path in the launchers,
- a supply-chain risk in how files are downloaded or verified.

## How to report

- Preferred: open a **private** [GitHub Security Advisory](https://github.com/i10s/pc-futbol-local/security/advisories/new).
- Alternatively: open a regular issue **without** sensitive exploit details and
  ask a maintainer to make contact.

Please do **not** open a public issue with a working exploit before it is fixed.

## Supported versions

The latest commit on the default branch is the only supported version.

## Not in scope

- The games themselves, the v86 emulator, and the official download servers are
  third-party. Report issues about those to their respective owners.
