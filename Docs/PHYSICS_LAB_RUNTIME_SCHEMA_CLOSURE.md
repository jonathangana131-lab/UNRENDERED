# Physics Lab runtime recipe schema-closure finding

Status: source-only capacity-mining finding. This note does **not** claim Roblox Studio, viewport, contact, performance-device, or two-client evidence and does not unlock Door/Chair/Player work.

## Finding

The retained runtime-synthesis candidate in PR #408 hardens `PhysicsLabRuntime.new()` substantially, but its canonical-recipe preflight is not closed over the complete declared recipe schema.

`assertCanonicalRecipe()` proves that the top-level recipe and each entity-recipe wrapper are plain tables, and it authenticates the expected top-level identity/population values. It then applies exact-key checks only to the nested `WorldEntityRecord` and `GenerationOrigin` tables.

As a result, a caller can add otherwise-ignored fields to:

- the top-level `PhysicsLabRecipe` table; or
- an individual `EntityRecipe` wrapper,

and still pass the constructor's canonical-recipe fence as long as the fields that are currently inspected remain canonical.

This is separate from `Docs/PHYSICS_LAB_RUNTIME_RECIPE_AUTHENTICITY.md` / PR #451. That finding concerns canonical **values** on realization-bearing entity fields. This finding concerns exact **schema closure**: whether a value claiming to be the canonical runtime recipe may contain undeclared sibling fields at all.

## Why it matters

`PhysicsLabRecipe` is a versioned production contract. A constructor described as accepting the canonical recipe should either reject undeclared fields at every owned record boundary or explicitly define those fields as outside its authentication claim. Allowing ignored extension fields makes schema drift silent and can let later callers attach non-plain or semantically meaningful data that the runtime never authenticated.

Current production construction is still bounded and internal; this note does **not** claim that extra fields currently alter Workspace realization. The concern is contract correctness and future-proofing before the runtime synthesis lineage is treated as the permanent canonical acceptance boundary.

## Concrete evidence

At PR #408 exact product head `d31c100c5d3766ca14d89b046fff4cdb09086754`:

- `assertCanonicalRecipe()` calls `assertPlainTable(recipe, ...)`, then checks `schemaVersion`, `recipeKey`, `worldId`, `regionId`, and `entities`, but does not enumerate/reject unknown top-level keys;
- each `rawEntityRecipe` is passed through `assertPlainTable(...)`, but the wrapper is not checked against a primitive/object exact-key set;
- nested `record` and `origin` tables **are** checked with `assertExactStringKeys(...)`, demonstrating that exact-schema rejection is already an intentional boundary one level lower;
- `tests/physics_lab_runtime_synthesis.luau` covers metatable-backed top-level/entity-list/entity-recipe/record/origin wrappers and hostile unknown keys on `record` / `origin`, but has no negative fixture for an extra top-level recipe field or an extra `EntityRecipe` wrapper field.

Repository PR search found the active synthesis PR #408 and the separate realization-value authenticity finding #451, but no existing runtime schema-closure repair for these two outer boundaries.

## Recommended bounded leaf

Propose a source-only follow-up such as `HG-PHYSICS-RUNTIME-SCHEMA-CLOSURE`, preferably absorbed into the retained synthesis lineage rather than merged as a competing runtime implementation.

Acceptance should be narrow:

1. define fixed allowed-key sets for the five top-level `PhysicsLabRecipe` fields and for each `EntityRecipe` variant;
2. reject unknown or non-string keys before any caller-derived diagnostic interpolation;
3. keep the check bounded by the canonical small schema and run it before registry/Fidelity authority construction;
4. add adversarial regressions for one extra top-level field, one extra primitive wrapper field, and one extra object wrapper field;
5. preserve all #408 transaction/facade/WorldEntity-ID invariants and also preserve #451's separate realization-value authenticity requirement;
6. require fresh exact-head canonical CI and independent review; no Studio evidence is needed or implied by this source-only contract leaf.

No broader runtime redesign is warranted for this finding.
