# FidelityManager private-state ownership finding

Status: bounded Hero-Gate capacity-mining finding. This document records a source-level ownership/bounded-state gap; it does not unlock or implement a new feature.

## Finding

`FidelityManager.new()` returns the same mutable table that directly owns the manager's policy config, per-entity temporal state, and mutable aggregate metrics:

- `config`
- `_states`
- `_metrics`

The constructor freezes the copied `config` table itself, but it does not freeze the returned manager table or hide `_states` / `_metrics` behind closure-private storage. `Manager` is exported from the structural `ManagerImpl` shape, and at runtime Luau table fields remain reachable regardless of underscore naming.

The retained hardening lineage in PR #385 validates config/input values and makes accepted transition callbacks transactional, but it preserves this storage shape. The registration-capacity successor in PR #419 adds a project-owned maximum configuration ceiling, but it is stacked on the same mutable manager object and does not close this ownership boundary.

A caller that bypasses static typing (for example through `any`, dynamically loaded code, or an accidental internal mutation) can therefore change manager-owned state without passing the validated capability methods. Source-derived examples include:

```luau
local config = table.clone(FidelityManager.defaultConfig())
config.maxRegisteredEntities = 1
local manager = FidelityManager.new(config)
manager:register("entity:a", "F0")

-- Runtime-reachable backing state: no capability/method boundary is crossed.
(manager :: any)._metrics.registered = 0
manager:register("entity:b", "F0")
```

`register()` checks capacity against `_metrics.registered`, so this mutation can make a manager retain more entity records than its configured capacity while aggregate accounting no longer describes the actual `_states` population.

Likewise, direct `_states` mutation can create/remove or rewrite temporal fidelity records without registration/unregistration accounting, and rebinding `(manager :: any).config` can replace the constructor-owned frozen policy object. The public methods subsequently trust these manager fields as their owned state.

This is a source inspection finding, not an executable test result. This connector-only mining pass did not run Luau locally.

## Why this matters

The Fidelity Manager is explicitly responsible for bounded per-entity temporal state and aggregate diagnostics while `WorldEntity` remains the authoritative lifecycle record. If callers can mutate the manager's backing maps/counters directly, the advertised registration envelope is not actually an ownership boundary: boundedness, F0-F4 count accounting, pending/hold state, transition fences, and synchronization diagnostics can be changed independently of the methods that enforce their invariants.

The issue is not that callers are expected to be malicious. Production module boundaries need to prevent ordinary aliasing or future adapter code from becoming a second writer to invariant-bearing state. `WorldEntity` already treats registry backing records and diagnostic history as closure-private for the same reason, and retained Physics Lab runtime synthesis uses closure-private state plus a frozen public facade.

## Existing coverage and non-duplication

This finding is distinct from current Fidelity work:

- PR #385 owns malformed config/input validation, rejected-step atomicity, callback transactionality, same-entity reentry fencing, and nested unwind/retry coverage;
- PR #398 adds cross-entity transition isolation coverage on the retained #385 lineage;
- `HG-FIDELITY-REGISTRATION-CAPACITY-CEILING` / PR #419 owns the maximum accepted value of `maxRegisteredEntities`, not ownership of the resulting manager storage;
- the prior `fidelity-extra-keys` capacity finding concerns undeclared keys in `PolicyConfig` / `PolicyInputs`, not post-construction mutation of manager-owned storage;
- entity-ID boundary and deterministic-order regressions exercise public operations and do not prove backing storage is unreachable.

Repository PR/issue searches for a FidelityManager private-state, frozen-facade, or backing-storage ownership repair did not surface a dedicated existing lineage.

## Recommended bounded follow-up

Do not add a second Fidelity implementation. When the scheduler explicitly unlocks Fidelity source work, absorb this invariant into the retained Fidelity successor lineage (after reconciling #385 / #419 and any accepted extra-key work).

A narrow source-only repair should:

1. move mutable per-manager backing state (`config`, entity states, metrics) behind a project-owned private capability boundary rather than storing it on caller-reachable facade fields;
2. expose only the intended manager operations and immutable snapshots/config needed by callers;
3. make the public manager facade immutable so field injection/rebinding cannot create shadow state or replace methods/config;
4. preserve O(1) policy/step/register/unregister behavior and the existing bounded registration envelope;
5. preserve the authoritative-WorldEntity boundary: hiding FidelityManager internals must not make the manager the durable lifecycle source of truth;
6. add adversarial regressions proving attempted public facade mutation and direct backing-state access cannot change registrations, counts, pending/cooldown state, transition fences, or policy config;
7. retain #385's failed-callback/retry and cross-entity semantics and #419's exact capacity-ceiling behavior;
8. make no Roblox Instance, persistence, networking, Studio, viewport, contact, or two-client claim.

A closure-private weak-key backing map plus frozen facade is one already-used project pattern, but the implementation choice should be made by the unlocked Fidelity source lane so it can preserve type ergonomics and the retained transition lineage without introducing a competing framework.

## Scope

Finding branch started from `main@af6a17aa7969d40e8b19f7e9d19fe93cc9b1d9a9` and audited retained Fidelity PR #385 exact head `827ce0cf63ca5f322502de883beb9f43581c69f2` plus capacity successor PR #419 exact head `1f017628bf49365663dfc2db3a30b81ba477a0a3`.

This document changes no production source, F0-F4 policy, config schema, WorldEntity identity, registration budget, metrics behavior, persistence, networking, Roblox Instance realization, Studio harness, viewport, physical contact, or multiplayer behavior. It does not unlock Door, Chair, or Player work.