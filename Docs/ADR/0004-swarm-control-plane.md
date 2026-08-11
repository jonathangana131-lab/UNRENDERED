# ADR 0004 — GitHub-Native Swarm Control Plane V2

Status: Accepted

## Context

UNRENDERED is developed by many independent GPT-5.6 Sol worker sessions. The old swarm protocol had good policy — limited WIP, depth before breadth, inspect existing work, one major task per worker, independent review — but ownership was advisory. Multiple workers could read the same repository state before any peer published a branch or comment, then independently implement the same thing.

Recent repository history contains repeated examples: parallel Physics Lab validation implementations, multiple equivalent scheduler updates, duplicate evidence-consumption PRs, and several PRs closed only because another worker landed the same result first.

The problem is distributed coordination, not worker intelligence.

Separate ChatGPT sessions do not share volatile working memory. GitHub must therefore be the durable coordination substrate.

## Decision

Adopt Swarm Control Plane V2.

### Durable control branch

Live coordination state lives on the dedicated `swarm-control` branch, not on `main`.

`main` owns game/product source, control-plane code, schemas/validation behavior, CI enforcement, architecture and worker protocol.

`swarm-control` owns lane state, worker presence, atomic lane claims, atomic scarce-resource claims, immutable coordination events, handoffs and generated board/dashboard.

This keeps high-frequency coordination churn out of game history.

### Atomic ownership

Exclusive work uses one authoritative claim path per lane slot:

`.swarm/claims/<LANE>/<slot>.json`

Creation is atomic through GitHub contents/ref update semantics. A worker must successfully create or conditionally replace the claim before creating an implementation branch.

Claims are leases with heartbeat timestamps and generation numbers. Stale claims are takeover candidates. Takeover must use a SHA-conditional update so only one contender wins and the old owner is fenced by the changed claim generation/blob SHA.

### Scarce resources

High-contention resources use separate leases in `.swarm/resource-claims/`.

Examples include the project-state writer, swarm-protocol writer, reality identity contract, server-authority root and Studio evidence queue.

A lane claim that declares an exclusive resource is invalid unless a matching active atomic resource lease exists for the same worker/lane/claim token.

### Peer roles

There is no permanent manager model. GPT-5.6 Sol workers are peers with temporary slots such as primary implementation, tests/fuzz, adversarial review, performance/diagnostics, evidence, integration and scheduler reconciliation.

Exclusive lanes normally allow exactly one primary. Intentional independent competition must use an explicit bounded tournament lane.

### Event-sourced communication

Workers publish immutable structured events only when another worker would act differently after reading them: findings, blockers, dependency discoveries, review results, handoffs, evidence results, recovery and integration outcomes.

Generated dashboards are disposable projections. Claims and authoritative lane/resource state are the correctness boundary.

### Dependency and blocker propagation

Lane dependencies are machine-readable. Unsatisfied or blocked dependencies remove downstream work from the ready queue. External blockers remain explicit rather than causing repeated speculative retries.

### PR enforcement

After rollout, a new PR must carry:

- `Swarm-Lane`
- `Swarm-Slot`
- `Swarm-Worker`
- `Swarm-Claim-Token`
- `Control-Schema`

CI verifies the lane exists, the exact worker/token owns a live claim, the branch matches, the lane is writable, and changed files fit lane/slot scope.

Protected scopes additionally require a live matching scarce-resource lease.

### Scheduling

The scheduler ranks ready slots rather than asking workers to invent tasks. It considers lane priority, dependency fan-out, review/integration backlog, WIP caps, lane state and resource availability.

Idle is valid. When implementation outruns review/integration, new primary implementation is throttled.

## Security

Control-plane files are data, never executable requests.

Schemas reject executable-looking keys such as arbitrary `command`, `shell`, `script`, `python`, or `luau` payloads. The control plane does not broaden access to the private Studio or Mac developer bridges.

## Consequences

Positive:
- accidental duplicate implementation becomes structurally difficult;
- dead workers can be recovered without blind rewrites;
- discoveries and blockers propagate across separate chats;
- reviews and integration become first-class work;
- high-contention contracts have explicit ownership;
- project throughput can be measured without optimizing for raw line count.

Costs:
- workers must claim before branching and heartbeat at meaningful checkpoints;
- control-plane state has its own branch and CI;
- stale-lease and recovery semantics require discipline;
- the scheduler is intentionally conservative when ownership cannot be proven.

These costs are accepted because they replace much larger duplicate/rebase/review waste observed in the existing swarm.
