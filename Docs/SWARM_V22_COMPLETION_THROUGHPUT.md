# Swarm V2.2 — Completion Throughput

V2.2 keeps the V2/V2.1 ownership, lease, resource, digest, exact-head and fail-closed invariants. It changes how capacity is routed when implementation output is arriving faster than accepted changes reach `main`.

## Goal

Optimize retained, reviewed, merged value rather than branch count or PR count. A healthy swarm may have fewer active implementers when the completion queue is already large.

## Completion pressure

The control plane derives completion backlog from live non-stale PR-bearing claims and real product lanes in `REVIEW`, `NEEDS_CHANGES`, or `INTEGRATION_READY`. Synthetic completion-queue lanes are excluded from the backlog count so they cannot permanently throttle the project after real work drains.

Default pressure bands:

- `NORMAL`: backlog below 4. Explicit completion queues stay hidden; normal scheduling applies.
- `SOFT`: backlog 4–7. Review/integration/reconciliation is strongly boosted and new creation is deprioritized.
- `HARD`: backlog 8+. Normal new primary implementation, new adversarial-test slices, READY-lane audits, and capacity mining are suppressed. Completion, red-main and control-repair work remain runnable.

The dashboard exposes `outstandingPRClaims`, `completionBacklog`, `completionPressure`, and `creationThrottle`.

## Review depth

Every new controlled PR created on or after `scheduler.v22ActivatedAt` must contain:

```text
Swarm-Self-Review: PASS
Swarm-Self-Review-Head: <exact 40-hex PR head SHA>
```

The implementer must reread and adversarially inspect the exact candidate diff before publishing `PASS`. Moving the head invalidates the self-review until it is repeated and rebound.

Risk is derived from changed paths and lane tags:

- **LOW** — bounded docs/tests-only work without a critical trust tag: self-review + exact-head CI + ownership/resource gates. No ceremonial second Sol is required.
- **STANDARD** — ordinary production source: self-review plus one independent exact-head `SPOT` or `FULL` approval.
- **CRITICAL** — Reality/identity/schema/persistence/server authority/multiplayer/security/control-plane or other trust-boundary work: self-review plus an independent exact-head `FULL` approval.

An independent approval is a strict immutable `REVIEW_RESULT` event whose metadata binds the exact PR number, exact head SHA, `verdict: APPROVE`, and review `depth`. Its `fromWorker` must differ from the implementation worker. A complementary adversarial worker may satisfy this requirement if it actually reviewed that exact candidate head.

PRs created before the activation timestamp are grandfathered under the prior review contract; V2.2 does not retroactively invalidate the existing backlog.

## Completion train

While completion pressure is active, fresh `Go` workers should prefer the family completion queues:

- `HG-COMPLETION-AUTHORITY`
- `HG-COMPLETION-PHYSICS`
- `HG-COMPLETION-REALITY`
- `HG-COMPLETION-CONTENT`

Each family exposes review, integration and reconciliation roles. Their job is to:

1. inspect exact current heads and retain the strongest non-overlapping work;
2. request/fix only real blocking changes;
3. rebase or reconstruct onto current `main` when necessary;
4. merge as soon as required exact-head gates are satisfied;
5. close/supersede stale duplicate lineages after useful commits/findings are retained;
6. publish durable review/integration/recovery events that change how other workers act.

Support/test/audit workers should prefer durable findings or commit handoffs into the retained lane lineage when that is safe. A separate main-targeting PR is not a success metric.

## What never changes

V2.2 does not bypass:

- atomic claim ownership or generation fencing;
- named protected-resource leases;
- trusted-base PR validation;
- validated-state digest fencing;
- red-main priority;
- exact-head CI requirements;
- independent review on critical trust boundaries;
- Roblox Studio evidence requirements;
- the external Studio/display blocker;
- Hero Gate / Hero Door unlock truth.

`GREEN` remains evidence, not completion. `HARD` completion pressure means finish what the swarm already produced before manufacturing more work.
