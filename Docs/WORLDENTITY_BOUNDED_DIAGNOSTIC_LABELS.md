# WorldEntity Bounded Diagnostic Labels

## Finding

The retained WorldEntity generation-9 lineage in PR #437 correctly fail-closes hostile non-string diagnostic inputs without executing caller-controlled metamethods. In particular, `safeValueLabel()` avoids `tostring()` for table/userdata/function-like values, and exact-shape validation reports non-string schema-key types without stringifying the key.

A narrower bounded-work gap remains for **primitive strings that are already invalid input**.

On PR #437 exact head `de1f14f9443237b57a7e68854d63dacbb5dfc2d3`:

- `safeValueLabel(value)` returns string inputs verbatim;
- invalid `fidelity` values therefore interpolate the complete caller string into `invalid fidelity ...` errors in `fidelityRank()`, `ownRecord()`, `WorldEntity.new()`, and `WorldEntity.transition()`;
- `assertExactRecordShape()` interpolates an unknown string schema key verbatim into its rejection.

The canonical metadata and persistent-state budgets bound retained accepted data, but those budgets do not cover pre-ownership rejection text. A malformed caller can therefore force an avoidably large temporary error/log string while still being rejected correctly.

This is a boundedness/diagnostics contract gap, not a canonical-truth corruption claim. Current code already demonstrates the intended pattern for a related surface: persistent-state diagnostic paths replace long/control-character string keys with `<string-key>` rather than copying them wholesale into paths.

## Why this matters

WorldEntity is a permanent domain boundary. Rejection paths should remain useful while also being bounded in work and retained/transient text size. A caller should not be able to turn a one-field invalid request into a megabyte-scale diagnostic merely by supplying a megabyte-scale primitive string.

The existing hostile-value hardening must remain intact: fixing string amplification must not reintroduce `tostring()` on tables/userdata or any other caller-controlled metamethod execution.

## Required boundary

A WorldEntity successor should introduce one project-owned bounded diagnostic-label rule for untrusted primitive strings used in contract errors.

The implementation shape may vary, but it should preserve these properties:

1. ordinary short invalid values remain readable enough to identify the failed contract;
2. long primitive strings are summarized/truncated under an explicit small fixed diagnostic bound rather than copied in full;
3. unknown long string schema keys use the same bounded-label rule;
4. non-string hostile values remain type-labeled without invoking caller metamethods;
5. canonical accepted values are never truncated or rewritten — this applies only to diagnostics formed while rejecting invalid input.

A summary may include a bounded prefix plus total byte length, or another deterministic representation that preserves useful operator context without retaining the whole payload.

## Regression target

Focused Pure Luau coverage should include:

- an invalid fidelity string far above the diagnostic bound; rejection must occur and the resulting error text must stay under a fixed project-owned maximum rather than contain the complete payload;
- an unknown top-level `WorldEntityRecord` key with a very long string name; rejection text must remain bounded;
- an unknown `GenerationOrigin` key with a very long string name; rejection text must remain bounded;
- short invalid fidelity/schema-key values still produce useful readable diagnostics;
- hostile non-string fidelity/schema-key fixtures with `__tostring` continue to execute zero callbacks;
- a registered transition rejected for an overlong invalid target leaves the incumbent registered record unchanged and permits an immediate valid retry.

The tests should assert semantic bounds instead of pinning incidental punctuation so diagnostics can evolve without weakening the safety contract.

## Scope

This finding does not change StableId, WorldEntity schema/versioning, generator versions, persistence format, fidelity policy, networking, Roblox Instances, or Studio evidence. It does not unlock Door/Chair/Player work.

It is intended for absorption by the existing `HG-BACKFILL-WORLDENTITY` successor lineage after the active #437/#453 review/test work is reconciled, or as a bounded one-shot WorldEntity source+test lane if the control plane chooses to materialize it. It should not become a competing WorldEntity implementation.
