#!/usr/bin/env node
/**
 * Unit tests for the agent's pure parsers (no network, no model calls).
 * Run with: node .github/agent/run-agent.test.mjs
 */
import assert from "node:assert/strict";
import { extractJson, parseFileBlocks } from "./run-agent.mjs";

let passed = 0;
function test(name, fn) {
  fn();
  passed++;
  console.log(`  ok  ${name}`);
}

// --- extractJson -----------------------------------------------------------
test("extractJson: fenced ```json block", () => {
  const j = extractJson('noise\n```json\n{"a":1,"b":"x"}\n```\ntail');
  assert.deepEqual(j, { a: 1, b: "x" });
});

test("extractJson: bare object", () => {
  assert.deepEqual(extractJson('prefix {"ok":true} suffix'), { ok: true });
});

test("extractJson: throws when no object", () => {
  assert.throws(() => extractJson("no json here"));
});

// --- parseFileBlocks -------------------------------------------------------
test("parseFileBlocks: parses one block and appends newline", () => {
  const b = parseFileBlocks("=== FILE: docs/x.md ===\nhello\n=== END FILE ===");
  assert.equal(b.length, 1);
  assert.equal(b[0].rel, "docs/x.md");
  assert.equal(b[0].body, "hello\n");
});

test("parseFileBlocks: parses multiple blocks", () => {
  const txt =
    "=== FILE: a.txt ===\nA\n=== END FILE ===\n" +
    "=== FILE: sub/b.txt ===\nB\n=== END FILE ===";
  const b = parseFileBlocks(txt);
  assert.deepEqual(b.map((x) => x.rel), ["a.txt", "sub/b.txt"]);
});

test("parseFileBlocks: rejects path traversal", () => {
  assert.throws(() => parseFileBlocks("=== FILE: ../evil ===\nx\n=== END FILE ==="));
});

test("parseFileBlocks: rejects absolute paths", () => {
  assert.throws(() => parseFileBlocks("=== FILE: /etc/passwd ===\nx\n=== END FILE ==="));
});

test("parseFileBlocks: rejects .play and .git and workflows and self", () => {
  for (const p of [".play/x", ".git/config", ".github/workflows/ci.yml", ".github/agent/run-agent.mjs", "a/.env"]) {
    assert.throws(() => parseFileBlocks(`=== FILE: ${p} ===\nx\n=== END FILE ===`), new RegExp("disallowed"));
  }
});

test("parseFileBlocks: throws when no blocks", () => {
  assert.throws(() => parseFileBlocks("nothing here"));
});

test("parseFileBlocks: enforces maxFiles", () => {
  const txt = "=== FILE: a ===\nx\n=== END FILE ===\n=== FILE: b ===\ny\n=== END FILE ===";
  assert.throws(() => parseFileBlocks(txt, { maxFiles: 1 }), /Too many files/);
});

test("parseFileBlocks: enforces maxBytes", () => {
  const txt = "=== FILE: big.txt ===\n" + "x".repeat(100) + "\n=== END FILE ===";
  assert.throws(() => parseFileBlocks(txt, { maxBytes: 10 }), /too large/i);
});

console.log(`\nagent parser tests: ${passed} passed`);
