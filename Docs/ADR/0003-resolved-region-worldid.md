# ADR 0003 — Resolved region identity uses WorldId, not generation seed

Status: Accepted

## Context

UNRENDERED treats `WorldId`, world seed, and world address as separate conceptual/global truth. ADR 0002 also requires first-observation truth to remain versioned and reproducible.

The first merged `ResolvedRegionRecipe` schema v1 derived stable `regionId` from:

`worldSeedRef + RegionAddress`

That makes generation provenance act as world identity. Two distinct WorldIds that intentionally reuse the same seed and address collide, while changing seed provenance for one conceptual world renames the region.

After v1 merged, #169 deliberately pinned its historical identity/fingerprint vector and reconstructability. The correction therefore cannot erase or silently reinterpret v1 truth even though persistence and published-world routing are still gated.

## Decision

### New observation truth

Schema/fingerprint v2 requires both:
- `worldId`: a project `world` StableId identifying conceptual global truth;
- `worldSeedRef`: separate generation provenance.

Stable v2 region identity is:

`StableId("region", WorldId + RegionAddress.key(address))`

The exact v2 recipe fingerprint includes both WorldId and world-seed reference, plus address, generator versions, semantic intent, topology anchors, and canonical content keys.

Normal `lock()` and first-observation resolution create **v2 only**. New production code cannot mint more seed-derived v1 identities.

### Historical v1 truth

V1 remains readable under its original law. It is not rewritten to look like v2.

- `deserialize()` is the normal v2 loader and refuses schema v1.
- `deserializeLegacyV1()` is the explicit compatibility loader for historical v1 records.
- A loaded v1 recipe preserves its original seed-derived `regionId`, fingerprint, generator versions, and content.
- If a v1 recipe is already established, later v2-capable observation cannot silently replace it. The incumbent v1 record wins after its legacy seed/address identity is checked.
- Generic generator migration refuses v1 because v1 has no trustworthy WorldId.

This explicit API boundary prevents accidental creation or implicit reinterpretation of legacy identity while keeping already-observed truth reconstructable.

### Explicit v1 -> v2 identity correction

`upgradeLegacyV1(recipe, worldId)` is the only in-module identity correction path.

The caller must provide a valid project WorldId. The function never derives or guesses WorldId from the seed reference. It preserves seed provenance, RegionAddress, generator-version snapshot, semantic intent, topology anchors, and canonical content, then creates a v2 recipe and a receipt recording source/target region IDs and fingerprints.

Because v1 and v2 use different identity laws, the region ID necessarily changes during this explicit compatibility conversion. This is not the same operation as a normal generator-version migration, where v2 WorldId/address identity must remain stable.

## Compatibility

- `ResolvedRegionRecipe.SCHEMA_VERSION` advances from 1 to 2.
- `FINGERPRINT_VERSION` advances from 1 to 2.
- Literal v1 compatibility vectors remain pinned and readable.
- Literal v2 WorldId, region-ID, and recipe-fingerprint goldens are pinned independently.
- Normal v2 deserialization is fail-closed for v1; legacy loading must be explicit.
- No automatic `worldSeedRef -> WorldId` inference exists.
- No Workspace, DataStore, MemoryStore, or full persistence layer is introduced by this ADR.

Future incompatible identity/fingerprint changes require another explicit compatibility path; they may not rewrite either v1 or v2 behavior in place.

## Consequences

- Distinct worlds may deliberately share generation seeds without v2 region-ID collisions.
- Seed rotation/provenance changes do not rename a v2 conceptual region.
- Exact reconstruction still detects seed changes because seed provenance remains inside the v2 content fingerprint.
- Historical v1 truth remains reproducible without pretending it always had a WorldId.
- World identity, generation provenance, resolved truth, and physical representation remain separate contracts.
