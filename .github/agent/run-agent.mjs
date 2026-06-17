#!/usr/bin/env node
/**
 * PC Fútbol Local — loop-engineering code agent driver
 * --------------------------------------------------------------------------
 * Thin, auditable wrapper around Cloudflare Workers AI. It powers the three
 * sub-agents of the loop (maker / checker split, per loop-engineering):
 *
 *   triage    — read a community issue, classify it, propose a plan (JSON).
 *   implement — draft the change as full-file blocks the workflow applies.
 *   review    — grade a diff against the project rules (JSON verdict).
 *
 * The model is intentionally configurable; it defaults to the one requested:
 *   @cf/moonshotai/kimi-k2.7-code
 *
 * Security: this script NEVER executes model output. It only writes files the
 * model returns (implement) or emits JSON (triage/review). All side effects
 * (running tests, opening PRs, deploying) happen in the workflow with scoped
 * permissions and human gates — see .github/agent/README.md.
 *
 * Usage:
 *   node run-agent.mjs triage     > triage.json
 *   node run-agent.mjs implement            # writes files into the worktree
 *   node run-agent.mjs review     > review.json
 *
 * Env:
 *   CF_ACCOUNT_ID, CF_AI_TOKEN      Cloudflare Workers AI credentials (required)
 *   AGENT_MODEL                     override the model id
 *   ISSUE_TITLE, ISSUE_BODY, ISSUE_NUMBER
 *   DIFF                            unified diff (review mode)
 *   MAX_TOKENS                      cap the response (default 4096)
 */
import { readFileSync, writeFileSync, existsSync, statSync } from "node:fs";
import { execSync } from "node:child_process";
import { join, dirname } from "node:path";
import { mkdirSync } from "node:fs";
import { pathToFileURL } from "node:url";

const ROOT = execSync("git rev-parse --show-toplevel").toString().trim();
const MODEL = process.env.AGENT_MODEL || "@cf/moonshotai/kimi-k2.7-code";
const MAX_TOKENS = Number(process.env.MAX_TOKENS || 4096);

function die(msg) {
  console.error(`agent: ${msg}`);
  process.exit(1);
}

function readPrompt(name) {
  return readFileSync(join(ROOT, ".github/agent/prompts", `${name}.md`), "utf8");
}

function skill() {
  const p = join(ROOT, ".github/agent/SKILL.md");
  return existsSync(p) ? readFileSync(p, "utf8") : "";
}

/* Collect a bounded snapshot of the tracked source tree for context. We skip
 * binaries, downloaded data and anything large so the prompt stays cheap. */
function repoContext({ perFile = 16000, total = 120000 } = {}) {
  const files = execSync("git ls-files", { cwd: ROOT })
    .toString()
    .split("\n")
    .filter(Boolean)
    .filter((f) => !f.startsWith(".play/"))
    .filter((f) => !/\.(png|jpg|jpeg|gif|svg|ico|wasm|bin|woff2?|ttf|map|json)$/i.test(f) || f.endsWith("games.json") || f.endsWith("mirror.json"))
    .filter((f) => f !== "data/games.json"); // huge manifest; summarised separately

  let budget = total;
  const parts = [];
  for (const f of files) {
    const abs = join(ROOT, f);
    let sz = 0;
    try { sz = statSync(abs).size; } catch { continue; }
    if (sz > perFile) { parts.push(`=== FILE: ${f} (${sz} bytes, truncated) ===\n[omitted for size]`); continue; }
    if (budget <= 0) { parts.push(`=== FILE: ${f} ===\n[omitted: context budget reached]`); continue; }
    const body = readFileSync(abs, "utf8");
    budget -= body.length;
    parts.push(`=== FILE: ${f} ===\n${body}`);
  }
  return parts.join("\n\n");
}

async function callModel(system, user) {
  const acct = process.env.CF_ACCOUNT_ID;
  const token = process.env.CF_AI_TOKEN;
  if (!acct || !token) die("CF_ACCOUNT_ID and CF_AI_TOKEN are required.");

  const url = `https://api.cloudflare.com/client/v4/accounts/${acct}/ai/run/${MODEL}`;
  const res = await fetch(url, {
    method: "POST",
    headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
    body: JSON.stringify({
      max_tokens: MAX_TOKENS,
      messages: [
        { role: "system", content: system },
        { role: "user", content: user },
      ],
    }),
  });
  if (!res.ok) die(`Workers AI HTTP ${res.status}: ${await res.text()}`);
  const data = await res.json();
  if (data.success === false) die(`Workers AI error: ${JSON.stringify(data.errors)}`);
  const out =
    data?.result?.response ??
    data?.result?.choices?.[0]?.message?.content ??
    data?.result?.output_text ??
    "";
  if (!out) die(`Empty model response: ${JSON.stringify(data).slice(0, 400)}`);
  return out.trim();
}

/* Extract the first fenced JSON object the model emitted. */
export function extractJson(text) {
  const fenced = text.match(/```(?:json)?\s*([\s\S]*?)```/i);
  const raw = fenced ? fenced[1] : text;
  const start = raw.indexOf("{");
  const end = raw.lastIndexOf("}");
  if (start === -1 || end === -1) throw new Error(`No JSON object in model output:\n${text}`);
  return JSON.parse(raw.slice(start, end + 1));
}

const MAX_FILES = Number(process.env.MAX_FILES || 20);
const MAX_WRITE_BYTES = Number(process.env.MAX_WRITE_BYTES || 256 * 1024);

/* A maker draft must never touch local data, secrets, CI workflows or the
 * agent's own driver — those are the guardrails it runs behind. */
function disallowedPath(rel) {
  return (
    rel.includes("..") ||
    rel.startsWith("/") ||
    rel.startsWith(".play/") ||
    rel.startsWith(".git/") ||
    rel.startsWith(".github/workflows/") ||
    rel === ".github/agent/run-agent.mjs" ||
    /(^|\/)\.env/i.test(rel) ||
    rel.includes("\\")
  );
}

/* Parse `=== FILE: path ===\n...\n=== END FILE ===` blocks into {rel, body}.
 * Pure + bounded: rejects disallowed paths and oversized changes. */
export function parseFileBlocks(text, { maxFiles = MAX_FILES, maxBytes = MAX_WRITE_BYTES } = {}) {
  const re = /===\s*FILE:\s*(.+?)\s*===\r?\n([\s\S]*?)\r?\n===\s*END FILE\s*===/g;
  const blocks = [];
  let m;
  let totalBytes = 0;
  while ((m = re.exec(text)) !== null) {
    const rel = m[1].trim();
    if (disallowedPath(rel)) throw new Error(`Refusing to write disallowed path: ${rel}`);
    const body = m[2].endsWith("\n") ? m[2] : m[2] + "\n";
    totalBytes += Buffer.byteLength(body, "utf8");
    blocks.push({ rel, body });
  }
  if (blocks.length === 0) throw new Error("Model returned no FILE blocks.");
  if (blocks.length > maxFiles) throw new Error(`Too many files in one change: ${blocks.length} > ${maxFiles}.`);
  if (totalBytes > maxBytes) throw new Error(`Change too large: ${totalBytes} > ${maxBytes} bytes.`);
  return blocks;
}

/* Apply parsed FILE blocks to the worktree. */
export function applyFileBlocks(text, opts) {
  const blocks = parseFileBlocks(text, opts);
  for (const { rel, body } of blocks) {
    const abs = join(ROOT, rel);
    mkdirSync(dirname(abs), { recursive: true });
    writeFileSync(abs, body);
  }
  return blocks.map((b) => b.rel);
}

async function main() {
  const mode = process.argv[2];
  const issue = {
    number: process.env.ISSUE_NUMBER || "?",
    title: process.env.ISSUE_TITLE || "",
    body: process.env.ISSUE_BODY || "",
  };

  if (mode === "triage") {
    const sys = skill() + "\n\n" + readPrompt("triage");
    const user = `Issue #${issue.number}\nTitle: ${issue.title}\n\nBody:\n${issue.body}`;
    const out = await callModel(sys, user);
    process.stdout.write(JSON.stringify(extractJson(out), null, 2));
  } else if (mode === "implement") {
    const sys = skill() + "\n\n" + readPrompt("implement");
    const user =
      `Issue #${issue.number}\nTitle: ${issue.title}\n\nBody:\n${issue.body}\n\n` +
      `--- CURRENT REPOSITORY (tracked source) ---\n${repoContext()}`;
    const out = await callModel(sys, user);
    const files = applyFileBlocks(out);
    writeFileSync(join(ROOT, ".github/agent/last-implement.txt"), files.join("\n") + "\n");
    console.error(`agent: wrote ${files.length} file(s):\n  ${files.join("\n  ")}`);
  } else if (mode === "review") {
    const sys = skill() + "\n\n" + readPrompt("review");
    const diff = process.env.DIFF || readFileSync(0, "utf8");
    const user = `Issue #${issue.number}: ${issue.title}\n\n--- DIFF UNDER REVIEW ---\n${diff}`;
    const out = await callModel(sys, user);
    process.stdout.write(JSON.stringify(extractJson(out), null, 2));
  } else {
    die("usage: run-agent.mjs <triage|implement|review>");
  }
}

// Only run the CLI when executed directly (so tests can import the parsers).
if (import.meta.url === pathToFileURL(process.argv[1] || "").href) {
  main().catch((e) => die(e.message));
}
