# Physics Lab Runtime Recipe Authenticity

## Finding

The retained Physics Lab runtime synthesis authenticates canonical recipe identity, WorldEntity population, provenance, state, and revisions before runtime authority construction. The same constructor does not currently compare the realization-bearing `EntityRecipe` values against `PhysicsLabRecipe.build()`.

Those values are part of the permanent lab recipe contract. Primitive entries include kind, role, size, transform, material, collision, and transparency. Object entries include kind, ObjectGenome key/id/fingerprint, and transform. `PhysicsLabRealizer` consumes these values when creating Roblox representation.

The current production Realizer builds the recipe internally, so this is a source-contract and future integration gap rather than evidence of live Workspace corruption.

## Required boundary

Before a recipe is treated as the canonical Physics Lab, one of these contracts must be explicit:

1. The runtime constructor authenticates the complete canonical recipe, including both WorldEntity records and all realization-bearing `EntityRecipe` values; or
2. The runtime constructor is explicitly domain-record-only, and the Realizer independently authenticates the complete realization-bearing recipe before allocating Instances.

A canonical recipe key plus canonical WorldEntity records is not sufficient proof that realization data is canonical.

## Regression target

Add pure regressions that preserve the canonical entity key and WorldEntity record while changing at least:

- one primitive realization field, such as size, transform, material, collision, or transparency; and
- one object realization field, such as ObjectGenome key/id/fingerprint or transform.

The chosen owner boundary must reject those variants before authority or physical representation is created.

## Scope

This finding does not unlock new Hero features, change the current F2 representation, or claim Roblox Studio evidence. It is intended for absorption by the existing Physics Lab runtime synthesis/recipe-fence lineage when the trusted-control integration blocker clears.
