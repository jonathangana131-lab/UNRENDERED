# MaterialDNA v1 Contract

MaterialDNA is the domain identity for a material recipe. It is plain/versioned data and does not contain Roblox Instances, `MaterialVariant` objects, `SurfaceAppearance` objects, asset IDs, URLs, or rendering-package calls.

The v1 contract lives in `src/shared/Materials/MaterialDNA.luau`. Approved example recipes live in `src/shared/Materials/MaterialFixtures.luau`.

## Immutable recipe vs mutable state

`MaterialRecipe` is canonical/generated truth. Once a resolved entity or region references a recipe, the recipe is treated as immutable for that schema/generation version. It contains:

1. stable material ID and schema version,
2. coherence class shared by visual/physical/acoustic bindings,
3. substrate,
4. manufactured finish,
5. installation method/batch/quality,
6. apparent age,
7. maintenance history summary,
8. environmental exposure,
9. bounded historical events,
10. visual family key and scale,
11. physical response,
12. acoustic response,
13. wetness/damage/stain response parameters,
14. optional bounded anomaly modifier keys.

`MaterialState` is mutable runtime/persistent delta state. v1 keeps only wear, damage, wetness, and soil amounts plus the source recipe ID/schema version. A state mutation must not rewrite the immutable recipe to represent temporary wetness or player damage.

## Coherence rule

`coherenceClass` is the cross-domain semantic identity. The visual, physical, and acoustic sections must carry the same coherence class. This prevents a recipe from silently combining unrelated identities such as a metal-looking visual family, carpet-like friction, and plastic impact audio.

The individual `familyKey`/`classKey` values remain subsystem-specific so rendering, physics, and audio adapters can evolve independently while still proving they belong to one coherent material identity.

## Project-owned keys and asset boundary

IDs and semantic keys use lowercase stable-key characters (`a-z`, `0-9`, `.`, `_`, `/`, `-`). Raw `rbxassetid://` values and HTTP(S) URLs are rejected by the domain validator.

`visual.familyKey` is therefore a project-owned lookup key such as `fallback.commercial-carpet.low-pile-beige`. A future registry/binding layer (planned by #13) maps that key to approved Roblox assets. The domain recipe never owns those asset IDs.

The same rule applies to `impactFamilyKey` and `scrapeFamilyKey`: they identify semantic audio families, not Sound asset IDs.

## Normalized values and physical bounds

Normalized `*01` values are finite numbers in `[0, 1]`.

Additional v1 bounds are deliberately broad enough for production content while rejecting nonsensical or dangerous data:

- substrate thickness: `(0, 5]` meters,
- apparent age: `[0, 250]` years,
- visual repeat scale: `(0, 100]` meters,
- density: `(0, 25000]` kg/m3,
- static/dynamic friction: `[0, 4]`, with dynamic friction not exceeding static friction,
- wet friction multiplier: `[0, 2]`,
- history events: at most 32,
- anomaly modifiers: at most 8.

These are validation bounds, not claims that every value inside them is appropriate for every material family. Family-specific generators/registries should impose tighter plausibility ranges.

## Historical events vs runtime deltas

`historyEvents` describes apparent pre-observation history that belongs to the immutable generated recipe: traffic wear, cabinet shadows, spot cleaning, moisture scars, repair evidence, and similar causal surface history.

Fresh player-caused damage, current wetness, and current soil belong in `MaterialState`/future durable deltas. This keeps generated base + meaningful deltas separate.

## Anomaly modifiers

Normal materials should normally have an empty `anomalyModifiers` list. The field exists so a later explicit anomaly pass can attach controlled semantic modifiers without replacing MaterialDNA with a parallel framework. The material generator should not independently roll unrelated anomalies.

## Example fixtures

The checked-in fixtures establish three ordinary commercial baselines:

- wallpaper over gypsum board,
- glued low-pile commercial carpet,
- warm-gray painted sheet metal.

They intentionally use fallback semantic visual/audio family keys and no licensed external assets.

## Validation API

- `validateRecipe(recipe)` returns `{ ok, errors }` without throwing.
- `assertValidRecipe(recipe)` asserts with the aggregated validation errors.
- `validateState(state)` / `assertValidState(state)` do the same for mutable state.
- `defaultState(recipeId)` creates a clean zero-delta state for a validated project key.
- `validate(recipe)` remains as a compatibility assertion alias while early bootstrap callers migrate.

Every generator or content fixture should validate before canonical observation/persistence. Procedural failures should attach the generator repro key at the call site; MaterialDNA itself does not own world/region RNG state.

## Versioning

`SchemaVersion` is currently `1`, matching `Docs/PROJECT_STATE.md`.

Changing field meaning, serialization meaning, or validation semantics in a way that can reinterpret already-resolved content requires a schema/version migration decision. Adding a renderer binding or approved asset entry behind a stable semantic key does not by itself change MaterialDNA identity.
