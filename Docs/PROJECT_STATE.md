# Project State

Current phase: **Hero Gate — Production Physics Lab / Perfect 5 Minutes foundation**

## Main health

- Roblox/Rojo production bootstrap is merged.
- The proven CI path covers pinned tool installation, Rojo sourcemap, StyLua, Selene, Roblox Luau analysis, pure deterministic tests, Rojo build, and artifact upload.
- Foundation Wave 1 is integrated on `main`; the latest post-#125 main CI is green.
- Every worker must inspect the latest `main` Actions status. Red main overrides feature work.

## Quality policy

`Docs/QUALITY_STANDARD.md` is mandatory.

Open issue != unlocked work. This file is the authoritative unlock board.

Project-wide WIP target: **3–5 major Feature Epics maximum**. With many workers, deepen active epics through tests, fuzzing, performance, polish, integration and independent review rather than opening unrelated systems.

## Completed Wave 1

### Epic A — Deterministic Reality Foundation
- #3 — StableId / scoped RNG contracts; **complete**.
- #8 — deterministic regression/repro harness; **complete**.

Exit gate is satisfied: golden vectors are stable, subsystem streams are isolated, and repro keys are explicit enough for later generators to attach failures directly.

### Epic B — WorldEntity / Fidelity Foundation
- #4 — WorldEntity identity and representation lifecycle; **complete**.
- #7 — F0–F4 promotion/demotion manager; **complete**.

Exit gate is satisfied: identity survives representation changes, duplicate IDs are detectable, lifecycle/state capture is tested, and fidelity policy exposes metrics with anti-thrashing behavior.

### Epic C — Physical Content Domain Foundation
- #5 — MaterialDNA production contract; **complete**.
- #6 — ObjectGenome construction-grammar contract; **complete**.
- #100 — ObjectGenome↔MaterialDNA exact-reference/content-revision repair; **complete via #121 with deterministic-seal corrective closure #129**.
- #101 — ObjectGenome mechanism-state/persistence semantics repair; **complete via #117 with finite-span closure #123**.
- #119 — ObjectGenome mechanism-range numeric-closure repair; **complete via #123**.
- #125 — cycle-independent/traversal-order-deterministic external-support reachability; **complete**.

Exit gate is satisfied: immutable recipes and mutable state remain separate; MaterialDNA stays asset-ID-independent while linking visual/physical/acoustic identity; ObjectGenome covers components, mechanisms, plausible dimensions/materials/mass/affordances; exact MaterialDNA references and same-version recipe drift are guarded; mechanism persistence/reference-pose arithmetic is finite; support-cycle rejection and external-support reachability are independent deterministic graph facts; validators reject bad examples.

## Unlocked Hero Gate

### #10 — Production-contract Physics Lab
**UNLOCKED.** Build the permanent lab through the landed production contracts. It is not permission for ad-hoc scripts, a parallel object framework, or a broad content/map push.

The lab should become the repeatable acceptance environment for physical realization, fidelity promotion/demotion, mechanisms, material response, diagnostics, performance budgets, and later Reality-Grade door/chair/body work.

### #9 — First-observation / resolved-region recipe joins
**UNLOCKED.** Implement the narrow production join between deterministic potential and resolved truth using the landed StableId/RNG/version contracts. Keep conceptual/resolved/physical layers separate; first meaningful observation must lock the canonical recipe/version without making Workspace the database.

Hero-gate work must preserve exact repro keys and generated-base + meaningful-delta persistence semantics. Shared contract changes remain review-sensitive.

## Hero Gate exit direction

Do not use this unlock to expand breadth. Finish the lab and observation-lock foundation deeply before opening additional major systems.

After the lab foundation is stable, the first Reality-Grade Hero Features should be **door, chair, and physical player movement**, not a giant procedural map. Applicable Reality-Grade gates include physical edge cases, graphics/material finish, audio, UX/accessibility, multiplayer/security, persistence/streaming lifecycle, performance budgets, automated tests/fuzzing, permanent experience scenarios, and independent review.

## Currently gated planned work

Issues #11–#25 remain planned future work unless this file explicitly unlocks a specific item or it becomes a direct prerequisite for #9/#10. An open issue by itself is not implementation permission.

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

1. #10 becomes a permanent production-contract Physics Lab rather than a disposable demo,
2. #9 locks first-observation/resolved-region recipe joins without collapsing conceptual/resolved/physical layers,
3. lab scenarios prove MaterialDNA/ObjectGenome/WorldEntity/Fidelity integration under real realization and teardown,
4. Reality-Grade door and chair work begins only on the finished lab foundation,
5. physical player movement follows finished object/physics foundations rather than compensating for weak ones.

Keep this file concise and operational. Git history is the changelog; Project Source is the long-term vision.
