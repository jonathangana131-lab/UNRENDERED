# Fidelity Manager

Issue #7 defines the first production F0–F4 promotion/demotion policy. The manager decides representation demand; it does not own WorldEntity identity, durable state, or Roblox Instances.

## Responsibility boundary

`WorldEntity` remains the domain source of truth for stable identity, current fidelity, state/representation revisions, and persistent state. `FidelityManager` keeps only a bounded control-plane mirror needed for cooldowns, hysteresis, and metrics.

Authority crosses the boundary explicitly:

- `track(entityId, initialFidelity)` registers the current authoritative WorldEntity fidelity.
- `captureState(entityId, from, to, reason)` captures meaningful durable state before an accepted demotion.
- `transition(entityId, from, target, capturedState, reason)` applies the authoritative WorldEntity transition and performs/queues representation work behind the adapter boundary.
- `resync(entityId, authoritativeFidelity, nowSeconds)` reconciles the manager when another trusted subsystem changed WorldEntity fidelity outside the manager.

Requests for untracked entities are rejected. The manager never discovers authority by scanning Workspace, never serializes an Instance, and never owns a second entity registry.

## Fidelity levels

- **F0 Potential** — deterministic/domain state only; no physical representation required.
- **F1 Structural** — coarse topology/route or structural presence.
- **F2 Render** — visible representation with cheap interaction.
- **F3 Interactive** — active physics/mechanisms/audio/local behavior.
- **F4 Hero** — intentionally expensive high-detail behavior for active interaction or strongly observed, highly significant content.

Fidelity changes representation cost, not WorldEntity identity.

## Policy inputs

The pure policy consumes:

- `distanceStuds` — non-negative physical/interest distance,
- `observation` — normalized 0–1 strength of current observation,
- `interaction` — normalized 0–1 current/recent interaction relevance,
- `significance` — normalized 0–1 informational importance,
- `networkRelevance` — normalized 0–1 multiplayer/network interest.

The policy takes the strongest required fidelity rather than averaging unrelated signals. For example, distance may only require F1 while active interaction requires F4; the interaction requirement wins. A highly significant object reaches F4 only while strongly observed, preventing significance alone from permanently pinning expensive representation.

Thresholds and transition timing live in an immutable manager config so later device/server profiles can tune the same contract without changing call sites.

## Hysteresis and cooldowns

Promotions are responsive but use a short promotion cooldown to prevent repeated upward churn. Demotions are conservative:

1. the requested lower target must remain stable for `demotionGraceSeconds`,
2. the previous transition must be outside `demotionCooldownSeconds`,
3. the adapter must successfully capture state,
4. only then may the authoritative transition occur.

Demotion stability is keyed by target fidelity, not diagnostic reason. A reason can change from distance to network or observation while the same lower target continues its grace window. If the lower target itself changes, the grace window restarts. Any equal-fidelity request or promotion clears the pending demotion. Timestamps must be monotonic per entity so a bad clock cannot bypass hysteresis.

A trusted external fidelity change must call `resync` with its authoritative fidelity and timestamp. Resync resets pending demotion state and treats that external change as the latest transition for cooldown purposes.

## Transition reasons and bounded diagnostics

Every request carries a non-empty reason. The built-in policy emits `distance`, `observation`, `interaction`, `significance`, `network`, or `idle`. Explicit callers may use a more specific reason string for adapter/debug context.

Metrics never retain arbitrary reason strings. Successful transitions are counted in seven fixed buckets: the six built-in reasons plus `other`. This keeps reason diagnostics bounded even if callers supply high-cardinality custom reasons.

The manager exposes a fixed-size snapshot containing:

- tracked entity count,
- F0–F4 counts,
- total promotions/demotions,
- state captures,
- cooldown and hysteresis blocks,
- external authoritative resyncs,
- the seven fixed transition-reason counters.

## Performance expectations

`track`, `request`, `update`, `resync`, `untrack`, and `getMetrics` are O(1). Normal policy/update work contains no Workspace traversal, raycast, Instance creation, persistence I/O, registry scan, or authoritative read callback. Capture and transition callbacks run only when a transition is actually accepted.

Callers should evaluate only entities whose relevance is being serviced by the project-owned streaming/simulation scheduler. This contract is not permission to loop over an unbounded universe each frame. Future budget schedulers may choose which entities receive updates, but they should continue to request transitions through this manager rather than bypassing hysteresis/state capture.

## WorldEntity integration

The adapter maps directly to the production WorldEntity lifecycle contract:

- registration supplies `record.fidelity` to `track`,
- `captureState` extracts meaningful mechanism/physics state from the current physical representation,
- `transition` verifies its `from` value against the authoritative record, calls `WorldEntity.transition`, passes fresh captured state on demotion and no capture on promotion, then realizes/destroys Roblox representation through a separate renderer/physics adapter,
- a trusted direct WorldEntity transition is followed by `resync(record.fidelity, timestamp)`.

The manager updates its mirror only after the transition adapter returns successfully. A production adapter should throw rather than silently ignore a failed authoritative transition. The integration regression test uses the real `WorldEntity` module and verifies the mirror's `from` fidelity against the authoritative record before every transition, plus `representationRevision` and `stateRevision` changes.

The manager deliberately does not require a furniture, character, networking, or persistence implementation. Those systems provide relevance signals and adapters without changing the core policy.

## Determinism

For identical starting fidelity, config, policy inputs, request reasons, and timestamps, transition decisions are deterministic. Pure Lune tests cover policy selection, cooldowns, target-stable demotion grace, state-capture ordering, WorldEntity integration, explicit resynchronization, bounded metrics, rejection of untracked requests, and repeated identical sequences.
