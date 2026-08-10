# Project State

Current phase: **Hero Gate — Production Physics Lab / Resolved Reality Foundation**

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

### #9 — First-observation lock / resolved-region recipe: complete via #163 + WorldId correction #183
The plain/versioned first-observation, exact-content fingerprint, explicit migration, and immutable generated-base boundary is landed. ADR 0003 corrects the post-#163 identity defect without erasing historical truth:
- all new observations/writes use schema/fingerprint v2 and require an explicit project `WorldId`,
- stable v2 regional identity is `WorldId + canonical RegionAddress`,
- `worldSeedRef` remains separate generation provenance and exact recipe content,
- historical v1 remains explicitly readable/reproducible under its original seed-derived identity law,
- normal v2 deserialization does not silently reinterpret v1,
- a loaded v1 incumbent remains established truth during first-observation reconciliation,
- v1 -> v2 correction requires an explicit caller-supplied WorldId and returns source/target identity evidence; WorldId is never inferred from seed provenance,
- generic generator-version migration is v2-only and preserves WorldId/address identity,
- literal v1 and v2 compatibility vectors pin both historical laws.

Do not reopen competing #9 identity implementations. Future incompatible changes require another explicit version path and compatibility evidence.

## Unlocked Hero Gate

Finish this foundation before broadening into planned P1 systems.

### #10 — Production-contract Physics Lab
The permanent lab foundation is active and must be deepened in place through the landed production contracts. This is not permission for ad-hoc gameplay scripts or a competing framework.

Landed foundation includes:
- #165 — deterministic 20-entity F2 anchored-proxy shell and Studio-only realization boundary,
- #174 — manufacturable versioned commercial-door jamb/header aperture repair,
- #185 — fail-closed MaterialDNA reference validation in the lab recipe,
- #189 — bounded WorldEntity/Fidelity runtime authority and lifecycle regressions.

Required next direction:
- bind permanent lab region/repro identity through corrected #9 schema-v2 `WorldId + RegionAddress`, not a seed-derived or lab-private competing formula,
- deepen F2 proxies into measured F3/F4 representations only where the production lifecycle owns promotion/demotion and state capture,
- implement and validate door/chair/cart/cabinet mechanisms without normalizing unstable constraints,
- add bounded runtime/rigidbody/constraint diagnostics and performance budgets,
- run the documented Roblox Studio evidence protocol for engine-only physics/contact/resource gates,
- keep Roblox Instances as physical representation, never canonical world state.

## Hero Gate exit direction

Before opening broader content, prove that #10 uses the Wave-1 and corrected #9 contracts without replacing them. Strike-team work should deepen #10 through tests, Studio/physics evidence, diagnostics, performance, integration and Reality-Grade review.

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

Historical ResolvedRegionRecipe v1 remains an explicit compatibility/read path. Any deliberate v1 -> v2 conversion must receive WorldId from the caller/operator; there is no automatic seed-to-WorldId migration.

## Generation/schema versions

- reality: 1
- topology: 1
- material: 1
- object: 1
- entity: 1
- persistence: 1

## Next critical outcomes

1. #10 consumes corrected schema-v2 resolved-region identity without inventing a second region contract,
2. the permanent Physics Lab deepens beyond the landed F2 proxy through measured lifecycle/mechanism/state-capture work,
3. Studio evidence closes engine-only physics/contact/resource gates rather than substituting headless CI,
4. the lab proves Wave-1 identity/material/object/fidelity contracts survive real Roblox realization and interaction,
5. door/chair/physical-player work begins only on those stable foundations.

Keep this file concise and operational. Git history is the changelog; Project Source is the long-term vision.
