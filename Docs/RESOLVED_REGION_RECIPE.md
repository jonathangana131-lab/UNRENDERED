# Resolved Region Recipe contract

`src/shared/Reality/ResolvedRegionRecipe.luau` is the first production boundary between deterministic potential and canonical observed regional truth.

It implements the first-observation decision from ADR 0002 without becoming a topology generator, persistence backend, or Workspace serializer.

## Invariants

A resolved recipe is **generated base truth**. It is plain/versioned domain data and contains no Roblox Instances.

A recipe locks:
- a stable region identity derived from `worldSeedRef + RegionAddress`,
- the exact generator-version snapshot used when truth was first resolved,
- a semantic-intent key,
- opaque topology-anchor keys,
- opaque canonical-content keys,
- a deterministic content fingerprint.

The stable `regionId` intentionally does **not** depend on generator versions or recipe content. A migrated recipe is still the same conceptual region. `recipeFingerprint` identifies the exact locked recipe content.

`topologyAnchors` and `canonicalContentKeys` are currently opaque key sets. #9 does not define topology graph semantics owned by later world-generation work. Inputs are sorted and duplicate keys are rejected so caller iteration/order cannot perturb canonical truth.

## First observation

Use:

```luau
local resolved = ResolvedRegionRecipe.resolveOnObservation(existingRecipe, candidate)
```

- If `existingRecipe == nil`, the candidate is fully validated, owned, canonicalized, fingerprinted, and frozen.
- If a recipe is already locked, established truth is validated first and wins. Only the incoming `worldSeedRef + RegionAddress` identity is inspected; later unresolved generator payload, versions, or content are not allowed to invalidate already-observed truth.
- Supplying an existing recipe for a different world-seed reference or region address is an error.

This makes first observation idempotent. A normal generator upgrade, including malformed or no-longer-supported unresolved output, cannot silently rewrite or make established truth unreadable.

## Reconstruction and storage boundary

`serialize(recipe)` produces a mutable plain-data copy suitable for a future repository/storage adapter. `deserialize(data)` validates exact schema shape, recomputes the stable region ID and deterministic fingerprint, and rejects drift instead of silently accepting or repairing it.

`equal(a, b)` compares the canonical recipe payload, not only the non-cryptographic fingerprint. `fingerprint(recipe)` is suitable for compatibility checks, diagnostics, and repro evidence; it is not a security primitive.

The deterministic repro string from `reproKey(recipe)` includes region identity, region address, locked reality version, and exact recipe fingerprint.

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

The migration builder receives frozen source truth and frozen target versions. The result must preserve `worldSeedRef` and `regionAddress`, use the exact requested target-version snapshot, and therefore preserve `regionId`. A successful migration returns a plain/frozen receipt containing source and target fingerprints and version snapshots.

Future storage/persistence work decides how migration receipts are durably recorded. #9 deliberately does not introduce DataStore, MemoryStore, or a full delta schema.

## Generated base + meaningful deltas

Mutable deltas are intentionally **not stored or journaled by this module**. The exact-shape recipe serializer/deserializer rejects embedded delta/runtime/representation fields, proving that the generated base is a closed immutable record. Future persistence work owns bounded delta storage, retention, backpressure, metrics, and durable replay semantics while binding those deltas to this stable region identity and exact base fingerprint as needed.

This keeps `ResolvedRegionRecipe` from becoming an in-memory universe database or an unbounded queue before the persistence epic is unlocked.

## Versioning policy

`SCHEMA_VERSION = 1` and `FINGERPRINT_VERSION = 1` are explicit compatibility contracts. Literal v1 region-ID and recipe-fingerprint goldens are pinned in the pure suite. Once recipes are persisted, future incompatible changes must add a deliberate version path rather than rewriting v1 behavior in place.

The recipe fingerprint uses the locked deterministic core framing/hash implementation. It is versioned and deterministic, but it is not authentication, signing, or hostile collision resistance.

## Test evidence

`tests/resolved_region_recipe.luau` covers:
- literal v1 region-ID and recipe-fingerprint goldens,
- deterministic lock/reconstruction,
- order-independent key-set canonicalization,
- exact serialize/deserialize equality,
- stored-fingerprint tamper rejection,
- first-observation non-rewrite under newer or malformed generator output,
- world/address identity mismatch rejection,
- explicit migration and migration receipt semantics,
- duplicate/sparse/unknown-field validation,
- generated-base rejection of embedded mutable delta fields,
- deterministic repro identity.

Full repository CI remains the acceptance source of truth.
