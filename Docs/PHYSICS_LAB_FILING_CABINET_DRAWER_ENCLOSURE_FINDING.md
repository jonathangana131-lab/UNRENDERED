# Physics Lab filing-cabinet drawer enclosure finding

Status: source-only capacity-mining finding

Audit base: `main@af6a17aa7969d40e8b19f7e9d19fe93cc9b1d9a9`

## Finding

The permanent Physics Lab's filing-cabinet ObjectGenome authors a full-size `shell` component and three drawer components, while the F2 realizer materializes **every** ObjectGenome component as a solid, anchored, collidable `Part`.

Those two contracts currently produce a physically contradictory F2 cabinet: each drawer is completely enclosed inside the solid shell volume rather than presenting a drawer front/opening.

This is source geometry / representation evidence only. It is not a Roblox Studio contact, viewport, articulation, or mechanism PASS/FAIL claim.

## Exact authored geometry

`src/shared/Objects/ObjectGenomeFixtures.luau` defines the filing-cabinet shell as:

- local center: `(0, 0, 0)` m;
- dimensions: `(0.48, 1.32, 0.62)` m;
- therefore shell bounds are `x=[-0.24, 0.24]`, `y=[-0.66, 0.66]`, `z=[-0.31, 0.31]`.

Each drawer is `(0.42, 0.28, 0.52)` m at local `z=-0.01` m. Their Y centers are `0.38`, `0.05`, and `-0.28` m, so their exact bounds are:

- top: `x=[-0.21, 0.21]`, `y=[0.24, 0.52]`, `z=[-0.27, 0.25]`;
- middle: `x=[-0.21, 0.21]`, `y=[-0.09, 0.19]`, `z=[-0.27, 0.25]`;
- bottom: `x=[-0.21, 0.21]`, `y=[-0.42, -0.14]`, `z=[-0.27, 0.25]`.

All six drawer faces lie strictly inside the shell bounds. In particular, every drawer is inset `0.03 m` from each shell X face, `0.04 m` from the shell's negative-Z face, and `0.06 m` from its positive-Z face. The authored 180-degree world yaw for `cabinet-a` preserves that local containment.

## Why the F2 representation makes this concrete

`src/server/PhysicsLab/PhysicsLabRealizer.luau` loops over `genome.components` and creates a `Part` for every component using its exact authored dimensions/transform. Each such component Part is currently:

- `Anchored = true`;
- `CanCollide = true`;
- `CanQuery = true`;
- `CanTouch = true`.

The shell is therefore realized as one solid collidable box occupying the complete cabinet envelope, while all three solid drawer Parts occupy volumes wholly inside that same box.

This is not merely a future F3 articulation concern. At F2 the component realization already treats the shell and drawers as simultaneous physical geometry, so the drawer construction graph is not represented as manufacturable cabinet geometry.

## Non-duplication

This finding is distinct from the current external placement finding in PR #473 (`cabinet-a` versus the lab `ledge`). That finding concerns the cabinet's **world-space outer envelope** intersecting an unrelated lab primitive. This finding concerns **self-geometry inside the cabinet's own ObjectGenome/F2 realization**.

It is also distinct from the retained chair caster/COM work, rolling-cart caster/COM work, rolling-cart shelf/frame debt, commercial-door hollow-frame/leaf-clearance work, and generic ObjectGenome mechanism/schema validation. Repository PR/issue searches for filing-cabinet shell/drawer overlap or enclosure surfaced only superseded PR #167's old dynamic-drawer implementation note, not a dedicated current repair/finding.

## Smallest safe successor contract

If this finding is explicitly unlocked for implementation, keep the existing production architecture and close the geometry contradiction rather than introducing another cabinet framework.

A bounded successor should:

1. define which ObjectGenome component geometry is canonical physical volume versus structural/semantic envelope metadata for the filing-cabinet family;
2. make the F2 representation expose plausible drawer-front/carcass geometry without positive-volume self-intersection between a solid full-envelope shell and the drawers;
3. preserve the cabinet's stable WorldEntity identity, ObjectGenome family identity unless an intentional family revision is required, material references, drawer mechanism keys, latch relationship, and authored outer dimensions unless the repair explicitly versions them;
4. add deterministic Pure Luau geometry regression coverage proving each drawer is physically representable at its closed state and remains compatible with its slide axis/travel contract;
5. keep actual Roblox articulation/contact/visual-quality evidence separate and unclaimed until a real Studio run exists.

A likely implementation can either decompose the carcass into manufacturable panels/rails or establish an explicit project-owned proxy representation rule. The audit does not preselect one architecture-risky solution.

## Evidence boundary

No production source is changed by this finding. No generator/schema version, ObjectGenome bytes, Physics Lab recipe, Roblox Instance, persistence, networking, authority, or Hero unlock changes are made.

No local Luau or Roblox Studio execution is claimed. Canonical GitHub CI on the docs-only branch is the executable validation for this publication.
