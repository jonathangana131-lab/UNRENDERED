# MaterialDNA Production Contract

MaterialDNA is the canonical plain-data material recipe shared by world generation, object construction, physical response, acoustics, wear/history systems, and Roblox realization adapters. It does not contain Roblox Instances, asset IDs, or renderer/package calls.

## Ownership boundary

A `MaterialRecipe` is canonical identity/history data. Call `MaterialDNA.freezeRecipe(input)` when a recipe becomes owned by the resolved world or a fixture/catalog. The function validates, deep-copies, and deep-freezes the complete recipe tree. Mutating the caller's input after that boundary cannot rewrite canonical material truth.

A material's stable `id` identifies the material line, while its positive `recipeVersion` identifies one exact immutable content revision of that line. Changing canonical visual, physical, acoustic, history, response, or other recipe values without changing the schema must increment `recipeVersion`; embedded version-like text in an `id` is opaque and is not the authoritative content revision.

`MaterialState` is intentionally separate and mutable. It carries runtime/durable deltas such as wear, damage, wetness, and soil together with the exact `recipeId`, `recipeVersion`, and `schemaVersion` that those deltas belong to. `MaterialDNA.defaultState(recipe)` derives that tuple from a validated recipe, and `MaterialDNA.stateMatchesRecipe(recipe, state)` can reject a state from a different content revision. Representation demotion/persistence should capture state without modifying or silently upgrading the immutable recipe.

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

`validateRecipe` accepts `unknown` plain data and returns a `ValidationResult`; structurally malformed persisted/generated input must report errors instead of crashing through missing nested fields. Canonical history/anomaly lists must be dense 1-based arrays with no keyed entries. Numeric plausibility ranges are finite and bounded. `recipeVersion` is a positive integer so the persistence reference cannot use an ambiguous zero/latest sentinel.

The validator also rejects direct URLs/Roblox asset IDs in project-owned semantic keys and checks known semantic compatibility families. V1 examples include vinyl wallcovering on wall-compatible substrates with pasted-wallpaper installation, low-pile carpet on carpet backing with a supported carpet install method, and baked enamel on sheet metal with factory-coated-panel installation.

Compatibility checks are intentionally conservative. Adding a new material family should add an explicit production rule or remain unconstrained until its construction semantics are defined; do not infer arbitrary compatibility from string similarity.

## Fixtures

`MaterialFixtures` provides three deliberately ordinary commercial materials:

- yellow vinyl wallcovering over gypsum board,
- beige low-pile commercial carpet,
- warm-gray baked-enamel sheet metal.

They are fallback/project semantic families, not licensed PBR asset references. Rendering adapters may map those family keys to approved project-owned assets later. The current catalog recipes are content revision `1`; future tuning of an established material keeps its stable `id` and increments `recipeVersion`.

## Versioning

`MaterialDNA.SchemaVersion` is currently `1`. Schema version controls the shape and interpretation rules of the contract; unknown schema versions are rejected. Changing the meaning or shape of established recipe fields is a schema migration, not an unversioned refactor.

`MaterialRecipe.recipeVersion` is independent of schema version and controls the canonical content revision for one stable material `id`. Any change to established canonical recipe values under the same schema increments this positive integer. Persisted mutable state identifies the exact `(recipeId, recipeVersion, schemaVersion)` tuple and must never resolve to an implicit "latest recipe by ID." Already-resolved world truth therefore cannot silently reinterpret old material values after a catalog tune.

A schema migration may also require a new recipe revision, but the two version numbers answer different questions: schema version says how to decode the data; recipe version says which exact material content was resolved.

## Performance boundary

Recipe validation/freezing is bounded content-generation/persistence work, not frame-loop work. History is capped at 32 entries and anomaly modifiers at 8 entries. MaterialState validation is constant-size. Roblox physical/audio/render realization remains behind later adapters.
