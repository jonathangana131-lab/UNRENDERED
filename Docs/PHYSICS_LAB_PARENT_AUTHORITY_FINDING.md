# Physics Lab parent-authority finding

Status: source-only capacity-mining finding. This document does **not** claim Roblox Studio, viewport, physical-contact, or two-client evidence.

## Scope

- lane: `HG-CAPACITY-MINING`
- slot: `mine-authority`
- worker: `sol-20260814-j3q8v6m1`
- inspected base: `main@af6a17aa7969d40e8b19f7e9d19fe93cc9b1d9a9`
- shard: Physics Lab server-side realization ownership / physical-placement boundary

This is intentionally distinct from the already-open authority lineages for wrong-context bootstrap ordering, Rojo server/client placement, harness teardown, and raw `RealizedLab.destroy()` capability ownership.

## Finding

`Docs/PHYSICS_LAB.md` defines `src/server/PhysicsLab/PhysicsLabRealizer.luau` as the Roblox representation adapter that, in Studio, realizes the deterministic recipe into `Workspace/UNRENDERED_PhysicsLab`.

The current source does not enforce that physical-placement contract:

1. `PhysicsLabStudioHarness.start(parent: Instance?)` accepts an arbitrary Roblox `Instance` supplied by its caller.
2. The harness passes `parent or workspace` directly to `PhysicsLabRealizer.realize(...)`.
3. `PhysicsLabRealizer.realize(parent: Instance)` performs its collision/ownership check only beneath that supplied parent.
4. After building the canonical lab representation, the realizer assigns `model.Parent = parent` without checking that `parent` is `Workspace` or an approved project-owned Workspace container.

Therefore a Studio server caller can request, for example, `PhysicsLabStudioHarness.start(game:GetService("ReplicatedStorage"))` and the current contract has no source guard preventing `UNRENDERED_PhysicsLab` from being realized outside Workspace.

That does not corrupt the plain-data recipe or make Workspace canonical, but it weakens the physical-world authority boundary: the permanent validation lab can exist outside the documented physical representation tree, while later diagnostics/runbook logic and human validation still reason about `Workspace/UNRENDERED_PhysicsLab` as the authoritative physical shell.

## Why this is not a duplicate

The current open authority work found during this audit covers different seams:

- wrong-context bootstrap guards and server/client import ownership;
- Rojo deployment placement of shared/server/client source trees;
- teardown ordering and duplicate harness ownership;
- the ability for callers to obtain a raw `RealizedLab.destroy()` capability.

Repository PR/issue searches for Physics Lab parent/Workspace realization did not surface an existing dedicated parent-placement repair or regression.

## Exact source repro

On the inspected base, the relevant flow is:

```text
PhysicsLabStudioHarness.start(parent)
  -> assertStudioServer()
  -> PhysicsLabRealizer.realize(parent or workspace)
  -> model.Parent = parent
```

No predicate between those steps constrains the supplied parent to Workspace.

The minimal source-level adversary should preserve every existing guard while supplying a non-Workspace parent and require the boundary to fail closed before any physical lab model is committed beneath that parent.

## Recommended bounded follow-up

Do **not** broaden the authority architecture from this mining PR. When the scheduler explicitly opens a follow-up authority leaf, first choose and document one stable v1 placement policy, then lock it with an expected-red regression before production repair.

Preferred policy shape:

- the public Studio harness owns the canonical lab location;
- callers cannot redirect the canonical lab into an arbitrary service/container;
- either remove the public parent override entirely, or validate it against an explicit project-owned Workspace placement contract;
- rejection occurs before physical realization/ownership is committed;
- existing exactly-one-lab, teardown, diagnostics, and domain/representation boundaries remain unchanged.

A repair should not be described as Studio evidence. It is a source/authority invariant; real engine evidence remains separately gated by `Docs/PROJECT_STATE.md`.
