# Fidelity Manager

Issue #7 defines the first production F0–F4 promotion/demotion policy. The manager decides representation demand; it does not own WorldEntity identity, durable state, or Roblox Instances.

## Responsibility boundary

`WorldEntity` remains the domain source of truth for stable identity, current fidelity, state/representation revisions, and persistent state. `FidelityManager` coordinates policy-driven transitions through an adapter:

- `getFidelity(entityId)` reads the authoritative current level.
- `captureState(entityId, from, to, reason)` captures meaningful durable state before a demotion.
- `transition(entityId, target, capturedState, reason)` applies the domain transition and performs/queues representation work behind the adapter boundary.

The manager never serializes an Instance and never scans Workspace.

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

The manager mirrors the last synchronized authoritative fidelity only for diagnostics/control timing. Every request re-reads the adapter's authoritative fidelity, and `refresh()` can resynchronize all tracked entries if another trusted system performed transitions.

## Performance expectations

Normal `update()`/`request()` work is O(1) per evaluated entity and contains no Workspace traversal, raycast, Instance creation, or persistence I/O. The hot path performs one authoritative fidelity read; capture and transition callbacks run only when a transition is actually accepted. `getMetrics()` is O(1) because its output cardinality is fixed. `refresh()` is intentionally O(tracked entities) and is for diagnostics/reconciliation, not per-frame use.

Callers should evaluate only entities whose relevance is being serviced by the project-owned streaming/simulation scheduler. This contract is not permission to loop over an unbounded universe each frame. Future budget schedulers may choose which entities receive updates, but they should continue to request transitions through this manager rather than bypassing hysteresis/state capture.

## WorldEntity integration

The adapter maps directly to the production WorldEntity lifecycle contract:

- `getFidelity` reads the record's authoritative F0–F4 value,
- `captureState` extracts meaningful mechanism/physics state from the current physical representation,
- `transition` calls `WorldEntity.transition`, passing fresh captured state on demotion and no capture on promotion, then realizes/destroys Roblox representation through a separate renderer/physics adapter.

The integration regression test uses the real `WorldEntity` module and verifies that accepted promotion/demotion requests preserve identity semantics while updating `representationRevision` and `stateRevision` through the authoritative contract.

The manager deliberately does not require a furniture, character, networking, or persistence implementation. Those systems provide relevance signals and adapters without changing the core policy.

## Determinism

For identical starting fidelity, config, policy inputs, request reasons, and timestamps, transition decisions are deterministic. Pure Lune tests cover policy selection, cooldowns, target-stable demotion grace, state-capture ordering, WorldEntity integration, bounded metrics, external resynchronization, and repeated identical sequences.
