# Resolved Region Recipe contract

`src/shared/Reality/ResolvedRegionRecipe.luau` is the first production boundary between deterministic regional potential and canonical observed truth.

## What the recipe owns

A locked recipe is immutable plain data containing:
- an explicit schema version and deterministic `recipeId`,
- `worldId` and an opaque `worldSeedRef`,
- stable `regionId` and `regionAddress` keys,
- the exact reality/topology/material/object/entity generator versions used to resolve it,
- a stable semantic-intent key,
- canonical topology-anchor keys,
- canonical content keys.

Topology-anchor and content-key collections are unique canonical sets. The contract sorts them before identity is computed so incidental array ordering cannot change resolved truth.

`recipeId` is the deterministic fingerprint of the immutable base recipe. Any change to its canonical content or generator-version snapshot produces a different ID.

## First-observation lock

`ResolvedRegionRecipe.resolve(existing, draft)` is first-write-wins:
- with no existing recipe, the draft is validated, canonicalized and locked;
- once a recipe exists, later candidate drafts do not rewrite it, including candidates produced by newer generator versions.

This module does not decide when an observer is meaningful. Observation policy belongs above this data contract. It only defines the irreversible resolved-truth transition once that policy elects to lock a candidate.

## Generated base + meaningful deltas

The resolved recipe is the generated immutable base. Mutable world history is deliberately not embedded into it.

`deltaBaseReference(recipe)` exposes only the recipe ID and recipe schema version required for a future delta stream to bind to the exact base it modifies. Delta schemas, persistence ordering, idempotency and storage adapters remain outside this issue and must not turn Workspace into canonical storage.

## Serialization and reconstruction

`serialize()` returns a detached plain-data copy. `reconstruct()` validates exact current shape, canonicalizes key sets, and verifies that `recipeId` still matches the immutable content. Tampered or non-plain data is rejected.

Current-schema reconstruction requires no Roblox Instances, Studio services, wall clock, unordered JSON encoding or uncontrolled randomness, so it remains headless-testable.

## Migration

Schema upgrades are explicit. `reconstruct(serialized, migrationHook)` invokes a caller-supplied migration only when the serialized schema version differs from the current contract, then validates the migration output as a current canonical recipe.

There is intentionally no implicit migration registry and no silent adoption of current generator versions. A future migration must be version-aware, reviewed and deterministic before old observed truth can change representation.

## Boundaries

This module does **not** own:
- topology generation or RegionIntent design,
- physical Workspace realization,
- observation-strength policy,
- DataStore/MemoryStore persistence,
- mutable delta schemas,
- world/server routing.

Those systems may depend on this contract; they must not copy or bypass it.
