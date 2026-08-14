# Physics Lab Runtime Recipe Order Authenticity

## Finding

The permanent Physics Lab recipe contract treats the entity sequence as deterministic. `tests/physics_lab_recipe.luau` compares two independent `PhysicsLabRecipe.build()` results by index and requires each indexed entry to preserve its `kind`, `key`, and stable WorldEntity id.

Retained runtime synthesis PR #408 authenticates the complete canonical key/id population, provenance, state, revisions, nested record/origin shape, lookup boundary, and transition ownership. Its constructor builds `CANONICAL_ENTITIES_BY_KEY`, then accepts each candidate entry by looking up `entityRecipe.key` in that map. It does not require the canonical key at the canonical array index.

As a result, a candidate can swap two otherwise-unchanged canonical `EntityRecipe` entries and still satisfy the current #408 runtime fence: the array remains dense and complete, every key is unique and canonical, every record still matches its own canonical key/id/provenance/state, and no realization-bearing value is modified.

That means the constructor can label a noncanonical sequence as the canonical Physics Lab recipe even though the production recipe contract explicitly treats indexed sequence as deterministic.

## Why this is distinct

This is not PR #451's realization-value authenticity finding. A permutation changes no primitive/object realization field at all; each entry is bit-for-bit canonical and only its array position changes.

This is also not PR #467 / `HG-PHYSICS-RUNTIME-RECIPE-CLOSED-SHAPE`. A swapped candidate can remain an exact dense array with no extra, sparse, high, negative, noninteger, or string keys and with exact wrapper shape. Container shape can therefore be fully closed while canonical index-to-key identity is still unauthenticated.

The current production `PhysicsLabRealizer` builds `PhysicsLabRecipe.build()` internally, so this finding does not claim current Workspace corruption or engine-visible failure. It is a source-contract gap in what `PhysicsLabRuntime.new()` is allowed to call canonical. Runtime construction also preserves caller sequence while registering entities and stores that sequence for teardown, so accepting permutation needlessly allows caller-controlled ordering into otherwise-canonical runtime ownership.

## Required boundary

If `PhysicsLabRuntime.new()` continues to authenticate a canonical permanent-lab recipe, require each dense candidate index to contain the same canonical key as `CANONICAL_RECIPE.entities[index]` before authority construction.

The smallest bounded check is:

- prove the candidate entities container has the exact closed dense shape required by the existing closed-shape follow-up;
- for each canonical index, prove the candidate wrapper key is a primitive string before diagnostic interpolation;
- require `candidate.entities[index].key == CANONICAL_RECIPE.entities[index].key`;
- retain the existing per-key record/provenance/state/value checks rather than replacing them.

This keeps validation bounded by the fixed permanent-lab population and adds no new dynamic lookup surface.

## Regression target

Add a pure deterministic adversary that:

1. copies the canonical entity array;
2. swaps two complete canonical entries without modifying either entry;
3. proves `PhysicsLabRuntime.new()` rejects the permutation before registry/Fidelity authority construction; and
4. immediately constructs the untouched canonical recipe successfully afterward.

The regression should coexist with the realization-value authenticity and closed-shape adversaries because each protects a different dimension: indexed order, entry values, and container shape.

## Scope

Source-contract finding only. No production runtime behavior is changed by this note, and no Roblox Studio, viewport, physical-contact, performance-device, networking, persistence, or two-client evidence is claimed. Door/Chair/Player remain locked. The intended integration target is the retained Physics Lab runtime synthesis lineage after its trusted ownership/integration blocker clears.
