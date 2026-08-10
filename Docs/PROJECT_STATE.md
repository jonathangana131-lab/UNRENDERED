# Project State

Current phase: **Hero Gate — Production Physics Lab**

## Main health

- Roblox/Rojo production bootstrap is merged.
- The proven CI path covers pinned tool installation, Rojo sourcemap, StyLua, Selene, Roblox Luau analysis, pure deterministic tests, Rojo build, and artifact upload.
- Every worker must inspect the latest `main` Actions status. Red main overrides feature work.

## Quality policy

`Docs/QUALITY_STANDARD.md` is mandatory.

Open issue != unlocked work. This file is the authoritative unlock board.

Project-wide WIP target: **3–5 major Feature Epics maximum**. With many workers, deepen active epics through tests, fuzzing, performance, polish, integration and independent review rather than opening unrelated systems.

## Foundation Lock — Wave 1 complete

### Epic A — Deterministic Reality Foundation
- #3 — StableId / scoped RNG contracts: complete.
- #8 — deterministic regression/repro harness: complete.

Exit evidence:
- golden vectors are stable,
- subsystem streams cannot perturb unrelated streams,
- repro keys are available for later canonical generation failures.

### Epic B — WorldEntity / Fidelity Foundation
- #4 — WorldEntity identity and representation lifecycle: complete.
- #7 — F0–F4 promotion/demotion manager: complete.

Exit evidence:
- identity is domain data rather than Roblox Instance identity,
- duplicate IDs are detectable,
- state capture/promotion/demotion behavior is tested,
- fidelity policy exposes metrics and anti-thrashing behavior.

### Epic C — Physical Content Domain Foundation
- #5 — MaterialDNA production contract: complete.
- #6 — ObjectGenome construction-grammar contract: complete.
- #100 — exact ObjectGenome↔MaterialDNA reference/content-revision lock: complete via #121 + fingerprint-v2 closure #129.
- #101 — mechanism-state/persistence semantics: complete via #117 + finite-span closure #123.
- #119 — mechanism-range numeric closure: complete via #123.
- #125 — cycle-independent deterministic external-support reachability: complete via #136.

Exit evidence:
- immutable recipe vs mutable state separation is explicit,
- MaterialDNA links visual/physical/acoustic identity without asset-ID coupling,
- ObjectGenome covers components, mechanisms, realistic dimensions/materials/mass/affordances,
- exact MaterialDNA identity/revision semantics are preserved and same-version canonical recipe drift is versioned/detectable,
- mechanism state has explicit kind-specific persistence semantics anchored to authored reference poses,
- accepted hinge/tilt/slide arithmetic stays finite through default-state derivation and canonical physical decode,
- support-cycle rejection and external-support reachability are independent deterministic graph facts,
- validators reject the locked invalid examples.

## Resolved Reality Foundation — complete

### #9 — First-observation lock / resolved-region recipe
Complete via #163.

Exit evidence:
- `ResolvedRegionRecipe` is plain/versioned data independent of Workspace serialization,
- stable region identity derives from the required world-seed reference + project-owned `RegionAddress`,
- first meaningful observation locks an immutable generated-base recipe and later malformed/newer generator output cannot rewrite or invalidate established truth,
- generator-version snapshots, canonical topology/content key sets, exact reconstruction equality, repro identity and literal v1 identity/fingerprint goldens are tested,
- stored drift/tampering and representation-shaped fields fail closed,
- migration is explicit and identity-preserving rather than an implicit reinterpretation of historical truth,
- mutable delta storage remains outside the closed base contract so gated persistence work can own bounded retention/replay semantics later.

## Remaining unlocked Hero Gate

Finish this foundation before broadening into planned P1 systems.

### #10 — Production-contract Physics Lab
Build the permanent test/lab shell using the landed WorldEntity, Fidelity, MaterialDNA and ObjectGenome contracts. This is not permission for ad-hoc gameplay scripts or a competing framework.

Required direction:
- deterministic lab recipe and stable IDs,
- production-contract realization boundaries,
- floor/walls/ceiling plus door/chair/table/cart/cabinet/stairs/ramp/ledge test geometry,
- development diagnostics for IDs/fidelity state,
- clear Studio validation/repro instructions,
- keep Roblox Instances as physical representation, never canonical world state.

## Hero Gate exit direction

Before opening broader content, prove that #10 uses the Wave-1 contracts without replacing them or contradicting the landed #9 resolved-truth boundary. Strike-team work should deepen #10 through tests, Studio/physics evidence, diagnostics, performance, integration and Reality-Grade review.

After the lab foundation is stable, the first Reality-Grade Hero Features should be **door, chair, and physical player movement**, not a giant procedural map.

## Currently gated planned work

Issues #11–#25 are planned future work. They are **not automatically implementation-ready** until this file unlocks them or they become an explicit prerequisite for an unlocked Epic.

Workers may inspect/review/decompose them, but should not build those major systems yet merely because worker capacity exists.

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

1. #10 becomes a permanent production-contract Physics Lab rather than a disposable demo,
2. the lab proves Wave-1 identity/material/object/fidelity contracts survive real Roblox realization and interaction,
3. the lab remains compatible with the landed #9 resolved-truth boundary and does not create a parallel world-state model,
4. door/chair/physical-player work begins only on those stable foundations,
5. the first five-minute experience can be improved deeply without replacing its foundations.

Keep this file concise and operational. Git history is the changelog; Project Source is the long-term vision.
