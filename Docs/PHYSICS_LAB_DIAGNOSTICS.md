# Physics Lab Studio Diagnostics

Issue #151 requires a real Roblox Studio observation for development diagnostics. This document defines the narrow production-boundary adapter used to collect that evidence. It does **not** make the diagnostics row PASS by existing in source or by passing CI.

## Ownership and scope

`src/server/PhysicsLab/PhysicsLabStudioDiagnostics.luau` is Studio/server-only validation instrumentation. It does not own WorldEntity identity, fidelity policy, resolved truth, persistence, networking, or a second Physics Lab runtime.

Every readout is derived from the existing `PhysicsLabRealizer.RealizedLab` record plus attributes already written by the production realizer. The adapter creates no remotes, event connections, registrations, histories, queues, background tasks, or persistence records.

Diagnostics-on creates exactly one owned `Folder` named `UNRENDERED_PhysicsLabDiagnostics` under the lab root. Its descendants are non-physical `BillboardGui`/`TextLabel` readouts. Diagnostics-off destroys that owned tree. The adapter refuses to operate on an unrelated same-name object instead of deleting foreign state.

The readout surface exposes:

- stable `WorldEntityId`;
- authoritative current fidelity from the `WorldEntity` record;
- entity recipe identity;
- representation/state revisions in the machine-readable snapshot;
- resolved-region fingerprint;
- resolved-region repro key.

The visual labels are diagnostic representation only. They are never canonical world data and are excluded from all diagnostics-off validation evidence by being destroyed before `PhysicsLabValidation.captureFull()` runs.

## Failure atomicity contract

The diagnostics boundary is fail-closed as well as leak-free. A failed diagnostics-on attempt must not leave a partial owned tree that changes the next observation or causes the next enable attempt to fail as "already enabled."

Current source enforces this in two stages. `enable()` first preflights the fingerprint/repro identity and every realized representation, authoritative record, fidelity value, and usable `BasePart` adornee before parenting the owned diagnostics folder. It then realizes the diagnostics tree inside a protected transaction: every newly created readout is parented under the owned folder before later fallible configuration, and any error destroys the entire owned folder before the original failure is propagated. Always-run source regressions lock that ordering so a future edit cannot silently move fallible dependency checks after mutation or drop rollback cleanup.

This source-level contract does **not** convert the engine evidence row to PASS. A real Studio candidate still has to demonstrate that an interrupted/errored diagnostics-on attempt leaves no owned diagnostics tree and does not poison the next observation. If such an attempt fails in Studio, explicitly force diagnostics off and re-establish the canonical lab baseline before collecting another candidate; do not reinterpret cleanup code or CI as engine evidence.

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
-- and the authoritative WorldEntity record.

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
2. diagnostics-on visibly exposes the stable identity/fidelity/fingerprint/repro information on real realized representations;
3. at least one structural entity and one ObjectGenome-backed representation are inspected;
4. the machine-readable snapshot agrees with production `WorldEntity` state;
5. diagnostics-off leaves no owned diagnostics tree;
6. the 20-cycle sweep records zero scoped resource drift and stable full-lab envelope at required checkpoints;
7. diagnostics are still off by default after normal bootstrap/rebuild;
8. no unrelated same-name Instance is silently destroyed or adopted;
9. a failed/interrupted diagnostics-on attempt cannot leave a partial owned diagnostics tree or poison the next candidate observation.

CI, a successful Rojo build, or source review alone cannot satisfy these observations.
