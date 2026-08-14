# Fidelity High-Cost Admission Budget Finding

## Finding

The current `FidelityManager` bounds how many entity records it retains, but it does not bound how many registered entities may simultaneously occupy or demand the expensive F3/F4 fidelity classes.

`PolicyConfig.maxRegisteredEntities` caps total manager records. `evaluatePolicy()` then chooses F0-F4 independently for one entity from distance, visibility, observation, interaction, significance, network relevance, and entity relevance. Neither `evaluatePolicy()` nor `step()` consults an aggregate F3/F4 admission budget before accepting a high-cost target.

This leaves a concrete source-level scalability gap: bounded manager state does not imply bounded expensive simulation demand.

With the default policy, every registered entity can independently request F4 when it is visible and has hero-level relevance. For example, `visible = true` plus `significance = 1` satisfies `visibleHeroDemand` regardless of distance. A manager at its ordinary default registration capacity can therefore have all 4096 registered entities independently select F4. The retained capacity successor in PR #419 adds a project-owned maximum registration envelope of 65,536 records, but it does not add an F3/F4 occupancy/admission envelope; a valid configuration at that ceiling can still admit every registered entity into an expensive class if its per-entity inputs demand it.

This is a contract/scalability finding, not a claim that the current 20-entity Physics Lab overloads a device. The permanent lab is intentionally tiny. The risk appears when the same production fidelity contract becomes the basis for larger streaming/interest populations.

## Why this matters

Project architecture defines F3 as interactive physics/mechanisms/audio/local AI and F4 as the highest-cost hero representation. `Docs/ARCHITECTURE.md` also assigns fidelity policy inputs, budgets, hysteresis, reasons, and target-fidelity timing to the Fidelity Manager boundary. The project quality canon requires configurable CPU, memory, Instance, rigidbody, constraint, light, audio, network, and generation budgets before scale.

The current manager provides a total-record memory bound and aggregate occupancy metrics, but the occupancy metrics are observational only. They do not prevent a demand spike from selecting F3/F4 for the full registered population.

That distinction is important:

- `maxRegisteredEntities` answers "how many policy records can exist?";
- a high-cost admission budget answers "how many expensive representations may be demanded/committed at once?".

Those are different safety properties.

## Non-duplication

This finding is distinct from the existing Fidelity lineages:

- PR #385 owns malformed input/config validation, rejected-step atomicity, callback transactionality, same-entity reentry fencing, and retry semantics.
- PR #398 adds cross-entity transition isolation coverage.
- PR #419 bounds the **total configured registration envelope**; it does not bound F3/F4 occupancy inside that envelope.
- PR #490 records mutable public manager backing-state ownership; it does not define admission limits for valid high-cost demand.
- the quarantined `fidelity-extra-keys` finding concerns undeclared `PolicyConfig` / `PolicyInputs` fields.
- issue #15 is a diagnostics/measurement overlay task; observing fidelity counts is not an admission-control contract.

Repository PR/issue searches on F3/F4 fidelity budgets, quotas, and simultaneous high-cost occupancy did not surface a dedicated existing repair.

## Source-derived repro

This finding does not require Roblox Studio execution.

Against current `FidelityManager.evaluatePolicy()` semantics, use default configuration and policy inputs equivalent to:

```text
distanceStuds = 900
visible = true
directlyObserved = false
secondsSinceInteraction = math.huge
significance = 1
networkRelevance = 0
entityRelevance = 0
```

The desired level is F4 because visible hero relevance is sufficient. The calculation is per entity and contains no aggregate budget check. Repeating the same valid demand across every registered entity is therefore not rejected or deferred by a project-owned F4 occupancy limit.

The same structural issue exists for F3: distance, observation/interaction, network relevance, or entity relevance can independently place every registered entity in interactive fidelity without an aggregate F3 admission ceiling.

## Recommended future leaf

Do not choose a magic F3/F4 count in this mining lane and do not silently make evaluation order determine which entities win.

A future explicitly unlocked Fidelity repair should first make the admission contract explicit. Acceptable architecture shapes include either:

1. the Fidelity Manager directly owns bounded F3/F4 admission budgets; or
2. a project-owned budget arbiter sits at the Fidelity Manager boundary and is the sole authority for admitting expensive target transitions.

Whichever shape is chosen should preserve these invariants:

- total registered state remains bounded by the existing registration envelope;
- F3 and F4 occupancy/cost demand has an explicit project-owned upper envelope independent of caller demand volume;
- arbitration is deterministic for identical world/policy state and does not depend on hash-table or call ordering;
- stable tie-breaking uses project-owned identity rather than Roblox Instance ordering;
- hysteresis/hold/cooldown behavior remains coherent when a desired promotion is budget-deferred;
- currently authoritative fidelity is not silently rewritten merely to make accounting fit;
- metrics distinguish raw demand, admitted occupancy, and budget-deferred/denied promotions;
- measured Studio/device profiles choose practical budgets below any defensive source-level ceiling;
- the tiny Physics Lab remains a permanent regression case rather than being used to justify world-scale numbers.

Focused Pure Luau regression targets should include oversubscribed F4 and F3 demand, deterministic winner stability under reversed evaluation order, release/re-admission after demotion/unregister, and aggregate accounting that never exceeds the configured high-cost envelope.

## Scope

This capacity-mining finding changes no production source, F0-F4 threshold semantics, WorldEntity truth, representation realization, networking, persistence, Roblox Instance behavior, Studio evidence, or project unlock state.

It does not unlock Door, Chair, Player, world generation, or any other gated Hero Feature. No local Luau, Roblox Studio, viewport, physical-contact, performance-device, or two-client execution is claimed.
