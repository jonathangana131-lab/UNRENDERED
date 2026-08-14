# Project State

Current phase: **Hero Gate — Production Physics Lab**

## Main health

- Roblox/Rojo production bootstrap is merged.
- The proven CI path covers pinned tool installation, Rojo sourcemap, StyLua, Selene, Roblox Luau analysis, pure deterministic tests, Rojo build, and artifact upload.
- Every worker must inspect the latest `main` Actions status. Red main overrides feature work.

## Quality policy

`Docs/QUALITY_STANDARD.md` is mandatory.

Open issue != unlocked work. This file is the authoritative unlock board.

Project-wide WIP limit: **3 major Feature Epics maximum**. With many chats, deepen active epics through tests, fuzzing, performance, polish, integration and independent review rather than opening unrelated systems; apply Foundry 17 repository-pressure admission before any new product branch.

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

### Mac ↔ GitHub Roblox Studio Execution Bridge: operational; Hero Gate evidence incomplete
The dedicated Mac ↔ GitHub ↔ Roblox Studio execution bridge is operational; its existence does **not** itself satisfy #151. See `Docs/STUDIO_EXECUTOR.md`.
- Private bridge repo: `jonathangana131-lab/UNRENDERED-STUDIO-BRIDGE`.
- Mac self-hosted runner: `UNRENDERED-STUDIO-MAC`.
- The bridge uses fixed repository-owned drivers, a managed Studio RunMode executor plugin, exact source-SHA validation, request-bound log provenance, bounded CreatorOutput evidence transport, and job-specific fail-closed evaluation.
- Historical request `20260810-005-reality-hero-gate` produced a lifecycle-style simulation signal but was incorrectly promoted to a composite Hero Gate `PASS`; that durable bridge result has been corrected to `FAIL`. It does not prove the complete Hero Gate.
- Request `20260810-015-server-smoke-managed-plugin-n7` never reached Studio because the older validator invalidated its queued SHA after public `main` advanced. It provides no engine evidence and must not be counted. The bridge now accepts an exact pinned SHA only when it is a real ancestor of the named canonical ref, so queued immutable evidence requests survive later canonical commits without accepting unrelated history.
- Request `20260810-018-server-smoke-managed-only-sol56j8` on exact UNRENDERED SHA `d225b3fe9f6da0a389bd8e14ddbe0f4cead26efe` is durable `PASS` / `evidence accepted` after removal of the proven legacy RunMode executor collision. It records `isRunning=true`, `isServer=true`, `labModelValid=true`, `baselineOk=true`, and `playerCount=0`. This proves only the single-server smoke/bootstrap/baseline slice; it does **not** prove two-client authority, diagnostics behavior, device/performance, or the composite Hero Gate.
- Request `20260810-025-lifecycle-current-d225-joeysol` on the same exact UNRENDERED SHA is durable `physics-lab-lifecycle` `PASS` / `evidence accepted`: 20 F2 -> F0 -> F2 cycles, checkpoints 1/5/10/20, zero resource-count deltas, zero full-lab envelope drift within the explicit 0.001 stud tolerance, stable resolved-region repro identity, and expected primitive/ObjectGenome revision advancement. This proves the lifecycle/rebuild/resource-envelope slice only.
- Request `20260810-027-physical-sanity-warmup-face-sol56k8` on exact UNRENDERED SHA `face848a32ce626796d1263bed4150142ff170f2` is durable `physics-lab-physical-sanity` `PASS` / `evidence accepted`: real server RunMode, exactly one canonical lab root, canonical baseline validation, engine contact on floor + stairs 1–4 + ramp + ledge, monotonic stair order, five ObjectGenome F2 proxies, and clean temporary-probe cleanup/resource/envelope checks with exact WorldId/RegionId/fingerprint/repro identity. This accepts the current F2 shell's canonical Studio bootstrap/physical-sanity slice without claiming articulated hinge/caster/drawer behavior.
- Fresh post-display-guard two-client request `20260810-039-two-client-post97-post93-835f-sol56m9` on exact public `main@835f6bc39f9468a0fbe3c8f6c1c1249365fc9540` is durable `physics-lab-two-client` `FAIL` / `NO_CAPTURE` with empty evidence and `transport status was not PASS`. It provides no accepted two-client authority evidence; the row remains open.
- Request `20260810-031-diagnostics-capture-090e-sol56k8` on exact UNRENDERED SHA `090e112c83126ebe8e6f9ba75f27b7bcc31dc3af` has raw transport `PASS` and proves the source-owned diagnostics behavior itself reached visible ON, completed all 20 bounded toggle cycles with checkpoints 1/5/10/20, preserved zero tracked resource deltas and zero envelope drift, emitted each request-bound runtime marker exactly once, and finished OFF. Its durable semantic status remains `FAIL` solely because the required live diagnostics-on viewport capture was missing (`NO_CAPTURE`). This is useful failure evidence, not an accepted diagnostics row. Fresh post-display-guard request `20260810-036-diagnostics-displayguard-835f-sol56r8` on exact public `main@835f6bc39f9468a0fbe3c8f6c1c1249365fc9540` also published durable `FAIL` / `NO_CAPTURE` with empty evidence and `transport status was not PASS`, so it contributes no accepted diagnostics evidence.
- Request `20260810-040-diagnostics-phaseprobe-835f-sol56sol` against UNRENDERED `835f6bc39f9468a0fbe3c8f6c1c1249365fc9540` predates bridge #118 and published durable `FAIL` / `NO_CAPTURE` with `failureDiagnostics.phase=NO_REQUEST_BOUND_LOG`, `requestMarkerLines=0`, and zero foundation/lab/visual/result/finished markers. This sharpens the observed blocker to pre-request-bound Studio execution, but it is **not** accepted diagnostics evidence and must not be cited as validation of #118.
- Bridge #118 later landed runner-owned non-PASS telemetry on bridge `main@fa8077e9365cd59e30a8c227397d8f056109558f` with Bridge CI `31455126625` green: bounded elapsed/timeout/watchdog state, Studio-alive-at-loop-end state, capture-attempt/success state, and request-bound marker counts are now durable failure diagnostics rather than inferred evidence. Because the display preflight remains red and the scheduler forbids speculative retries, these newly added #118 runner-owned fields have **not yet been exercised by a fresh Studio request**. Do not queue a probe solely to exercise them; wait for real GUI recovery or a distinct post-recovery defect.
- Request `20260810-032-performance-observation-090e-sol56s9` on exact UNRENDERED SHA `090e112c83126ebe8e6f9ba75f27b7bcc31dc3af` is accepted as the bounded `physics-lab-performance-observation` row after hardened full-payload re-evaluation. The original Studio result records real server RunMode on Roblox engine `0.733.0.7330989`, 30 warmup + 120 measured Heartbeats (mean 17.785 ms, median 16.692 ms, p95 18.304 ms, max 93.643 ms), full-capture/restart observations, exact canonical WorldId/RegionId/fingerprint/repro identity, zero tracked restart resource deltas, and the documented 0.001-stud envelope preserved. Bridge #65 first added total/mean/sample and typed-zero consistency checks; #75 then added nearest-rank percentile/extrema feasibility; merged bridge #78 loaded the **entire durable request-032 result JSON** and required current `evaluate_evidence.evaluate()` acceptance under those hardened guards, with Bridge CI run `31450117146` green. This accepts measurement capture/consistency only under explicit `OBSERVED_NO_BUDGET`; it does **not** establish a permanent frame-time/startup/device-suitability budget. Fresh request `20260810-033-performance-post65-090e-sol56h3` later timed out before durable engine output and contributes no additional evidence.
- Future engine evidence requests must pin an exact canonical SHA that is reachable from the named canonical ref and satisfy the job-specific evaluator. No lifecycle, single-server, physical-sanity, or measurement-only performance result may unlock the Hero Gate by itself.

## Current unlock status

**No new major Feature Epic is unlocked yet.** Issues #11–#25 remain gated until this file explicitly unlocks one after the Hero Gate evidence is strong enough.

Workers may still:
- repair red `main`,
- review/integrate active work,
- repair a concrete regression in the landed #10 contracts,
- prepare or consume real Roblox Studio evidence for the permanent lab without inventing PASS results,
- perform scheduler/contract maintenance needed to keep the swarm state accurate.

While bridge #88's macOS display preflight is red, workers must not queue speculative diagnostics/two-client evidence retries. Resume those evidence lanes only after the runner has a real active GUI display or a post-recovery run exposes a distinct code defect.

Do not start a Reality-Grade door, chair, physical-player controller, world generator, or another major system merely because worker capacity is available.

## Hero Gate exit direction

The source-contract portion of the Physics Lab gate is established. Accepted engine evidence now covers the source-owned lifecycle/rebuild/resource-envelope slice, single-server bootstrap/baseline smoke, the current F2 shell's canonical Studio physical-sanity/contact slice, and the bounded measurement-only performance-observation row. Remaining engine-facing work includes accepted diagnostics capture/behavior evidence and true two-client canonical authority; articulated mechanisms remain UNVERIFIED where the current shell intentionally provides only anchored F2 proxies.

After that evidence is gathered and reviewed, update this file to explicitly unlock the next narrow Hero Feature. The intended order remains **door, chair, then physical player movement**, not a giant procedural map.

## Currently gated planned work

Issues #11–#25 are planned future work. They are **not automatically implementation-ready** until this file unlocks them or they become an explicit prerequisite for an unlocked Epic.

Workers may inspect/review/decompose them, but should not build those major systems yet merely because worker capacity exists.

## Known external setup gaps

- No published Roblox universe/place is connected to automated publishing yet.
- The bridge now has accepted lifecycle/rebuild, single-server bootstrap/baseline, canonical F2-shell physical-sanity/contact, and bounded measurement-only performance-observation evidence, but #151 still lacks accepted diagnostics and true two-client authority evidence. Post-#97 exact-SHA probes for the remaining rows failed closed before request-bound Studio execution (`NO_CAPTURE`, empty evidence, zero request-bound markers). Bridge #118 has since landed richer runner-owned failure telemetry, but no fresh request has exercised those new fields because the display preflight is still red and speculative retries are forbidden. The runner-side GUI/WindowServer/display path therefore remains a practical external blocker rather than evidence of a gameplay/source PASS.
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

1. restore a usable runner GUI/display path and gather the remaining accepted diagnostics and true two-client canonical-authority evidence without weakening source truth,
2. keep source-owned lifecycle/repro/ownership, accepted physical-sanity, and bounded performance-observation evidence green, and keep every remaining evidence path fail closed on regressions,
3. explicitly update this scheduler before opening the next major Hero Feature,
4. when unlocked, deepen door/chair/physical-player work on these foundations rather than replacing them,
5. improve the first five-minute experience only after the relevant foundations are actually unlocked and proven.

Keep this file concise and operational. Git history is the changelog; Project Source is the long-term vision.
