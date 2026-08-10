# Project State

Current phase: **Hero Gate — Production Physics Lab depth / Resolved Reality Foundation**

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

### #9 — First-observation lock / resolved-region recipe: complete via #163
The plain/versioned `ResolvedRegionRecipe` boundary is landed and post-merge `main` CI is green.

Landed direction:
- deterministic potential -> canonical observed truth stays independent of Workspace serialization,
- first meaningful observation locks recipe/version truth,
- reconstruction equality/repro and v1 identity/fingerprint goldens are testable,
- later generator output cannot silently rewrite established observed truth,
- generator-version migration is explicit rather than automatic,
- mutable deltas/runtime representation remain outside the immutable generated base.

Do not open competing #9 implementations. Any future contract change must be a narrowly justified repair/migration with compatibility evidence.

### #10 — Production-contract Physics Lab: active depth lane
The initial deterministic F2 anchored-proxy shell landed via #165. It is a production-contract foothold, not Hero-Gate completion.

Landed shell evidence:
- plain deterministic lab recipe and stable project IDs,
- Wave-1 WorldEntity/Fidelity/MaterialDNA/ObjectGenome contracts are consumed,
- required room/object fixture coverage exists as disposable Roblox representation,
- development diagnostics and Studio repro instructions exist,
- ordinary CI is green,
- `Docs/PHYSICS_LAB_VALIDATION.md` defines the engine-evidence protocol.

Remaining unlocked #10 direction:
- consume the landed #9 resolved-region identity boundary rather than treating the lab-only region formula as a second permanent region identity contract,
- add measured F3/F4 physical bodies/constraints through the landed ObjectGenome mechanism/state semantics,
- exercise authoritative WorldEntity/Fidelity promotion/demotion with state capture before teardown and state survival after re-realization,
- keep runtime ownership/diagnostics bounded and fail closed on duplicate representation/identity,
- gather actual Studio physics/contact/constraint/resource evidence under the validation protocol; unrun engine checks stay UNVERIFIED,
- deepen the existing lab rather than merge or create another competing full-shell framework.

## Unlocked Hero Gate

**#10 is the sole major implementation lane.** Strike-team work may add focused tests, lifecycle/runtime integration, physics quality, diagnostics, performance/resource evidence, Studio validation and Reality-Grade review around the landed shell.

## Hero Gate exit direction

Before opening broader content, prove that #10 uses the Wave-1 and landed #9 contracts without replacing them. The lab must demonstrate real Roblox realization/interaction while preserving domain identity/state and bounded lifecycle ownership.

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

1. deepen the landed F2 Physics Lab into a bounded authoritative F3/F4 lifecycle path,
2. bind the lab to the landed resolved-region identity boundary instead of preserving a second permanent region formula,
3. prove identity/material/object/fidelity state survives real Roblox realization, demotion, teardown and promotion,
4. collect honest Studio physics/resource evidence under `Docs/PHYSICS_LAB_VALIDATION.md`,
5. begin door/chair/physical-player Hero work only after the lab foundation clears Reality-Grade review.

Keep this file concise and operational. Git history is the changelog; Project Source is the long-term vision.
