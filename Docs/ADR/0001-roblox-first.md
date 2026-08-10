# ADR 0001 — Roblox-first implementation

Status: Accepted

## Context

The project needs persistent multiplayer reach, cross-device availability, physics, streaming, procedural content, and a development model that many GitHub-based AI workers can extend through text source.

## Decision

Build UNRENDERED Roblox-first using Luau + Rojo, with external/offline asset production as needed.

Use Roblox-native capabilities intentionally:
- Instance Streaming,
- constraints/rigging/physics,
- server authority/prediction where production-ready for our use,
- Parallel Luau for suitable compute jobs,
- DataStore/MemoryStore/Messaging abstractions,
- PBR SurfaceAppearance/material assets,
- ProceduralModel for appropriate parameterized object families.

## Consequences

Advantages:
- immediate Roblox distribution/social platform,
- one multiplayer platform stack,
- broad devices,
- project source can remain text-heavy and Git-friendly.

Costs:
- graphics/shader freedom is lower than a bespoke HDRP desktop game,
- high-end physics must respect Roblox solver/network budgets,
- engine-only validation still requires Studio/hardware tests,
- procedural PBR must be asset-family driven rather than arbitrary runtime shader/image generation.

The architecture retains project-owned domain models so the game is not conceptually defined by one Roblox Instance hierarchy.
