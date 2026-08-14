# MaterialDNA Known-Family Coherence Finding

## Status

Capacity-mining finding only. This document does not change the MaterialDNA schema, fixtures, identity, renderer, physics, audio, persistence, or any Roblox Studio behavior.

Audited base: `main@eead13b2e90ffbba36248909d97e17856e002ad9`.

## Finding

`MaterialDNA.validateRecipe()` requires `visual.coherenceClass`, `physical.coherenceClass`, and `acoustic.coherenceClass` to equal the top-level `MaterialRecipe.coherenceClass`, but it does not relate the corresponding semantic family/class keys to one another.

For the three ordinary families that MaterialDNA already knows explicitly, that leaves a semantic alias: a recipe can keep a wallpaper coherence label while selecting the already-known low-pile-carpet physical or acoustic class key and still validate.

The compatibility pass currently constrains only:

- `finish.vinyl-wallpaper` against wall substrate + pasted-wallpaper installation;
- `finish.olefin-low-pile` against carpet substrate + supported carpet installation;
- `finish.baked-enamel-paint` against sheet-metal substrate + factory-coated-panel installation.

`validatePhysical()` independently checks only that `physical.classKey` is a valid project semantic key, its numeric values are plausible, and its copied `coherenceClass` equals the recipe label. `validateAcoustic()` has the same shape for `acoustic.classKey`. `validateVisual()` likewise accepts any valid `visual.familyKey` while checking only the separate coherence label.

## Exact source repro

Starting from the valid commercial-wallpaper fixture (or the equivalent valid test recipe), change only:

```luau
recipe.physical.classKey = "physics.low-pile-carpet"
```

Leave all of these unchanged:

```luau
recipe.coherenceClass = "interior.wallpapered-drywall"
recipe.physical.coherenceClass = "interior.wallpapered-drywall"
recipe.finish.classKey = "finish.vinyl-wallpaper"
recipe.substrate.classKey = "substrate.gypsum-board"
recipe.installation.methodKey = "installation.pasted-wallpaper"
```

The mutated `physical.classKey` is a project-owned key already used by the shipped carpet fixture, yet no current predicate rejects that known carpet physical family under the wallpaper recipe.

The same class of mismatch can be constructed with the shipped `acoustic.low-pile-carpet` key (and, independently, a shipped visual family key) while preserving the copied wallpaper coherence label.

This is different from the existing `cross-domain coherence mismatch rejected` regression, which mutates `acoustic.coherenceClass` itself. The problematic recipe keeps every coherence label equal and cross-wires an already-known semantic family key instead.

## Why it matters

The MaterialDNA contract says visual, physical, and acoustic profiles are different responses of one material identity, not independent random selections. A generator or migration boundary that accepts an internally contradictory known-family recipe can therefore freeze canonical truth whose visual construction says wallpaper while its semantic physical response says carpet. A later realization adapter then has to honor contradictory canonical data or invent an unversioned repair.

This is a source/data-contract issue. It does not require Studio evidence to demonstrate the validation gap, and this mining pass does not claim any engine consequence has been observed.

## Non-duplication

This finding is not the already-owned MaterialDNA work:

- `HG-BACKFILL-MATERIALDNA` closed hostile unknown-key execution and fixture same-revision drift seals;
- `HG-BACKFILL-MATERIALDNA-COUNTERS` owns `maintenance.repairCount` exact-integer bounds;
- `HG-BACKFILL-MATERIALDNA-DENSE-BOUNDS` owns oversized validation work and bounded diagnostics;
- `HG-BACKFILL-MATERIALDNA-KEY-GRAMMAR` owns the `%` semantic-key grammar alias.

The fixture content seals from PR #283 protect accidental edits to the three shipped recipes. They do not reject a newly generated, decoded, or otherwise caller-supplied recipe that cross-wires already-known family keys and then passes `validateRecipe()`.

## Bounded follow-up

Do not infer compatibility from string prefixes and do not create a generic material registry.

A narrow source-only successor can extend the existing conservative compatibility boundary with explicit knowledge of the already-shipped families. One acceptable shape is a small table that assigns only known built-in visual/physical/acoustic family keys to their expected coherence/family class, rejecting a known key when it is paired with another known recipe family while leaving unknown future semantic keys unconstrained until their construction semantics are deliberately defined.

Focused deterministic regressions should prove at minimum:

1. wallpaper + known carpet physical key rejects even when all coherence labels are copied to wallpaper;
2. wallpaper + known carpet acoustic key rejects under the same condition;
3. representative correct shipped combinations remain valid and retain exact fixture content/identity;
4. an otherwise-valid unknown future project semantic class key remains unconstrained rather than being rejected by string-prefix inference;
5. no schema, `id`, `recipeVersion`, fixture content, or MaterialRef shape changes are introduced.

Because the existing MaterialDNA counter/dense-bound/key-grammar leaves edit the same production validator, any implementation should be sequenced after or absorbed into that lineage rather than creating overlapping production WIP.

## Evidence boundary

This audit inspected current-main MaterialDNA source, contract tests, fixture catalog, the MaterialDNA contract, completed PR #283, and the currently materialized MaterialDNA backfill lanes. No executable test, performance timing, Roblox Studio run, viewport inspection, audio behavior, physical contact, or multiplayer evidence is claimed by this docs-only mining artifact.
