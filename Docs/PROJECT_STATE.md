# Project State

Current phase: **Hero Gate — Production Physics Lab**

This file is the authoritative board for **current product maturity, dependencies, and major-feature unlocks**. Repository execution and concurrency policy lives in the root [`AGENTS.md`](../AGENTS.md). The retired Dynamic Swarm / Foundry claim, lease, worker-ID, fencing, admission, and `swarm-control` machinery is not normal execution authority.

Open issue != unlocked major product work. The Reality-Grade product WIP limit remains **3 major Feature Epics maximum**, but there is no fixed worker count or synthetic capacity target; agents should converge live GitHub work through branches, PRs, checks, reviews, and exact runtime evidence.

## Main health

- Roblox/Rojo production bootstrap is merged.
- The proven CI path covers pinned tool installation, Rojo sourcemap, StyLua, Selene, Roblox Luau analysis, pure deterministic tests, Rojo build, and artifact upload.
- Every agent must inspect the latest `main`/CI state before changing product code. Red `main` overrides feature work.
- The autonomous-development cutover is merged in #518. Historical swarm artifacts remain evidence/history only.

## Quality policy

`Docs/QUALITY_STANDARD.md` is mandatory. CI green is necessary where applicable, never sufficient proof of visual, physical, multiplayer, performance, or player-experience truth.

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
- support-cycle rejection and external-support reachability are independent deterministic graph facts.

## Hero Gate foundations

### #9 — First-observation lock / resolved-region recipe: complete via #163 + #169 + #190

The production boundary preserves first-observation truth without conflating conceptual world identity with generation provenance.

Current contract:
- deterministic potential -> canonical observed truth stays independent of Workspace serialization,
- first meaningful observation locks plain/versioned immutable generated-base truth,
- canonical schema/fingerprint v2 requires explicit project `WorldId`,
- stable v2 regional identity is `WorldId + canonical RegionAddress`,
- `worldSeedRef` remains separate generation provenance and exact recipe content,
- reconstruction equality/repro and literal v2 identity/fingerprint goldens are testable,
- historical schema-v1 seed-derived truth remains executable behind a replay-only compatibility boundary,
- canonical v2 never infers WorldId from a v1 seed reference,
- later generator output cannot silently rewrite established truth,
- generator-version migration is explicit and preserves v2 WorldId/seed/address identity,
- mutable deltas/runtime representation remain outside the immutable generated base.

Do not reopen competing #9 frameworks. Future incompatible identity/fingerprint changes require an explicit ADR/version/compatibility path and preservation of accepted historical truth.

### #10 — Production-contract Physics Lab: source-contract closure landed

The permanent Physics Lab shell is closed at the source-contract level. #151 remains open as the Roblox Studio/engine evidence gate. Do not reopen broad #10 source work or redundant source-validation slices unless a concrete regression or newly gathered engine evidence exposes a specific defect.

Landed source evidence includes:
- deterministic lab recipe and stable WorldEntity IDs,
- schema-v2 `ResolvedRegionRecipe` identity/provenance with exact fingerprint and repro key,
- production-owned F2/F0 lifecycle transitions without making Workspace canonical state,
- MaterialDNA/ObjectGenome-backed representations through project boundaries,
- bounded development diagnostics and a server-only Studio harness,
- source-owned 20-cycle F2 -> F0 -> F2 lifecycle evidence with exact revision/resource/envelope checks,
- full-F2 evidence that fails closed against canonical recipe/provenance/representation metadata,
- clear Studio validation/repro instructions,
- green source/pure CI and Rojo build evidence on the accepted implementation path.

Source-contract closure does **not** claim Roblox Studio physics/contact/constraint/server-authority PASS. Those observations remain external engine evidence and must stay explicitly UNVERIFIED until actually run.

## Mac ↔ GitHub Roblox Studio execution bridge

The dedicated bridge is operational, but its existence does **not** itself satisfy #151. See `Docs/STUDIO_EXECUTOR.md` and issue #151 for the full evidence ledger.

Accepted engine rows currently include:
- `20260810-018-server-smoke-managed-only-sol56j8` on exact UNRENDERED SHA `d225b3fe9f6da0a389bd8e14ddbe0f4cead26efe`: accepted single-server smoke/bootstrap/baseline only.
- `20260810-025-lifecycle-current-d225-joeysol` on the same exact SHA: accepted 20-cycle F2 -> F0 -> F2 lifecycle/rebuild/resource-envelope evidence.
- `20260810-027-physical-sanity-warmup-face-sol56k8` on exact SHA `face848a32ce626796d1263bed4150142ff170f2`: accepted current F2-shell canonical physical-sanity/contact evidence across floor, stairs, ramp, ledge, and ObjectGenome proxies.
- `20260810-032-performance-observation-090e-sol56s9` on exact SHA `090e112c83126ebe8e6f9ba75f27b7bcc31dc3af`: accepted bounded measurement capture/consistency under explicit `OBSERVED_NO_BUDGET`; it does not establish a permanent performance or device-suitability budget.

Remaining Hero-Gate engine rows:
1. **Diagnostics evidence — UNVERIFIED.** Historical request `20260810-031-diagnostics-capture-090e-sol56k8` proved useful source-owned behavior/log-path evidence but remains durable FAIL because the required live diagnostics-on viewport capture was missing (`NO_CAPTURE`).
2. **True two-client canonical authority — UNVERIFIED.** Post-guard request `20260810-039-two-client-post97-post93-835f-sol56m9` failed closed before accepted request-bound Studio evidence and contributes no authority PASS.

The private bridge issue #88 tracks the current macOS GUI/WindowServer/display-session blocker. Bridge #118 added richer runner-owned non-PASS telemetry, but those fields have not been exercised by a fresh accepted Studio request because the display preflight remains red.

While the display preflight is red, do **not** queue speculative diagnostics/two-client retries. Resume those exact evidence lanes only after the runner has a real active GUI display or a post-recovery run exposes a distinct code defect. A failed/no-capture bridge run is infrastructure evidence, not gameplay validation.

## Current product unlock status

**No new major Feature Epic is unlocked yet.** Issues #11–#25 remain gated as major product work until this file explicitly unlocks the next Hero Feature after the Physics Lab evidence is strong enough.

The autonomous-development cutover in `AGENTS.md` does **not** silently unlock the door, chair, physical-player controller, world generator, or another gated major system. It removes obsolete coordination bureaucracy and allows useful independent progress that does not violate real product dependencies or truth boundaries.

Safe current work includes:
- repair red `main`/CI,
- review, integrate, or repair active work,
- fix a concrete regression in the landed #9/#10/foundation contracts,
- add focused deterministic regression coverage, diagnostics/tooling hardening, or source correctness work that deepens the current foundations without creating a competing framework,
- prepare or consume real Roblox Studio evidence for the permanent lab without inventing PASS results,
- maintain docs/contracts/tooling so current GitHub truth and evidence rules remain unambiguous.

Do not start a Reality-Grade door, chair, physical-player controller, broad world generator, or another major system merely because agent capacity is available.

## Hero Gate exit direction

Accepted engine evidence covers the source-owned lifecycle/rebuild/resource-envelope slice, single-server bootstrap/baseline smoke, the current F2 shell's canonical Studio physical-sanity/contact slice, and bounded measurement-only performance observation.

Before the next Hero Feature is unlocked, the remaining diagnostics and true two-client canonical-authority evidence must be gathered and independently reviewed under the current fail-closed contracts. Articulated mechanisms remain UNVERIFIED where the current shell intentionally provides only anchored F2 proxies.

The intended Hero order remains **door, chair, then physical player movement**, not a giant procedural map.

## Known external setup gaps

- No published Roblox universe/place is connected to automated publishing yet.
- The bridge still lacks accepted diagnostics and true two-client authority evidence because its current GUI/display preflight is externally blocked.
- Approved production PBR, audio, and model libraries do not exist yet. Use project-owned fallbacks and do not add unlicensed content.

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

1. restore a usable runner GUI/display path and gather the remaining accepted diagnostics and true two-client canonical-authority evidence without weakening source truth,
2. keep source-owned lifecycle/repro/ownership, accepted physical-sanity, and bounded performance-observation evidence green, and keep every remaining evidence path fail closed on regressions,
3. explicitly update this product-state board before opening the next major Hero Feature,
4. when unlocked, deepen door/chair/physical-player work on these foundations rather than replacing them,
5. improve the first five-minute experience only after the relevant foundations are actually unlocked and proven.

Keep this file concise and operational. Git history is the changelog; Project Source is the long-term vision.
