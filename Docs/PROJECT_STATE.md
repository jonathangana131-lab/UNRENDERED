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

### #10 — Production-contract Physics Lab: source-contract closure landed
The permanent Physics Lab shell is closed at the source-contract level. #151 remains open as the Roblox Studio/engine evidence gate. Do not reopen broad #10 source work or redundant #151 source-validation slices unless a concrete regression, red-main repair, or newly gathered engine evidence exposes a specific defect.

Landed source evidence:
- deterministic lab recipe and stable WorldEntity IDs,
- schema-v2 `ResolvedRegionRecipe` identity/provenance with exact fingerprint and repro key,
- production-owned F2/F0 lifecycle transitions without making Workspace canonical state,
- MaterialDNA/ObjectGenome-backed representations through project boundaries,
- bounded development diagnostics and a server-only Studio harness,
- source-owned 20-cycle F2 -> F0 -> F2 lifecycle evidence with exact revision/resource/envelope checks,
- full-F2 evidence fails closed against canonical recipe/provenance/representation metadata rather than trusting a prior Instance snapshot,
- clear Studio validation/repro instructions,
- green source/pure CI and Rojo build evidence.

This source-contract closure does **not** claim Roblox Studio physics/contact/constraint/server-authority PASS. Those observations remain external engine evidence and must stay explicitly UNVERIFIED until actually run.

### Mac ↔ GitHub Roblox Studio Execution Bridge: complete
The dedicated Mac ↔ GitHub ↔ Roblox Studio execution bridge is operational ([Docs/STUDIO_EXECUTOR.md](file:///Users/joey/.gemini/antigravity/scratch/UNRENDERED/Docs/STUDIO_EXECUTOR.md)).
- Private bridge repo: `jonathangana131-lab/UNRENDERED-STUDIO-BRIDGE`
- Mac self-hosted runner: `UNRENDERED-STUDIO-MAC`
- Real Roblox Studio execution loop: GitHub request -> Mac self-hosted runner -> Roblox Studio -> result.json + artifact.

## Current unlock status

**No new major Feature Epic is unlocked yet.** Issues #11–#25 remain gated until this file explicitly unlocks one after the Hero Gate evidence is strong enough.

Workers may still:
- repair red `main`,
- review/integrate active work,
- repair a concrete regression in the landed #10 contracts,
- prepare or consume real Roblox Studio evidence for the permanent lab without inventing PASS results,
- perform scheduler/contract maintenance needed to keep the swarm state accurate.

Do not start a Reality-Grade door, chair, physical-player controller, world generator, or another major system merely because worker capacity is available.

## Hero Gate exit direction

The source-contract portion of the Physics Lab gate is established. The remaining gate is actual Roblox Studio/engine evidence where pure CI cannot prove behavior: contact/traversability, constraints/mechanisms as they become applicable, diagnostics behavior, server/two-client authority behavior, and device/performance observations.

After that evidence is gathered and reviewed, update this file to explicitly unlock the next narrow Hero Feature. The intended order remains **door, chair, then physical player movement**, not a giant procedural map.

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

1. gather real Studio physics/contact/constraint evidence for the permanent #10 lab without weakening source truth,
2. keep source-owned lifecycle/repro/ownership evidence green and fail closed on regressions,
3. explicitly update this scheduler before opening the next major Hero Feature,
4. when unlocked, deepen door/chair/physical-player work on these foundations rather than replacing them,
5. improve the first five-minute experience only after the relevant foundations are actually unlocked and proven.

Keep this file concise and operational. Git history is the changelog; Project Source is the long-term vision.
