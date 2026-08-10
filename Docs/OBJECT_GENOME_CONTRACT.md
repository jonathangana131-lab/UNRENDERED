# ObjectGenome Contract

`ObjectGenome` is the immutable manufactured-object recipe used by the object domain. It describes what an object is built from and how its parts relate without assuming a Roblox `Model`, `MeshPart`, constraint hierarchy, or asset ID.

The contract intentionally stays plain-data and meter/kilogram based so deterministic generation, validation, persistence recipes, headless tests, and Roblox realization can share the same source of truth.

## Identity and versioning

Every genome carries:
- `schemaVersion` — serialization/contract schema version.
- `familyId` + `familyVersion` — stable manufactured family/version identity.
- `variantKey` — deterministic recipe/member key inside that family.
- `id` — canonical `og:<familyId>:v<familyVersion>:<variantKey>` composed by `ObjectGenome.composeId`.

Changing the meaning of an existing family in a way that would rewrite already-resolved content requires a new family version. Renderer/model changes that do not change domain meaning do not require a genome-version bump.

ObjectGenome IDs identify immutable recipes, not physical world instances. A `WorldEntityId` identifies an occurrence of an object in the world and survives representation changes.

## Construction graph

Each component has:
- a stable component key and semantic role,
- a MaterialDNA-facing `materialId` domain reference,
- mass and local center of mass,
- zero or more `supportKeys`,
- a `loadBearing` declaration.

An empty `supportKeys` list marks a structural root. The support graph must reference existing components and remain acyclic. Validators also require component masses to approximately sum to the object mass.

The graph is intentionally construction-oriented rather than a Roblox Instance tree. A future realizer can choose Parts, MeshParts, constraints, proxies, or an offline-authored mesh while preserving the same genome.

## Dimensions and plausibility

Dimensions are plain `{x, y, z}` meter records:
- `sizeM` is the actual bounding size for this genome.
- `plausibleMinM` / `plausibleMaxM` define the family's accepted manufacturing range.
- object/component centers of mass and affordance regions are local-space meter coordinates relative to the object bounds.

Validators reject non-finite/negative dimensions, dimensions outside the declared family range, and centers/interaction regions that sit implausibly outside the object bounds.

## Mechanisms

Mechanisms connect one moving component to one anchor component. The initial production contract supports:
- hinge,
- slide,
- caster swivel,
- tilt,
- latch.

Mechanisms declare canonical travel limits and units plus an optional break force. This is domain intent only; Roblox constraint selection belongs to the physical realization layer.

## Affordances

Affordances expose semantic interaction regions such as grip, sit, push, pull, open, close, and roll. They reference a component and may reference a mechanism.

They are not animation markers or hard-coded click targets. Physical-character grip/contact systems may later use these regions as candidate interaction geometry.

## Immutable genome vs mutable state

Wear, damage, detached parts, and current mechanism positions are intentionally excluded from the immutable genome.

`ObjectGenome.newState()` creates mutable `ObjectState`, and `ObjectGenome.validateState()` ensures mutable state only references components/mechanisms present in the immutable genome and that mechanism positions remain within declared limits.

Persistence should therefore treat the genome/generated base separately from meaningful state deltas.

## Production fixtures

`ObjectGenomeExamples.luau` contains three normal, manufacturable baseline fixtures:
- a five-caster upholstered office task chair,
- a welded-frame laminate office table,
- a three-drawer painted-steel filing cabinet.

These fixtures use semantic material-domain keys only. No Roblox asset IDs are embedded in the object contract.

## Validation boundary

`ObjectGenome.validate()` returns `(ok, issues)` so generators can reject candidates without throwing. `ObjectGenome.assertValid()` is available for authored fixtures/startup checks where a hard failure is appropriate.

Current validation covers deterministic identity, version/range rules, mass balance, support graph integrity, component/mechanism/affordance references, mechanism travel plausibility, and local bounds. Later family-specific generators may add stricter manufacturability checks without weakening this shared baseline.
