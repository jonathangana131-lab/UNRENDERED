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

The diagnostics boundary must be fail-closed as well as leak-free. A failed diagnostics-on attempt must not leave a partial owned tree that changes the next observation or causes the next enable attempt to fail as "already enabled."

The source path was hardened by PR #285, merged as `f4c4e4a2f89caba4d258669417f85206f96d4e98`. `enable()` now preflights the realized representations, authoritative records, required representation identity/fidelity attributes, usable `BasePart` adornees, and the model's resolved-region fingerprint/repro key before mutating the lab. It does **not** preflight every root identity field: required `UNRENDERED_WorldId` and `UNRENDERED_RegionId` are re-read by the final machine-readable capture after the diagnostics folder has been parented. The diagnostics folder name/owned marker, root parenting, child realization, and that final capture execute inside one protected transaction, so a capture-time root-identity failure rolls back the exact folder created by that call before propagating the original error. Every `BillboardGui` and `TextLabel` is attached to that owned subtree before later fallible configuration. The unrelated same-name-object refusal remains fail-closed.

`tests/physics_lab_diagnostics_atomicity.luau`, executed through the normal Hero Gate pure suite, guards those source-ordering invariants while the Studio display path is unavailable. That test is **source-only evidence**: it does not prove Roblox Instance runtime behavior, viewport behavior, or the failure path in a real Studio server. The #151 diagnostics row still requires the engine observation below.

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

## Failure-atomicity engine probe

Run this only from the **server** Command Bar after establishing a clean diagnostics-off baseline. The probe deliberately injects a capture-time validation failure *after* preflight by temporarily changing one representation's optional `UNRENDERED_RepresentationClass` attribute from its valid value to a number. That causes the final diagnostics capture to reject the representation after the owned diagnostics tree has been realized, exercising rollback rather than only preflight rejection.

```luau
local ServerScriptService = game:GetService("ServerScriptService")
local HttpService = game:GetService("HttpService")

local PhysicsLab = ServerScriptService.UNRENDERED_Server.PhysicsLab
local Harness = require(PhysicsLab.PhysicsLabStudioHarness)
local Diagnostics = require(PhysicsLab.PhysicsLabStudioDiagnostics)

local lab = assert(Harness.get(), "Physics Lab bootstrap handle is missing")
local rootName = "UNRENDERED_PhysicsLabDiagnostics"
assert(lab.model:FindFirstChild(rootName) == nil, "start from diagnostics-off baseline")

local target = nil
for _, child in ipairs(lab.model:GetChildren()) do
	if child:GetAttribute("UNRENDERED_WorldEntityId") ~= nil then
		target = child
		break
	end
end
assert(target ~= nil, "no realized Physics Lab representation found")

local originalRepresentationClass = target:GetAttribute("UNRENDERED_RepresentationClass")
target:SetAttribute("UNRENDERED_RepresentationClass", 151285)

local ok, injectedError = pcall(function()
	Diagnostics.enable(lab)
end)

-- Restore canonical diagnostic metadata before any retry or assertion can abort.
target:SetAttribute("UNRENDERED_RepresentationClass", originalRepresentationClass)

if ok then
	Diagnostics.disable(lab)
	error("expected injected diagnostics capture failure")
end

local injectedErrorText = tostring(injectedError)
local expectedErrorFragment = "invalid representation class diagnostics attribute"
local expectedFailureObserved = string.find(injectedErrorText, expectedErrorFragment, 1, true) ~= nil

local rootAfterFailure = lab.model:FindFirstChild(rootName)
assert(rootAfterFailure == nil, "failed diagnostics enable leaked its owned tree")
assert(
	expectedFailureObserved,
	"injected diagnostics failure did not reach the expected capture validation: " .. injectedErrorText
)

local retry = Diagnostics.enable(lab)
assert(retry.enabled, "clean retry did not enable diagnostics")
local retryOff = Diagnostics.disable(lab)
assert(not retryOff.enabled, "clean retry did not disable diagnostics")

print("PHYSICS_LAB_DIAGNOSTICS_FAILURE_ATOMICITY=" .. HttpService:JSONEncode({
	injectedFailureObserved = expectedFailureObserved,
	injectedError = injectedErrorText,
	rootPresentAfterFailure = rootAfterFailure ~= nil,
	retryEnabled = retry.enabled,
	retryDisabled = not retryOff.enabled,
}))
```

Accepted evidence must show the exact injected representation-class capture rejection, the owned diagnostics root was absent immediately afterward, and a clean enable/disable retry succeeded. An unrelated transient failure is not accepted as the intended experiment. This probe validates one deliberate post-mutation failure path. It does not convert source review or CI into general proof against hard process termination; the engine evidence record must state exactly what was injected and observed.

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

A failed sweep is not reusable evidence. Current source validates the enabled canonical window before the cycle's `disable(lab)` call; if that enabled-window capture/comparison/assertion fails, the helper can exit while its owned diagnostics overlay is still enabled. Before any retry or other candidate observation, explicitly run `Diagnostics.disable(lab)` from the server Command Bar and verify `Diagnostics.capture(lab).enabled == false`. Do not reuse partial checkpoints from the failed sweep. This operator recovery rule remains necessary until the helper itself guarantees final-OFF cleanup on every post-enable failure path.

A **successful** sweep proves bounded cleanup of the diagnostics Instances that this adapter owns. The stronger "no connection/registration/history/queue accumulation" requirement is satisfied structurally because the adapter creates none of those resources; a future diagnostics extension that introduces any of them must add explicit ownership counters and leak evidence rather than relying on this statement.

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
9. the failure-atomicity engine probe records the exact injected representation-class capture rejection, no owned diagnostics tree afterward, and a successful clean retry.

CI, a successful Rojo build, or source review alone cannot satisfy these observations.