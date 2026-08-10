# Resolved Region Recipe

`src/shared/Reality/ResolvedRegionRecipe.luau` is the plain-data boundary where deterministic regional potential becomes established observed truth.

## Identity versus recipe truth

A region has two deliberately separate identifiers:

- `regionId` identifies the WorldId + RegionAddress and remains stable when the region's canonical recipe changes through an explicit migration.
- `fingerprint` identifies the exact resolved recipe schema/content/version tuple that was locked by observation.

Do not use a Roblox Instance, Model, Folder, or Workspace path as either identity.

## First-observation lock

`lockFirstObservation()` accepts only plain authored/generated data:

- WorldId and world-seed reference,
- RegionAddress,
- explicit reality/topology/material/object/entity generator versions,
- semantic intent,
- topology anchor keys,
- canonical content keys.

Topology/content key arrays are canonicalized as duplicate-free sorted sets before fingerprinting. The returned recipe is defensively copied and frozen.

Persist the result as the region's generated base recipe. Later physical realization reconstructs from that recipe; it must not silently substitute today's generator versions.

## Reconstruction and drift detection

`serialize()` returns the portable recipe record. `deserialize()` validates the exact schema, recomputes the canonical region identity and recipe fingerprint, and rejects tampered or same-record drift.

`lockInput()` exposes the canonical inputs needed to reproduce the same locked recipe in deterministic tests or reconstruction tooling.

## Generator upgrades

`migrationPlan(recipe, targetVersions)` compares a locked recipe with an explicitly supplied version set. It never mutates the recipe. A non-`nil` result is only a migration *request description*; migration policy and persistence are intentionally outside this module.

Already-observed regions therefore remain on their locked versions until project-owned migration code deliberately creates and validates replacement truth.

## Mutable deltas

`newDelta()` defines a small bounded plain-data snapshot for meaningful changes after the generated base has been locked. Payloads are finite, metatable-free, acyclic, defensively copied/frozen, depth/node bounded, and have explicit positive sequence numbers.

This module does not keep a delta queue and does not write DataStore/MemoryStore. Persistence owns storage, ordering/compaction, conflict handling, retention, and cross-server authority.

## Pure repro

Run the repository pure suite:

```sh
lune run tests/run
```

The `resolved_region_recipe` tests cover deterministic reconstruction, input-order independence, content drift versus stable region identity, fingerprint tamper rejection, explicit migration planning, immutable snapshots, and invalid delta payload boundaries.

Any later procedural failure attached to a region should report at minimum its WorldId, RegionAddress/`regionId`, locked generator versions, and recipe `fingerprint` so the exact established truth can be reconstructed.
