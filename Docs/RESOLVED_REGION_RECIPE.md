# Resolved Region Recipe contract

`src/shared/Reality/ResolvedRegionRecipe.luau` is the production boundary between deterministic potential and canonical observed regional truth.

It implements the first-observation decision from ADR 0002 and the WorldId/seed identity correction from ADR 0003 without becoming a topology generator, persistence backend, or Workspace serializer.

## Current v2 invariants

A newly resolved recipe is **generated base truth**. It is plain/versioned domain data and contains no Roblox Instances.

A v2 recipe locks:
- an explicit `WorldId` StableId,
- a stable `regionId` derived from `WorldId + RegionAddress`,
- a separate `worldSeedRef` describing generation provenance,
- the exact generator-version snapshot used when truth was first resolved,
- a semantic-intent key,
- opaque topology-anchor keys,
- opaque canonical-content keys,
- a deterministic exact-content fingerprint.

`WorldId` and generation seed are different pieces of global truth. Reusing the same seed for two worlds must not merge their regional identity, and changing seed provenance must not rename an already-defined v2 region.

The v2 `regionId` does **not** depend on seed provenance, generator versions, or recipe content. Normal v2 generator migration therefore preserves region identity. `recipeFingerprint` identifies the exact locked recipe content and includes both `worldId` and `worldSeedRef`.

`topologyAnchors` and `canonicalContentKeys` remain opaque key sets. #9 does not define later topology/world-generation semantics. Inputs are sorted and duplicate keys are rejected so caller iteration order cannot perturb canonical truth.

## First observation

Use:

```luau
local resolved = ResolvedRegionRecipe.resolveOnObservation(existingRecipe, candidate)
```

For new truth, `candidate` must include a valid project `worldId`, and the function creates schema v2 only.

- If `existingRecipe == nil`, the v2 candidate is fully validated, owned, canonicalized, fingerprinted, and frozen.
- If a v2 recipe is already locked, established truth is validated first. Only incoming `worldId + worldSeedRef + RegionAddress` identity is inspected before the incumbent is returned; later unresolved payload, versions, or content cannot invalidate already-observed truth.
- If an explicitly loaded historical v1 recipe is already locked, it remains v1. Only its legacy seed/address identity can be checked because v1 never contained WorldId.
- Supplying an incumbent for a mismatched identity is an error.

This keeps first observation idempotent and prevents generator upgrades from silently rewriting established truth.

## Historical schema-v1 compatibility

Schema v1 accidentally used `worldSeedRef + RegionAddress` as stable regional identity. That law is frozen for compatibility; it is not reused for new observations.

Normal `deserialize(data)` accepts current v2 records only. Historical records must be loaded deliberately:

```luau
local legacy = ResolvedRegionRecipe.deserializeLegacyV1(data)
```

The legacy loader verifies the exact historical v1 region-ID and fingerprint laws. `serialize(legacy)` emits the original v1 shape, `equal`, `fingerprint`, and `reproKey` remain schema-aware, and `isLegacyV1` exposes the compatibility state.

Generic generator migration refuses v1 because no trustworthy WorldId exists in that schema.

To correct identity, a caller must provide the WorldId explicitly:

```luau
local upgraded, receipt = ResolvedRegionRecipe.upgradeLegacyV1(legacy, worldId)
```

The upgrade never guesses WorldId from seed provenance. It preserves seed/address/version/content truth, creates a v2 identity/fingerprint, and returns a receipt with source/target region IDs and fingerprints. V1 remains unchanged.

## Reconstruction and storage boundary

`serialize(recipe)` produces a mutable plain-data copy suitable for a future repository/storage adapter.

- `deserialize(data)` verifies exact current-v2 shape, region identity, and fingerprint.
- `deserializeLegacyV1(data)` verifies exact historical-v1 shape and compatibility law.
- Unknown fields, embedded runtime representation, and embedded mutable delta state are rejected.

`equal(a, b)` is schema-aware and compares canonical payloads rather than trusting only non-cryptographic fingerprints.

The deterministic repro key includes the schema-appropriate identity and exact fingerprint. V2 repro includes WorldId and seed provenance; v1 repro is explicitly marked `legacy-v1`.

## Generator versions

The recipe snapshots the currently owned generation domains:
- reality,
- topology,
- material,
- object,
- entity.

`currentGeneratorVersions()` is sourced from `RealityVersions`; callers should not invent an independent current-version table.

`requiresMigration(recipe, targetVersions)` reports true for legacy v1 and reports generator-version mismatch for v2. It never mutates truth.

## Explicit v2 generator migration

A v2 locked recipe can change generator versions only through:

```luau
local migrated, receipt = ResolvedRegionRecipe.migrate(
    recipe,
    targetVersions,
    migrationKey,
    builder
)
```

The migration builder receives frozen source truth and frozen target versions. The result must preserve WorldId, world-seed provenance, and RegionAddress, use the exact requested target-version snapshot, and therefore preserve v2 `regionId`. A successful migration returns a frozen receipt containing WorldId, region ID, source/target fingerprints, and version snapshots.

Future storage/persistence work decides how migration receipts are durably recorded. #9 deliberately does not introduce DataStore, MemoryStore, or a full delta schema.

## Generated base + meaningful deltas

Mutable deltas are intentionally **not stored or journaled by this module**. Exact-shape serializers reject embedded delta/runtime/representation fields, proving that the generated base is a closed immutable record.

Future persistence work owns bounded delta storage, retention, backpressure, metrics, and durable replay semantics while binding deltas to stable region identity and exact base fingerprint as appropriate.

## Versioning policy

- Historical schema/fingerprint v1 stays compatibility-locked.
- Current `SCHEMA_VERSION = 2` and `FINGERPRINT_VERSION = 2` use the corrected WorldId-based identity law.
- Normal creation and normal deserialization are v2-only.
- Legacy loading and v1 -> v2 identity correction are explicit APIs.
- Future incompatible changes require another deliberate version/compatibility path.

The recipe fingerprint uses the locked deterministic core framing/hash implementation. It is deterministic and versioned, but it is not authentication, signing, or hostile collision resistance.

## Test evidence

The permanent pure suites cover:
- literal historical-v1 region-ID/fingerprint reconstruction,
- explicit legacy loading and fail-closed normal loading,
- explicit v1 -> v2 WorldId upgrade receipts,
- literal v2 WorldId, region-ID, and recipe-fingerprint goldens,
- distinct WorldIds remaining distinct even when seed/address match,
- seed provenance not renaming a v2 conceptual region,
- deterministic lock/reconstruction,
- order-independent key-set canonicalization,
- stored-fingerprint tamper rejection,
- first-observation non-rewrite under newer or malformed generator output,
- WorldId/seed/address identity mismatch rejection,
- explicit v2 generator migration semantics,
- duplicate/sparse/unknown-field validation,
- generated-base rejection of embedded mutable delta fields,
- deterministic schema-aware repro identity.

Full repository synthetic-merge CI remains the acceptance source of truth.
