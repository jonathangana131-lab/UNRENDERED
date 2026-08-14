# MaterialDNA seam-period semantics finding

## Scope

Bounded Hero-Gate capacity-mining audit of `MaterialDNA` on exact product base:

`main@af6a17aa7969d40e8b19f7e9d19fe93cc9b1d9a9`

This is a source-contract finding only. It does not change MaterialDNA schema/identity, fixtures, rendering, Physics Lab behavior, Studio evidence, or unlock any later Hero feature.

## Finding

`InstallationSpec.seamPeriodMeters` is optional, and `validateInstallation()` validates it only when it is present. The known compatibility rules then require:

- `finish.vinyl-wallpaper` -> `installation.pasted-wallpaper`, and
- `finish.olefin-low-pile` -> one of the supported carpet installation methods,

but do not define or validate what a missing `seamPeriodMeters` means for those already-known installed covering families.

The three shipped ordinary fixtures make the intended distinction visible:

- commercial wallpaper: `installation.pasted-wallpaper`, seam period `0.53 m`;
- low-pile roll carpet: `installation.glued-carpet-roll`, seam period `3.6576 m`;
- factory-coated painted metal: seam period omitted (`nil`).

Today an otherwise-valid wallpaper recipe can therefore change only:

```luau
recipe.installation.seamPeriodMeters = nil
```

and still pass `MaterialDNA.validateRecipe()`. The same is true for a compatible carpet recipe.

That leaves canonical consumers without a project-owned interpretation of `nil`: it could mean seam-free, unknown/unresolved, representation-owned, or "use an adapter default." Those meanings are materially different. A renderer/history/installation adapter must currently invent semantics outside the canonical MaterialDNA contract.

This is especially undesirable for the project's normality-first material model: installation seams are manufacturing/construction evidence, not a cosmetic random detail.

## Why this is a separate gap

This does not duplicate the existing MaterialDNA work lines:

- **repair-count exactness** bounds `maintenance.repairCount`;
- **dense/diagnostic bounds** limit malformed-input validation work and retained diagnostics;
- **semantic-key grammar** owns the accepted `%` alias;
- **hostile-key / fixture-drift hardening** owns no-execute validation and same-revision production-fixture seals;
- **known-family coherence** owns cross-wiring visual/physical/acoustic family keys while coherence labels still match.

The seam finding is instead about the meaning and requiredness of an existing optional canonical installation field for already-supported installation methods. Repository issue/PR searches for `seamPeriodMeters` found no dedicated existing owner at audit time.

## Bounded follow-up contract

A future explicitly unlocked source-only repair should define `seamPeriodMeters` semantics before changing validation. The smallest production-worthy direction is:

1. Define whether `nil` has any valid canonical meaning.
2. For installation methods whose construction grammar inherently carries regular seams in MaterialDNA, require an explicit positive seam period instead of allowing adapters to invent one.
3. Keep seam semantics method-specific; do not require the field for every installation method merely because it exists in the record.
4. Preserve the current positive finite upper bound and all shipped fixture identity/content unless a fixture intentionally changes with a corresponding `recipeVersion` advance.
5. Add focused deterministic regressions for each known seamed method, including present-valid and missing-invalid behavior if that is the chosen contract.
6. Keep Roblox asset IDs/render packages outside MaterialDNA and do not create a second material registry or migration framework.

For the currently known families, `installation.pasted-wallpaper` and `installation.glued-carpet-roll` are the clearest required-seam candidates. `installation.carpet-tile-adhesive` should be decided explicitly rather than inferred from its string name, because tile dimensions/seam representation may need a distinct later field. `installation.factory-coated-panel` should remain optional unless its panel-seam ownership is deliberately defined here.

## Evidence boundary

The demonstrated result is source-derived from the current validator predicates and shipped fixtures. No local Luau execution or Roblox Studio run is claimed by this capacity-mining pass.

Any production repair must carry executable expected-red/green regression evidence and normal exact-head CI before integration.
