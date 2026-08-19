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

Before a readout is accepted, the realized representation's fidelity, `UNRENDERED_RecipeKey`, `UNRENDERED_RepresentationRevision`, and `UNRENDERED_StateRevision` attributes must agree exactly with the authoritative `WorldEntity` record. Revision attributes must be valid nonnegative integers. The identity-tagged realized representation population must be duplicate-free, every identity must remain authoritative through the production `RealizedLab.isRepresented()` boundary, and the total population must equal the realizer's `UNRENDERED_RepresentedCount`. A missing identity tag, duplicate ID, stale/non-represented identity, or count mismatch therefore cannot silently project a partial-but-successful diagnostics surface. Diagnostics fails closed on missing, malformed, stale, contradictory, non-authoritative, or incomplete physical metadata.

The visual labels are diagnostic representation only. They are never canonical world data and are excluded from all diagnostics-off validation evidence by being destroyed before `PhysicsLabValidation.captureFull()` runs.

## Failure atomicity

Diagnostics-on is fail-closed. `enable()` preflights the duplicate-free authoritative representation population/cardinality, authoritative records, required identity/fidelity/recipe attributes, valid revision attributes and exact representation-to-record agreement, plus usable `BasePart` adornees before it parents the owned diagnostics root. The owned Instance tree is then realized inside a protected transaction; if any later configuration/capture step fails, the owned root is destroyed before the original error is rethrown.

`tests/physics_lab_diagnostics_atomicity.luau` guards duplicate-ID/cardinality handling, preflight-before-mutation ordering, representation-to-record fidelity/recipe/revision agreement, ownership-before-configuration ordering, rollback path, live revision-readout contract, default-off evidence precondition, and final-off evidence publication guard. `tests/physics_lab_diagnostics_authority_bounds.luau` additionally locks authoritative `RealizedLab.isRepresented()` membership and the bounded cycle-input contract. These source tests do **not** replace the real Studio observation required for #151.

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

`runToggleEvidence()` validates its cycle request before any evidence mutation or iteration. Exact `nil` selects the canonical twenty-cycle proof; explicit overrides are accepted only as finite integer values from 1 through 20. Runtime-typed callers therefore cannot expand the Studio-only full-validation loop into an unbounded workload.

The helper then captures the current diagnostics state without mutating it and fails unless diagnostics are already OFF with zero owned diagnostic Instances. It does not call `disable()` to manufacture a clean initial state. Only after that observed precondition does it capture the canonical baseline and perform the requested bounded diagnostics-on/off cycles. After every disable it runs the existing `PhysicsLabValidation.captureFull()` and `compare()` boundary against that initial canonical baseline. It fails immediately if any scoped Instance/resource count changes or the full-lab envelope moves beyond the existing `0.001` stud tolerance. The canonical twenty-cycle proof retains checkpoints at cycles 1, 5, 10, and 20.

The sweep deliberately keeps its bounded Heartbeat yields for Studio watchdog safety. After the final yield it captures diagnostics state one more time and refuses to publish a successful evidence object unless diagnostics are still OFF with zero owned diagnostic Instances. A concurrent or accidental re-enable therefore invalidates the run instead of being encoded as a nominal success with `finallyEnabled=true`.

This proves bounded cleanup of the diagnostics Instances that this adapter owns while keeping the required default-OFF observation distinct from cleanup behavior and the final-OFF state distinct from the last cycle's earlier cleanup check. The stronger "no connection/registration/history/queue accumulation" requirement is satisfied structurally because the adapter creates none of those resources; a future diagnostics extension that introduces any of them must add explicit ownership counters and leak evidence rather than relying on this statement.

## Required engine evidence before PASS

The diagnostics row remains open until a tester/bridge run on the exact commit establishes all of the following:

1. the code runs in real Studio server RunMode (`RunService:IsStudio()` and `RunService:IsServer()`);
2. diagnostics-on visibly exposes the stable identity, fidelity, representation/state revisions, fingerprint, and repro information on real realized representations;
3. at least one structural entity and one ObjectGenome-backed representation are inspected;
4. the machine-readable snapshot agrees with production `WorldEntity` state, the realized fidelity/recipe/revision attributes agree with that same authoritative state, and the identity-tagged representation population is duplicate-free, authoritative through `RealizedLab.isRepresented()`, and matches `UNRENDERED_RepresentedCount`;
5. diagnostics-off leaves no owned diagnostics tree;
6. the canonical 20-cycle sweep records zero scoped resource drift and stable full-lab envelope at required checkpoints, and its final post-yield observation is still OFF with zero owned diagnostic Instances;
7. diagnostics are observed OFF by default after normal bootstrap/rebuild; the evidence sweep must fail rather than normalize a pre-existing ON state;
8. no unrelated same-name Instance is silently destroyed or adopted;
9. a failed/interrupted diagnostics-on attempt cannot leave a partial owned diagnostics tree or poison the next candidate observation.

CI, a successful Rojo build, or source review alone cannot satisfy these observations.