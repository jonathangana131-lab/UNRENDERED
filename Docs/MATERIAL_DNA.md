# MaterialDNA production contract

Issue #5 promotes the bootstrap flat material record into the first production domain contract for visual, physical, acoustic, and history-coherent material identity.

## Boundary

`MaterialDNA` is plain Luau data. It does not know about `Instance`, `MaterialVariant`, `SurfaceAppearance`, texture IDs, sound IDs, or a rendering/audio package.

The immutable `MaterialRecipe` contains:
- stable opaque material ID plus explicit schema/recipe versions,
- substrate, manufactured finish, installation, apparent-age, maintenance, environment, and history-event layers,
- a project-owned visual family key and normalized visual parameters,
- a physical class/profile,
- an acoustic class/profile plus project-owned impact/scrape family keys.

The mutable `MaterialState` contains current wear, damage, wetness, and soil. Creating a `MaterialDNA` record deep-copies/freezes the recipe while leaving state mutable. This keeps canonical history/identity separate from runtime or persistent deltas.

## Identity and determinism

`MaterialRecipe.id` is opaque to this module. Authoring and deterministic generation may use the project StableId contract once that contract is locked; MaterialDNA deliberately does not duplicate or pre-empt StableId hashing rules.

`schemaVersion` is currently `1`. `recipeVersion` is a positive per-recipe version used when a specific recipe family evolves. Resolved content must not silently mutate merely because a future schema or family changes.

## Asset indirection

Visual, impact, and scrape references are lowercase project keys such as `surface.office.carpet.low_pile` or `sound.impact.painted_sheet_metal`. The validator rejects raw Roblox asset IDs in these fields.

A later project-owned registry/adapter may resolve these keys to approved Roblox assets. Domain content must not embed those asset IDs directly.

## Validation policy

The validator rejects invalid ranges and broadly impossible combinations before realization. Current checks include:
- finite/bounded normalized values,
- positive physical dimensions/density,
- coating thickness not exceeding the substrate thickness,
- installation orientation and seam plausibility,
- integer repair counts,
- unique event keys and events that do not predate the material's apparent age,
- dynamic friction not exceeding static friction,
- indirect project keys rather than raw Roblox asset IDs,
- mutable wear/damage/wetness/soil constrained to `[0, 1]`.

These checks are intentionally physical/domain-level. Rendering package rules belong in adapters, and deeper collision/acoustic event contracts belong in their own later systems.

## Canonical fixtures

`MaterialFixtures.luau` provides three deterministic, asset-agnostic production examples:
1. late-20th-century commercial vinyl wallcovering over gypsum board,
2. low-pile office carpet tile,
3. powder-coated cold-rolled steel.

They are regression fixtures and starting points for the future Material/Physics Lab, not final art assets.
