# ObjectGenome Contract

`ObjectGenome` is the immutable construction recipe for a manufactured object family/variant. It is domain data, not a Roblox prefab and not a `WorldEntityId`.

## Contract boundaries

- All measurements are plain-data SI units: meters, kilograms, degrees.
- `schemaVersion` is an explicit compatibility lock. A reader rejects unknown versions instead of interpreting future schemas as v1.
- `familyId + familyVersion + variantKey + schemaVersion` form the stable genome identity input. `ObjectGenome.identityParts()` is intended to feed the project StableId contract; ObjectGenome does not duplicate hashing/canonical encoding.
- `components`, per-component `supportKeys`, `mechanisms`, and `affordances` are canonical dense 1-based arrays. Sparse arrays and map-like extra keys are rejected so accepted plain data has one unambiguous shape.
- `materialKey` is an opaque stable reference. Objects do not import MaterialDNA implementation details or Roblox asset IDs.
- Roblox `Instance`, `Vector3`, `CFrame`, meshes, constraints, and rendering APIs are deliberately absent from the schema.
- Mutable wear, damage, mechanism position, and detach state live in `ObjectState`, never in the immutable genome.
- Mutable state is a complete snapshot for the referenced genome: every component/mechanism key must be present and unknown keys are rejected.

## Immutable ownership

Validation alone does not mutate or freeze caller-owned input. Production code that retains a genome uses `ObjectGenomeOwnership.own(genome)`. The ownership boundary accepts only the explicit v1 schema: records may not have metatables or unknown fields, canonical arrays must stay dense, non-plain/runtime values cannot enter declared scalar fields, and finite-number checks are enforced before retention.

Ownership then constructs a defensive schema-exact copy, validates that owned copy with `ObjectGenome.validate`, and recursively freezes the complete recipe tree. Later mutation of caller input therefore cannot rewrite resolved truth, and unversioned extra data cannot hide outside deterministic identity/schema rules. `ObjectGenomeFixtures` exports all three examples through this boundary. `ObjectGenome.defaultState()` intentionally returns a separate mutable `ObjectState`.

## Construction graph

Each component records:

- a stable semantic key and role,
- material assignment,
- mass,
- local position/rotation and dimensions,
- immediate `supportKeys`,
- optional external support (`ground`, `wall`, `ceiling`).

A component is structurally valid only when its support chain reaches an external support. Validators reject missing support nodes, self-support, cycles, unsupported/floating components, duplicate keys, non-positive mass/dimensions, and component bounds outside the declared object envelope.

The component mass sum must remain within 5% of the declared object mass. The genome also carries family plausibility envelopes for dimensions and mass plus local center-of-mass metadata.

## Mechanisms

The first production mechanism vocabulary is intentionally small and semantic:

- `hinge`
- `slide`
- `caster`
- `tilt`
- `latch`

Mechanisms reference component keys and plain axes/limits. A later Roblox realization adapter may choose constraints, servo settings, collision groups, fidelity simplifications, or authored meshes without changing the domain recipe.

## Affordances

Affordances describe stable interaction/grip regions (`grip`, `push`, `pull`, `sit`, `open`, `close`) on components using a local point and radius. They are not click detectors or animation spots; physical interaction systems can resolve them into the current representation.

## Validation APIs

- `ObjectGenome.inspect(genome)` returns a structured deterministic report with stable issue codes.
- `ObjectGenome.validate(genome)` asserts when the report is invalid.
- `ObjectGenomeOwnership.own(genome)` creates the schema-exact immutable production-owned recipe.
- `ObjectGenome.defaultState(genome)` creates separate zeroed mutable state.
- `ObjectGenome.inspectState(genome, state)` validates mutable state keys/ranges against the immutable recipe.
- `ObjectGenome.validateState(genome, state)` is the asserting state validator.

Stable issue codes are suitable for test diagnostics and future procedural rejection/repro tooling.

## Fixtures

`ObjectGenomeFixtures.luau` contains three immutable production-contract examples:

1. a task office chair with a load path, five casters, seat tilt, provenance, material assignments and interaction regions;
2. a rectangular utility office table with four ground-supported legs and anti-racking structure;
3. a three-drawer vertical filing cabinet with slide/latch mechanisms.

These are contract fixtures, not final art or Hero Feature implementations. Their purpose is to prove the schema can describe believable manufactured construction without depending on a MeshPart/prefab.

## Evolution

Changing field meaning or deterministic identity inputs requires an object schema/version decision. Extend mechanism/affordance vocabularies through this contract rather than embedding furniture-specific runtime state into unrelated systems.
