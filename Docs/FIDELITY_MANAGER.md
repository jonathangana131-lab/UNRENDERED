# Fidelity Manager Contract

Issue #7 defines the pure policy/service boundary that chooses a WorldEntity representation fidelity without making Roblox Instances the source of truth.

## Fidelity meanings

- **F0 Potential** — deterministic/data-only possibility; no local representation required.
- **F1 Structural** — coarse topology/route/state presence.
- **F2 Render** — visible representation with cheap interaction.
- **F3 Interactive** — local physics/mechanisms/audio or similarly expensive interaction state.
- **F4 Hero** — highest-cost representation reserved for close, important, actively relevant entities.

The literal values intentionally match `Reality/WorldEntity` so the manager can drive that lifecycle contract without inventing a second identity model.

## Inputs

The default policy is deterministic and pure. It evaluates:

- distance,
- direct visibility,
- observation strength,
- time since interaction,
- significance/informational mass,
- network relevance,
- motion,
- entity relevance.

Thresholds are configuration, not hidden globals. Calling `evaluateTarget` with identical inputs and policy produces the same target fidelity.

The default thresholds are conservative bootstrap values for the permanent Physics Lab. They are not claimed as final Roblox performance limits; Studio/device profiling may tune configuration without changing the public contract.

## Transition lifecycle

`FidelityManager` owns transition stabilization and diagnostics, not Roblox representation objects.

A transition passes through:

1. target selection or an explicit `request`,
2. promotion/demotion hysteresis,
3. transition cooldown,
4. for demotion only, `captureBeforeDemotion`,
5. `applyTransition`,
6. metrics/state update only after the adapter succeeds.

A failed capture blocks demotion. This prevents a cheap representation from replacing an interactive/hero representation before meaningful mutable state has been handed back to the WorldEntity lifecycle/persistence layer.

Every request carries a non-empty reason. The manager retains the last successful transition reason per registered entity for diagnostics. Policy-driven transitions use `policy`.

## Adapter boundary

The manager is Studio-independent. Roblox realization belongs behind `TransitionAdapter`:

- `captureBeforeDemotion(entityId, from, to)` must return plain persistent state suitable for the WorldEntity contract.
- `applyTransition(entityId, from, to, capturedState)` performs the domain lifecycle update and representation realization/destruction appropriate to the target.

Production adapters should call the WorldEntity transition contract first/atomically with representation work as appropriate. They must not serialize arbitrary Instances as persistent state.

## Anti-thrashing behavior

A target/reason must remain stable for its configured hold window before transition. Promotions and demotions have separate hold windows; demotion is intentionally slower by default. A post-transition cooldown prevents rapid reversal.

Time is injected as `nowSeconds` rather than read from a global clock, making transition decisions reproducible in pure tests. Per-entity timestamps must be monotonic.

## Diagnostics

Metrics are fixed-size apart from one entry per registered WorldEntity:

- registered entity count,
- current F0–F4 counts,
- total promotions/demotions/transitions,
- hysteresis and cooldown blocks,
- capture/transition failures,
- last successful transition reason per entity.

Unregistering an entity removes its per-entity diagnostic reason. The manager stores no unbounded transition history or work queue.

## Performance expectations

Policy evaluation and a transition request are **O(1)** per entity. Memory is **O(number of registered active entities)** with one small state record per entity; no Roblox Instance references are retained by the pure manager.

Do not evaluate every dormant F0 entity every render frame. Region/interest systems should register/evaluate entities at a cadence appropriate to relevance and feed this manager changed observations. Global CPU/rigidbody/constraint budgets and prioritization can layer above this contract once measured Physics Lab data exists; they should not make identity or persistent state depend on representation lifetime.
