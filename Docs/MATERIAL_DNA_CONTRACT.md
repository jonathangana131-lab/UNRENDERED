# MaterialDNA Production Contract

MaterialDNA is the canonical plain-data material recipe shared by world generation, object construction, physical response, acoustics, wear/history systems, and Roblox realization adapters. It does not contain Roblox Instances, asset IDs, or renderer/package calls.

## Ownership boundary

A `MaterialRecipe` is canonical identity/history data. Call `MaterialDNA.freezeRecipe(input)` when a recipe becomes owned by the resolved world or a fixture/catalog. The function validates, deep-copies, and deep-freezes the complete recipe tree. Mutating the caller's input after that boundary cannot rewrite canonical material truth.

`MaterialState` is intentionally separate and mutable. It carries runtime/durable deltas such as wear, damage, wetness, and soil. Representation demotion/persistence should capture state without modifying the immutable recipe.

A material's durable content identity is `{ id, recipeVersion }`. `id` names the stable material identity; `recipeVersion` is a positive integer content revision and must increase whenever canonical physical, visual, acoustic, history, response, or other recipe values change for that `id`. `schemaVersion` is different: it versions the record shape. A previously published `{ id, recipeVersion }` pair must never be reused for different content, including across schema migrations.

`MaterialState` stores both `recipeId` and `recipeVersion`. `validateStateForRecipe` rejects applying a state snapshot to any other recipe revision, and `MaterialDNA.reference(recipe)` returns the small frozen `{ id, recipeVersion }` value that other domain contracts can persist without importing rendering or asset concerns.

The existing fixture IDs contain a `.v1.` token as part of their stable material identity namespace; that token is not `MaterialDNA.SchemaVersion` and is intentionally not renamed during the schema-v2 migration.

## Recipe layers

The schema-v2 recipe keeps the material-history stack explicit:

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

`maintenance.repairCount` is a canonical non-negative integer counter in `[0, 9007199254740991]` (`2^53 - 1`). Values at or above `2^53` are rejected so distinct conceptual repair counts cannot alias once represented as IEEE-754 doubles before validation, freezing, or persistence.

The validator also rejects direct URLs/Roblox asset IDs in project-owned semantic keys and checks known semantic compatibility families. Schema-v2 examples include vinyl wallcovering on wall-compatible substrates with pasted-wallpaper installation, low-pile carpet on carpet backing with a supported carpet install method, and baked enamel on sheet metal with factory-coated-panel installation.

Compatibility checks are intentionally conservative. Adding a new material family should add an explicit production rule or remain unconstrained until its construction semantics are defined; do not infer arbitrary compatibility from string similarity.

Schema-v2 record shapes are closed: undeclared top-level or nested fields are validation errors. This prevents a generated or persisted field from validating and then being silently discarded by `freezeRecipe`. New canonical fields therefore require an explicit schema migration (or a future versioned extension mechanism with preservation semantics).

## Fixtures

`MaterialFixtures` provides three deliberately ordinary commercial materials:

- yellow vinyl wallcovering over gypsum board,
- beige low-pile commercial carpet,
- warm-gray baked-enamel sheet metal.

They are fallback/project semantic families, not licensed PBR asset references. Rendering adapters may map those family keys to approved project-owned assets later.

The literal fixture definitions live in `MaterialFixtureCatalog`, a pure builder shared by the Roblox `MaterialFixtures` wrapper and headless Lune regression tests. This keeps one production source of fixture truth while allowing CI to execute the exact same validation/freezing path without emulating Roblox `script.Parent` lookup.

## Versioning

`MaterialDNA.SchemaVersion` is currently `2`. Unknown schema versions are rejected. Changing the meaning/shape of established recipe data is a schema migration, not an unversioned refactor. Already-resolved world truth must never silently reinterpret an old recipe under a new schema.

Schema v2 introduces the required `recipeVersion` content-revision field and exact state/reference binding. Schema v1 did not encode enough information to distinguish two immutable revisions of one material ID, so v1 records are rejected at this Foundation-Lock boundary rather than being guessed or silently upgraded. A future persistence migration must choose an explicit revision from authoritative historical data; it must not infer one from current material content.

`recipeVersion` is independent from `schemaVersion`: schema revisions describe how to decode a record; recipe revisions distinguish immutable material content. Content-only edits require a new recipe revision even when the schema stays v2. Recipe revisions are positive 31-bit integers, and schema migrations must preserve the rule that an existing `{ id, recipeVersion }` pair never resolves to different material truth.

## Performance boundary

Recipe validation/freezing is bounded content-generation/persistence work, not frame-loop work. History is capped at 32 entries and anomaly modifiers at 8 entries. MaterialState validation is constant-size. Roblox physical/audio/render realization remains behind later adapters.
