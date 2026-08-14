# Physics Lab Cabinet / Ledge Clearance Finding

## Finding

The authored Physics Lab recipe places `cabinet-a` partially inside the collidable `ledge` primitive.

This is a source-visible physical-geometry defect in the permanent Hero Gate lab, not a Studio-evidence claim.

On current `main` (`PhysicsLabRecipe.luau`):

- `ledge` is an axis-aligned primitive with size `(2.2, 0.65, 1.8)` m centered at `(3.6, 0.325, 2.8)` m;
- its world extents are therefore `x=[2.50, 4.70]`, `y=[0.00, 0.65]`, `z=[1.90, 3.70]` m;
- `cabinet-a` is placed at `(4.85, 0.66, 3.90)` m with a 180-degree yaw;
- the retained `filingCabinet` shell is centered at the ObjectGenome origin with dimensions `(0.48, 1.32, 0.62)` m;
- 180-degree yaw preserves those axis-aligned extents, so the shell occupies `x=[4.61, 5.09]`, `y=[0.00, 1.32]`, `z=[3.59, 4.21]` m.

The authored ledge and cabinet shell therefore have positive overlap on every axis:

- `x`: `4.61..4.70` = **0.09 m**;
- `y`: `0.00..0.65` = **0.65 m**;
- `z`: `3.59..3.70` = **0.11 m**.

That is approximately `0.006435 m^3` of overlapping world-space bounding volume before meters-to-studs conversion.

Both representations are collidable anchored Parts in the current F2 realizer. This is not merely a decorative mesh intersection: the Physics Lab currently authors two collision volumes into the same physical space.

## Why this matters

The Physics Lab is the permanent Reality-Grade validation environment for physical movement and contact behavior. Static authored fixtures should not create accidental collision seams that can contaminate character contact, object contact, or later engine evidence.

The overlap also weakens the lab as evidence: a snag, depenetration response, contact normal, or movement artifact near the ledge/cabinet corner would be ambiguous between the tested system and malformed fixture placement.

The existing recipe regression coverage validates deterministic entity identity, material/ObjectGenome binding, the commercial-door internal frame geometry, and retained rolling-cart support/COM invariants. It does not currently assert world-space non-intersection between this cabinet placement and the ledge.

## Required boundary

A bounded Physics Lab geometry successor should remove the accidental `cabinet-a` / `ledge` overlap without widening into Hero Door/Chair/Player implementation.

Acceptable repair shape:

1. preserve `cabinet-a` as the same conceptual lab entity and preserve its ObjectGenome architecture;
2. move the cabinet, move/resize the ledge, or otherwise revise the authored placement so the two collidable envelopes have no positive-volume overlap;
3. keep the cabinet grounded and inside the lab shell with useful circulation/inspection clearance;
4. explicitly advance the project-owned Physics Lab recipe/generator revision according to the existing canonical-versioning convention; do not rotate StableIds merely to repair placement;
5. add deterministic source-only regression coverage that reconstructs the relevant world-space extents and proves the cabinet/ledge collision volumes do not overlap;
6. preserve existing door/cart/chair geometry regressions and deterministic recipe ordering;
7. do not convert a source fix into Roblox Studio/contact PASS. Fresh engine evidence remains a separate gate once the display path is available.

A small reusable world-space authored-fixture clearance helper is reasonable if it directly replaces repeated test math, but this finding does not justify a new geometry framework or generic collision engine.

## Regression target

At minimum, Pure Luau coverage should prove:

- `ledge` still exists, remains collidable, and has finite positive dimensions;
- `cabinet-a` still resolves the retained filing-cabinet genome and remains ground-supported by its shell;
- after applying the object placement transform, the cabinet shell and ledge have no positive overlap on all three axes simultaneously;
- the test fails on the currently authored placement rather than merely checking a future magic coordinate;
- the corrected recipe is deterministic across repeated builds and carries the intended recipe/generator revision;
- the fix does not weaken existing shell/object identity or ObjectGenome fingerprint assertions.

If the successor chooses intentional contact between these fixtures, it must encode that relationship explicitly and prove surface contact without penetration. The current recipe declares no such support/contact relationship, so positive-volume overlap should fail closed.

## Scope

This finding does not change Roblox Instances, physics contact evidence, Studio diagnostics, WorldEntity identity, ObjectGenome schema, networking, persistence, or Hero feature unlocks. It is a docs-only capacity-mining artifact intended to materialize one narrow Physics Lab authored-placement lane after the scheduler confirms a non-conflicting source slot.
