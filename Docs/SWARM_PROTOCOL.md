# Dynamic Swarm Protocol

The user may open 2 workers or 20+ workers and simply say `go`. Workers may disappear after completing work. GitHub is therefore the durable scheduler and memory.

## Every worker starts by orienting

Read:
1. Project Source supplied in ChatGPT Project.
2. `Docs/PROJECT_STATE.md`.
3. `Docs/ROADMAP.md`.
4. `Docs/ARCHITECTURE.md`.
5. recent ADRs.
6. open issues and PRs.
7. latest CI state.

Never restart investigations recorded as complete.

## Role selection

Choose in this order:
1. Red main/critical CI -> repair it.
2. Unclaimed critical-path P0 -> implement it.
3. Review/integration backlog -> review rather than create duplicate code.
4. Too few ready tasks for visible worker count -> decompose next roadmap outcome into independent production issues.
5. Overcrowded area -> move to another dependency-compatible area.
6. Shared contract blocking many tasks -> resolve contract/ADR.
7. Otherwise highest-value unclaimed task.

## Claiming

Before edits:
- inspect issues/PRs/branches for duplication,
- comment a claim with intended branch,
- use branch `agent/<area>/<issue>-<slug>-<nonce>`,
- re-check for a race before touching high-contention files.

A worker should claim one major task at a time.

## High-contention files/contracts

Coordinate before editing:
- `default.project.json`,
- `rokit.toml`,
- persistence schemas,
- ID/hash/seed contracts,
- server-authority simulation root,
- shared base rigs,
- world-address/topology contracts.

Architecture changes require an ADR.

## Keep working

A worker SHOULD NOT stop simply because one small issue or PR is complete.

If the session/tool budget allows:
1. validate and publish current work,
2. update issue/PR state,
3. re-read swarm state,
4. claim the next safe compatible task,
5. continue.

Hard stops:
- user/external secret is required,
- independent architecture review is required before dependent implementation,
- no non-conflicting useful work remains,
- tool/session limitations,
- continuing would duplicate another active worker.

Before stopping, push/publish useful work and leave an exact handoff.

## Worker-density guidance

1–3 workers: critical path + necessary review.
4–8: implementation plus dedicated test/CI/review capacity.
9–20+: cap workers per shared subsystem; create leaf tasks in materials, generators, validation, fuzzing, docs, performance, tooling, UI, audio, and integration rather than having ten workers rewrite Core.

## Definition of done

Not just `it compiles`.
- correct architecture,
- tests/validation,
- deterministic repro where procedural,
- metrics where performance-sensitive,
- evidence in PR,
- docs/ADR updated when contracts change,
- no unrelated rewrite,
- CI green.

## Stale work

Before taking over apparently abandoned work, inspect its issue/branch/PR and preserve useful commits. Do not blindly duplicate it.
