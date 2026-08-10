# Fidelity Manager

Issue #7 defines the production policy service that chooses F0-F4 representation fidelity without changing WorldEntity identity.

## Fidelity levels

- **F0 Potential** — deterministic/domain potential only; no physical representation is implied.
- **F1 Structural** — structural/coarse state is relevant, but no rendered representation is required.
- **F2 Render** — a visible or otherwise presentation-relevant representation is justified.
- **F3 Interactive** — physics, mechanisms, local audio, or similarly active simulation is justified.
- **F4 Hero** — highest-cost representation for close active observation/interaction or exceptionally relevant locally presented state.

The manager owns policy and transition timing only. It does not create, destroy, serialize, or own Roblox Instances.

## Policy inputs and requests

`PolicyInputs` is plain data: distance, observation strength, time since interaction, significance, and network relevance. The policy contains no hidden clock; callers supply time explicitly, so identical input/config/state/time sequences produce identical decisions.

`FidelityRequest` provides an explicit `at-least` or `at-most` constraint with a required reason. This lets a system request temporary interactive fidelity for a grip, or impose an explicit budget cap, without embedding furniture/character rules in the manager. Every policy decision and transition result exposes the reason that selected or constrained its target level.

Significance alone only keeps distant truth structural by default. High significance or network relevance can justify F4 only when the entity is locally presented; distant relics do not consume hero physics merely because they are important.

## Anti-thrashing

Three mechanisms prevent oscillation:

1. distance hysteresis expands the release threshold for a level already held,
2. promotion and demotion targets must survive configurable hold durations,
3. a post-transition cooldown blocks immediate reversal.

Changing only the textual reason for the same pending level does not restart its hold timer.

## Demotion safety

Demotion cannot commit unless the configured `TransitionAdapter` supplies `captureBeforeDemotion`. Missing capture returns `capture-required` and preserves the current level.

When present, capture runs before `applyTransition`. An adapter can therefore snapshot mechanism/physics state into the owning WorldEntity/delta layer before simplifying or destroying physical Instances. If capture or realization throws, the manager has not yet committed its new level.

Promotion does not require capture. `applyTransition` is optional and is the narrow realization seam for Roblox-specific work; the core policy imports no Roblox API and owns no Instance.

## Metrics

The manager exposes aggregate, bounded-history metrics: registered entity count, current F0-F4 counts, transitions, promotions, demotions, capture calls, and hold/cooldown/capture blocks. It stores no transition history or global work queue.

The entity registry itself contains one small state record per entity deliberately registered by the upstream interest/streaming owner. That owner is responsible for unregistering entities that leave its working set; the Fidelity Manager is not a universe database.

## Performance expectations

Pure policy evaluation and one entity `step` are O(1). Metrics reads are O(1). No conceptual-world scan occurs inside this module.

Callers should evaluate only relevant/changed entities at a cadence selected by project-owned streaming/interest budgets. Later device profiling may tune thresholds, hold times, or scheduling without changing the F0-F4 contract.

## Integration flow

1. The WorldEntity/interest owner supplies identity plus policy inputs.
2. Optional subsystem requests constrain the target with an explicit reason.
3. The Fidelity Manager applies deterministic policy, hysteresis, hold, and cooldown rules.
4. Before any demotion, the adapter captures mutable state into the WorldEntity/delta boundary.
5. The adapter realizes the promotion/demotion in Roblox.
6. WorldEntity identity and durable state survive the representation change.
