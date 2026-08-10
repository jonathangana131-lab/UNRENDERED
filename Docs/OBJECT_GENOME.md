# ObjectGenome Contract

`ObjectGenome` is the immutable construction recipe for a manufactured object family/variant. It is domain data, not a Roblox prefab and not a `WorldEntityId`.

## Contract boundaries

- All measurements are plain-data SI units: meters, kilograms, degrees.
- `schemaVersion` is an explicit compatibility lock. A reader rejects unknown versions instead of interpreting future schemas as v1.
- `familyId + familyVersion + variantKey + schemaVersion` form the stable genome identity input. `ObjectGenome.identityParts()` supplies those semantic parts to the locked project `StableId` contract; ObjectGenome does not duplicate hashing/canonical encoding.
- `ObjectGenome.contentFingerprint()` is a separate versioned deterministic digest over the complete immutable recipe. It is a drift/review lock, not a replacement for the published v1 StableId inputs; changing fingerprint inputs does not silently rewrite `genomeId`.
- `components`, per-component `supportKeys`, `mechanisms`, and `affordances` are canonical dense 1-based arrays. Sparse arrays and map-like extra keys are rejected so accepted plain data has one unambiguous shape.
- Each component pins an exact MaterialDNA recipe revision as `(materialKey, materialRecipeVersion)`. ObjectGenome reconstructs that plain `{ id, recipeVersion }` pair and delegates validation to the production MaterialDNA v2 reference contract, while remaining asset-agnostic and free of Roblox representation data. A published component material-revision change is a canonical object recipe change and therefore requires the corresponding `familyVersion` to advance rather than silently retargeting an established genome identity.
- Roblox `Instance`, `Vector3`, `CFrame`, meshes, constraints, and rendering APIs are deliberately absent from the schema.
- Mutable wear, damage, mechanism position, and detach state live in `ObjectState`, never in the immutable genome.
- Mutable state is a complete snapshot for the referenced genome: every component/mechanism key must be present and unknown keys are rejected.
- Every `ObjectState` stores `genomeId = ObjectGenome.identityKey(genome)`. State validation requires exact equality, so a snapshot cannot be silently reinterpreted against another family/variant revision merely because its component/mechanism keys happen to match.

## Immutable ownership

Validation alone does not mutate or freeze caller-owned data. Production code that retains a generated/decoded genome calls `ObjectGenomeOwnership.own(genome)`. The ownership boundary first applies the semantic validator, then requires the exact v1 record shape at every canonical table, rejects metatables/unknown schema keys, copies only explicitly versioned fields into a detached data graph, validates the owned copy, and recursively freezes it.

This prevents unversioned fields, runtime objects, representation state, caller aliases, and later mutation from entering or rewriting resolved ObjectGenome truth. Unknown top-level or nested fields are rejected rather than silently retained or silently dropped. `ObjectGenome.defaultState()` remains intentionally separate and mutable for wear, damage, mechanism position, and detach state; mutability does not remove its required exact `genomeId` reference.

## Construction graph

Each component records:

- a stable semantic key and role,
- exact material recipe id/revision,
- mass,
- local position/rotation and dimensions,
- immediate `supportKeys`,
- optional external support (`ground`, `wall`, `ceiling`).

A component is structurally valid only when its support chain reaches an external support. Validators reject missing support nodes, self-support, cycles, unsupported/floating components, duplicate keys, non-positive mass/dimensions, and component bounds outside the declared object envelope.

The component mass sum must remain within 5% of the declared object mass. The genome also carries family plausibility envelopes for dimensions and mass plus local center-of-mass metadata.

## Transform convention

Schema v1 uses one explicit plain-data local basis and rotation convention so independent realization adapters resolve identical geometry without relying on Roblox types:

- object-local `+X` is right, `+Y` is up, and `+Z` is back; the basis is right-handed;
- `localRotationDeg = { x, y, z }` stores **fixed-axis (extrinsic) XYZ** rotations in degrees about that object-local basis: rotate about basis `+X`, then basis `+Y`, then basis `+Z`;
- for column-vector math, the composed matrix is therefore `Rz * Ry * Rx`;
- every stored Euler component uses the bounded v1 representation `[-180, 180]` degrees. Equivalent turns outside that range are rejected rather than silently normalized; the inclusive endpoints are bounded representations, not a claim of globally unique Euler encoding;
- component-envelope validation evaluates the rotated component AABB using `abs(R) * halfDimensions`, then applies the component's local translation. Rotation is therefore part of the v1 bounds invariant rather than an adapter-specific afterthought.

This convention is intentionally project-owned domain math. A Roblox realization adapter may convert it to `CFrame`, but the canonical recipe never stores `CFrame` or delegates rotation order to an engine default. Tests include a mixed-axis case that distinguishes the declared matrix order from a silently reversed order.

## Mechanisms

The first production mechanism vocabulary is intentionally small and semantic:

- `hinge`
- `slide`
- `caster`
- `tilt`
- `latch`

Mechanism `axis`, caster `swivelAxis`, and caster `rollAxis` values are canonical unit direction vectors in the same object-local basis. Their magnitude must be within `0.0001` of `1.0`; scale-bearing alternatives such as `{ x = 0, y = 2, z = 0 }` are invalid recipes. This prevents equivalent directions from acquiring multiple persistent encodings or requiring adapter-specific normalization.

Mechanisms reference component keys and plain axes/limits. A later Roblox realization adapter may choose constraints, servo settings, collision groups, fidelity simplifications, or authored meshes without changing the domain recipe.

## Affordances

Affordances describe stable interaction/grip regions (`grip`, `push`, `pull`, `sit`, `open`, `close`) on components using a local point and radius. They are not click detectors or animation spots; physical interaction systems can resolve them into the current representation.

## Validation APIs

- `ObjectGenome.inspect(genome)` returns a structured deterministic report with stable issue codes.
- `ObjectGenome.validate(genome)` asserts when the report is invalid.
- `ObjectGenome.contentFingerprint(genome)` returns the versioned full immutable-recipe drift fingerprint without changing `identityParts()` / `genomeId` semantics.
- `ObjectGenomeOwnership.own(genome)` validates exact canonical shape, defensively copies, and recursively freezes a production-owned recipe.
- `ObjectGenome.defaultState(genome)` creates separate zeroed mutable state bound to the exact canonical genome identity.
- `ObjectGenome.inspectState(genome, state)` validates the state identity plus mutable keys/ranges against the immutable recipe.
- `ObjectGenome.validateState(genome, state)` is the asserting state validator.

The semantic validators themselves are fail-closed plain-data boundaries, not only the ownership copier: undeclared v1 record fields are rejected before retention, metatable-backed canonical tables are rejected before metamethods can influence field reads, `ObjectState` has an exact top-level v1 shape, and its mutable maps may not carry metatables. This keeps validation/identity behavior dependent only on explicit versioned data.

Stable issue codes are suitable for test diagnostics and future procedural rejection/repro tooling.

## Fixtures

`ObjectGenomeFixtures.luau` contains three production-contract examples:

1. a task office chair with a load path, five casters, seat tilt, provenance, exact material recipe revisions and interaction regions;
2. a rectangular utility office table with four ground-supported legs and anti-racking structure;
3. a three-drawer vertical filing cabinet with slide/latch mechanisms.

These are contract fixtures, not final art or Hero Feature implementations. Their purpose is to prove the schema can describe believable manufactured construction without depending on a MeshPart/prefab. Tests also pass these recipes through the immutable ownership boundary before treating them as retained canonical data.

## Evolution

Changing field meaning or deterministic identity inputs requires an object schema/version decision. Changing published canonical recipe content such as a component's exact material revision requires advancing `familyVersion`; fixture content fingerprints must change only alongside that intentional revision. Extend mechanism/affordance vocabularies through this contract rather than embedding furniture-specific runtime state into unrelated systems.
