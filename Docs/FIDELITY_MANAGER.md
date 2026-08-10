# Fidelity Manager

The fidelity manager is the project-owned policy layer above Roblox Instance Streaming. It decides how much physical/visual simulation a `WorldEntityId` deserves without owning that entity's identity or requiring a Roblox `Instance` to exist.

## Levels

- **F0 Potential** — identity/recipe only; no physical representation required.
- **F1 Structural** — topology/coarse state needed for world truth and routing.
- **F2 Render** — visible representation with cheap interaction/state.
- **F3 Interactive** — active physics, mechanisms, audio, and other nearby interaction costs.
- **F4 Hero** — highest-cost representation reserved for close, important, actively interacted-with, or network-relevant entities.

`src/shared/Physics/FidelityManager.luau` keeps this state as plain data. Issue #4 remains the owner of the `WorldEntity` identity/lifecycle contract; realization code should adapt that contract to the manager rather than creating a second identity system.

## Policy inputs

The initial deterministic policy considers:
- distance,
- whether truth has been observed,
- time since interaction,
- significance/informational mass proxy,
- network relevance,
- whether the entity is moving.

The policy deliberately uses both threshold hysteresis and transition cooldowns. An entity already at a level gets a small release margin, while a lower-fidelity entity must cross the normal entry threshold. This prevents boundary oscillation without permanently pinning expensive states.

## State capture and realization boundary

The manager never serializes Instances. A realization adapter may provide:
- `captureState(entityId, fromLevel, toLevel)` — invoked before any demotion,
- `applyTransition(entityId, fromLevel, toLevel, snapshot)` — performs the representation change.

If either adapter callback errors, the registry has not yet committed the level/count transition. This keeps policy state from claiming a representation transition that did not complete.

Captured state is retained on the entity record and is supplied to later promotions so the representation layer can reconstruct meaningful mutable state.

## Metrics

The registry exposes:
- active entity counts at F0–F4,
- total transitions,
- promotions,
- demotions,
- transitions blocked by cooldown.

These are intentionally small counters suitable for the future diagnostics overlay and budget manager.

## Performance expectations

Policy evaluation is O(1) per entity and allocates no intermediate collections. Registry lookup/update is O(1) average-case by entity ID. The initial implementation validates numeric policy input at the boundary because correctness is more important than micro-optimizing an unmeasured hot path.

Callers should not blindly evaluate every known entity every frame. Region/interest systems should schedule bounded candidate updates, and later profiling should determine cadence by fidelity class. High-cost realization work stays behind the adapter and must be incremental/budgeted separately.

## Test expectations

Pure Lune tests cover deterministic target selection, threshold hysteresis, demotion cooldowns, capture-before-apply ordering, state preservation, and metrics accounting. Studio tests will be required once concrete Roblox realization adapters exist.
