# ADR 0002 — Deterministic reality with versioned first-observation lock

Status: Accepted

## Context

An effectively infinite persistent shared world cannot store every unobserved room. Generator upgrades also must not rewrite locations players already established.

## Decision

Unobserved space is deterministic potential. Canonical generation uses scoped deterministic streams. The first meaningful observation of a region records the generation versions and canonical recipe/anchors needed for stable reconstruction. Later modifications are stored as deltas.

## Consequences

- A furniture algorithm update cannot reshuffle topology because streams are independently salted.
- Existing regions retain their historical generation version unless explicitly migrated.
- Procedural bugs are reproducible by seed/address/version.
- Persistence storage grows with observed/significant truth rather than theoretical universe volume.
