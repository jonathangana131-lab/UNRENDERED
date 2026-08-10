# Resolved Region Recipe Contract

`src/shared/Reality/ResolvedRegionRecipe.luau` is the production plain-data boundary for issue #9: deterministic potential becomes canonical regional truth only when the first meaningful observation locks a recipe.

## What a locked recipe stores

A `ResolvedRegionRecipe` is compact reconstruction truth, not serialized Roblox geometry. It owns:

- a stable region ID derived from `worldId + RegionAddress`,
- a world-seed reference rather than a Workspace representation,
- the integer region address and canonical region key,
- an explicit snapshot of reality/topology/material/object/entity generator versions,
- canonical semantic-intent keys,
- canonical topology-anchor keys,
- canonical content keys,
- the first-observation key,
- a generated-base fingerprint and a full locked-record fingerprint,
- optional explicit migration provenance.

Key arrays are copied, sorted, bounded and duplicate-rejected at the boundary. The recipe and all nested records are frozen after validation. Region coordinates are restricted to finite safe integers so reconstruction does not depend on ambiguous numeric precision.

## First-observation lock

`ResolvedRegionRecipe.lock(existing, request)` has two behaviors:

1. With no existing recipe, it owns/canonicalizes the request and returns the first locked recipe.
2. With an existing recipe, it reconstructs and preserves that exact historical record. A newer generator candidate cannot overwrite it. `candidateMatches` reports whether the newly proposed generated base is byte-contract-equivalent to the already locked base.

The observation key is intentionally excluded from `baseFingerprint`; two observers can independently propose the same generated base. It is included in the full `fingerprint`, because which observation actually won the lock is historical truth.

`ResolvedRegionRecipe.snapshot()` produces a mutable plain-data copy suitable for a persistence adapter. `reconstruct()` validates derived identity, region key and both fingerprints before returning an owned frozen record. Tampered versions/content therefore cannot be accepted as old truth by merely retaining an old fingerprint.

## Generator upgrades and migration

Normal `lock()` never upgrades an observed region. `ResolvedRegionRecipe.migrate()` is the only contract-level path that can replace the generated base intentionally. It:

- preserves WorldId, world-seed reference, RegionAddress and first-observation history,
- requires a named migration key,
- records the previous full fingerprint,
- accepts a new explicit generator-version snapshot and canonical key sets,
- emits a new validated recipe/fingerprint.

The migration API is a hook, not a migration policy. Any real version migration still requires its own implementation, deterministic regressions and rollout evidence.

## Generated base + meaningful deltas

Later world changes do not mutate the locked recipe. `createDelta()` creates one bounded plain-data delta record with:

- the exact `baseFingerprint` it applies to,
- an explicit positive stream sequence,
- a semantic delta kind,
- an optional target key,
- a recursively validated/frozen plain-data payload.

`reconstructDelta()` rejects a delta if its base fingerprint does not match the recipe being reconstructed. The module deliberately does **not** retain an in-memory delta queue or implement DataStore/MemoryStore. Persistence owns bounded storage, paging/compaction and sequencing policy later; this contract only makes the base/delta separation explicit.

## Determinism and repro

Recipe fingerprints use the landed deterministic `encodeParts/hashParts/StableId` contracts with a recipe-schema-v1 domain separator and fixed hash seeds. The fingerprint input is explicit and canonically ordered. The contract does not consume RNG and does not depend on Roblox Instances, Workspace, wall-clock time or table iteration order.

Focused headless regressions live in:

- `tests/resolved_region_recipe.luau`
- `tests/resolved_region_delta.luau`

These cover ordering invariance, ownership/freeze boundaries, snapshot reconstruction, silent generator-upgrade resistance, explicit migration provenance, safe-integer addresses, duplicate-key rejection and cross-base delta rejection.
