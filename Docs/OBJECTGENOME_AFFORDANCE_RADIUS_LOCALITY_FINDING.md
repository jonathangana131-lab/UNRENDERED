# ObjectGenome affordance radius locality finding

Status: bounded Hero-Gate capacity-mining finding. This document records a source-level contract gap; it does not unlock or implement a new feature.

## Finding

`ObjectGenome.inspect()` requires each affordance to reference a known component, requires `localPointM` to be a finite point inside that component's local bounds, and requires `radiusM` to be positive and finite. It does not constrain the radius relative to the referenced component, the manufactured object's envelope, or another project-owned physical locality bound.

That means an otherwise unchanged valid recipe can assign an arbitrarily large finite interaction radius while still satisfying the current affordance predicates. For example, starting from the canonical office-chair fixture and changing only:

```luau
mutated.affordances[1].radiusM = 1000000
```

leaves the affordance key, kind, component reference, and in-component local point unchanged, while `radiusM` remains positive and finite. By source inspection, the current validator has no subsequent affordance-radius locality check that would reject this mutation.

This is not an executable-result claim: this mining pass did not run Luau locally. The observation is derived from the current production validation predicates and should receive a focused expected-red regression if the scheduler unlocks a repair leaf.

## Why this matters

The durable ObjectGenome contract describes affordances as stable interaction/grip regions **on components**, represented by a local point and radius. A radius with no component/object locality relationship can turn a canonical chair grip, cabinet pull, or table push region into an interaction volume spanning a room or much farther.

That creates an adapter ambiguity at exactly the data/representation boundary ObjectGenome is meant to own: a physical interaction system must either honor the canonical oversized region, silently clamp it, or invent a second adapter-specific validity rule. None of those are desirable for deterministic manufactured-object semantics.

This is primarily a contract/manufacturability issue, not a rendering issue. It does not require Roblox Studio to reproduce at source level.

## Existing coverage and non-duplication

This finding is distinct from already active/proposed ObjectGenome depth work:

- `HG-BACKFILL-OBJECTGENOME-STRING-BUDGET` covers unbounded provenance/component-role text and fingerprint/retention work;
- PR #466 records the caster `swivelAxis` / `rollAxis` degeneracy gap;
- existing ObjectGenome generations cover exact schema shape, metatable/no-execute boundaries, semantic-key bounds, state-map aliasing, deterministic diagnostics, recipe fingerprinting, support graphs, mechanism record decoding, and state identity;
- chair/cart geometry work validates authored support contact, mass closure, and component-derived COM for specific fixtures rather than generic affordance-region locality.

Repository PR/issue searches for ObjectGenome affordance-radius/component-bounds locality did not surface a dedicated existing repair or finding.

## Recommended bounded follow-up

Do not choose an arbitrary meter ceiling in a capacity-mining pass. First make the v1 semantic decision explicit: define what `radiusM` means geometrically and how an affordance region is allowed to extend from its referenced component.

A safe source-only repair should then:

1. keep the affordance center constrained to the referenced component;
2. define a project-owned locality rule derived from the referenced component and/or whole-object envelope, or a separately documented finite physical cap with a compatibility rationale;
3. reject an affordance whose complete interaction region violates that rule instead of relying on realization adapters to clamp it;
4. cover the exact accepted boundary and the first rejected value, plus at least one offset point near a component face where center-only validation would be insufficient;
5. preserve all shipped fixture behavior and advance recipe/family versioning only if the chosen compatibility rule changes established canonical content;
6. keep the rule domain-only and Roblox-independent.

If the intended v1 semantics deliberately allow a radius to extend outside a component, the contract should still define how far and why; “positive finite” alone is not a stable physical interpretation.

## Scope

Finding based on `main@ec7755717c9512b8418e2cfc77f0da69610ea9ae`.

No production source, schema/version, StableId, recipe fingerprint, fixture, ObjectState, MaterialDNA, Physics Lab, Roblox Instance realization, persistence, networking, Studio, viewport, or physical-contact behavior is changed or claimed here.
