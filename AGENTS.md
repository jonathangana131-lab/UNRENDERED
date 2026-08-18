# UNRENDERED autonomous development contract

This root `AGENTS.md` is the execution authority for Codex, ordinary ChatGPT sessions using the GitHub connector, and other coding agents working in UNRENDERED.

The old Dynamic Swarm / Foundry / `swarm-control` scheduler, worker IDs, claim leases, fencing tokens, admission rules, capacity mining, synthetic role allocation, and recovery-branch machinery are retired for normal development. Historical swarm documents and branches may contain useful evidence, but they do not decide whether an agent may do ordinary repository work.

## Product goal

UNRENDERED is a Roblox-first persistent procedural physics-horror universe where observation resolves an effectively infinite shared reality. Development should move toward a deeply finished, shippable experience rather than maximizing branch count, issue count, world size, or simultaneous workers.

Preserve the core direction in `Docs/GAME_VISION.md`, `Docs/ARCHITECTURE.md`, `Docs/ROADMAP.md`, `Docs/QUALITY_STANDARD.md`, and current product truth in `Docs/PROJECT_STATE.md`.

When the owner says `Go`, `continue`, `keep going`, `work on UNRENDERED`, `finish UNRENDERED`, or equivalent, begin real repository work immediately and continue through as many useful checkpoints as the current execution window permits:

`refresh live GitHub -> choose/finish highest-value real outcome -> implement -> test/review -> merge -> verify main -> refresh -> continue`

Do not stop after one plan, commit, PR, review, test, or merge when useful work remains. Do not ask the owner to choose work when current GitHub truth and product docs can determine the next action.

## Source of truth

Use, in this order:

1. current `main` code and tests;
2. current open PRs, checks, reviews, recent commits, and exact runtime/Studio evidence;
3. current product/architecture/quality docs;
4. issues that still reproduce on current code.

Chat memory is context, not authority when GitHub has newer truth. Historical swarm boards, claims, continuation packets, worker labels, and control-plane state are not ownership authority.

## Startup loop

Before writing:

1. Refresh `main`, CI, open PRs, review pressure, recent merges, and release/quality-critical issues.
2. Read this file plus the relevant product/architecture/quality docs for the subsystem.
3. Prefer finishing, fixing, reviewing, or integrating a strong overlapping PR over opening a competing implementation.
4. If no near-merge work should be finished first, choose the smallest high-value outcome that advances the current product direction without violating a real dependency or truth boundary.
5. Read the affected code before changing it.
6. Implement, run risk-proportionate checks, review the exact diff/evidence, and merge when accepted and permissions allow.
7. Verify post-merge `main`, refresh GitHub, and continue while useful work remains.

A checkpoint is not an automatic stopping point.

## Lightweight concurrency

There is **no fixed agent count** and no capacity target.

- Default to one implementation for an overlapping subsystem/root cause.
- Add another writer only for a genuinely independent outcome with separable files, authority, and integration path.
- Reviewers/testers/Studio-evidence workers may work against live candidates without opening competing implementations.
- When CI, review, merge conflicts, or integration backlog grows, reduce new writing and converge existing candidates first.
- When independent work is plentiful and current candidates integrate cleanly, additional agents may work in parallel.
- Optimize for accepted product outcomes landing on `main`, not simultaneous-agent count.
- Prefer a few short-lived PRs directly against `main` over PR-on-PR recovery chains.
- Never create placeholder branches/PRs, fake tasks, or issue-mining work merely to occupy agents.
- If an existing branch contains useful work, preserve and improve/integrate it rather than starting over without cause.

GitHub branches, PRs, reviews, checks, and exact-head evidence are the collision/handoff mechanism. No custom distributed scheduler is required.

## Implementation loop

For selected work:

1. Inspect current implementation, tests, and relevant accepted evidence.
2. Make the narrowest coherent change that fixes the real defect or advances the intended product outcome.
3. Add or update deterministic regression coverage when behavior changes.
4. Run the relevant source checks, Luau tests, build, Studio/runtime validation, or profiling that the risk of the change requires.
5. Review the exact diff and evidence. Never weaken a gate merely to make it green.
6. Open/update one direct-to-`main` PR with factual scope, tests actually run, evidence, and limitations.
7. Resolve real review findings on the same branch when practical.
8. When checks/review/evidence are sufficient and the change is safe, merge it instead of leaving accepted work parked.
9. Refresh and verify `main`, then continue.

If a test exposes a product bug, fix the bug rather than diluting the test. Close obsolete or superseded PRs cleanly instead of stacking another recovery layer.

## Risk-based quality gates

`Docs/QUALITY_STANDARD.md` remains authoritative for product quality. Retiring swarm bureaucracy lowers coordination overhead, not the Reality-Grade bar.

Ordinary PRs need checks proportionate to what they change; not every change requires the whole final acceptance matrix.

Examples:

- docs/governance: exact diff and reference review; doc/schema checks if affected;
- deterministic domain logic: focused tests plus StyLua/Selene/Luau analysis/build as applicable;
- physics/authority/persistence: focused regression tests plus the strongest applicable Studio/server evidence;
- rendering/material/audio/UI: structural checks plus actual Roblox Studio/device captures when visual or experiential truth matters;
- networking/multiplayer: server-authority and multi-client evidence where the claim depends on it;
- major milestones/Reality-Grade Hero Features: the full applicable quality surface from `Docs/QUALITY_STANDARD.md`.

CI green is necessary where applicable, never sufficient proof of visual, physical, multiplayer, performance, or player-experience truth.

## Roblox / Studio truth boundary

Never invent Roblox Studio, engine, device, multiplayer, performance, visual, audio, or physics observations.

- Source tests are not Studio physics proof.
- A single-server run is not two-client authority proof.
- A generated place file is not a visual PASS.
- A screenshot is not accepted visual evidence until actually inspected.
- A failed/no-capture bridge run is not gameplay validation.
- Simulator or mocked evidence does not become real engine/device truth.
- Preserve exact source SHA, engine/environment identity, request provenance, and evaluator result when those matter.

If a specific Studio GUI/display/device path is externally blocked, that blocks only claims that require that unavailable evidence. Continue with independent source correctness, tests, deterministic contracts, tooling, profiling that can be measured truthfully, review/integration, and other roadmap work whose acceptance does not depend on the unavailable observation. Do not manufacture PASS evidence and do not let one unavailable runner freeze the whole repository.

## Product invariants worth preserving

Keep the architecture/quality direction intact, especially:

- stable world/entity IDs independent of Roblox Instances;
- deterministic, versioned procedural contracts and reproducible RNG/repro keys;
- generated base plus persistent deltas rather than Workspace as the universe database;
- conceptual, resolved, and physical world separation;
- F0–F4 representation/simulation fidelity with identity surviving representation changes;
- server-authoritative critical gameplay with prediction only where appropriate;
- deterministic procedural grammars plus rejection/validation instead of uncontrolled randomness;
- Reality-Grade depth before content breadth;
- normality before anomaly;
- permanent production labs and experience scenarios for Hero Features;
- bounded caches/queues and measured performance architecture;
- licensed/project-owned content only;
- no fake physics, screenshot-only hacks, hidden teleports, arbitrary scaling, or test-only product behavior used to conceal real defects.

## Roadmap and blocked work

`Docs/ROADMAP.md` and `Docs/PROJECT_STATE.md` describe dependencies and current product maturity. Treat genuine architectural dependencies and evidence requirements as real, but do not reinterpret old scheduler-specific phrases such as "claim", "ready slot", "Foundry admission", "worker resource", or `swarm-control` ownership as execution authority.

A blocked Hero-Gate observation may keep that exact acceptance row unverified without forbidding all unrelated safe progress. Prefer deepening current foundations and directly enabling the next coherent experience over jumping randomly to distant roadmap breadth.

## Issue discipline

Do not mass-mine issues as autonomous busywork. Fix small adjacent defects while already in the area when safe and coherent.

Create a separate issue when a problem genuinely needs independent scheduling, broader architecture work, unavailable external/Studio evidence, or would make the current PR unsafe/unfocused. Search for the same root cause before filing.

Issue count is not progress.

## Preferred toolchain

Pinned through Rokit:

- Rojo 7.6.1
- StyLua 2.5.2
- Selene 0.31.0
- luau-lsp 1.69.0
- Lune 0.10.5
- Wally 0.3.2

Typical source validation:

```bash
rokit install
rojo sourcemap default.project.json --output sourcemap.json
curl --proto '=https' --tlsv1.2 -sSf \
  https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/1.69.0/scripts/globalTypes.d.luau \
  -o globalTypes.d.luau
stylua --check src tests
selene src tests
luau-lsp analyze --platform=roblox --definitions:@roblox=globalTypes.d.luau --sourcemap=sourcemap.json src
lune run tests/run
mkdir -p build
rojo build default.project.json --output build/UNRENDERED.rbxlx
```

Run the subset appropriate to the change, and use the broader matrix when risk warrants it.

## Codex behavior

Codex should treat this root `AGENTS.md` as the repository instruction. For a broad prompt such as `work on UNRENDERED and keep making the best progress you can`, inspect live GitHub, choose the strongest current outcome, edit/test/commit real code, merge accepted work when possible, refresh, and continue rather than returning only a roadmap.

If several Codex tasks are launched, use them for clearly independent work or review/testing/evidence on the same candidate; do not race them to implement the same subsystem.

## Ordinary ChatGPT / GitHub-connector behavior

A ChatGPT coding session should follow the same loop with the connected GitHub repository. If it can safely edit, review, merge, or update existing work, it should do so. If its environment cannot perform a required Roblox Studio/device action, use GitHub-visible evidence and make another useful non-conflicting contribution rather than reverting to swarm bookkeeping.

## Stopping and handoff

There is no scheduler-owned `STOP`. Continue while useful safe work remains in the current execution window. Stop only when tooling/session limits end the run or every meaningful next step truly requires unavailable external/owner/Studio/device input.

Before an unavoidable stop, leave durable GitHub state when useful: exact branch/commit/PR, tests actually run, remaining blocker, and the next concrete action. Never imply work continues in the background after the current execution ends.

## Historical coordination artifacts

`Docs/SWARM_PROTOCOL.md`, `Docs/SWARM_FOUNDRY_V17.md`, `Docs/SWARM_CONTROL_PLANE.md`, `swarm-control`, old worker claims/events, and historical swarm workflows are retained only as history/evidence where useful. They are not normal scheduling or ownership authority after this contract reaches `main`.

Operating principle:

**inspect live truth -> finish the highest-value real outcome -> test it -> merge it -> refresh -> continue**
