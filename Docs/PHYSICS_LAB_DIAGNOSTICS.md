# Physics Lab Studio Diagnostics

Issue #151 requires a real Roblox Studio observation for development diagnostics. This document defines the narrow production-boundary adapter used to collect that evidence. It does **not** make the diagnostics row PASS by existing in source or by passing CI.

## Ownership and scope

`src/server/PhysicsLab/PhysicsLabStudioDiagnostics.luau` is Studio/server-only validation instrumentation. It does not own WorldEntity identity, fidelity policy, resolved truth, persistence, networking, or a second Physics Lab runtime.

Every readout is derived from the existing `PhysicsLabRealizer.RealizedLab` record plus attributes already written by the production realizer. The adapter creates no remotes, event connections, registrations, histories, queues, background tasks, or persistence records.

Diagnostics-on creates exactly one owned `Folder` named `UNRENDERED_PhysicsLabDiagnostics` under the lab root. Its descendants are non-physical `BillboardGui`/`TextLabel` readouts. Diagnostics-off destroys that owned tree. The adapter refuses to operate on an unrelated same-name object instead of deleting foreign state.

The readout surface exposes:

- stable `WorldEntityId`;
- authoritative current fidelity from the `WorldEntity` record;
- authoritative representation/state revisions from the same record, both in the live visual label and the machine-readable snapshot;
- entity recipe identity in the machine-readable snapshot;
- resolved-region fingerprint;
- resolved-region repro key.

The visual labels are diagnostic representation only. They are never canonical world data and are excluded from all diagnostics-off validation evidence by being destroyed before `PhysicsLabValidation.captureFull()` runs.

## Failure atomicity

Diagnostics-on is fail-closed. `enable()` preflights the realized representations, authoritative records, required identity/fidelity attributes, revision counters, and usable `BasePart` adornees before it parents the owned diagnostics root. The owned Instance tree is then realized inside a protected transaction; if any later configuration/capture step fails, the owned root is destroyed before the original error is rethrown.

`tests/physics_lab_diagnostics_atomicity.luau` guards the preflight-before-mutation ordering, ownership-before-configuration ordering, rollback path, and live revision-readout contract. This source test does **not** replace the real Studio observation required for #151.

An unrelated same-name object is still never adopted or destroyed. If Studio evidence ever exposes a distinct post-preflight failure path that leaves owned state behind, preserve that exact repro and repair the smallest source defect rather than weakening the evidence contract.

## Manual server procedure

Use the **server** Command Bar in a running Roblox Studio server session:

```luau
local ServerScriptService = game:GetService("ServerScriptService")
local HttpService = game:GetService("HttpService")

local PhysicsLab = ServerScriptService.UNRENDERED_Server.PhysicsLab
local Harness = require(PhysicsLab.PhysicsLabStudioHarness)
local Diagnostics = require(PhysicsLab.PhysicsLabStudioDiagnostics)

local lab = assert(Harness.get(), "Physics Lab bootstrap handle is missing")

local enabled = Diagnostics.enable(lab)
print("PHYSICS_LAB_DIAGNOSTICS_ON=" .. HttpService:JSONEncode(enabled))

-- Inspect at least one structural representation and one ObjectGenome-backed F2
-- proxy in the 3D view. The labels must agree with the representation attributes
-- and the authoritative WorldEntity record, including fidelity and revisions.

local disabled = Diagnostics.disable(lab)
print("PHYSICS_LAB_DIAGNOSTICS_OFF=" .. HttpService:JSONEncode(disabled))
```

A successful command block is only a candidate observation. Record exact source SHA, Studio version/channel, OS, server/client topology, screenshot/capture provenance, and the emitted evidence before updating the #151 matrix.

## Source-owned bounded toggle sweep

For leak/regression evidence, run:

```luau
local ServerScriptService = game:GetService("ServerScriptService")
local HttpService = game:GetService("HttpService")

local PhysicsLab = ServerScriptService.UNRENDERED_Server.PhysicsLab
local Harness = require(PhysicsLab.PhysicsLabStudioHarness)
local Diagnostics = require(PhysicsLab.PhysicsLabStudioDiagnostics)

local lab = assert(Harness.get(), "Physics Lab bootstrap handle is missing")
local evidence = Diagnostics.runToggleEvidence(lab, 20)
print("PHYSICS_LAB_DIAGNOSTICS_20=" .. HttpService:JSONEncode(evidence))
```

`runToggleEvidence()` performs twenty diagnostics-on/off cycles. After every disable it runs the existing `PhysicsLabValidation.captureFull()` and `compare()` boundary against the initial canonical baseline. It fails immediately if any scoped Instance/resource count changes or the full-lab envelope moves beyond the existing `0.001` stud tolerance. Checkpoints are retained at cycles 1, 5, 10, and 20.

This proves bounded cleanup of the diagnostics Instances that this adapter owns. The stronger "no connection/registration/history/queue accumulation" requirement is satisfied structurally because the adapter creates none of those resources; a future diagnostics extension that introduces any of them must add explicit ownership counters and leak evidence rather than relying on this statement.

## Required engine evidence before PASS

The diagnostics row remains open until a tester/bridge run on the exact commit establishes all of the following:

1. the code runs in real Studio server RunMode (`RunService:IsStudio()` and `RunService:IsServer()`);
2. diagnostics-on visibly exposes the stable identity, fidelity, representation/state revisions, fingerprint, and repro information on real realized representations;
3. at least one structural entity and one ObjectGenome-backed representation are inspected;
4. the machine-readable snapshot agrees with production `WorldEntity` state;
5. diagnostics-off leaves no owned diagnostics tree;
6. the 20-cycle sweep records zero scoped resource drift and stable full-lab envelope at required checkpoints;
7. diagnostics are still off by default after normal bootstrap/rebuild;
8. no unrelated same-name Instance is silently destroyed or adopted;
9. a failed/interrupted diagnostics-on attempt cannot leave a partial owned diagnostics tree or poison the next candidate observation.

CI, a successful Rojo build, or source review alone cannot satisfy these observations.
