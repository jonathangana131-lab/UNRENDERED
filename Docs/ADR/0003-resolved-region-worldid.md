# ADR 0003 — Resolved region identity uses WorldId, not generation seed

Status: Accepted

## Context

UNRENDERED treats `WorldId`, world seed, and world address as separate conceptual/global truth. ADR 0002 also requires first-observation truth to remain versioned and reproducible.

The first merged `ResolvedRegionRecipe` v1 accidentally derived stable `regionId` from:

`worldSeedRef + RegionAddress`

That makes generation provenance act as world identity. Two distinct WorldIds that intentionally reuse the same seed and address collide, while changing seed provenance for one conceptual world renames the region.

This was caught immediately after #163 merged, before the gated persistence epic exists and before any published Roblox universe/place is connected. The v1 contract therefore has no sanctioned durable write path, but ADR 0002 still requires its accepted deterministic reconstruction behavior to remain historical truth.

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
- The canonical `ResolvedRegionRecipe` module accepts/writes only v2 truth and never silently interprets a seed-derived v1 record as v2.
- The exact accepted v1 implementation is frozen separately as `ResolvedRegionRecipeV1` for historical reconstruction/compatibility evidence only. Its literal #169 vector remains executable without consulting current generator versions.
- Normal production code must not use the legacy module to create new canonical truth.
- No automatic `worldSeedRef -> WorldId` inference exists because that would recreate the conflation this ADR removes.

No automatic production data migration is required because the persistence epic is still gated/unimplemented and no published universe/place is connected. If experimental external v1 records ever need conversion to v2, the caller/operator must supply an explicit WorldId and make a deliberate migration decision outside normal reconstruction; the project must not guess identity.

Literal v1 and v2 goldens pin their respective historical identity/fingerprint laws. Future incompatible identity/fingerprint changes require another explicit version path.

## Consequences

- Distinct worlds may deliberately share generation seeds without region-ID collisions in v2.
- Seed rotation/provenance changes do not rename conceptual v2 regions.
- Exact v2 reconstruction still detects seed changes because seed provenance remains inside the content fingerprint.
- Accepted v1 reconstruction remains available as isolated historical truth without legitimizing the v1 identity law for new content.
- World identity, generation provenance, resolved truth, and physical representation remain separate contracts.
- The correction happens before persistence, avoiding a long-lived automatic migration burden while still obeying ADR 0002's anti-rewrite guarantee.
