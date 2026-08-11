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

When a transition becomes eligible, `step` requires an `applyTransition` callback. The callback runs **before** the manager updates its mirror or metrics. A production adapter should perform the `WorldEntity.transition` there and then realize/demote Roblox representation as appropriate.

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

All time is supplied explicitly by the caller. The policy contains no hidden clock and is deterministic for identical state/config/input/time sequences.

Significance alone only keeps distant state at F1 by default. Inside render range, unseen significance still does not force F4. Hero fidelity requires close active demand or exceptional relevance that is actually visible.

## Transition reasons

Every policy evaluation returns both a desired fidelity and a deterministic primary reason. `step` exposes that reason in its result and supplies it to the transition callback when a transition commits.

Reasons are bounded categorical diagnostics rather than durable state:

- `distance`,
- `visibility`,
- `observation`,
- `interaction`,
- `significance`,
- `network-relevance`,
- `entity-relevance`,
- `no-demand`.

The reason explains the strongest deterministic cause selected by the current policy. It can be logged, profiled, or used by a realization adapter for diagnostics, but it does **not** own lifecycle truth.

Most importantly, anti-thrashing hold state is keyed to the **target fidelity only**, not to the reason. If network relevance requests F3 and direct observation requests the same F3 on the next evaluation, the original hold continues rather than restarting. This prevents a stable target from starving under changing causes. The deterministic regression suite locks this behavior.

## Anti-thrashing

Three mechanisms protect fidelity from oscillation:

1. distance hysteresis expands the current authoritative level's distance boundary before demotion,
2. promotion and demotion candidates must survive configurable hold durations,
3. a post-transition cooldown blocks immediate reversal.

The default values are an initial Foundation-Lock profile, not permanent world-scale tuning. Studio/device profiling may tune profiles later without changing the F0-F4 contract.

## Bounded state and metrics

The manager has a configurable `maxRegisteredEntities` hard budget (4096 by default). Configuration may lower or raise that runtime budget, but it may never exceed the project-owned `FidelityManager.MAX_REGISTERED_ENTITIES` safety ceiling of 65,536 records. The ceiling prevents a caller from turning a finite-looking configuration into an effectively unbounded `_states` table.

That 65,536 ceiling is a defensive source-level envelope, **not** a claim that a target device can sustain that many active fidelity records. Measured runtime/device profiles should normally choose a lower budget and remain responsible for frame-time and memory evidence. Changing the safety ceiling itself is an explicit project contract change rather than ordinary profile tuning.

Registration beyond the configured capacity fails closed and increments an observable rejection counter. Callers must unregister entities when their interest/streaming ownership ends.

The manager exposes bounded aggregate metrics:

- registered entity count and current mirrored F0-F4 counts,
- manager-coordinated transitions/promotions/demotions,
- successful transition-hook calls,
- hold/cooldown/missing-transition blocks,
- external authoritative synchronizations,
- registration-capacity rejections.

It intentionally stores no transition-history queue and no world-sized entity data beyond the bounded registered set.

## Performance expectations

Policy selection and `step` are O(1) for one registered entity. The manager stores one small temporal/diagnostic state record per registered entity plus aggregate counters, with total records capped first by the caller-selected runtime budget and absolutely by the project-owned safety ceiling.

Callers should register/evaluate only entities relevant to current streaming/interest work rather than scan the conceptual universe every frame. Later device profiling can tune both capacity and evaluation cadence under explicit frame/memory budgets without changing the F0-F4 contract or bypassing the source-level safety ceiling.

## Integration flow

1. WorldEntity/interest owner supplies entity ID, current authoritative fidelity, and policy inputs.
2. Fidelity Manager evaluates desired F0-F4 plus a deterministic primary reason and applies hysteresis/holds/cooldown.
3. When eligible, the manager invokes `applyTransition` with the reason before touching its own mirror.
4. The callback applies `WorldEntity.transition`; demotion includes captured persistent state.
5. After the callback succeeds, manager counters/mirror commit to the same level.
6. A Roblox realization adapter promotes/demotes the physical representation without changing domain identity.

No furniture-specific, character-specific, persistence-service, networking-service, or Roblox rendering logic belongs in the core manager.
