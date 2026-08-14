# ObjectGenome caster radius locality finding

## Scope

This is a docs-only capacity-mining finding from `HG-CAPACITY-MINING / mine-objectgenome` against `main@af6a17aa7969d40e8b19f7e9d19fe93cc9b1d9a9`.

It does not change ObjectGenome schema/version semantics, fixtures, ObjectState, StableId, recipe fingerprints, Physics Lab realization, Studio evidence, or any Hero Feature unlock.

## Finding

`ObjectGenome.inspect()` validates caster `wheelRadiusM` only with `isPositiveFinite()`. Unlike component geometry, center of mass, and affordance points, the caster radius has no relationship to the referenced moving component or to the declared object envelope.

That leaves a physical scale invariant outside the canonical domain boundary.

The shipped office-chair fixture shows the intended scale relationship:

- caster moving component dimensions: `0.09 x 0.08 x 0.04 m`;
- caster wheel radius: `0.028 m`;
- complete chair envelope: `0.68 x 1.08 x 0.68 m`.

But an otherwise-valid copy of that fixture can change only one caster mechanism's `wheelRadiusM` to an arbitrarily large finite value such as `1000000`. The current validator still accepts the radius predicate because it is positive and finite; no subsequent caster geometry/locality predicate relates that radius back to the moving component or object envelope.

A Physical-World adapter must then either:

1. realize a wheel whose canonical radius is wildly incompatible with the construction recipe,
2. silently clamp/reinterpret the radius, splitting domain truth from representation, or
3. invent a second adapter-owned validity rule.

All three conflict with ObjectGenome's purpose as the project-owned manufacturable construction contract.

## Existing protections do not close this

Current ObjectGenome v1 already fails closed on adjacent concerns:

- component dimensions must be positive finite values;
- rotated component bounds must fit the object envelope;
- center of mass must lie within the object envelope;
- mechanism axes are finite unit vectors;
- hinge/tilt/slide ranges have finite spans and include the authored zero pose;
- caster radius must be positive finite;
- affordance points must lie inside their referenced component.

The missing rule is specifically the **physical locality/scale relationship** for caster `wheelRadiusM`.

Current ObjectGenome tests exercise fixture validity, identities/fingerprints, component bounds/mass/support, state shape, mechanism decoding, and schema/ownership hardening. The current `tests/object_genome.luau` source contains no dedicated `wheelRadiusM` boundary regression, so the huge-finite-radius case is not locked by an executable test.

## Non-duplication

This finding is distinct from known ObjectGenome work:

- PR #480 records affordance `radiusM` locality for interaction regions; this finding concerns caster mechanism wheel geometry.
- PR #466 records the relationship between caster `swivelAxis` and `rollAxis`; this finding does not change axis semantics.
- retained ObjectGenome decoder/shape work such as PR #395 validates a standalone caster record and positive radius, but does not relate the accepted radius to component geometry.
- proposed string-budget work concerns free-form provenance/component-role text, not mechanism geometry.

Repository PR/issue searches for `wheelRadiusM`, `wheel radius`, and `caster wheel radius` did not surface a dedicated caster-radius locality repair.

## Recommended future leaf

Do not repair this from the capacity-mining lane. When the retained ObjectGenome lineage and scheduler explicitly unlock another depth leaf:

1. define v1 caster radius geometry semantics before tightening compatibility;
2. choose one project-owned locality rule that can be evaluated from plain ObjectGenome data;
3. preserve the existing office-chair fixture and Roblox-independent domain boundary;
4. add expected-red tests for an otherwise-valid huge finite radius plus exact-bound / first-rejected cases;
5. confirm the rule also applies at the standalone decoder/validation boundary where canonical caster mechanism records are accepted;
6. only then implement the smallest source repair and rerun exact-head CI plus independent review.

A likely rule should tie wheel diameter/radius to the moving caster component's declared dimensions and/or the object envelope rather than introduce an arbitrary global magic cap. The exact compatibility rule needs an explicit contract decision; this finding intentionally does not pre-decide it.

## Why this matters

Reality-Grade procedural objects require manufacturable plain-data recipes before Roblox realization. A canonical mechanism may be unusual, but it should not be accepted with unbounded physical scale that contradicts the construction graph and then depend on adapters to repair it. Keeping this invariant in ObjectGenome preserves data-before-representation and deterministic procedural rejection at the correct boundary.
