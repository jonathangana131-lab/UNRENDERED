# Physics Lab Studio Runbook

This runbook executes the #151 Physics Lab evidence procedures through the production lifecycle boundary. It does **not** record a PASS by itself. Every Studio-only row remains UNVERIFIED until a tester actually runs the procedure on an exact commit and records the observations.

Use the **server** Command Bar in a running Roblox Studio server session. Do not manually delete the lab model to simulate lifecycle behavior.

## Production validation modules

The server bootstrap owns the current `RealizedLab` through `PhysicsLabStudioHarness`. The harness is Studio/server-only and delegates realization, teardown and representation-aware entity transitions to `PhysicsLabRealizer`; it does not own a second runtime or fidelity state machine.

```luau
local ServerScriptService = game:GetService("ServerScriptService")
local HttpService = game:GetService("HttpService")

local PhysicsLab = ServerScriptService.UNRENDERED_Server.PhysicsLab
local Harness = require(PhysicsLab.PhysicsLabStudioHarness)
local Validation = require(PhysicsLab.PhysicsLabValidation)

local lab = assert(Harness.get(), "Physics Lab bootstrap handle is missing")
print(HttpService:JSONEncode(Validation.captureFull(lab.model)))
```

The snapshot is source-owned evidence. It includes lab/world/region identity, the exact resolved-region fingerprint and repro key, scoped Instance/resource counts, and the full physical envelope. Before emitting evidence, the collector also rejects noncanonical direct representations: unknown or duplicate representation keys, wrong/duplicate WorldEntityIds, wrong entity recipe identity, incorrect primitive MaterialDNA references, and incorrect ObjectGenome identity/fingerprint/class metadata. `Validation.captureFull()` additionally requires every canonical F2 representation to be present; `Validation.capture()` allows the expected canonical subset during an intentional F0/F2 lifecycle transition. `Validation.compare()` rejects snapshots from different canonical resolved truth before producing a delta.

## Exact evidence identity

Before any lifecycle manipulation, record:

```luau
local ServerScriptService = game:GetService("ServerScriptService")
local HttpService = game:GetService("HttpService")
local PhysicsLab = ServerScriptService.UNRENDERED_Server.PhysicsLab
local Harness = require(PhysicsLab.PhysicsLabStudioHarness)
local Validation = require(PhysicsLab.PhysicsLabValidation)

local lab = assert(Harness.get(), "Physics Lab bootstrap handle is missing")
local snapshot = Validation.captureFull(lab.model)
print("PHYSICS_LAB_BASELINE=" .. HttpService:JSONEncode(snapshot))
```

Record the tested Git commit SHA, Studio version/channel, OS, server/client topology and flags next to that JSON output.

## Source-owned 20-cycle lifecycle sweep

`PhysicsLabStudioEvidence` drives every canonical lab WorldEntity through the existing representation-safe `RealizedLab.step` boundary. It performs 20 complete F2 -> F0 -> F2 cycles, checks that all representations disappear and return, verifies identity/revision progression, and captures the source-owned resource/envelope evidence at cycles 1, 5, 10 and 20.

Run it from the **server** Command Bar:

```luau
local ServerScriptService = game:GetService("ServerScriptService")
local HttpService = game:GetService("HttpService")
local PhysicsLab = ServerScriptService.UNRENDERED_Server.PhysicsLab
local Evidence = require(PhysicsLab.PhysicsLabStudioEvidence)

local evidence = Evidence.runLifecycle20()
print("PHYSICS_LAB_LIFECYCLE_20=" .. HttpService:JSONEncode(evidence))
```

The runner fails immediately if a production hold/transition behaves differently than expected, an F0 representation survives, an F2 representation fails to rebuild, the canonical identity changes, resource counts drift at a checkpoint, or the complete F2 envelope moves beyond the recorded `0.001` stud tolerance. The returned value is frozen plain evidence and does not retain Instances or the runtime.

A successful run is strong lifecycle/resource evidence for the exact Studio session, but it is not a substitute for visible physical inspection. Record the emitted JSON with commit/Studio/OS/topology identity and still inspect at least one structural entity and one ObjectGenome-backed entity before marking the lifecycle row PASS.

## Production F2 -> F0 -> F2 lifecycle

The landed lab adapter intentionally realizes only F0/F2. The following inputs exercise the production FidelityManager policy without introducing lab-only transition rules. Use this focused block when inspecting one structural entity such as `floor` and one ObjectGenome-backed entity such as `door-main`, or when diagnosing a failure from the source-owned 20-cycle sweep. The block intentionally restarts the harness first so its fixed synthetic timestamps own a fresh monotonic FidelityManager clock.

```luau
local ServerScriptService = game:GetService("ServerScriptService")
local PhysicsLab = ServerScriptService.UNRENDERED_Server.PhysicsLab
local Harness = require(PhysicsLab.PhysicsLabStudioHarness)

local lab = Harness.restart(workspace)
local target = assert(lab.model:FindFirstChild("door-main"), "target representation missing")
local entityId = assert(target:GetAttribute("UNRENDERED_WorldEntityId"), "target has no WorldEntityId") :: string

local noDemand = {
    distanceStuds = 1000000,
    visible = false,
    directlyObserved = false,
    secondsSinceInteraction = math.huge,
    significance = 0,
    networkRelevance = 0,
    entityRelevance = 0,
}
local f2Demand = {
    distanceStuds = 100,
    visible = false,
    directlyObserved = false,
    secondsSinceInteraction = math.huge,
    significance = 0,
    networkRelevance = 0,
    entityRelevance = 0,
}

local before = lab.getRecord(entityId)
assert(before.fidelity == "F2", "expected initial F2 proxy")
assert(lab.isRepresented(entityId), "initial F2 representation missing")

-- First sample establishes the pending demotion; the second exceeds the
-- production demotion hold. Synthetic monotonic timestamps avoid a manual wait.
lab.step(entityId, noDemand, 100)
local demotionResult, demoted = lab.step(entityId, noDemand, 102)
assert(demotionResult.transitioned and demoted.fidelity == "F0", "F2->F0 did not commit")
assert(not lab.isRepresented(entityId), "F0 entity still has a representation")

-- Partial lifecycle evidence may use Validation.capture(lab.model) here. It
-- still rejects any present noncanonical representation but intentionally
-- permits the demoted F0 entity to be absent from the Instance tree.

-- Respect transition cooldown, establish the pending promotion, then exceed the
-- production promotion hold.
lab.step(entityId, f2Demand, 102.3)
local promotionResult, promoted = lab.step(entityId, f2Demand, 102.5)
assert(promotionResult.transitioned and promoted.fidelity == "F2", "F0->F2 did not commit")
assert(lab.isRepresented(entityId), "F2 entity did not rebuild its representation")
assert(promoted.id == before.id, "WorldEntity identity changed across representation lifecycle")

print("LIFECYCLE_PASS_CANDIDATE", entityId, before.stateRevision, promoted.stateRevision)
```

The printed line is only a candidate observation. Record the before/after authoritative state and inspect the physical representation before marking the corresponding #151 row PASS.

## Whole-lab teardown/rebuild envelope

This procedure uses the harness rather than deleting Workspace Instances. It proves deterministic rebuild identity/count/envelope behavior at checkpoints 1, 5, 10 and 20. Full checkpoints use `captureFull()` so a stable-but-wrong shell cannot pass merely by reproducing the same counts and outer bounds.

```luau
local ServerScriptService = game:GetService("ServerScriptService")
local HttpService = game:GetService("HttpService")
local PhysicsLab = ServerScriptService.UNRENDERED_Server.PhysicsLab
local Harness = require(PhysicsLab.PhysicsLabStudioHarness)
local Validation = require(PhysicsLab.PhysicsLabValidation)

local lab = assert(Harness.get(), "Physics Lab bootstrap handle is missing")
local baseline = Validation.captureFull(lab.model)
local checkpoints = { [1] = true, [5] = true, [10] = true, [20] = true }

for cycle = 1, 20 do
    lab = Harness.restart(workspace)
    local snapshot = Validation.captureFull(lab.model)
    local comparison = Validation.compare(baseline, snapshot)

    assert(comparison.delta.instances == 0, "Instance count drifted")
    assert(comparison.delta.models == 0, "Model count drifted")
    assert(comparison.delta.parts == 0, "Part count drifted")
    assert(comparison.delta.assemblies == 0, "assembly count drifted")
    assert(comparison.delta.attachments == 0, "Attachment count drifted")
    assert(comparison.delta.constraints == 0, "Constraint count drifted")
    assert(comparison.delta.joints == 0, "joint count drifted")
    assert(comparison.envelope.ok, comparison.envelope.reason or "lab envelope drifted")

    if checkpoints[cycle] then
        print(string.format(
            "PHYSICS_LAB_REBUILD_%02d=%s",
            cycle,
            HttpService:JSONEncode(snapshot)
        ))
    end
end
```

These zero deltas are an exact-rebuild check for this deterministic shell, not a permanent project-wide resource budget. If a later intentionally versioned lab recipe changes its physical content, establish a new baseline for that exact recipe identity instead of weakening cross-truth comparison.

To verify teardown itself through the production path:

```luau
local ServerScriptService = game:GetService("ServerScriptService")
local PhysicsLab = ServerScriptService.UNRENDERED_Server.PhysicsLab
local Harness = require(PhysicsLab.PhysicsLabStudioHarness)

Harness.stop()
assert(workspace:FindFirstChild("UNRENDERED_PhysicsLab") == nil, "owned lab root survived production teardown")
Harness.start(workspace)
```

## Recovery after an interrupted validation block

If a Command Bar assertion interrupts a procedure, restore one clean canonical lab with:

```luau
local ServerScriptService = game:GetService("ServerScriptService")
local PhysicsLab = ServerScriptService.UNRENDERED_Server.PhysicsLab
local Harness = require(PhysicsLab.PhysicsLabStudioHarness)
Harness.restart(workspace)
```

## What still requires observation

Source/CI cannot establish physical contact stability, traversability, visible assembly correctness, two-client consistency, Studio memory behavior, or device performance. Record those results with the matrix in `Docs/PHYSICS_LAB_VALIDATION.md`. A green CI run or successful Command Bar setup must never be rewritten as Studio physics evidence.
