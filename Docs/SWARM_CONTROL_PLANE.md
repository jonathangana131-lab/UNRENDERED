# Swarm Control Plane V2.1

UNRENDERED's worker swarm uses GitHub as a distributed control plane. This document explains the mechanics. `Docs/SWARM_PROTOCOL.md` is the worker-facing operating protocol.

## Branches

- `main`: product source, control-plane implementation, CI, architecture.
- `swarm-control`: live coordination state.

Never merge `swarm-control` into `main`.

## Live tree

```text
.swarm/
  config.json
  lanes/
  claims/<lane>/<slot>.json
  resource-claims/
  resources/
  workers/
  events/YYYY-MM-DD/
  handoffs/
  generated/board.json
  generated/dashboard.md
```

Generated files are observability only. The authoritative state is lane/resource definitions plus current claim/resource-claim files.

## Worker identity

Each Sol session creates a collision-resistant ID:

`sol-YYYYMMDD-<4..16 lowercase alphanumeric>`

A worker record is presence/observability. It does not grant ownership.

New worker records use exactly one canonical status: `WORKING`, `WAITING`, `REVIEWING`, `INTEGRATING`, `BLOCKED`, `IDLE`, or `STOPPED`.

The validator also accepts the finite historical aliases `ACTIVE`, `CLAIMING`, and `DONE` because those values already exist in audited control history. They are compatibility-only and must not be emitted by new producers. Unknown statuses remain invalid. Status compatibility never grants or extends lane/resource ownership.

## Lane claims

Before creating an implementation branch, atomically create:

`.swarm/claims/<LANE>/<slot>.json`

Required fields:

```json
{
  "schemaVersion": 1,
  "laneId": "HG151-TWOCLIENT",
  "slotId": "primary",
  "workerId": "sol-20260811-a81f",
  "claimToken": "0123456789abcdef",
  "claimedAt": "2026-08-11T04:30:00+00:00",
  "heartbeatAt": "2026-08-11T04:30:00+00:00",
  "leaseSeconds": 1800,
  "generation": 1,
  "resources": [],
  "branch": "agent/physics/HG151-TWOCLIENT-a81f",
  "pr": null
}
```

Creation must fail if the path already exists. Do not overwrite another live owner.

`claimToken` is a random non-secret fencing token and must also appear in the PR metadata. It is not a credential.

## Leases

A claim is live until `heartbeatAt + leaseSeconds`.

Heartbeat only at meaningful checkpoints such as a substantial push, before a long external validation wait, after review feedback, or before integration. Do not spam GitHub.

If a claim is stale, inspect the branch/PR/events/handoff first. Takeover must conditionally replace the stale file using its current Git blob SHA and increment `generation`. Two takeover workers racing on the same SHA must produce only one winner.

An old worker that wakes after takeover must re-read the claim. If token/generation/worker ownership changed, it is fenced and must not continue as primary.

## Scarce resources

Protected/high-contention work uses a second atomic resource lease. Exclusive resources use:

`.swarm/resource-claims/<RESOURCE>.json`

A lane claim declaring a resource is invalid at PR acceptance without a matching live resource lease carrying the same worker, lane, and claim token.

Acquire multiple resources in increasing `order` from the resource definitions. If any acquisition fails, release what was acquired and choose another slot. This prevents deadlock cycles.

## Structured events

Events are immutable and collision-resistant:

`.swarm/events/YYYY-MM-DD/<event-id>.json`

Publish an event when another worker would act differently after reading it.

Supported event families include FINDING, BLOCKER, EXTERNAL_BLOCKER, DEPENDENCY_DISCOVERED, QUESTION, ANSWER, DECISION, REVIEW_REQUEST, REVIEW_RESULT, HANDOFF, SCOPE_CHANGE, EVIDENCE_RESULT, SUPERSEDED, INTEGRATION_RESULT and RECOVERY.

New typed `REVIEW_RESULT` producers use the ordinary strict event envelope plus the top-level trio `pr`, `headSha`, and `verdict`:

```json
{
  "schemaVersion": 1,
  "eventId": "evt-20260812-example-review-result",
  "timestamp": "2026-08-12T08:30:00+00:00",
  "fromWorker": "sol-20260812-abcd",
  "eventType": "REVIEW_RESULT",
  "laneId": "LANE-A",
  "summary": "Independent exact-head review result.",
  "affects": ["LANE-A"],
  "pr": 423,
  "headSha": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  "verdict": "APPROVE"
}
```

The trio is atomic when used: `pr` is a positive integer, `headSha` is exactly 40 lowercase hexadecimal characters, and `verdict` is `APPROVE`, `REQUEST_CHANGES`, `BLOCK`, or `SUPERSEDE`. These top-level fields are event-specific and remain unknown/rejected on other event types. Older immutable review events are not rewritten merely to adopt the current producer shape.

Do not publish private chain-of-thought. Publish concise conclusions, evidence, blockers and next actions.

## Lane states

Typical lifecycle:

`PROPOSED → READY → CLAIMED/IMPLEMENTING → REVIEW → INTEGRATION_READY → MERGED → VERIFYING → DONE`

Side states include NEEDS_CHANGES, BLOCKED, BLOCKED_EXTERNAL, LOCKED, SUPERSEDED and CANCELLED. Staleness is derived from leases.

Dependencies are machine-readable. If an upstream lane is not in an acceptable state, downstream slots are not ready.

## Slots

A lane may contain complementary roles such as `primary`, `tests-1`, `reviewer-1`, `performance`, `evidence`, `integration`, `audit`, and `capacity-mining`.

One lane can therefore use several Sol workers without several Sol workers building the same implementation.

Reviewer slots may declare `requiresIndependentFrom: primary`; validation rejects the same worker owning both live slots.

## Capacity and externally blocked critical paths

V2.1 distinguishes **critical-path readiness** from **useful project capacity**.

A blocked Studio/Xcode/other scarce resource can make a critical-path primary unrunnable without making the rest of the active Epic useless. The control plane therefore supports bounded source-only `backfill` lanes and standing `capacity` mining roles.

Backfill lanes are not permission to broaden the roadmap. They must:

- stay inside an already-active/unlocked Epic;
- have narrow, non-overlapping source/test scopes;
- deepen existing systems through concrete defects, missing invariants, regressions, failure-path hardening, performance/diagnostic contracts, or integration gaps;
- avoid claims that require the unavailable external resource;
- never reinterpret source-only confidence as engine evidence.

Capacity-mining roles exist to prevent exhaustion of the static backfill list. A miner inspects a bounded shard of current source/tests/PR history/events and either:

1. publishes a concrete finding and proposes/creates a bounded one-shot lane; or
2. publishes that no actionable gap was found in that shard and releases the role.

This is decomposition and quality mining, not speculative feature invention.

### Green-main semantics

`mainHealth.status == GREEN` means only that canonical CI for the recorded head passed. It is **not** a scheduler terminal state and must never be rendered/interpreted as “all work complete.”

Likewise, `readySlots == 0` describes the currently materialized ordinary queue at one instant. It is not sufficient proof that no useful work exists. Worker protocol requires checking review/integration, stale recovery, active-Epic backfill and capacity mining before a no-work stop.

### Stress-test lesson

The first real ~25-worker burst after V2 activation registered roughly two dozen Sol workers successfully but yielded zero active claims because the only critical-path engine work was externally blocked and the board exposed no alternate capacity. That outcome proved duplicate prevention but failed throughput. V2.1 makes useful blocked-path capacity an explicit control-plane concern.

The desired burst behavior is:

```text
many Go workers
  → atomic competition for highest-value slots
  → losers reroute immediately
  → mix of primary/tests/audit/review/recovery/mining
  → no duplicate primary implementation
  → no mass "green and stop" collapse
```

It is acceptable for some workers to become idle after the useful queue is genuinely exhausted. It is not acceptable for the whole swarm to treat healthy CI as completion while source-only depth work remains.

## PR metadata

Every new post-rollout swarm PR contains exactly these lines somewhere in the body:

```text
Swarm-Lane: HG151-TWOCLIENT
Swarm-Slot: primary
Swarm-Worker: sol-20260811-a81f
Swarm-Claim-Token: 0123456789abcdef
Control-Schema: 1
```

The PR head must match the branch in the live claim.

CI checks changed files against lane/slot scopes. Tests and relevant docs are generally allowed adjacent to implementation; unrelated production subsystems are not.

Protected scopes require their named resource lease.

## Scheduler

On a checked-out `swarm-control` state:

```bash
python3 tools/swarm/swarmctl.py validate --root .swarm
python3 tools/swarm/swarmctl.py recommend --root .swarm
python3 tools/swarm/swarmctl.py render --root .swarm
```

The control-branch workflow regenerates `generated/board.json` and `generated/dashboard.md`.

Scoring favors high priority, dependency fan-out, review when review backlog is high, integration when integration-ready, and work that fits WIP/resource availability.

The scheduler deliberately withholds new primaries when the review backlog or primary-WIP limit is saturated. Non-primary test/audit/mining capacity may remain available so unused Sol capacity can deepen the active Epic without multiplying implementations.

## Intentional competition

Normal lane mode is `exclusive`.

If independent competing approaches are genuinely valuable, define an explicit `tournament` lane with bounded candidate slots and an independent judge/synthesis slot. Accidental duplicate PRs are not tournament mode.

## Project-state writer

`Docs/PROJECT_STATE.md` is still the strategic unlock board, but it is a protected scope. Only a worker holding the `PROJECT-STATE` resource may modify it. Evidence workers publish structured evidence events; one temporary reconciler consumes accepted events and updates strategic state.

## Security

The control plane never runs request-supplied code.

Control JSON rejects executable-looking fields. Do not put tokens, cookies, credentials, local commands, arbitrary shell, arbitrary Luau, or arbitrary Mac paths into control state.

Studio/Xcode execution remains behind separate fixed-preset private bridges.

## Recovery

When control CI is red:
1. stop new primary implementation claims;
2. preserve current product branches;
3. repair control data/tooling with one dedicated recovery lane;
4. validate deterministic tests;
5. rebuild generated state;
6. resume scheduling.

When the product critical path is externally blocked but control/main are healthy:
1. keep the blocker explicit and forbid speculative retries;
2. expose source-only backfill roles on the current active Epic;
3. expose review/recovery/audit roles;
4. use standing capacity miners to derive additional bounded nonduplicate work as needed;
5. stop workers only after those categories are genuinely exhausted.

If the generated board is wrong, rebuild it from authoritative state. Never edit generated files as source of truth.