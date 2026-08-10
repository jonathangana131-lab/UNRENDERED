# MaterialDNA contract

`MaterialDNA` is the project-owned, Roblox-independent identity for a manufactured material recipe. It is resolved domain data, not a `Material`, `MaterialVariant`, `SurfaceAppearance`, texture asset, or live Workspace object.

## Immutable recipe

A MaterialDNA recipe records the stable facts needed to reconstruct why a surface looks, feels, and sounds the way it does:

- stable namespaced material ID and schema version,
- substrate family and physical thickness,
- manufactured finish family/process with bounded roughness and porosity,
- installation method, supplier/batch key, and optional seam period,
- apparent age,
- maintenance history,
- environmental exposure history,
- bounded historical events,
- project-owned visual-family key,
- physical-response class,
- acoustic-response class.

The visual-family key is deliberately indirect. Raw Roblox asset IDs are rejected by the domain validator; a later rendering registry/adaptor owns the mapping from approved project families to asset-backed PBR resources.

The schema is intentionally small. It describes perceptible material identity and causal history without turning the domain layer into a renderer or a universal chemistry simulation.

## Mutable surface state

Current wetness, wear, damage, dirt, and optional temperature live in `MaterialSurfaceState`, not in the immutable MaterialDNA recipe. This lets the same resolved material identity survive unload/reconstruction while meaningful current-state deltas can be persisted or simulated independently.

A generated apparent-history event such as old water staining belongs to the immutable recipe. A puddle that wets the carpet during play belongs to mutable surface state.

## Validation

`MaterialDNA.validateRecipe` returns structured issues instead of throwing on malformed input. `assertValidRecipe` is available at trusted construction boundaries. `MaterialDNA.SchemaVersion` names the one schema understood by this validator; a recipe declaring a different positive schema version is rejected as `unsupported_version` rather than being interpreted with v1 semantics.

The first production compatibility rules cover the Wave 1 fixtures:

- vinyl wallcovering requires a wall-compatible substrate and wallcovering adhesive,
- low-pile carpet requires a floor-compatible substrate and supported carpet adhesive installation,
- painted metal requires a steel or aluminum substrate.

Unknown future finish families are still accepted when their base fields are valid; new compatibility rules should be added only when a real material family requires them.

`MaterialDNA.validateSurfaceState` independently validates mutable state values.

## Reference fixtures

`MaterialExamples.luau` contains three deterministic, asset-ID-free reference recipes:

1. late-80s/90s commercial vinyl wallcovering over gypsum board,
2. glued low-pile commercial carpet over concrete,
3. baked-enamel painted steel suitable for office cabinets/fixtures.

These are contract fixtures and development fallbacks, not final art assets. They give later MaterialLab, ObjectGenome, acoustics, physics, and rendering work stable semantic inputs without coupling those systems to one Roblox representation.

## Versioning rule

Changing the meaning of existing fields, compatibility semantics, or reconstruction behavior requires an explicit schema-version decision. Already-resolved world content must never silently acquire new MaterialDNA meaning merely because implementation code changed. The v1 validator therefore accepts schema version `1` only; support for a later schema requires an explicit validator/migration change rather than falling through to v1 behavior.
