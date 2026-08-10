# Project State

Current phase: **Foundation Lock — Reality-Grade Wave 1**

## Main health

- Roblox/Rojo production bootstrap is merged.
- The proven CI path covers pinned tool installation, Rojo sourcemap, StyLua, Selene, Roblox Luau analysis, pure deterministic tests, Rojo build, and artifact upload.
- Every worker must inspect the latest `main` Actions status. Red main overrides feature work.

## Quality policy

`Docs/QUALITY_STANDARD.md` is mandatory.

Open issue != unlocked work. This file is the authoritative unlock board.

Project-wide WIP target: **3–5 major Feature Epics maximum**. With many workers, deepen active epics through tests, fuzzing, performance, polish, integration and independent review rather than opening unrelated systems.

## Unlocked Wave 1

### Epic A — Deterministic Reality Foundation
- #3 — lock StableId / scoped RNG contracts.
- #8 — deterministic regression/repro harness.

Exit gate:
- golden vectors are stable,
- subsystem streams cannot perturb unrelated streams,
- repro keys are clear enough that later generators can attach failures directly.

### Epic B — WorldEntity / Fidelity Foundation
- #4 — WorldEntity identity and representation lifecycle.
- #7 — F0–F4 promotion/demotion manager.

Exit gate:
- identity survives Roblox Instance destruction/recreation,
- duplicate IDs are detectable,
- state capture/promotion/demotion is tested,
- fidelity policy has metrics and anti-thrashing behavior.

### Epic C — Physical Content Domain Foundation
- #5 — MaterialDNA production contract.
- #6 — ObjectGenome construction-grammar contract.
- #100 — ObjectGenome↔MaterialDNA exact-reference/content-revision repair; **merged green via #121 with canonical fingerprint v2 closure #129 and complete**.
- #101 — ObjectGenome mechanism-state/persistence semantics repair; **merged green via #117, with finite-span closure #123, and complete**.
- #119 — post-#117 ObjectGenome mechanism-range numeric-closure repair; **merged green via #123 and complete**.
- #125 — ObjectGenome external-support reachability must be cycle-independent and traversal-order deterministic; **blocking Epic C exit**.

Exit gate:
- coherent immutable recipe vs mutable state separation,
- MaterialDNA links visual/physical/acoustic identity without asset-ID coupling,
- ObjectGenome supports components, mechanisms, realistic dimensions/materials/mass/affordances,
- ObjectGenome material references obey the exact landed MaterialDNA identity/revision contract and same-version canonical recipe drift is detectable through the versioned project-owned recipe fingerprint contract,
- ObjectGenome mechanism state has explicit kind-specific persistence semantics anchored to authored reference poses,
- accepted hinge/tilt/slide range arithmetic stays finite through default-state derivation and canonical physical decode,
- support-cycle rejection and external-support reachability are independent deterministic graph facts,
- validators reject bad examples.

## Next unlock

### Hero Gate — Production Physics Lab / Perfect 5 Minutes foundation
- #10 — production-contract Physics Lab.
- #9 — first-observation/resolved-region recipe joins once deterministic contracts are ready.

This remains a **next unlock, not current implementation permission**. Do not begin #10/#9 until the Wave 1 exit gates are green, including the remaining #125 blocker, and this file is updated to unlock the Hero Gate.

Do not treat #10 as permission for ad-hoc scripts. Its objects must instantiate through the production contracts from Wave 1 as they land.

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

1. deterministic core is a golden locked contract,
2. WorldEntity/F0–F4 lifecycle is production-safe,
3. MaterialDNA/ObjectGenome foundations pass validators/tests, with #100/#101/#119 closures landed and the remaining #125 support-reachability repair completed,
4. Physics Lab begins using those exact contracts only after the Hero Gate is explicitly unlocked,
5. the first five-minute experience can be improved deeply without replacing its foundations.

Keep this file concise and operational. Git history is the changelog; Project Source is the long-term vision.
