# Physics Lab door / wall-header clearance finding

## Scope

This is a bounded, source-only Reality-Grade geometry finding for the permanent Physics Lab. It does not change production source, claim Roblox Studio contact evidence, or unlock Door/Chair/Player work.

Audited source: `main@af6a17aa7969d40e8b19f7e9d19fe93cc9b1d9a9`.

## Finding

The authored front-wall opening and the grounded commercial-door envelope disagree vertically by much more than they disagree horizontally.

`PhysicsLabRecipe` authors:

- `wall-front-left` and `wall-front-right` so the centered opening spans `x = [-0.60, 0.60] m`;
- `wall-front-header` at `y = 3.125 m` with height `1.75 m`, so its underside is `2.25 m` above the floor;
- `door-main` at `y = 1.08 m`.

`PhysicsLabObjectGenomes.commercialDoor` authors an outer envelope of `1.18 x 2.16 x 0.14 m`. Because the door is grounded, its envelope spans `x = [-0.59, 0.59] m` and `y = [0.00, 2.16] m`.

Therefore the installed clearances are:

- left: `0.01 m`;
- right: `0.01 m`;
- head: `0.09 m`.

The realized door-frame header itself reaches the same `2.16 m` top plane (`door origin 1.08 + local header center 1.015 + half-height 0.065`). The F2 realizer creates the wall header and all ObjectGenome components as anchored Parts at those exact authored transforms. The resulting ~9 cm vertical strip is therefore real empty opening geometry in the disposable physical representation, not only metadata drift.

That is inconsistent with the deliberately small positive clearances already used inside the door proxy and with the ~1 cm side installation clearances. It is large enough to read as an accidental construction gap in the permanent normality lab rather than a controlled anomaly.

## Non-duplication

This is not the already-known ramp-entry/floor penetration finding: PR #302's discussion already records that exact ramp geometry.

It is also distinct from:

- merged PR #174 / #187, which make the *door leaf relative to its own jamb/header* manufacturable and mass/COM coherent;
- the closed PR #302 geometry draft, whose proposed wall-opening assertion allowed head clearance up to `0.15 m` and therefore would accept the current `0.09 m` mismatch;
- PR #473, which records the separate cabinet / ledge positive-volume overlap;
- the retained chair caster/COM, cart caster/COM, cart shelf/frame, scale, and validation-contract lineages.

Repository PR searches for `door top clearance`, `rough opening`, `wall header`, `90 mm`, and `9 cm` did not surface a dedicated door-frame-to-wall-head closure.

## Smallest production follow-up

Materialize a narrow Physics Lab geometry leaf rather than reopening the Hero Door feature.

Acceptance should require:

1. preserve the same conceptual `door-main` WorldEntity and commercial-door ObjectGenome unless the door itself truly needs a versioned geometry change;
2. keep the door grounded and the front opening centered;
3. reduce the frame-to-wall head clearance to the same small installation scale as the existing side clearances, with an explicit source-owned tolerance;
4. avoid introducing positive-volume overlap between the wall header and door frame;
5. version the canonical Physics Lab recipe/generator when changing authored canonical geometry, without rotating StableIds merely for a placement repair;
6. add deterministic Pure Luau regression coverage that computes left/right/head clearances from the authored wall opening and the realized door/frame envelope and fails on the current `0.09 m` head gap;
7. preserve the landed leaf-to-frame clearance, hollow aperture, hinge binding, door mass/COM, and all unrelated retained geometry contracts;
8. require fresh exact-head CI and independent review before integration.

A likely minimal geometry-only correction is to extend the front wall header downward while keeping its top flush with the 4.00 m wall top, rather than lifting the grounded door. The exact clearance target should remain an explicit reviewed production constant, not an accidental by-product of arithmetic.

## Evidence boundary

This finding is derived from deterministic authored meter geometry and the current F2 realization transform path. It does **not** prove Roblox engine contact quality, traversal feel, viewport appearance, articulated door behavior, performance, networking, persistence, or two-client authority. Those remain governed by the existing Hero-Gate evidence lanes.
