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

## Hero Gate foundations

### #9 — First-observation lock / resolved-region recipe: complete via #163 + #169 + #190
The production boundary now preserves first-observation truth without conflating conceptual world identity with generation provenance.

Landed direction:
- deterministic potential -> canonical observed truth stays independent of Workspace serialization,
- first meaningful observation locks plain/versioned immutable generated-base truth,
- current schema/fingerprint v2 requires explicit project `WorldId`,
- stable v2 regional identity is `WorldId + canonical RegionAddress`,
- `worldSeedRef` remains separate generation provenance and exact recipe content,
- reconstruction equality/repro and literal v2 identity/fingerprint goldens are testable,
- historical schema-v1 seed-derived truth remains executable behind a replay-only compatibility boundary with its literal #169 vector,
- canonical v2 never infers WorldId from a v1 seed reference,
- later generator output cannot silently rewrite established truth,
- generator-version migration is explicit and preserves v2 WorldId/seed/address identity,
- mutable deltas/runtime representation remain outside the immutable generated base.

Do not reopen competing #9 frameworks. Future incompatible identity/fingerprint changes require an explicit ADR/version/compatibility path and preservation of accepted historical truth.

## Unlocked Hero Gate

Finish this foundation before broadening into planned P1 systems.

### #10 — Production-contract Physics Lab
Build and deepen the permanent test/lab shell using the landed WorldEntity, Fidelity, MaterialDNA, ObjectGenome, and corrected resolved-region contracts. This is not permission for ad-hoc gameplay scripts or a competing framework.

Required direction:
- deterministic lab recipe and stable IDs,
- production-contract realization boundaries,
- floor/walls/ceiling plus door/chair/table/cart/cabinet/stairs/ramp/ledge test geometry,
- development diagnostics for IDs/fidelity state,
- clear Studio validation/repro instructions,
- keep Roblox Instances as physical representation, never canonical world state,
- consume schema-v2 `ResolvedRegionRecipe` for permanent lab region identity rather than minting a competing formula,
- keep F2/F3/F4 claims honest and require actual Studio/engine evidence for physical behavior that pure CI cannot prove.

## Hero Gate exit direction

Before opening broader content, prove that #10 uses the Wave-1 and landed #9 contracts without replacing them. Strike-team work should deepen #10 through tests, Studio/physics evidence, diagnostics, performance, integration and Reality-Grade review.

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

Compatibility note: historical `ResolvedRegionRecipe` schema v1 remains replay-only; schema v2 is the canonical write/lock contract. Never infer WorldId from a seed reference.

## Generation/schema versions

- reality: 1
- topology: 1
- material: 1
- object: 1
- entity: 1
- persistence: 1

## Next critical outcomes

1. #10 becomes a permanent production-contract Physics Lab rather than a disposable demo,
2. the lab consumes schema-v2 resolved-region identity and the landed WorldEntity/Fidelity/MaterialDNA/ObjectGenome contracts without competing replacements,
3. the lab proves source-level lifecycle/repro/ownership contracts in CI and gathers real Studio physics/contact/constraint evidence separately,
4. door/chair/physical-player work begins only on those stable foundations,
5. the first five-minute experience can be improved deeply without replacing its foundations.

Keep this file concise and operational. Git history is the changelog; Project Source is the long-term vision.
