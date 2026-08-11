# Swarm Control Plane V2

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

A lane claim declaring a resource is invalid without a matching live resource lease carrying the same worker, lane, and claim token.

Acquire multiple resources in increasing `order` from the resource definitions. If any acquisition fails, release what was acquired and choose another slot. This prevents deadlock cycles.

## Structured events

Events are immutable and collision-resistant:

`.swarm/events/YYYY-MM-DD/<event-id>.json`

Publish an event when another worker would act differently after reading it.

Supported event families include FINDING, BLOCKER, EXTERNAL_BLOCKER, DEPENDENCY_DISCOVERED, QUESTION, ANSWER, DECISION, REVIEW_REQUEST, REVIEW_RESULT, HANDOFF, SCOPE_CHANGE, EVIDENCE_RESULT, SUPERSEDED, INTEGRATION_RESULT and RECOVERY.

Do not publish private chain-of-thought. Publish concise conclusions, evidence, blockers and next actions.

## Lane states

Typical lifecycle:

`PROPOSED → READY → CLAIMED/IMPLEMENTING → REVIEW → INTEGRATION_READY → MERGED → VERIFYING → DONE`

Side states include NEEDS_CHANGES, BLOCKED, BLOCKED_EXTERNAL, LOCKED, SUPERSEDED and CANCELLED. Staleness is derived from leases.

Dependencies are machine-readable. If an upstream lane is not in an acceptable state, downstream slots are not ready.

## Slots

A lane may contain complementary roles such as `primary`, `tests-1`, `reviewer-1`, `performance`, `evidence`, and `integration`.

One lane can therefore use several Sol workers without several Sol workers building the same implementation.

Reviewer slots may declare `requiresIndependentFrom: primary`; validation rejects the same worker owning both live slots.

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

The scheduler deliberately withholds new primaries when the review backlog or primary-WIP limit is saturated.

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

If the generated board is wrong, rebuild it from authoritative state. Never edit generated files as source of truth.
