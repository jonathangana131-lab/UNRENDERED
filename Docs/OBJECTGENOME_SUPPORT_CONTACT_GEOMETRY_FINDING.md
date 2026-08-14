# ObjectGenome support-contact geometry finding

## Status

Source-only capacity-mining finding on `main@af6a17aa7969d40e8b19f7e9d19fe93cc9b1d9a9`.

This note does **not** unlock Door, Chair, Player, or any new Feature Epic. It does not claim Roblox Studio, viewport, physical-contact, networking, persistence, or two-client evidence.

## Finding

`ObjectGenome` models `ComponentSpec.supportKeys` as canonical construction/load relationships and validates them deeply as a graph: support keys must exist, self-support and duplicate edges are rejected, cycles are rejected, and every component must have a graph path to an `externalSupport` component.

The contract does not currently prove the geometric fact implied by a support edge: the supported component and the referenced supporting component may be spatially separated in the authored reference pose.

The validator checks each component independently against the object envelope, but support propagation later uses only key membership and graph reachability. No support-edge contact/proximity predicate compares the two components' authored transforms or rotated bounds.

That allows a structurally disconnected construction graph to remain canonical even though the same graph is treated as the load path for manufacturability and grounding.

## Concrete current-fixture repro

The shipped office-table fixture provides a small deterministic repro without inventing new object data:

- `top` is centered at local Y `0.33 m` with height `0.10 m`, so its bottom face is at `0.28 m`.
- `crossbar` is centered at local Y `0.15 m` with height `0.08 m`, so its top face is at `0.19 m`.
- The two authored AABBs therefore have a vertical gap of `0.09 m` in the reference pose.
- `crossbar` already has valid support paths to the four ground-supported legs.
- Change only `top.supportKeys` from the four legs to `{ "crossbar" }`.

The resulting support graph is still dense, key-valid, acyclic, and externally reachable (`top -> crossbar -> legs -> ground`). Every component remains independently inside the object envelope and all existing mass/material/dimension rules remain unchanged. The current `ObjectGenome.inspect()` topology therefore has no predicate that rejects the 9 cm unsupported air gap.

This is a contract-level gap, not a claim that the shipped office-table fixture is currently malformed: the shipped `top` points directly at the legs.

## Why this matters

ObjectGenome is the project-owned construction grammar and domain source of truth. A physical realization adapter should not have to invent whether a declared support edge is physically meaningful, silently bridge a gap, or reinterpret the canonical graph.

The issue is especially important because support relationships already drive semantic validity (`component.unsupported`) and later object families are expected to be manufacturable before anomaly. Accepting disconnected load paths makes graph validity weaker than the physical meaning downstream systems are expected to trust.

## Non-duplication

This is distinct from retained ObjectGenome support work:

- issue #125 / the landed support-reachability repair makes cycle rejection and external-support reachability deterministic; it does not validate geometry between connected components;
- the existing `component.outside_bounds` rule validates each component against the object envelope independently, not contact between support-linked components;
- rolling-cart PRs #311/#352 repaired and regression-tested contact for one authored Physics Lab fixture, including caster-to-chassis contact, but did not add a generic ObjectGenome support-edge contact contract;
- PR #480 records affordance-radius locality, not construction support edges;
- PR #489 records caster wheel-radius locality, not support graph geometry;
- PR #466 records caster swivel/roll-axis relation, not support graph geometry;
- issue #14's future office-chair generator requires no floating/non-supporting construction, but that Feature work is currently locked and does not provide the generic v1 domain validator rule needed here.

Repository PR/issue searches for `ObjectGenome`, `supportKeys`, `support contact`, and support-graph geometry surfaced the fixture-specific cart repair but no dedicated generic support-contact owner.

## Recommended bounded follow-up

Only after an explicitly unlocked ObjectGenome source leaf owns this compatibility decision:

1. Define what a v1 `supportKeys` edge physically means in the authored reference pose. Do not infer a broad physics solver contract from the existing string graph.
2. Add an expected-red regression using the office-table mutation above so an acyclic, ground-reachable but spatially disconnected edge is rejected.
3. Prefer the smallest deterministic geometry rule compatible with existing v1 data, for example contact/proximity between the referenced components' rotated authored bounds within a documented manufacturing tolerance.
4. Cover touching, small allowed tolerance, first rejected gap, rotated components, multi-support edges, and existing chair/table/cabinet fixtures.
5. Keep external-support semantics separate unless their local-space ground/wall/ceiling geometry is explicitly defined; do not silently broaden this finding into a world-placement framework.
6. Preserve schema version, StableId inputs, recipe-fingerprint behavior, material references, support cycle/reachability diagnostics, mechanisms, mutable state, and all current golden fixtures unless compatibility evidence requires an explicit version decision.
7. Require exact-head Pure Luau/canonical CI plus independent source review. Any later claim about actual Roblox contact still requires engine evidence where applicable.

## Evidence boundary

Audited source blob: `src/shared/Objects/ObjectGenome.luau@9dc23f98705f3073471998368df6fdb3829a9d2c`.

Audited fixture source: `src/shared/Objects/ObjectGenomeFixtures.luau` on the same main base.

Audited focused tests: `tests/object_genome.luau@10f801a970d7cc5024397e20f12c2afb0ba7212d`.

No production code or test behavior is changed by this finding.
