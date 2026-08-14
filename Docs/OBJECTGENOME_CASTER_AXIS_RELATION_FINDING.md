# ObjectGenome caster-axis relation finding

Status: source-only capacity-mining finding for the active Hero Gate. This note does not unlock a new feature and does not claim Roblox Studio or engine evidence.

## Concrete gap

`ObjectGenome` currently validates a caster's `swivelAxis` and `rollAxis` independently as finite unit vectors, but it does not validate any relationship between them.

That means a recipe can replace a valid caster's `rollAxis` with its exact `swivelAxis` (or the exact opposite direction) and still satisfy the caster-specific semantic checks. The resulting record describes two named motions around the same physical axis: caster swivel and wheel roll collapse into one degree of freedom.

This is a construction-contract defect rather than a rendering preference. `ObjectGenome` is the manufactured-object source of truth, and the v1 mechanism vocabulary gives `swivelAxis` and `rollAxis` distinct meanings. A degenerate pair leaves realization adapters to either invent a repair or realize physically meaningless caster semantics.

## Source evidence

Current `src/shared/Objects/ObjectGenome.luau` validates `caster` mechanisms by checking:

- positive finite `wheelRadiusM`;
- unit `swivelAxis`;
- unit `rollAxis`.

There is no dot-product, cross-product, collinearity, or independent-DOF check between those axes.

Retained ObjectGenome generation-8 PR #395 adds an exact standalone mechanism-record boundary for `decodeMechanismPosition()`, but its `standaloneMechanismIsCanonical()` likewise calls `isCanonicalUnitAxis()` on each caster axis independently. The gap therefore survives that retained hardening candidate and is not a stale-main-only observation.

The production office-chair fixture demonstrates the intended non-degenerate shape:

- `swivelAxis = { x = 0, y = 1, z = 0 }`;
- `rollAxis = { x = 1, y = 0, z = 0 }`.

Existing ObjectGenome tests cover non-unit individual axes and caster persisted-state semantics, but do not mutate a caster to parallel/antiparallel unit axes.

## Exact source repro

Starting from `ObjectGenomeFixtures.officeChair`:

1. deep-copy the genome;
2. locate `caster-front-left-swivel`;
3. assign `rollAxis` to `{ x = 0, y = 1, z = 0 }`, equal to its canonical `swivelAxis`;
4. run `ObjectGenome.inspect(mutatedGenome)`.

By source inspection, the mutation preserves every currently checked caster predicate, so the degenerate recipe remains semantically admissible. An antiparallel `{ x = 0, y = -1, z = 0 }` roll axis has the same defect class.

No executable test result is claimed by this mining worker; the evidence is a bounded source-contract audit.

## Non-duplication check

This is distinct from the already-materialized ObjectGenome leaves:

- `HG-BACKFILL-OBJECTGENOME-STATE-BOUNDS` — recipe/state collection cardinality and bounded validation work;
- `HG-BACKFILL-OBJECTGENOME-STRING-BUDGET` — free-form canonical string byte budgets;
- retained `HG-BACKFILL-OBJECTGENOME` PR #395 — identity/no-execute/diagnostic-order/state-map-alias/standalone-decoder shape closure.

It also does not overlap the chair authored support-geometry repair: this finding concerns the generic `caster` mechanism contract, not one fixture's physical placement.

## Recommended bounded leaf

Recommend a one-shot Hero-Gate source-only leaf after the retained ObjectGenome lineage is safely integrated, tentatively `HG-BACKFILL-OBJECTGENOME-CASTER-AXIS-RELATION`.

Acceptance should require:

- define an explicit project-owned non-degeneracy rule for caster `swivelAxis` versus `rollAxis` without silently normalizing caller data;
- at minimum reject parallel and antiparallel unit-axis pairs so swivel and roll cannot collapse to one canonical degree of freedom;
- decide and document whether v1 requires strict orthogonality or permits intentionally tilted/cambered caster geometry with a bounded minimum separation angle; do not invent a tolerance without checking realization semantics;
- apply the same relation rule in full `ObjectGenome.inspect()` and the standalone mechanism boundary used by `decodeMechanismPosition()`;
- add deterministic regressions for canonical fixture acceptance, equal-axis rejection, opposite-axis rejection, and any chosen near-degenerate tolerance boundary;
- preserve ObjectGenome schema v1 identity fields and existing valid fixture fingerprints unless a compatibility review proves a recipe-content revision is required;
- no Roblox Studio, viewport, networking, persistence, or physical-contact evidence claim for this source-only contract repair.

## Why it matters now

Hero Door/Chair work is intentionally gated on trustworthy production object contracts. Rejecting a caster whose two semantic motion axes are the same keeps manufacturability errors at the domain boundary instead of forcing later physics adapters to guess what the author meant.
