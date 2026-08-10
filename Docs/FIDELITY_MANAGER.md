# Fidelity Manager

The Fidelity Manager is the pure-domain policy boundary that decides how much physical representation a stable WorldEntity needs. It sits above Roblox Instance Streaming and never treats a live Instance as identity or canonical state.

## Fidelity levels

- **F0 Potential** — deterministic/domain data only; no physical representation required.
- **F1 Structural** — coarse topology/route representation.
- **F2 Render** — visible geometry and cheap interaction representation.
- **F3 Interactive** — physics, mechanisms, local audio/AI as applicable.
- **F4 Hero** — intentionally expensive close interaction and highest-detail simulation.

The manager accepts an externally supplied stable entity ID. It does not create IDs, own persistence, or inspect Roblox Instances.

## Policy inputs

The default policy consumes only plain data:

- distance in studs,
- observation strength in `[0, 1]`,
- seconds since meaningful interaction,
- significance in `[0, 1]`,
- network relevance in `[0, 1]`.

The policy is deterministic for identical inputs and configuration. Thresholds are explicit in `FidelityManager.defaultConfig()` and can be replaced by a validated configuration profile.

Recent close interaction is the only default route directly to F4. Strong observation, significance, or network relevance can retain F3 without making every important object hero-fidelity. Render and structural distance thresholds provide the normal fallback.

## Explicit requests and reasons

Each update may include one explicit request with a non-empty reason:

- `at-least` establishes a minimum fidelity floor, for example a radio/network session that must remain interactive.
- `at-most` establishes a maximum fidelity ceiling, for example a higher-level server budget controller reducing expensive simulation.

The resolved reason is returned with every update result so diagnostics can explain why an entity wants its current target.

Higher-level budget schedulers should remain deterministic in how they select entities before issuing `at-most` requests. The core manager intentionally does not retain an unbounded priority queue or transition history.

## Anti-thrashing behavior

A target change becomes pending before transition. Promotion and demotion hold times are configurable independently, and every completed transition starts a cooldown before another transition can occur.

The default configuration uses a short promotion hold and a longer demotion hold so brief relevance loss does not unload an object that is about to become relevant again. Repeated identical inputs and timestamps produce identical transition decisions.

## Representation adapter

Roblox realization stays behind two optional callbacks:

1. `captureBeforeDemotion(entityId, fromLevel, toLevel)` runs before any lower-fidelity realization change and may return plain captured state.
2. `applyTransition(entityId, fromLevel, toLevel, capturedState)` performs the representation change outside the domain policy.

The manager does not serialize Instances. Captured state is retained on the tracked entity and is passed back to future realization callbacks. If capture or realization throws, the manager has not yet committed the new fidelity level, so callers can fail the operation rather than silently losing canonical state.

Adapters may instantiate/destroy Parts, models, constraints, sounds, or other Roblox presentation, but those operations must not move identity into Workspace.

## Metrics and lifetime

`getMetrics()` exposes bounded counters only:

- registered entities,
- current F0–F4 counts,
- total transitions,
- promotions,
- demotions,
- hysteresis blocks,
- cooldown blocks.

No per-transition history is retained. Per-entity state is constant-size and includes current/pending level, timestamps, pending reason, and latest captured state. Call `unregister()` when an entity leaves the manager's authority set so the tracked-entity map remains bounded by the active simulation set.

## Performance expectations

Policy evaluation and each manager update are **O(1)** time and allocate no growing history. Manager memory is **O(active tracked entities)** plus adapter-owned captured state.

The manager does not perform global scans. A region/streaming scheduler should update only entities whose relevance inputs changed or whose pending hysteresis/cooldown deadline needs evaluation. Global F3/F4 budget selection belongs in a measured higher-level scheduler that can rank the currently relevant set and issue explicit `at-most` requests without embedding furniture-, character-, or region-specific rules into this core.

Before large-scale use, profiling should track active entity count, update frequency, F0–F4 counts, transition rate, and hysteresis/cooldown block rates. High transition rate is a jank/performance signal, not something to hide by increasing thresholds blindly.
