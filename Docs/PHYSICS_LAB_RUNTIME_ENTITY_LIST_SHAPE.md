# Physics Lab runtime entity-list shape finding

## Status

Source-only capacity-mining finding. This does **not** change product runtime behavior and does not claim Roblox Studio, viewport, physical-contact, performance-device, networking, persistence, or two-client evidence.

Audited retained runtime synthesis: PR #408 exact product head `d31c100c5d3766ca14d89b046fff4cdb09086754`.

## Finding

`PhysicsLabRuntime.assertCanonicalRecipe()` correctly rejects a metatable-backed `recipe.entities` container before caller metamethod execution, requires `#entities` to equal the canonical population, and later requires the `ipairs()` traversal count to equal that population.

Those checks do not close the **container shape** itself. A plain, otherwise-canonical entity list can carry an undeclared non-array/hash field and still pass:

```luau
local candidate = PhysicsLabRecipe.build()
local entities = table.clone(candidate.entities)
entities.injected = "not-canonical"
candidate = {
    schemaVersion = candidate.schemaVersion,
    recipeKey = candidate.recipeKey,
    worldId = candidate.worldId,
    regionId = candidate.regionId,
    entities = entities,
}

PhysicsLabRuntime.new(candidate) -- current retained #408 fence accepts this shape
```

The injected key is ignored by both `#entities` and `ipairs(entities)`. Every canonical entity entry remains unchanged, so the key/id/provenance/state/revision authenticity checks still succeed.

This matters because the constructor describes itself as a canonical-recipe fence. If the entities container is accepted as canonical data, its own schema must be bounded as explicitly as the top-level recipe, each `EntityRecipe` wrapper, `WorldEntityRecord`, and `GenerationOrigin`.

## Non-duplication

This is distinct from the three existing runtime capacity findings:

- PR #451: realization-bearing `EntityRecipe` values can differ while domain-record identity remains canonical.
- PR #467: undeclared keys on the **top-level recipe** or an individual **EntityRecipe wrapper** are accepted.
- PR #494: complete canonical entity entries can be **permuted** because validation authenticates them by key rather than canonical dense index.

A container with canonical entries in canonical order plus `entities.injected = ...` keeps all three of those dimensions canonical while still widening the entity-list schema.

## Smallest production-worthy follow-up

Do not create a competing runtime framework. Absorb this into the retained #408 canonical-recipe hardening lineage alongside #451, #467, and #494.

Before consuming the entity list, validate that every key in `recipe.entities` is an integer array index in the exact dense range `1..#CANONICAL_RECIPE.entities`, with no hash/string keys, non-integer numeric keys, zero/negative indices, or numeric indices outside the canonical range. Then preserve the existing exact population and per-entry authenticity checks.

The validation should be bounded by the fixed permanent Physics Lab population and should reject before registry/Fidelity authority construction.

## Focused regression

Add a pure constructor regression that:

1. copies the canonical entities into a plain table;
2. adds one undeclared hash field to that container while leaving every canonical entry byte-equivalent/in canonical order;
3. requires `PhysicsLabRuntime.new()` to reject it;
4. proves an immediate untouched canonical recipe still constructs successfully.

A stronger bounded table-shape helper may additionally reject out-of-range/non-integer numeric keys, but the minimum regression above is sufficient to prove the currently demonstrated false acceptance.

## Evidence boundary

This finding is based on source inspection of the retained PR #408 runtime and its synthesis regression corpus. No local Luau/Lune command or Roblox Studio run was executed by this worker. Canonical GitHub CI on this docs-only branch is the executable validation source for publication; any future production repair requires fresh exact-head CI and independent review.

Door, Chair, Player, HG151 diagnostics, and HG151 two-client evidence remain unchanged and locked/gated by their existing scheduler state.
