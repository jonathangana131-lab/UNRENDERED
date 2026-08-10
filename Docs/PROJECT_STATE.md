# Project State

Current phase: **Hero Gate — Production Physics Lab / Perfect 5 Minutes foundation**

## Main health

- Roblox/Rojo production bootstrap is merged.
- The proven CI path covers pinned tool installation, Rojo sourcemap, StyLua, Selene, Roblox Luau analysis, pure deterministic tests, Rojo build, and artifact upload.
- Every worker must inspect the latest `main` Actions status. Red main overrides feature work.

## Quality policy

`Docs/QUALITY_STANDARD.md` is mandatory.

Open issue != unlocked work. This file is the authoritative unlock board.

Project-wide WIP target: **3–5 major Feature Epics maximum**. With many workers, deepen active epics through tests, fuzzing, performance, polish, integration and independent review rather than opening unrelated systems.

## Foundation Lock — Reality-Grade Wave 1 complete

### Epic A — Deterministic Reality Foundation
- #3 — StableId / scoped RNG contracts — **complete**.
- #8 — deterministic regression/repro harness — **complete**.

Exit gate satisfied: golden vectors are locked, subsystem streams are isolated, and later procedural failures can carry explicit repro keys.

### Epic B — WorldEntity / Fidelity Foundation
- #4 — WorldEntity identity and representation lifecycle — **complete**.
- #7 — F0–F4 promotion/demotion manager — **complete**.

Exit gate satisfied: identity is independent of Roblox Instance lifetime, duplicate IDs are detectable, lifecycle/state handoff is tested, and fidelity policy exposes hysteresis/metrics.

### Epic C — Physical Content Domain Foundation
- #5 — MaterialDNA production contract — **complete**.
- #6 — ObjectGenome construction-grammar contract — **complete**.
- #100 — ObjectGenome↔MaterialDNA exact-reference/content-revision repair — **complete via #129**, including explicit recipe-fingerprint v2 for the canonical numeric encoder.
- #101 — ObjectGenome mechanism-state/persistence semantics repair — **complete via #117**, with finite-span closure in #123.
- #119 — mechanism-range numeric-closure repair — **complete via #123**.
- #125 — cycle-independent deterministic external-support reachability — **complete via #137**.

Exit gate satisfied: immutable recipes and mutable state are separated; MaterialDNA links visual/physical/acoustic identity without asset-ID coupling; ObjectGenome covers manufacturable components, mechanisms, dimensions, materials, mass and affordances; exact MaterialDNA references and same-version recipe drift are validated; mechanism persistence and finite numeric decode are locked; support-cycle rejection and support reachability are independent deterministic facts; invalid examples are covered by validators/tests.

## Unlocked Hero Gate

Only the following major work is implementation-ready now.

### Epic D — Production Physics Lab
- #10 — create the production-contract Physics Lab shell.

Rules:
- use the Wave 1 StableId, WorldEntity, fidelity, MaterialDNA and ObjectGenome contracts directly;
- simple Roblox primitives are acceptable for the first shell, but no ad-hoc competing gameplay/object framework is allowed;
- the lab recipe must be deterministic and expose development diagnostics for world/entity IDs and fidelity state;
- add clear Studio repro/test instructions and preserve pure-CI coverage where applicable.

Exit gate:
- deterministic lab reconstruction,
- production-contract instantiation for the test objects,
- usable diagnostics and Studio test path,
- no disposable shared place-file architecture,
- strongest available CI plus Studio evidence for engine-specific behavior when that workflow is available.

### Epic E — First Observation / Resolved Region
- #9 — implement first-observation lock and `ResolvedRegionRecipe`.

Rules:
- conceptual/resolved/physical layers remain separate;
- recipes are plain versioned data: generated base + meaningful mutable deltas, never serialized Workspace;
- first meaningful observation locks canonical recipe/version rather than silently adopting future generator changes;
- canonical generation continues to use scoped deterministic streams only.

Exit gate:
- a region recipe can be created, serialized as plain data, reconstructed and compared deterministically,
- locked recipes do not silently mutate across generator-version changes,
- an explicit migration hook exists,
- no Roblox Instance serialization enters the domain contract.

## Next unlock — not current permission

After #10 and #9 reach their applicable Reality-Grade exit gates and receive independent review, deliberately update this board again before starting the first Hero Feature wave.

The intended first Hero Features remain **Reality-Grade door, chair, and physical player movement/body**. Do not compensate with a giant procedural map, monster roster, or unrelated breadth.

## Currently gated planned work

Issues #11–#25 remain planned future work unless this file explicitly unlocks one of them or it becomes a demonstrated prerequisite that directly blocks #10/#9.

Workers may inspect/review/decompose gated issues, but should not build those major systems merely because worker capacity exists.

## Known external setup gaps

- No published Roblox universe/place is connected to automated publishing yet.
- Studio engine tests, graphics validation, server-authority tests, and device profiling require a Roblox Studio/test-place workflow; current GitHub CI covers source/pure deterministic logic/Rojo builds.
- Approved production PBR, audio and model libraries do not exist yet. Use project-owned fallbacks and do not add unlicensed content.

## Architecture migrations

None active.

## Generation/schema versions

- reality: 1
- topology: 1
- material: 1
- object: 1
- entity: 1
- persistence: 1

## Next critical outcomes

1. build the deterministic production-contract Physics Lab through #10 without introducing a temporary framework,
2. land #9 first-observation/resolved-region truth using plain versioned data and the locked deterministic contracts,
3. validate the lab with the strongest available CI/Studio evidence and make failures reproducible,
4. only then deliberately unlock and deepen the first Reality-Grade door/chair/physical-player wave,
5. keep the first five-minute experience small enough that physics, materials, audio, UX and interaction can be finished rather than merely demonstrated.

Keep this file concise and operational. Git history is the changelog; Project Source is the long-term vision.
