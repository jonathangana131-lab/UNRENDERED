# MaterialDNA Production Contract

MaterialDNA is the canonical plain-data material recipe shared by world generation, object construction, physical response, acoustics, wear/history systems, and Roblox realization adapters. It does not contain Roblox Instances, asset IDs, or renderer/package calls.

## Ownership boundary

A `MaterialRecipe` is canonical identity/history data. Call `MaterialDNA.freezeRecipe(input)` when a recipe becomes owned by the resolved world or a fixture/catalog. The function validates, deep-copies, and deep-freezes the complete recipe tree. Mutating the caller's input after that boundary cannot rewrite canonical material truth.

`MaterialState` is intentionally separate and mutable. It carries runtime/durable deltas such as wear, damage, wetness, and soil plus the exact `recipeId + recipeRevision` those deltas belong to. `validateStateForRecipe` rejects state from a different semantic material or content revision. Representation demotion/persistence should capture state without modifying the immutable recipe.

## Recipe layers

The v1 recipe keeps the material-history stack explicit:

1. substrate,
2. manufactured finish,
3. installation/batch,
4. apparent age,
5. maintenance,
6. environmental exposure,
7. bounded history events,
8. visual identity,
9. physical identity,
10. acoustic identity,
11. wetness/damage/stain response,
12. bounded anomaly modifiers.

Visual, physical, and acoustic profiles share a `coherenceClass`. They are different responses of one material identity, not independent random selections.

## Validation

`validateRecipe` accepts `unknown` plain data and returns a `ValidationResult`; structurally malformed persisted/generated input must report errors instead of crashing through missing nested fields. Canonical history/anomaly lists must be dense 1-based arrays with no keyed entries. Numeric plausibility ranges are finite and bounded.

The validator also rejects direct URLs/Roblox asset IDs in project-owned semantic keys and checks known semantic compatibility families. V1 examples include vinyl wallcovering on wall-compatible substrates with pasted-wallpaper installation, low-pile carpet on carpet backing with a supported carpet install method, and baked enamel on sheet metal with factory-coated-panel installation.

Compatibility checks are intentionally conservative. Adding a new material family should add an explicit production rule or remain unconstrained until its construction semantics are defined; do not infer arbitrary compatibility from string similarity.

V1 record shapes are closed: undeclared top-level or nested fields are validation errors. This prevents a generated or persisted field from validating and then being silently discarded by `freezeRecipe`. New canonical fields therefore require an explicit schema migration (or a future versioned extension mechanism with preservation semantics).

## Fixtures

`MaterialFixtures` provides three deliberately ordinary commercial materials:

- yellow vinyl wallcovering over gypsum board,
- beige low-pile commercial carpet,
- warm-gray baked-enamel sheet metal.

They are fallback/project semantic families, not licensed PBR asset references. Rendering adapters may map those family keys to approved project-owned assets later.

The literal fixture definitions live in `MaterialFixtureCatalog`, a pure builder shared by the Roblox `MaterialFixtures` wrapper and headless Lune regression tests. This keeps one production source of fixture truth while allowing CI to execute the exact same validation/freezing path without emulating Roblox `script.Parent` lookup.

## Versioning

`MaterialDNA.SchemaVersion` is currently `1`. Unknown schema versions are rejected. `recipeRevision` is a separate positive integer for canonical content changes that keep the same schema and semantic material ID. Changing the meaning/shape of established recipe data is a schema migration; changing established recipe values requires a new recipe revision. Persisted mutable state records that exact revision so already-resolved world truth cannot silently reinterpret old deltas under newer material content.

## Performance boundary

Recipe validation/freezing is bounded content-generation/persistence work, not frame-loop work. History is capped at 32 entries and anomaly modifiers at 8 entries. MaterialState validation is constant-size. Roblox physical/audio/render realization remains behind later adapters.
