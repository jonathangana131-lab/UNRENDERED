# Architecture

## Non-negotiable law

**Domain identity must not depend on a Roblox Instance existing.**

A chair may be a detailed physical assembly near a player, a cheap proxy farther away, a compact persistent record when unloaded, or deterministic potential before first observation. Its WorldEntityId survives every representation.

## Core layers

### Core
Stable IDs, deterministic hashing/RNG, versions, clocks, diagnostics, immutable data contracts.

### Reality
Truth hierarchy, observation, reality confidence, first-observation lock, significance, anchor state, mutation eligibility.

### Spatial
WorldAddress, RegionAddress, topology adjacency, floating/local simulation coordinates, streaming cells, non-Euclidean connectors.

### WorldGen
Macro fields -> region intent -> topology graph -> structural assembly -> material history -> furnishing history -> incidents -> anomalies -> traces/entities.

### Materials
`MaterialDNA`: visual recipe + physical class + acoustic class + wear/history. Roblox PBR assets are selected from curated families; runtime uniqueness comes from recipe combinations, colors, variants, geometry, decals, masks/state, and placement history rather than runtime-generating arbitrary images.

### Objects
`ObjectGenome`: construction graph, parts, dimensions, materials, mass, mechanisms, affordances, wear and damage. ProceduralModel may support authoring/runtime parameterized families, but project-owned genomes remain the domain source of truth.

### Physics / Characters
Fidelity manager, physical props, constraints, active-ragdoll body, gait/balance, contact planning, grip, bracing, recovery, injury.

### Entities / StillLife
Controlled anatomy/behavior genomes and scene grammars. Normal plausible construction precedes anomaly passes.

### Environment / Audio / Perception
Lighting/electrical personality, humidity/water/air, material acoustics, propagation graph, body camera, optical adaptation, device sensors.

### Multiplayer
Server-authoritative critical state, Roblox prediction/server-authority where suitable, spatial interest, audio interest, authority handoff, Entry Cohorts.

### Persistence
Generated base + persistent deltas. Never serialize the live Workspace as the world database.

## Truth hierarchy

1. Global truth — seed, versions, major anchors/events.
2. Regional truth — resolved topology/grammar/history.
3. Observed truth — exact local objects, damage, traces, recordings.
4. Unobserved possibility — deterministic potential only.

## First-observation lock

When a region becomes canonical, store enough recipe/version information that future generator upgrades do not silently rewrite established space. New unobserved regions can use newer generation versions; old regions migrate only explicitly.

## Determinism

Never use uncontrolled randomness inside canonical generation. Random streams are derived from explicit seed + scope salts, for example:

`world seed -> region -> subsystem -> local semantic key`

Topology, materials, props, anomalies, and traces use separate streams so changing furniture selection does not reshuffle the building graph.

## Fidelity states

- F0 Potential: data/seed only.
- F1 Structural: topology and coarse route state.
- F2 Render: visible geometry, cheap interactions.
- F3 Interactive: physics/mechanisms/audio/local AI.
- F4 Hero: active-ragdoll/high-detail mechanisms/high-cost effects.

Promotion and demotion preserve domain identity and persistent state.

### WorldEntity lifecycle boundary

`src/shared/Reality/WorldEntity.luau` owns the representation-independent lifecycle contract. A `WorldEntityRecord` contains only stable identity, entity kind, deterministic generation-origin metadata, F0–F4 fidelity, plain persistent state, and a monotonic lifecycle revision. It deliberately contains no Roblox `Instance` reference.

Representation adapters may realize Roblox objects for F2–F4 and destroy/recreate them as fidelity changes. Before any demotion, the adapter must explicitly capture meaningful mutable state and pass that plain-data patch into the lifecycle transition. Promotions reconstruct presentation from the same `WorldEntityId`, origin, and captured state. The lifecycle revision lets adapters reject stale representation work without changing identity.

A registry detects duplicate live `WorldEntityId` values. It is an in-memory identity/lifecycle guard, not the persistence database. Fidelity policy inputs, hysteresis, cooldowns, and budgets belong to the separate Fidelity Manager (#7), which must consume this shared F0–F4 contract rather than redefine it.

Persistent state is restricted to serializable plain data: finite numbers, strings, booleans, maps with string keys, and contiguous arrays. Functions, userdata/Instances, metatables, cycles, mixed map/array tables, NaN, and infinities are rejected at the domain boundary.

## Roblox-specific constraints

- `Workspace.StreamingEnabled` is the engine streaming layer; our region/fidelity system sits above it.
- Parallel Luau is for pure/mostly immutable computation split across Actors. Mutation returns to serial phases.
- Roblox ProceduralModel generation is useful but cannot be treated as the only runtime world generator and is not supported inside Actor instances.
- Critical client input is untrusted. Server authority/prediction is the long-term direction for gameplay-critical physical state.
- SurfaceAppearance PBR maps are asset-backed and generally not arbitrarily rewritten by scripts at runtime, so procedural material realism relies on curated map families + parametric composition/state.

## Anti-rewrite rules

1. Stable project-owned IDs from day one.
2. Generation schemas are versioned.
3. Networking APIs behind project adapters/services.
4. DataStore/MemoryStore calls behind persistence interfaces.
5. No giant `GameManager`.
6. No giant procedural generator file.
7. No world-as-one-Place/scene assumption.
8. No hard-coded Backrooms level enum.
9. No direct random calls in canonical generation.
10. No duplicate temporary framework beside the production framework.
11. Shared high-contention contracts require an ADR.
12. Pure generation logic should be testable without Studio when possible.
13. Every procedural bug gets seed/repro coordinates.
14. Main stays buildable.
