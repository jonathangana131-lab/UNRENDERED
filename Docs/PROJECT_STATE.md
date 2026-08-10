# Project State

Current phase: **Hero Gate — Production Physics Lab / Resolved Truth Foundation**

## Main health

- Roblox/Rojo production bootstrap is merged.
- The proven CI path covers pinned tool installation, Rojo sourcemap, StyLua, Selene, Roblox Luau analysis, pure deterministic tests, Rojo build, and artifact upload.
- Every worker must inspect the latest `main` Actions status. Red main overrides feature work.

## Quality policy

`Docs/QUALITY_STANDARD.md` is mandatory.

Open issue != unlocked work. This file is the authoritative unlock board.

Project-wide WIP target: **3–5 major Feature Epics maximum**. With many workers, deepen active epics through tests, fuzzing, performance, polish, integration and independent review rather than opening unrelated systems.

## Completed Wave 1 — Reality-Grade Foundation Lock

### Epic A — Deterministic Reality Foundation
- #3 — StableId / scoped RNG contracts: complete.
- #8 — deterministic regression/repro harness: complete.

Locked invariants:
- golden vectors are stable,
- subsystem streams cannot perturb unrelated streams,
- repro keys are explicit enough for later generators to attach failures directly.

### Epic B — WorldEntity / Fidelity Foundation
- #4 — WorldEntity identity and representation lifecycle: complete.
- #7 — F0–F4 promotion/demotion manager: complete.

Locked invariants:
- identity survives Roblox Instance destruction/recreation,
- duplicate IDs are detectable,
- state capture/promotion/demotion is tested,
- fidelity policy has metrics and anti-thrashing behavior,
- public fidelity boundaries enforce the WorldEntityId contract.

### Epic C — Physical Content Domain Foundation
- #5 — MaterialDNA production contract: complete.
- #6 — ObjectGenome construction-grammar contract: complete.
- #100 — exact ObjectGenome↔MaterialDNA reference/content-revision lock: complete via #121 + #129.
- #101 — mechanism-state/persistence semantics: complete via #117.
- #119 — finite mechanism-range arithmetic closure: complete via #123.
- #125 — cycle-independent deterministic support reachability: complete via #136/#137.

Locked invariants:
- immutable recipe and mutable state are separate,
- MaterialDNA links visual/physical/acoustic identity without asset-ID coupling,
- ObjectGenome supports components, mechanisms, realistic dimensions/materials/mass/affordances,
- ObjectGenome material references obey the landed MaterialDNA reference contract,
- same-version canonical recipe drift is caught by the separately versioned deterministic fingerprint contract without changing ObjectGenome v1 entity/state identity,
- mechanism state has explicit kind-specific persistence semantics anchored to authored reference poses,
- accepted hinge/tilt/slide range arithmetic stays finite through default-state derivation and canonical physical decode,
- support-cycle rejection and external-support reachability are independent deterministic graph facts,
- validators reject malformed and structurally nonsensical examples.

Wave 1 exits green. Issue #28 may be closed once this scheduler transition is merged.

## Unlocked Hero Gate

### #10 — Production-contract Physics Lab
Build the first permanent playable/testable Roblox lab using the exact Wave-1 contracts.

Required direction:
- deterministic lab recipe,
- floor/walls/ceiling test bay plus chair, table, hinged door, rolling cart, cabinet/drawer placeholder, stairs/ramp/ledge and physical-character spawn anchor,
- objects instantiated through production WorldEntity / MaterialDNA / ObjectGenome / fidelity boundaries rather than ad-hoc scripts,
- development diagnostics expose IDs/fidelity state,
- simple primitives are acceptable initially, but disposable parallel frameworks are not,
- Studio evidence is required for engine/physics behavior that pure CI cannot prove.

### #9 — First-observation lock / resolved-region recipe
Define the first production resolved-truth recipe and observation lock on top of the deterministic foundation.

Required direction:
- plain/versioned `ResolvedRegionRecipe`,
- region address + WorldId/seed reference + generator versions + semantic/topology anchors + canonical content keys,
- first meaningful observation locks the recipe/version,
- generated base + meaningful mutable deltas boundary,
- deterministic reconstruction equality/hash tests,
- migration hook for future generator versions,
- no Roblox Instance serialization.

## Hero Gate WIP policy

#10 and #9 are the only newly unlocked major implementation lanes. Prefer finishing/integrating these two deeply before opening additional systems. Extra workers should form strike teams around them: tests/fuzz/repro, Studio physics evidence, performance/metrics, UX/diagnostics, contract review and integration.

The first Reality-Grade Hero Features after the lab foundation is stable should be **door, chair, and physical player movement**. Do not compensate for weak lab physics/material/audio/movement foundations with a giant procedural map or broad content wave.

## Currently gated planned work

Issues #11–#25 remain planned future work. They are **not automatically implementation-ready** until this file explicitly unlocks them or one becomes a direct prerequisite for the two active Hero-Gate lanes.

Workers may inspect/review/decompose them, but should not build those major systems merely because worker capacity exists.

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
2. #9 proves deterministic potential can become version-locked resolved truth without Workspace serialization,
3. Studio evidence closes engine-only physics/realization gaps that current pure CI cannot prove,
4. the first Reality-Grade door and chair are built through those exact contracts,
5. physical player movement follows on finished foundations before broad world/content expansion.

Keep this file concise and operational. Git history is the changelog; Project Source is the long-term vision.
