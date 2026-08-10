# Resolved Region Recipe

`src/shared/Reality/ResolvedRegionRecipe.luau` is the plain-data boundary where deterministic regional potential becomes established observed truth.

## Identity versus recipe truth

A region has two deliberately separate identifiers:

- `regionId` identifies the canonical WorldId + RegionAddress and remains stable when the region's canonical recipe changes through an explicit migration.
- `fingerprint` identifies the exact resolved recipe schema/content/version tuple that was locked by observation.

WorldId must already satisfy the project `StableId` `world` namespace contract. Do not use a Roblox Instance, Model, Folder, Workspace path, or ad-hoc string as world/region identity.

## First-observation lock

`lockFirstObservation()` canonicalizes a candidate plain-data recipe. `resolveFirstObservation(existing, candidate)` is the first-write-wins transition used when establishing truth:

- with no existing recipe, the candidate becomes the locked base;
- with existing truth for the same WorldId, world-seed reference, and RegionAddress, the existing recipe wins unchanged even if a later candidate uses newer generators or different content;
- a candidate from a different world, world seed, or region is rejected rather than being substituted across identity boundaries.

Candidate data contains:

- canonical WorldId and world-seed reference,
- RegionAddress,
- explicit reality/topology/material/object/entity generator versions,
- semantic intent,
- topology anchor keys,
- canonical content keys.

Topology/content key arrays are canonicalized as duplicate-free sorted sets before fingerprinting. Returned recipes are defensively copied and frozen.

Persist the locked result as the region's generated base recipe. Later physical realization reconstructs from that recipe; it must not silently substitute today's generator versions.

## Reconstruction and drift detection

`serialize()` returns the portable recipe record. `deserialize()` validates the exact schema, recomputes the canonical region identity and recipe fingerprint, and rejects tampered or same-record drift.

`lockInput()` exposes the canonical inputs needed to reproduce the same locked recipe in deterministic tests or reconstruction tooling.

## Generator upgrades

`migrationPlan(recipe, targetVersions)` compares a locked recipe with an explicitly supplied version set. It never mutates the recipe. A non-`nil` result is only a migration *request description*; migration policy and persistence are intentionally outside this module.

Already-observed regions therefore remain on their locked versions until project-owned migration code deliberately creates and validates replacement truth.

## Mutable deltas

`newDelta(recipe, ...)` creates a bounded plain-data snapshot for meaningful changes after the generated base has been locked. Every delta carries the base schema version, canonical `regionId`, and exact recipe `fingerprint`. `assertDeltaMatchesBase()` rejects replay against a different region or different resolved recipe.

Payloads are finite, metatable-free, acyclic, defensively copied/frozen, depth/node bounded, individually string-byte bounded, and have explicit positive sequence numbers. Supplying a non-table payload is rejected; only omitted/`nil` payloads default to an empty map.

This module does not keep a delta queue and does not write DataStore/MemoryStore. Persistence owns storage, ordering/compaction, conflict handling, retention, and cross-server authority.

## Pure repro

Run the repository pure suite:

```sh
lune run tests/run
```

The `resolved_region_recipe` tests cover deterministic reconstruction, input-order independence, first-write-wins behavior across generator/content drift, wrong-seed/region rejection, canonical WorldId enforcement, fingerprint tamper rejection, explicit migration planning, base-bound deltas, immutable snapshots, and invalid payload boundaries.

Any later procedural failure attached to a region should report at minimum its WorldId, RegionAddress/`regionId`, locked generator versions, and recipe `fingerprint` so the exact established truth can be reconstructed.
