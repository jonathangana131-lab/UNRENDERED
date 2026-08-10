# ADR 0003 — Resolved region identity uses WorldId, not generation seed

Status: Accepted

## Context

UNRENDERED treats `WorldId`, world seed, and world address as separate conceptual/global truth. ADR 0002 also requires first-observation truth to remain versioned and reproducible.

The first merged `ResolvedRegionRecipe` v1 accidentally derived stable `regionId` from:

`worldSeedRef + RegionAddress`

That makes generation provenance act as world identity. Two distinct WorldIds that intentionally reuse the same seed and address collide, while changing seed provenance for one conceptual world renames the region.

This was caught immediately after #163 merged, before the gated persistence epic exists and before any published Roblox universe/place is connected. The v1 contract therefore has no sanctioned durable storage path.

## Decision

Resolved-region schema/fingerprint v2 requires both:
- `worldId`: a project `world` StableId identifying conceptual global truth;
- `worldSeedRef`: separate generation provenance.

Stable region identity is:

`StableId("region", WorldId + RegionAddress.key(address))`

The exact recipe fingerprint includes both WorldId and world-seed reference, plus address, generator versions, semantic intent, topology anchors, and canonical content keys.

First-observation reuse validates the incumbent first, then checks only incoming WorldId, seed provenance, and RegionAddress before returning established truth. Later unresolved content cannot invalidate already-observed truth.

Explicit generator-version migration must preserve WorldId, seed provenance, and RegionAddress. It may change exact recipe content/fingerprint, but not stable region identity.

## Compatibility and migration

This is an intentional compatibility correction:
- `ResolvedRegionRecipe.SCHEMA_VERSION` advances from 1 to 2.
- `FINGERPRINT_VERSION` advances from 1 to 2.
- The v1 seed-derived record shape is rejected; it is never silently interpreted as v2.
- No automatic `worldSeedRef -> WorldId` inference exists because that would recreate the conflation this ADR removes.

No production data migration is required because the persistence epic is still gated/unimplemented and no published universe/place is connected. If experimental external v1 records ever surface, importing them requires an explicit operator-supplied WorldId and a deliberate one-off conversion outside normal reconstruction; the project must not guess identity.

Literal v2 goldens pin WorldId, stable region ID, and recipe fingerprint. Future incompatible identity/fingerprint changes require another explicit version path.

## Consequences

- Distinct worlds may deliberately share generation seeds without region-ID collisions.
- Seed rotation/provenance changes do not rename conceptual regions.
- Exact reconstruction still detects seed changes because seed provenance remains inside the content fingerprint.
- World identity, generation provenance, resolved truth, and physical representation remain separate contracts.
- The correction happens before persistence, avoiding a long-lived migration burden while still recording the compatibility break explicitly.
