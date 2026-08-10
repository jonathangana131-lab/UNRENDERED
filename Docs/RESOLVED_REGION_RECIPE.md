# Resolved Region Recipe contract

`src/shared/Reality/ResolvedRegionRecipe.luau` is the first production boundary between deterministic potential and canonical observed regional truth.

It implements the first-observation decision from ADR 0002 and the WorldId/seed identity correction from ADR 0003 without becoming a topology generator, persistence backend, or Workspace serializer.

## Invariants

A resolved recipe is **generated base truth**. It is plain/versioned domain data and contains no Roblox Instances.

A recipe locks:
- an explicit `WorldId` StableId,
- a stable `regionId` derived from `WorldId + RegionAddress`,
- a separate `worldSeedRef` describing generation provenance,
- the exact generator-version snapshot used when truth was first resolved,
- a semantic-intent key,
- opaque topology-anchor keys,
- opaque canonical-content keys,
- a deterministic exact-content fingerprint.

`WorldId` and generation seed are intentionally different pieces of global truth. Reusing the same seed for two worlds must not merge their regional identity, and changing seed provenance must not rename an already-defined conceptual region.

The stable `regionId` does **not** depend on seed provenance, generator versions, or recipe content. A migrated recipe is still the same conceptual region. `recipeFingerprint` identifies the exact locked recipe content and includes both `worldId` and `worldSeedRef`.

`topologyAnchors` and `canonicalContentKeys` are currently opaque key sets. #9 does not define topology graph semantics owned by later world-generation work. Inputs are sorted and duplicate keys are rejected so caller iteration/order cannot perturb canonical truth.

## First observation

Use:

```luau
local resolved = ResolvedRegionRecipe.resolveOnObservation(existingRecipe, candidate)
```

- If `existingRecipe == nil`, the candidate is fully validated, owned, canonicalized, fingerprinted, and frozen.
- If a recipe is already locked, established truth is validated first and wins.
- Only incoming `worldId + worldSeedRef + RegionAddress` identity is inspected before returning established truth; later unresolved generator payload, versions, or content are not allowed to invalidate already-observed truth.
- Supplying an existing recipe for a different WorldId, seed provenance, or region address is an error.

This makes first observation idempotent. A normal generator upgrade, including malformed or no-longer-supported unresolved output, cannot silently rewrite or make established truth unreadable.

## Reconstruction and storage boundary

`serialize(recipe)` produces a mutable plain-data copy suitable for a future repository/storage adapter. `deserialize(data)` validates exact schema shape, recomputes the stable region ID and deterministic fingerprint, and rejects drift instead of silently accepting or repairing it.

`equal(a, b)` compares the canonical recipe payload, not only the non-cryptographic fingerprint. `fingerprint(recipe)` is suitable for compatibility checks, diagnostics, and repro evidence; it is not a security primitive.

The deterministic repro string from `reproKey(recipe)` includes WorldId, region identity, seed provenance, region address, locked reality version, and exact recipe fingerprint.

## Generator versions

The recipe snapshots the currently owned generation domains:
- reality,
- topology,
- material,
- object,
- entity.

`currentGeneratorVersions()` is sourced from `RealityVersions`; callers should not invent an independent version table.

`requiresMigration(recipe, targetVersions)` only reports version mismatch. It never mutates a recipe.

## Explicit migration only

A locked recipe can change generator versions only through:

```luau
local migrated, receipt = ResolvedRegionRecipe.migrate(
    recipe,
    targetVersions,
    migrationKey,
    builder
)
```

The migration builder receives frozen source truth and frozen target versions. The result must preserve `worldId`, `worldSeedRef`, and `regionAddress`, use the exact requested target-version snapshot, and therefore preserve `regionId`. A successful migration returns a plain/frozen receipt containing WorldId, region ID, source/target fingerprints, and version snapshots.

Future storage/persistence work decides how migration receipts are durably recorded. #9 deliberately does not introduce DataStore, MemoryStore, or a full delta schema.

## Generated base + meaningful deltas

Mutable deltas are intentionally **not stored or journaled by this module**. The exact-shape recipe serializer/deserializer rejects embedded delta/runtime/representation fields, proving that the generated base is a closed immutable record. Future persistence work owns bounded delta storage, retention, backpressure, metrics, and durable replay semantics while binding those deltas to this stable region identity and exact base fingerprint as needed.

This keeps `ResolvedRegionRecipe` from becoming an in-memory universe database or an unbounded queue before the persistence epic is unlocked.

## Versioning policy

`SCHEMA_VERSION = 2` and `FINGERPRINT_VERSION = 2` are the first persistence-eligible resolved-region compatibility contract.

The short-lived merged v1 contract derived `regionId` from `worldSeedRef + RegionAddress`, conflating world identity with seed provenance. ADR 0003 records why v2 corrects this before persistence/world publishing exists. V1 serialized data is rejected rather than silently reinterpreted or heuristically assigned a WorldId.

Literal v2 WorldId, region-ID, and recipe-fingerprint goldens are pinned in the pure suite. Future incompatible changes must add another deliberate version path rather than rewriting v2 behavior in place.

The recipe fingerprint uses the locked deterministic core framing/hash implementation. It is versioned and deterministic, but it is not authentication, signing, or hostile collision resistance.

## Test evidence

`tests/resolved_region_recipe.luau` covers:
- literal v2 WorldId, region-ID, and recipe-fingerprint goldens,
- distinct WorldIds remaining distinct even when seed/address match,
- seed provenance not renaming a conceptual region,
- deterministic lock/reconstruction,
- order-independent key-set canonicalization,
- exact serialize/deserialize equality,
- stored-fingerprint tamper rejection,
- explicit rejection of legacy v1 seed-derived records,
- first-observation non-rewrite under newer or malformed generator output,
- WorldId/seed/address identity mismatch rejection,
- explicit migration and migration receipt semantics,
- duplicate/sparse/unknown-field validation,
- generated-base rejection of embedded mutable delta fields,
- deterministic repro identity.

Full repository CI remains the acceptance source of truth.
