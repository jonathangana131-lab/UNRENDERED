# Physics Lab diagnostics text-renderability finding

Status: bounded Hero-Gate capacity-mining finding. This document records a source-level diagnostics evidence-integrity gap; it does not unlock or implement a new feature and does not substitute for Roblox Studio viewport evidence.

## Finding

Retained diagnostics generation 18 (PR #486 exact head `29a2f949eebbd509c2c839d48c3d75a7ff03dc22`) strengthens `validateReadoutCompleteness()` so a readout is rejected when its `BillboardGui.Enabled` is false or its `TextLabel.Visible` is false. That closes the semantic visibility gap from expected-red PR #474.

The same completeness boundary still does not validate whether the authoritative text itself is renderable. In particular, it does not inspect `TextLabel.TextTransparency`.

A caller can therefore take an otherwise canonical enabled readout and make only this mutation:

```luau
readout.TextTransparency = 1
```

The label remains `Visible = true`; its parent `BillboardGui` remains `Enabled = true`; the label remains the only descendant; `Readout.Text` can still equal the exact authoritative identity/fidelity/fingerprint/repro projection; the Adornee, WorldEntityId, and cardinality can all remain correct. By source inspection, generation 18's `validateReadoutCompleteness()` still accepts that tree and counts it as a complete diagnostics readout even though the evidence text is fully transparent to the viewport.

This is a source-derived finding, not an engine execution result. No Roblox Studio run was performed by this mining pass.

## Why this matters

The Physics Lab diagnostics overlay exists to make stable identity, fidelity, fingerprint, and repro information directly inspectable on real representations. Presence of the correct text string in an Instance is not equivalent to visible evidence if the text renderer is fully transparent.

Generation 18 already treats `Enabled` and `Visible` as evidence-integrity predicates rather than cosmetic styling. `TextTransparency = 1` is the adjacent same-class failure: the readout tree remains structurally and semantically correct while the information it is supposed to expose disappears from the viewport.

This does not imply every typography/style property must become canonical world truth. The narrow missing invariant is that capture must not certify a readout whose authoritative text has an unequivocally non-rendering display state.

## Existing coverage and non-duplication

This finding is distinct from active diagnostics work:

- PR #486 generation 18 owns enabled-window cleanup precedence and absorbs #474's `BillboardGui.Enabled` / `TextLabel.Visible` guards;
- PR #484 hardens the cleanup source-contract matcher against fallback root pins;
- draft PR #487 records a test-integrity gap where the readout source matcher can be satisfied by inert long comments/strings; it does not change or evaluate production text-renderability semantics;
- PR #401 / retained successors own authoritative Adornee and exact text equality;
- earlier generations own duplicate-root, enabled canonical-world integrity, clone completeness, final disabled state, exact readout shape/count, and authoritative representation binding.

Repository PR/issue searches for diagnostics `TextTransparency`, text renderability, or an equivalent fully-transparent-readout invariant did not surface a dedicated repair/finding.

## Recommended bounded follow-up

Do not broaden this into a visual-style rewrite. When the scheduler explicitly unlocks another diagnostics source/test leaf on the retained successor lineage:

1. add a focused expected-red regression proving a readout with exact authoritative text but `TextTransparency = 1` is rejected by the same machine completeness boundary;
2. close the source invariant with the smallest project-owned predicate that rejects unequivocally non-rendering authoritative text;
3. preserve generation 18's `Enabled`, `Visible`, Adornee, identity, exact-text, shape, and count checks;
4. avoid turning arbitrary typography choices into canonical world state unless a separate evidence requirement justifies them;
5. harden the regression using the same inert-source masking/scoping work recommended by PR #487 so a mere text token cannot false-pass;
6. require fresh exact-head canonical CI and independent source/test review after the retained diagnostics lineages are reconciled;
7. keep Roblox Studio viewport evidence independently mandatory. A source-level renderability predicate is necessary evidence hygiene, not proof that the overlay actually renders correctly on a device.

If the intended diagnostics contract deliberately permits fully transparent authoritative text, that should be stated explicitly because it conflicts with the overlay's inspectability/evidence purpose.

## Scope

Finding branch started from `main@af6a17aa7969d40e8b19f7e9d19fe93cc9b1d9a9` and audited diagnostics generation 18 PR #486 exact head `29a2f949eebbd509c2c839d48c3d75a7ff03dc22` plus its absorbed readout regression.

This document changes no production diagnostics source, UI realization, WorldEntity truth, Realizer ownership, persistence, networking, physics, Studio bridge, viewport behavior, or multiplayer behavior. It does not promote `HG151-DIAGNOSTICS`, alter the external Mac display blocker, or unlock Door/Chair/Player.