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

## Foundation Wave 1 — complete

Wave 1 exit is green on the authoritative contracts and their post-merge Reality-Grade repairs:

### Epic A — Deterministic Reality Foundation
- #3 — StableId / scoped RNG contracts.
- #8 — deterministic regression/repro harness.

Locked outcomes:
- golden vectors are stable,
- subsystem streams cannot perturb unrelated streams,
- repro keys are available to later generators.

### Epic B — WorldEntity / Fidelity Foundation
- #4 — WorldEntity identity and representation lifecycle.
- #7 — F0–F4 promotion/demotion manager.

Locked outcomes:
- identity survives Roblox Instance destruction/recreation,
- duplicate IDs are detectable,
- state capture/promotion/demotion is tested,
- fidelity policy has metrics and anti-thrashing behavior.

### Epic C — Physical Content Domain Foundation
- #5 — MaterialDNA production contract.
- #6 — ObjectGenome construction-grammar contract.
- #100 — exact ObjectGenome↔MaterialDNA reference and deterministic recipe-drift seal; complete via #121 + #129.
- #101 — explicit ObjectGenome mechanism-state/persistence semantics; complete via #117.
- #119 — finite mechanism-range numeric closure; complete via #123.
- #125 — cycle-independent, traversal-order-deterministic external-support reachability; complete via #136. The duplicate #137 merge was zero-diff.

Locked outcomes:
- coherent immutable recipe vs mutable state separation,
- MaterialDNA links visual/physical/acoustic identity without asset-ID coupling,
- ObjectGenome supports components, mechanisms, realistic dimensions/materials/mass/affordances,
- ObjectGenome material references obey the exact MaterialDNA identity/revision contract and same-version canonical recipe drift is detected by a separately versioned deterministic seal,
- ObjectGenome mechanism state has explicit kind-specific persistence semantics anchored to authored reference poses,
- accepted hinge/tilt/slide range arithmetic stays finite through default-state derivation and canonical physical decode,
- support-cycle rejection and external-support reachability are independent deterministic graph facts,
- validators reject bad examples.

## Unlocked Hero Gate

### #10 — Production-contract Physics Lab
**UNLOCKED.** Build the permanent lab through the production contracts from Wave 1. Do not create ad-hoc object, material, identity, state, or fidelity frameworks beside them.

The lab exists to make physical behavior measurable, reproducible and polishable before broad world generation. Engine-dependent claims require actual Studio/test-place evidence; pure/domain claims continue to use the pinned headless suite.

### #9 — First-observation / resolved-region recipe joins
**UNLOCKED.** Join deterministic/resolved-region recipes to the locked identity/material/object/fidelity contracts without turning Workspace into canonical state and without expanding into a giant procedural map.

Prefer finishing the Physics Lab foundation and shared join contracts over opening more major systems. #9 and #10 may proceed in parallel only where ownership is non-conflicting and both remain within the project-wide WIP cap.

## Hero Gate exit direction

Do not treat this unlock as permission for broad content expansion. The next Reality-Grade Hero Features after the lab/join foundation proves stable are **door, chair, and physical player movement** in that order of dependency, with applicable graphics, audio, UX, networking, persistence, performance and independent-review gates.

## Currently gated planned work

Issues #11–#25 remain planned future work unless this file explicitly promotes one as a prerequisite or active Hero task. Open issue alone is not implementation permission.

Workers may inspect/review/decompose gated work, but should not build those major systems merely because worker capacity exists.

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

1. #10 Physics Lab instantiates the exact Wave 1 production contracts and becomes the permanent Reality-Grade physics test surface,
2. #9 first-observation/resolved-region joins preserve conceptual/resolved/physical separation and deterministic repro,
3. door and chair become the first deeply finished physical Hero Features instead of broad procedural content,
4. physical player movement builds on those proven contact/physics foundations,
5. the first five-minute experience improves deeply without replacing its contracts.

Keep this file concise and operational. Git history is the changelog; Project Source is the long-term vision.
