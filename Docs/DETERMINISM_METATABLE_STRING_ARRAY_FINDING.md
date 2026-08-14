# DeterminismContract metatable-backed string-array finding

Status: bounded Hero-Gate capacity-mining finding. This document records a source-level canonical-input gap; it does not unlock or implement a new Reality feature.

## Finding

`Core/DeterminismContract.validateStringArray()` checks that its argument is a table, but it does not prove that table is plain before applying the length operator or indexed reads:

```luau
assert(type(parts) == "table", `{label} must be an array`)
local length = #parts
...
for index = 1, length do
    local value = parts[index]
    ...
end
```

In current Luau, `#table` can invoke a table's `__len` metamethod, and ordinary `parts[index]` lookup can invoke `__index`. The canonical deterministic boundary therefore reaches caller-controlled executable behavior before it has established the dense string-array data it intends to hash.

A concrete adversarial shape is a table with no raw array entries and a metatable whose `__len` reports `1` while `__index` returns a string for index `1`. The `pairs(parts)` shape scan sees no raw keys, the subsequent indexed loop can obtain the semantic part through the metatable, and the resulting value can flow into canonical encoding / hashing.

By source inspection, the same helper is shared by:

- `DeterminismContract.encodeParts()`;
- `DeterminismContract.hashParts()` through `encodeParts()`;
- `DeterminismContract.stableId()` and therefore `Core/StableId.fromParts()`;
- `DeterminismContract.seedFor()` for scoped RNG semantic scopes.

This is a stronger problem than merely accepting an extra hidden table property: canonical identity or RNG stream derivation can depend on executable metatable behavior rather than explicit raw semantic data.

This mining pass does **not** claim an executable repository test result. The behavior follows from the current source plus Luau's implemented `__len` / ordinary indexing semantics. An unlocked repair should first land an expected-red pure-Luau regression against the exact project toolchain.

## Contract relevance

`Docs/DETERMINISM_CONTRACT.md` defines StableId semantic parts and SeedStream scopes as dense ordered arrays of semantic strings. Higher-level Reality contracts already fail closed on metatable-backed canonical records/arrays before deriving identity or content fingerprints.

Allowing the core primitive to synthesize semantic parts through `__len` / `__index` creates a lower-level exception to that data-before-representation boundary. It also weakens the project's recurring no-execute-on-rejection/input-validation rule: a caller can execute code before the deterministic primitive has established its canonical inputs.

The defect is independent of the current `HG-BACKFILL-REALITY` PR #359 schema-key diagnostic hardening and PR #370 v1 replay-depth tests. Those operate on ResolvedRegionRecipe records and do not close the shared core string-array validator.

## Recommended bounded follow-up

Do not change hash bytes, StableId formatting, RNG algorithms, seed salts, or historical resolved-recipe vectors as part of this repair.

A source-only follow-up should:

1. add a focused expected-red regression using a metatable-backed virtual semantic array and prove caller `__len` / `__index` execution is currently reachable from at least `stableId()` and `seedFor()`;
2. reject metatable-backed string-array inputs **before** `#parts`, iteration, indexing, interpolation, or hashing;
3. cover `encodeParts()` as the shared generic boundary as well as StableId and SeedStream callers;
4. prove all existing StableId, encoding, RNG, and resolved-region golden vectors remain byte-identical for accepted plain arrays;
5. preserve the existing dense-array, semantic-count, semantic-byte, empty-string, namespace, salt, and generation-version rules;
6. verify whether the rejection-only tightening is compatible with Determinism Contract v1 history before editing the frozen v1 implementation. If any accepted persisted producer is known to supply metatable-backed arrays, use an explicit version/migration decision rather than silently redefining historical input acceptance.

The simplest likely implementation is a plain-table preflight at the shared validator, but the regression and compatibility audit should drive the exact source change.

## Non-duplication

Repository PR/issue archaeology for `DeterminismContract`, `StableId`, metatable/no-execute string arrays, and ResolvedRegionRecipe found existing work for:

- noncanonical StableId version aliases (#282);
- resolved-recipe hostile schema-key stringification (#306 / retained #359);
- v1 resolved-recipe replay ownership/immutability (#280 / retained #370);
- higher-level ObjectGenome and WorldEntity metatable/no-execute boundaries.

No dedicated core `DeterminismContract.validateStringArray()` plain-array repair or finding surfaced.

## Scope

Finding refreshed against `main@af6a17aa7969d40e8b19f7e9d19fe93cc9b1d9a9`, where `src/shared/Core/DeterminismContract.luau` retains blob `227e94a65ff482e1d47dcc8a702c339d05315b80`.

No production source, Determinism Contract version, StableId bytes, RNG stream, resolved recipe, generator/schema version, persistence, networking, Roblox Instance, Studio, viewport, physics, or two-client behavior is changed or claimed here.
