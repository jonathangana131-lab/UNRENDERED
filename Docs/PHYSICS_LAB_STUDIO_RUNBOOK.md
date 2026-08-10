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
print(HttpService:JSONEncode(Validation.capture(lab.model)))
```

The snapshot is source-owned evidence. It includes lab/world/region identity, the exact resolved-region fingerprint and repro key, scoped Instance/resource counts, and the full physical envelope. `Validation.compare()` rejects snapshots from different canonical resolved truth before producing a delta.

## Exact evidence identity

Before any lifecycle manipulation, record:

```luau
local ServerScriptService = game:GetService("ServerScriptService")
local HttpService = game:GetService("HttpService")
local PhysicsLab = ServerScriptService.UNRENDERED_Server.PhysicsLab
local Harness = require(PhysicsLab.PhysicsLabStudioHarness)
local Validation = require(PhysicsLab.PhysicsLabValidation)

local lab = assert(Harness.get(), "Physics Lab bootstrap handle is missing")
local snapshot = Validation.capture(lab.model)
print("PHYSICS_LAB_BASELINE=" .. HttpService:JSONEncode(snapshot))
```

Record the tested Git commit SHA, Studio version/channel, OS, server/client topology and flags next to that JSON output.

## Production F2 -> F0 -> F2 lifecycle

The landed lab adapter intentionally realizes only F0/F2. The following inputs exercise the production FidelityManager policy without introducing lab-only transition rules. Run the block separately for one structural entity such as `floor` and one ObjectGenome-backed entity such as `door-main`.

```luau
local ServerScriptService = game:GetService("ServerScriptService")
local PhysicsLab = ServerScriptService.UNRENDERED_Server.PhysicsLab
local Harness = require(PhysicsLab.PhysicsLabStudioHarness)

local lab = assert(Harness.get(), "Physics Lab bootstrap handle is missing")
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

This procedure uses the harness rather than deleting Workspace Instances. It proves deterministic rebuild identity/count/envelope behavior at checkpoints 1, 5, 10 and 20.

```luau
local ServerScriptService = game:GetService("ServerScriptService")
local HttpService = game:GetService("HttpService")
local PhysicsLab = ServerScriptService.UNRENDERED_Server.PhysicsLab
local Harness = require(PhysicsLab.PhysicsLabStudioHarness)
local Validation = require(PhysicsLab.PhysicsLabValidation)

local lab = assert(Harness.get(), "Physics Lab bootstrap handle is missing")
local baseline = Validation.capture(lab.model)
local checkpoints = { [1] = true, [5] = true, [10] = true, [20] = true }

for cycle = 1, 20 do
    lab = Harness.restart(workspace)
    local snapshot = Validation.capture(lab.model)
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
