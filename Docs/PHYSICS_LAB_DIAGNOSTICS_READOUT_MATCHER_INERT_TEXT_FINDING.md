# Physics Lab diagnostics readout matcher inert-text finding

## Scope

This is a bounded source/test audit finding for the active Physics Lab diagnostics lineage. It does not change production behavior, satisfy any Roblox Studio evidence row, or unlock a Hero Feature.

Audited product lineage:
- active diagnostics generation-17 PR #468, exact head `0703a44ff68a96d5907d514f66480ac8aca0145a`;
- expected-red visibility support PR #474, exact head `de4c4c778faebba8116000819c83dbfa1aa3db1a`.

## Finding

`tests/physics_lab_diagnostics_readout_contract.luau` searches the diagnostics source text for required contract tokens after removing only ordinary `-- ...` line comments:

```luau
local source = string.gsub(rawSource, "%-%-[^\n]*", "")
```

The matcher does not mask Luau long comments, long-bracket strings, quoted strings, or backtick strings before checking the readout helper. Therefore an expected predicate can stop being executable while its source text remains searchable.

For example, after PR #474 is absorbed, deleting an executable readout-visibility assertion while retaining equivalent text inside an inert `--[[ ... ]]`, `[=[ ... ]=]`, quoted string, or backtick string within the helper region can still satisfy a raw `string.find`-based guard. The same proof weakness applies to existing readout checks such as the exact Adornee and exact text projections: their tokens can be present without proving the production helper actually executes them.

This is a **regression-integrity gap**, not a claim that current production readout behavior is already wrong. It means the source-contract test can false-pass a future mutation that removes an executable invariant.

## Why this is concrete

The diagnostics lineage already encountered this exact class of false confidence in the enabled-canonical-validation contract. `tests/physics_lab_diagnostics_enabled_integrity.luau` was hardened over later generations to mask long comments, long-bracket strings, and quoted strings before accepting source-token evidence. The readout matcher remains on the weaker line-comment-only shape.

PR #474 strengthens the semantic requirement by asking `validateReadoutCompleteness()` to reject disabled `BillboardGui` and hidden `TextLabel` readouts, but its new matcher still derives from the same `source` string and therefore inherits this inert-text false-pass surface.

## Non-duplication

This finding is separate from current diagnostics work:

- PR #474 owns the **semantic visibility requirement** (`BillboardGui.Enabled` / `TextLabel.Visible`).
- PR #479 owns **cleanup error precedence** after an enabled-window validation failure.
- PR #468 generation 17 owns the broader enabled-window failure-atomicity production repair.
- The existing enabled-integrity matcher hardening protects a different helper and does not automatically protect `physics_lab_diagnostics_readout_contract.luau`.

Repository PR/issue searches for a dedicated `physics_lab_diagnostics_readout_contract` inert-text/matcher-hardening repair did not surface another owner.

## Recommended bounded follow-up

When the active diagnostics primary/successor absorbs PR #474, harden the readout source-contract matcher at the same time or through a narrow test-only support leaf:

1. mask inactive line comments, long comments, long-bracket strings, quoted strings, and backtick strings before helper-contract searches;
2. scope the searched body to `validateReadoutCompleteness()` rather than allowing unrelated source regions to satisfy helper predicates;
3. add negative mutants that delete an executable predicate and preserve its exact text only inside each inert-text family;
4. keep a positive control proving the real executable readout predicate is accepted;
5. preserve the existing authoritative identity, membership, Adornee, text, shape, and exact-count assertions;
6. do not convert a green source-contract test into live viewport or Studio evidence.

The smallest safe implementation may reuse the already-proven inert-source masking approach from the enabled-integrity regression rather than creating another parsing framework.

## Evidence boundary

This finding is source-derived. No local Luau/Lune execution, Roblox Studio run, viewport capture, physical-contact run, performance-device run, networking run, or two-client run is claimed here.

The Mac display blocker and the `HG151-DIAGNOSTICS` acceptance requirements remain unchanged. Fresh exact-head canonical CI is required for this docs-only publication, and any later test repair should obtain its own expected-red/green executable evidence plus independent review.
