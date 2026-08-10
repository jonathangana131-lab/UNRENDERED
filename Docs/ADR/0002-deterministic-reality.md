# ADR 0002 — Deterministic reality with versioned first-observation lock

Status: Accepted

## Context

An effectively infinite persistent shared world cannot store every unobserved room. Generator upgrades also must not rewrite locations players already established.

The bootstrap deterministic core was sufficient to prove the toolchain but was not a durable world contract: StableId exposed only a 64-bit non-cryptographic digest, string parts were separated by control delimiters rather than an explicit byte encoding, and SeedStream did not require generator version or subsystem salt as distinct inputs. Those weaknesses become expensive once resolved world data depends on them.

## Decision

Unobserved space is deterministic potential. Canonical generation uses scoped deterministic streams. The first meaningful observation of a region records the generation versions and canonical recipe/anchors needed for stable reconstruction. Later modifications are stored as deltas.

Determinism contract v1 is locked as follows:
- ordered string parts use the unambiguous length-prefixed `u1` byte encoding defined in `Docs/DETERMINISM_CONTRACT.md`,
- Hash32 v1 is Jenkins one-at-a-time with explicit unsigned 32-bit seeds,
- StableId v1 is visibly versioned as `<namespace>:v1:<128-bit digest>` and remains independent of Roblox Instances,
- xorshift32 RNG behavior, including zero-seed normalization, is golden-tested,
- SeedStream derivation explicitly includes world seed, generator version, lowercase dotted subsystem salt, and ordered semantic scopes,
- topology/material/object/etc. streams are derived independently rather than by consuming a shared parent generator.

Golden vectors are normative compatibility fixtures. The implementation source shared by Roblox wrappers is also loaded directly by the headless test suite so CI executes the canonical algorithm rather than a copied approximation.

## Migration policy

Once canonical content is resolved with v1, v1 behavior is historical truth. A future algorithm or encoding change must add a new explicit version path and preserve old reconstruction behavior. New unobserved content may adopt the new generator/contract version explicitly; observed content migrates only through a deliberate migration with regression evidence.

StableId collisions must be detectable by registries that know the canonical identity behind an ID. StableId/Hash32 are not security primitives and must never be used for authentication, secrecy, anti-cheat trust, signatures, or hostile collision resistance.

## Consequences

- A furniture algorithm update cannot reshuffle topology because streams are independently salted.
- Existing regions retain their historical generation version unless explicitly migrated.
- Procedural bugs are reproducible by seed/address/version/salt/scope.
- Persistence storage grows with observed/significant truth rather than theoretical universe volume.
- IDs become longer than the bootstrap format and the old unversioned shape is intentionally rejected before production content depends on it.
- Contract changes require new golden vectors and an explicit migration/version decision rather than an in-place refactor.
