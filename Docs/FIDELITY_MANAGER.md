# Fidelity Manager

Issue #7 defines the production F0-F4 selection/anti-thrashing service. `WorldEntity` remains the authoritative lifecycle record; the Fidelity Manager never replaces it with a second domain state.

## Fidelity levels

- **F0 Potential** — seed/domain state only; no physical representation is implied.
- **F1 Structural** — topology/coarse route or keepalive state is required.
- **F2 Render** — visible/cheap representation is justified.
- **F3 Interactive** — physics, mechanisms, local audio, or similarly interactive simulation is justified.
- **F4 Hero** — highest-cost representation for close active observation, recent interaction, or exceptionally relevant visible state.

The manager chooses a desired level and coordinates when a transition is allowed. It does **not** create, destroy, serialize, or own Roblox Instances.

## Authority boundary

`src/shared/Reality/WorldEntity.luau` owns the authoritative `fidelity` value and the persistent-state lifecycle contract.

The manager stores only an observed fidelity mirror for diagnostics/counts plus temporal policy state (pending target, hold start, last evaluation, last committed transition). Every `step` receives the current authoritative fidelity from its caller.

If that current value differs from the manager's mirror, the manager synchronizes its diagnostic counts, clears stale pending work, and starts a cooldown from the synchronization point. This lets reconnects, reconstruction, or other legitimate lifecycle owners repair the manager without making the manager authoritative.

When a transition becomes eligible, `step` requires an `applyTransition` callback. The callback receives `(entityId, fromLevel, toLevel, reason)` and runs **before** the manager updates its mirror or metrics. A production adapter should perform the `WorldEntity.transition` there and then realize/demote Roblox representation as appropriate.

For demotion, `WorldEntity.transition` requires fresh captured persistent state. Therefore an unsafe demotion callback fails before the Fidelity Manager can commit its mirror. The pure integration test exercises this exact behavior.

## Policy inputs

`PolicyInputs` is plain data:

- distance,
- visibility,
- direct observation,
- time since interaction,
- significance,
- network relevance,
- entity relevance.

All evaluation time is supplied explicitly by the caller. There is no hidden clock or randomness. Configuration thresholds and evaluation timestamps must be finite. Policy distance and time-since-interaction inputs may use positive infinity to represent effectively absent proximity/interaction.

Significance alone only keeps distant state at F1 by default. Inside render range, unseen significance still does not force F4. Hero fidelity requires close active demand or exceptional relevance that is actually visible.

## Transition reasons

Every policy decision returns a typed deterministic reason describing the strongest rule responsible for the selected level:

- `potential`,
- `distance`,
- `visibility`,
- `observation`,
- `interaction`,
- `significance`,
- `network-relevance`,
- `entity-relevance`,
- `hero-proximity`,
- `hero-relevance`.

Reasons are carried in `PolicyDecision`, `StepResult`, and the transition callback so realization/diagnostics can explain why work was requested. They are ephemeral decision data; the manager does not retain an unbounded per-entity transition-reason history.

Reason precedence is deterministic. The same state/config/input/time sequence therefore yields the same target, reason, transition outcome, and aggregate transition metrics. The regression suite compares two independent managers executing an identical sequence.

## Anti-thrashing

Three mechanisms protect fidelity from oscillation:

1. distance hysteresis expands the current authoritative level's distance boundary before demotion,
2. promotion and demotion candidates must survive configurable hold durations,
3. a post-transition cooldown blocks immediate reversal.

Pending holds are keyed to the **target fidelity**, not the reason string. If the cause changes from network relevance to direct observation while both still request F3, the original F3 hold continues maturing instead of restarting. The transition callback receives the latest reason when the target finally commits.

The default values are an initial Foundation-Lock profile, not permanent world-scale tuning. Studio/device profiling may tune profiles later without changing the F0-F4 contract.

## Bounded state and metrics

The manager has a configurable `maxRegisteredEntities` hard budget (4096 by default). The budget must be a finite positive integer. Registration beyond that capacity fails closed and increments an observable rejection counter. Callers must unregister entities when their interest/streaming ownership ends.

The manager exposes bounded aggregate metrics:

- registered entity count and current mirrored F0-F4 counts,
- manager-coordinated transitions/promotions/demotions,
- successful transition-hook calls,
- hold/cooldown/missing-transition blocks,
- external authoritative synchronizations,
- registration-capacity rejections.

It intentionally stores no transition-history queue and no world-sized entity data beyond the bounded registered set.

## Performance expectations

Policy selection and `step` are O(1) for one registered entity. The manager stores one small temporal/diagnostic state record per registered entity plus aggregate counters, with total records capped by configuration.

Callers should register/evaluate only entities relevant to current streaming/interest work rather than scan the conceptual universe every frame. Later device profiling can tune both capacity and evaluation cadence under explicit frame/memory budgets without changing this contract.

## Integration flow

1. WorldEntity/interest owner supplies entity ID, current authoritative fidelity, and policy inputs.
2. Fidelity Manager evaluates a desired F0-F4 level plus deterministic reason, then applies hysteresis/holds/cooldown.
3. When eligible, the manager invokes `applyTransition` with the latest reason before touching its own mirror.
4. The callback applies `WorldEntity.transition`; demotion includes captured persistent state.
5. After the callback succeeds, manager counters/mirror commit to the same level.
6. A Roblox realization adapter promotes/demotes the physical representation without changing domain identity.

No furniture-specific, character-specific, persistence-service, networking-service, or Roblox rendering logic belongs in the core manager.
