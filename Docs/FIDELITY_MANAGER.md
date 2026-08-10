# Fidelity Manager

Issue #7 defines the first production F0-F4 fidelity policy without tying domain identity to Roblox Instances.

## Fidelity levels

- **F0 Potential** — seed/domain state only; no physical representation is implied.
- **F1 Structural** — topology/coarse route or keepalive state needed, but no visible representation is required.
- **F2 Render** — visible/cheap representation is justified.
- **F3 Interactive** — physics, mechanisms, local audio, or similarly interactive simulation is justified.
- **F4 Hero** — highest-cost representation for close active observation, recent interaction, or exceptionally relevant nearby state.

The manager chooses a desired fidelity level. It does **not** create, destroy, serialize, or own Roblox Instances. Realization remains behind a separate adapter so WorldEntity identity can survive representation changes.

## Policy inputs

`PolicyInputs` is plain data:

- distance,
- visibility,
- direct observation,
- time since interaction,
- significance,
- network relevance,
- entity relevance.

All time is supplied explicitly by the caller. The policy contains no hidden clock and is deterministic for identical state/config/input/time sequences.

Significance alone only keeps distant state at F1 by default; it does not make a far-away relic consume F4 physics. F4 requires local presentation relevance or close active demand.

## Anti-thrashing

Three mechanisms protect fidelity from oscillation:

1. distance hysteresis expands the current level's distance boundary before demotion,
2. promotion and demotion candidates must survive configurable hold durations,
3. a post-transition cooldown blocks immediate reversal.

The default values are an initial Foundation-Lock profile, not permanent world-scale tuning. Studio/device profiling may tune profiles later without changing the F0-F4 contract.

## Demotion safety

Every demotion is gated by `captureBeforeDemotion`.

If no capture hook is supplied, the manager returns `capture-required` and preserves the current level. When a hook exists, it runs **before** the fidelity level changes. An adapter can therefore capture mutable mechanism/physics state into the owning WorldEntity/delta representation before destroying or simplifying physical Instances.

The core manager does not define the captured payload. That belongs to the WorldEntity/representation boundary rather than this generic policy service.

## Metrics

The manager exposes bounded aggregate metrics:

- registered entity count,
- current F0-F4 counts,
- total transitions/promotions/demotions,
- successful capture calls,
- hold/cooldown/capture blocks.

It intentionally stores no unbounded transition history or global queue.

## Performance expectations

Policy selection and a manager `step` are O(1) for one registered entity. The manager stores one small state record per registered entity plus aggregate counters.

Callers should evaluate relevant or changed entities at an appropriate cadence rather than scanning the conceptual universe every frame. World streaming/interest systems remain responsible for deciding which entities are registered/evaluated. Later device profiling can schedule these evaluations under explicit frame budgets without changing the contract.

## Integration boundary

Expected flow:

1. WorldEntity/interest owner supplies current domain identity and policy inputs.
2. Fidelity Manager returns/commits the next F0-F4 state when hysteresis allows.
3. On demotion, the caller captures mutable state before the manager commits.
4. A Roblox realization adapter promotes/demotes the physical representation.
5. WorldEntity identity and persistent state remain independent from Instance lifetime.

No furniture-specific, character-specific, persistence-service, networking-service, or Roblox rendering logic belongs in this module.
