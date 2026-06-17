# Agent loop — state / memory

This file is the **spine of the loop** (loop engineering: the memory lives on
disk, not in the model's context). Each automated run appends what it did so the
next run — and any human — can see what was tried, what passed, and what is open.
The agent forgets between runs; the repo does not.

## How to read this
Newest entries on top. One block per issue the loop acted on.

## Log

<!-- AGENT-LOG:START -->
_(empty — the loop will append entries here as issues come in.)_
<!-- AGENT-LOG:END -->
