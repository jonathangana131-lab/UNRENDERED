# Resolved Region Recipe contract

`src/shared/Reality/ResolvedRegionRecipe.luau` is the current production boundary between deterministic potential and canonical observed regional truth.

It implements the first-observation decision from ADR 0002 and the WorldId/seed identity correction from ADR 0003 without becoming a topology generator, persistence backend, or Workspace serializer.

## Invariants

A resolved recipe is **generated base truth**. It is plain/versioned domain data and contains no Roblox Instances.

A v2 recipe locks:
- an explicit `WorldId` StableId,
- a stable `regionId` derived from `WorldId + RegionAddress`,
- a separate `worldSeedRef` describing generation provenance,
- the exact generator-version snapshot used when truth was first resolved,
- a semantic-intent key,
- opaque topology-anchor keys,
- opaque canonical-content keys,
- a deterministic exact-content fingerprint.

`WorldId` and generation seed are intentionally different pieces of global truth. Reusing the same seed for two worlds must not merge their regional identity, and changing seed provenance must not rename a conceptual region.

The stable v2 `regionId` does **not** depend on seed provenance, generator versions, or recipe content. A migrated recipe is still the same conceptual region. `recipeFingerprint` identifies the exact locked recipe content and includes both `worldId` and `worldSeedRef`.

`topologyAnchors` and `canonicalContentKeys` are currently opaque key sets. #9 does not define topology graph semantics owned by later world-generation work. Inputs are sorted and duplicate keys are rejected so caller iteration/order cannot perturb canonical truth.

## First observation

Use:

```luau
local resolved = ResolvedRegionRecipe.resolveOnObservation(existingRecipe, candidate)
```

- If `existingRecipe == nil`, the v2 candidate is fully validated, owned, canonicalized, fingerprinted, and frozen.
- If a v2 recipe is already locked, established truth is validated first and wins.
- Only incoming `worldId + worldSeedRef + RegionAddress` identity is inspected before returning established truth; later unresolved generator payload, versions, or content are not allowed to invalidate already-observed truth.
- Supplying an existing recipe for a different WorldId, seed provenance, or region address is an error.

This makes first observation idempotent. A normal generator upgrade, including malformed or no-longer-supported unresolved output, cannot silently rewrite or make established truth unreadable.

## Reconstruction and storage boundary

`serialize(recipe)` produces a mutable plain-data copy suitable for a future repository/storage adapter. `deserialize(data)` validates exact v2 schema shape, recomputes the stable region ID and deterministic fingerprint, and rejects drift instead of silently accepting or repairing it.

`equal(a, b)` compares the canonical recipe payload, not only the non-cryptographic fingerprint. `fingerprint(recipe)` is suitable for compatibility checks, diagnostics, and repro evidence; it is not a security primitive.

The deterministic repro string from `reproKey(recipe)` includes WorldId, region identity, seed provenance, region address, locked reality version, and exact recipe fingerprint.

## Generator versions

The recipe snapshots the currently owned generation domains:
- reality,
- topology,
- material,
- object,
- entity.

`currentGeneratorVersions()` is sourced from `RealityVersions`; callers should not invent an independent version table for new truth. Historical compatibility fixtures deliberately pin literal old version snapshots so later `RealityVersions` changes cannot move old goldens.

`requiresMigration(recipe, targetVersions)` only reports version mismatch. It never mutates a recipe.

## Explicit migration only

A locked v2 recipe can change generator versions only through:

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

`SCHEMA_VERSION = 2` and `FINGERPRINT_VERSION = 2` are the current resolved-region write/lock contract.

The short-lived merged v1 contract derived `regionId` from `worldSeedRef + RegionAddress`, conflating world identity with seed provenance. ADR 0003 records why v2 corrects this before persistence/world publishing exists.

ADR 0002 still requires accepted historical reconstruction behavior to remain reproducible. Therefore the exact v1 implementation is frozen separately as `src/shared/Reality/ResolvedRegionRecipeV1.luau` and exercised by the literal #169 compatibility vector. That module is a legacy replay/compatibility path, not the canonical API for new locks. The current v2 module does not accept a v1 record or infer WorldId from seed provenance. Any future v1-to-v2 conversion requires an explicit caller/operator-supplied WorldId and a deliberate migration decision.

Literal v1 and v2 WorldId/region-ID/recipe-fingerprint goldens are pinned independently of current generator-version constants. Future incompatible changes must add another deliberate version path rather than rewriting v1 or v2 behavior in place.

The recipe fingerprint uses the locked deterministic core framing/hash implementation. It is versioned and deterministic, but it is not authentication, signing, or hostile collision resistance.

## Test evidence

`tests/resolved_region_recipe.luau` covers the current v2 contract, including:
- WorldId/region-ID/recipe-fingerprint behavior,
- distinct WorldIds remaining distinct even when seed/address match,
- seed provenance not renaming a conceptual region,
- deterministic lock/reconstruction,
- order-independent key-set canonicalization,
- exact serialize/deserialize equality,
- stored-fingerprint tamper rejection,
- canonical v2 rejection of legacy v1 seed-derived records,
- first-observation non-rewrite under newer or malformed generator output,
- WorldId/seed/address identity mismatch rejection,
- explicit migration and migration receipt semantics,
- duplicate/sparse/unknown-field validation,
- generated-base rejection of embedded mutable delta fields,
- deterministic repro identity.

`tests/resolved_region_recipe_v1_compat.luau` preserves the accepted literal v1 identity/fingerprint/reconstruction vector through the legacy module. `tests/resolved_region_recipe_v2_compat.luau` pins the literal v2 identity/fingerprint vector to fixed generator versions and regression-locks migration preservation of world-seed provenance.

Full repository CI remains the acceptance source of truth.
