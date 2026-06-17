# Code-agent loop / Bucle de agente de código

A small **loop-engineering** system ([Addy Osmani](https://addyosmani.com/blog/loop-engineering/)):
you design the loop once, and it triages community issues, drafts fixes, reviews
them adversarially, and proposes deploys — while a human stays the engineer.

> **You stay in control.** The loop only ever opens **draft** PRs and **proposes**
> deploys. Nothing merges or ships without a maintainer. El bucle solo abre PRs
> en borrador y propone despliegues; nada se fusiona ni publica sin un humano.

## The five pieces (mapped to this repo)

| Loop piece | Here |
|------------|------|
| **Automation / heartbeat** | `agent-triage.yml` runs on every opened issue |
| **Sub-agents (maker/checker)** | `prompts/implement.md` writes, `prompts/review.md` grades — separate calls |
| **Skill (project knowledge)** | `SKILL.md` — conventions, rules, the validation suite |
| **Connectors** | the GitHub CLI (`gh`) + Cloudflare Workers AI REST API |
| **State / memory** | `state.md` — appended every run, lives on disk not in context |
| **Verification** | the existing `ci.yml` validates every draft PR; humans review |

## The loop

```
issue opened ──▶ triage (classify, label, reply)
                    │  maintainer adds  agent:go
                    ▼
              implement (maker)  ──▶  review (checker)  ──▶  draft PR
                    │                                            │
                    └────────── state.md updated ◀───────────────┘
                                                                 ▼
                                          CI validates ▶ human merges ▶ deploy (gated)
```

The model is **`@cf/moonshotai/kimi-k2.7-code`** on Cloudflare Workers AI
(override with the `AGENT_MODEL` repo variable).

## One-time setup

1. **Secrets** (Settings → Secrets and variables → Actions):
   - `CF_ACCOUNT_ID` — your Cloudflare account id.
   - `CF_AI_TOKEN` — a Workers AI token (scope: *Workers AI → Read*).
   - `CLOUDFLARE_API_TOKEN` — a token that can deploy the Worker (deploy only).
2. **Variable** (optional): `AGENT_MODEL` to pin/override the model id.
3. **Labels** — create these (used as the loop's gates and inbox):
   ```bash
   gh label create agent:candidate  -c '#0e8a16' -d 'Triage thinks the agent can do this'
   gh label create agent:go         -c '#5319e7' -d 'Maintainer: let the agent draft a PR'
   gh label create agent:reviewed   -c '#1d76db' -d 'Checker approved; needs human merge'
   gh label create agent:needs-human -c '#d93f0b' -d 'Checker flagged issues; read before merge'
   ```
4. **Deploy gate** — Settings → Environments → `production` → add yourself as a
   **required reviewer**. `agent-deploy.yml` will then wait for your approval.

## Day-to-day

- A community issue comes in → it gets auto-triaged, labelled, and answered.
- If it looks safe and small, triage adds `agent:candidate`.
- You glance at it; if you agree, add **`agent:go`**.
- The agent drafts a branch + **draft PR**, with the checker's verdict in the
  body. CI runs the full validation suite.
- You read the diff (always), merge if happy. The deploy job then asks for your
  approval before touching Cloudflare.

## Guardrails (why this is safe)

- Triage only comments/labels — it never writes code.
- Implementation is gated by a **maintainer-only label** (`agent:go`).
- The agent **cannot** write outside the repo, to `.play/`, to secrets, or
  re-host game data (enforced in `run-agent.mjs`).
- PRs are **draft**; CI must pass; a human merges. Deploy needs environment
  approval. The maker never grades its own work — a separate checker does.
- Mind token costs: triage is cheap; `implement`/`review` cost more, so they run
  only behind the `agent:go` gate.
