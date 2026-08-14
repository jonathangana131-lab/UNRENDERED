# WorldEntity StableId Authenticity Finding

## Finding

The retained WorldEntity generation-10 lineage in PR #477 still accepts a broader identity language than the project StableId contract.

`WorldEntity.isId()` currently returns true for any string that is non-empty, at most 256 bytes, and contains no control characters. `WorldEntity.new()`, direct mutable-record ownership, and every registry lookup/mutation boundary use that predicate. They do not call `StableId.is()` / `DeterminismContract.isStableId()`.

That means a structurally valid WorldEntity can currently use identifiers such as `printable-but-not-a-stable-id` even though `Docs/ARCHITECTURE.md` defines `WorldEntityId` as supplied by the project StableId contract and `Docs/DETERMINISM_CONTRACT.md` defines canonical StableId v1 text as `<namespace>:v1:<32 lowercase hex digits>`.

The permanent Physics Lab already generates its entity identities with `StableId.fromParts("entity", { ... })`, so the production fixture follows the stronger contract. The WorldEntity boundary itself does not authenticate that contract.

## Why this is distinct

This is not the same defect as merged PR #282. #282 made `DeterminismContract.isStableId()` reject non-canonical textual version aliases such as `v01`; this finding is that WorldEntity never invokes the canonical StableId validator in the first place.

It is also distinct from the registry identity hardening retained through PR #378. That lineage correctly rejects hostile/non-string lookup identities before indexing or diagnostic interpolation, but it centralizes the same permissive `WorldEntity.isId()` predicate. The no-execute boundary can therefore be correct while still accepting a printable non-StableId string as canonical domain identity.

This finding does not overlap the current metadata-budget, duplicate-origin, returned-diagnostic ownership, bounded-diagnostic-label, or registered no-op-transition work.

## Compatibility caution

Do not silently replace the predicate without an explicit compatibility check.

Several existing WorldEntity tests use readable legacy-shaped fixture IDs such as `entity:0000000000000001` rather than StableId v1 output. Tightening `WorldEntity.isId()` directly would intentionally invalidate those fixtures and could also invalidate any pre-contract serialized test/dev data if such data exists.

Before a source repair, choose and document the v1 boundary explicitly:

1. If every `WorldEntityId` must use the `entity` namespace, validate with the project StableId contract plus the exact `entity` namespace.
2. If WorldEntity intentionally permits multiple project-owned StableId namespaces, validate canonical StableId syntax/version generically and document the allowed namespace model.
3. If a temporary legacy compatibility path is required, keep it explicit and bounded rather than treating arbitrary printable strings as canonical forever.

Because StableId v1 is a historical deterministic contract, the repair must preserve generated StableId bytes; this is an acceptance-boundary decision, not a hash/encoding rewrite.

## Repro and regression target

Source-level repro against PR #477 exact head `fdd5bbe85f0f813172cb5b1e8564550b9c9beb96`:

- build an otherwise-valid `WorldEntity.new()` spec;
- set only `id = "printable-but-not-a-stable-id"`;
- the current `WorldEntity.isId()` predicate accepts that value even though `StableId.is()` rejects it.

A future explicitly unlocked source-only repair should add focused Pure Luau coverage that:

- accepts an ID produced by `StableId.fromParts()` under the chosen namespace policy;
- rejects printable non-StableId strings;
- rejects non-canonical StableId aliases already covered by the StableId contract;
- preserves hostile/non-string no-execute lookup behavior from the registry hardening lineage;
- preserves duplicate authority, lifecycle atomicity, metadata/state budgets, and all StableId golden vectors;
- records any intentional legacy-fixture migration instead of silently weakening the canonical boundary.

## Scope

This capacity-mining finding changes no production source, StableId bytes, hash/RNG behavior, WorldEntity schema/version, persistence backend, networking, Roblox Instances, Physics Lab behavior, or Hero Gate evidence.

It does not unlock Door/Chair/Player work and makes no Roblox Studio, viewport, physical-contact, performance-device, or two-client claim. Any source repair belongs in the retained WorldEntity lineage or a scheduler-created one-shot leaf after the compatibility decision is explicit.
