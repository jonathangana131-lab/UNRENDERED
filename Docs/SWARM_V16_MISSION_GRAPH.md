# UNRENDERED Swarm V16 — Mission Graph

V16 adds a persistent mission-level control plane above the existing Dynamic Swarm V2.1 lane/claim/event engine. It is an additive migration: the audited `swarm-control` immutable-event history, atomic legacy claims, resource leases, PR ownership fence, and generated validation digest remain authoritative. V16 must not rewrite or reset them.

## Why V16 exists

V2.1 is strong at preventing unsafe concurrent edits, but a large swarm can still optimize for locally runnable slots instead of finishing coherent milestones. V16 changes the scheduling object from “which lane is open?” to “which mission objective most efficiently destroys the remaining milestone blockers?”

The durable graph is:

`Mission → Objectives → Dependencies → Blockers → Work Items → Solutions → Evidence → Integration → Milestone`

Persisted state lives at `.swarm/runtime/v16/mission-graph.json` on `swarm-control`. The existing control-state digest therefore covers the V16 file while a dedicated V16 fence validates its schema and authority invariants.

## Non-negotiable compatibility laws

- Existing immutable events are never rewritten, deleted, normalized, or replayed by V16.
- Existing lane claims and scarce-resource leases remain enforced during migration.
- `destructiveActionsAllowed` remains `false` unless a future separately reviewed protocol explicitly changes that rule.
- V16 state is data only. Executable payloads, shell, scripts, local paths, and command fields are rejected.
- A source/CI PASS is not Roblox Studio truth.
- A local/simulated run is not two-client truth.
- A Studio screenshot is not server-authority proof by itself.
- Real Studio, multi-client, device, graphics, and authority evidence require an explicitly identified external executor/evidence source.
- V16 cannot automatically promote external runtime truth.

## Truth classes

V16 uses explicit evidence classes:

- `SOURCE_VERIFIED`
- `CI_VERIFIED`
- `SIMULATED`
- `STUDIO_OBSERVED`
- `MULTICLIENT_OBSERVED`
- `DEVICE_PROFILED`
- `AUTHORITY_VERIFIED`

The last four are elevated external truth. Evidence in those classes is rejected unless `externalAuthorityExplicit` is present. An objective's `runtimeTruth` genome cannot become `ACCEPTED` unless accepted elevated evidence is actually attached.

## Feature genome

Every objective carries the same completion genome:

- functionality
- determinism
- physics
- visual quality
- audio
- accessibility
- multiplayer/security
- persistence
- performance
- testing
- integration
- runtime truth
- known blockers

Dimensions can be `NOT_STARTED`, `ACTIVE`, `BLOCKED`, `ACCEPTED`, or `NOT_APPLICABLE`. The genome prevents “CI is green” from being confused with “Reality-Grade.”

## Mission model

The initial graph contains two top-level missions.

### Hero Gate Reality-Grade

This mission converges Foundation Lock and the permanent Physics Lab into the next retained milestone. Seed objectives include stable identity/determinism, WorldEntity, MaterialDNA, ObjectGenome, Fidelity, Physics Lab, server authority, Studio runtime evidence, two-client authority evidence, and the final Hero Gate audit.

Legacy Hero Gate lanes are imported as additional objectives/work items instead of being erased. Their dependencies, blockers, PR links, scopes, and current operational state are preserved.

### Swarm Operations

This mission owns control-plane health and the V16 rollout itself. The `swarm-v16-mission-graph` objective is deliberately dogfoodable: after the V16 implementation PR is merged and accepted, the trusted operator path can bind that objective to the exact merged PR, exact source head, successful acceptance runs, source-bound independent review, merge ancestry, and unchanged affected paths.

## Duplicate suppression and branch convergence

Before creating work, V16 compares the proposed outcome against active work. A substantial semantic duplicate is joined/reviewed/integrated instead of spawning another implementation branch.

Intentional parallel solutions require an explicit solution tournament with a bounded two-to-three candidate limit. A winner is selected using recorded comparison evidence; losing candidates become superseded rather than lingering as competing canonical branches.

Repeated activity without meaningful blocker progress triggers convergence mode and a rabbit-hole review. The purpose is to stop “branch multiplication as progress.”

## Dynamic agents and scheduling

V16 allocates builders, reviewers, and integrators dynamically according to review and integration pressure. Objectives are scored by severity, release blocking, safety criticality, user value, dependency fan-out, age, proximity to completion, integration state, and surge mode.

A mission packet contains the mission, why it matters, objective state, canonical branch, exact scope, forbidden areas, known blockers, relevant evidence, and exit condition. Workers should consume those packets rather than rediscovering context from scratch.

Captains are coordination hints, not single points of failure. Scheduling continues when a captain disappears.

## Blockers and solution tournaments

Blockers are first-class records with severity, evidence, owner/backup, attempts, current hypothesis, related branches, next action, and an evidence-bound exit condition.

A blocker cannot be resolved without evidence. Four or more recent attempts with almost no meaningful progress trigger convergence pressure. Five-plus attempts across multiple workers/branches with little progress are flagged as a rabbit hole.

## Evidence, test impact, and reuse

Evidence is bound to source, dependencies, environment, and affected paths. When a bound path changes, prior PASS evidence becomes `STALE` instead of silently carrying forward.

The impact map selects relevant suites for Reality, MaterialDNA, ObjectGenome, Physics/Fidelity, Physics Lab, server/client authority, workflows, the legacy swarm engine, and V16. Integration and release boundaries add broader suites, but release validation still explicitly records that Studio evidence remains external.

## Merge train

Integration is serialized through a merge train. A candidate must contain work already in review/integration-ready state and list required suites. Only one candidate can be active. Failure returns the work to actionable integration state rather than converting it into a false green.

## Memory, failure knowledge, specialization, and complexity

V16 retains bounded mission memory and structured failure knowledge so future workers can avoid rediscovery. Agent outcome profiles support specialization based on accepted/integrated results and regressions.

Complexity review flags pathological test-to-production ratios, workflow proliferation, branch proliferation, repeated validation primitives, and excessive integration overhead. Momentum is measured by blocker removal, dependency unlocks, acceptance/integration gained, and user-visible improvement—not raw branch or line count.

## `Go` under V16

`Go` means: validate current main/control truth, read the Mission Graph, select the highest-value safe unblocked mission packet, atomically acquire ownership, do the bounded work, attach evidence, move it toward review/integration, then ask the graph for the next useful packet while capacity remains.

A green main is health information, not completion. Zero ordinary primaries is not completion. External Studio blockage is not permission to invent evidence; capacity redirects to review, integration, recovery, tests, audits, source-only depth, or bounded mining exactly as V2.1 already requires.

## Migration and activation

`Swarm V16 Mission Graph Shadow` runs deterministic tests, a 30-worker adversarial simulation, and a live read-only migration against current `swarm-control`.

`Swarm V16 Mission Graph Activate` is manually dispatched from trusted `main`. It re-runs the gates, imports current legacy state, and atomically creates or refreshes `.swarm/runtime/v16/mission-graph.json` on `swarm-control` using GitHub Contents SHA compare-and-swap. Activation is idempotent and destructive cleanup stays disabled.

`Swarm V16 Live Main Refresh` binds the active graph to each new `main` head without pretending that main movement preserves path-bound evidence.

`Swarm V16 Mission Graph Control Fence` validates each V16 state write and, after activation, requires graph revision to advance exactly once. Existing evidence is immutable except for the explicit `PASS → STALE` invalidation transition.

## Trusted objective integration

The repository owner may use:

`/v16-objective-integrate OBJECTIVE PR SOURCE_HEAD MERGE_SHA RUN_IDS REVIEW_IDS PATHS`

The trusted workflow verifies the PR is merged to the default branch, exact source/merge SHAs match live GitHub, the merge is an ancestor of current main, evidence-bound paths have not changed since that merge, every cited Actions run is completed successfully, at least one run is exact-source-head, every cited review is anchored to that source head, and at least one review body binds the source head plus all cited run IDs.

Only then does a CAS state mutation add source/CI/review/integration evidence and complete a **non-external** objective. This operator cannot complete Studio/two-client/device objectives and reports `runtimeAuthorityPromoted: false`.

## Adversarial acceptance

The reusable V16 test kit currently proves at least:

- 30 simultaneous claims produce one winner;
- duplicate implementation is suppressed;
- explicit tournaments converge and supersede losers;
- blockers cannot be closed with evidence-free green claims;
- rabbit holes trigger convergence pressure;
- changed paths stale bound evidence;
- fake Studio truth is rejected;
- merge train candidates serialize;
- integration failure remains actionable;
- captain loss does not deadlock scheduling;
- legacy claim/event authority remains preserved;
- external runtime truth remains blocked until explicit external evidence exists.

V16 is successful only when it improves coherent milestone completion without weakening the Reality-Grade or control-state truth boundaries that UNRENDERED already earned.
