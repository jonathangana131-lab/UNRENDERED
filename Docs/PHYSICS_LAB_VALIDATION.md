# Physics Lab Reality-Grade Validation

Issue #151 is the validation strike-team child of the unlocked production Physics Lab (#10). This document defines the evidence protocol for the lab. It does **not** claim that Roblox Studio evidence has been run.

The goal is to prove that the first playable room exercises the landed Wave-1 contracts instead of hiding an ad-hoc demo behind convincing Roblox Instances.

## Evidence rule

Every reported check has one of three states:

- **PASS** — the named procedure was actually run and the captured observation satisfies the pass condition.
- **FAIL** — the named procedure was actually run and violates the pass condition; record the exact repro and blocker.
- **UNVERIFIED** — the procedure has not been run in the required environment.

Do not translate a successful Rojo build, pure-Luau test, source inspection, or expected Studio behavior into a Studio PASS. Engine-only claims remain UNVERIFIED until somebody runs the documented Studio procedure.

## Evidence identity

Every evidence bundle must record enough identity to reproduce the exact build:

- Git commit SHA under test,
- Physics Lab recipe/schema version,
- locked resolved-region ID/fingerprint/repro key exposed by the lab root diagnostics,
- Roblox Studio version/channel,
- OS,
- server/client topology used by the test,
- development diagnostics enabled/disabled state,
- any non-default flags relevant to realization or fidelity.

If the lab cannot expose an exact deterministic recipe identity once its contract lands, report that as a #10 blocker rather than substituting a screenshot or place-file timestamp.

## Source and CI preflight

Before Studio evidence, validate the exact commit with the project toolchain:

```bash
rokit install
rojo sourcemap default.project.json --output sourcemap.json
curl --proto '=https' --tlsv1.2 -sSf \
  https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/1.69.0/scripts/globalTypes.d.luau \
  -o globalTypes.d.luau
stylua --check src tests
selene src tests
luau-lsp analyze --platform=roblox --definitions:@roblox=globalTypes.d.luau --sourcemap=sourcemap.json src
lune run tests/run
mkdir -p build
rojo build default.project.json --output build/UNRENDERED.rbxlx
```

The ordinary synthetic-merge GitHub Actions run is the integration gate for code/test changes. A green CI run proves only those automated checks.

## Contract audit matrix

The primary lab recipe must account for all required #10 content. Audit the canonical recipe and its realization path before judging appearance.

| Required content | Stable WorldEntity identity | Fidelity path uses production manager/lifecycle | Material/ObjectGenome path | Physical representation is disposable | Result |
| --- | --- | --- | --- | --- | --- |
| floor | required | required | project contract or documented structural-only rationale | required | UNVERIFIED |
| walls | required | required | project contract or documented structural-only rationale | required | UNVERIFIED |
| ceiling | required | required | project contract or documented structural-only rationale | required | UNVERIFIED |
| hinged door placeholder | required | required | ObjectGenome/MaterialDNA | required | UNVERIFIED |
| chair placeholder | required | required | ObjectGenome/MaterialDNA | required | UNVERIFIED |
| table placeholder | required | required | ObjectGenome/MaterialDNA | required | UNVERIFIED |
| rolling cart placeholder | required | required | ObjectGenome/MaterialDNA | required | UNVERIFIED |
| cabinet/drawer placeholder | required | required | ObjectGenome/MaterialDNA | required | UNVERIFIED |
| stairs | required | required | project contract or documented structural-only rationale | required | UNVERIFIED |
| ramp | required | required | project contract or documented structural-only rationale | required | UNVERIFIED |
| ledge | required | required | project contract or documented structural-only rationale | required | UNVERIFIED |
| physical-character spawn anchor | required | required | domain identity; no character framework required | required | UNVERIFIED |

“Structural-only rationale” is not permission for anonymous Parts. The recipe still needs stable production identity; it only allows structural lab geometry to avoid pretending it is a furniture ObjectGenome.

For each row, capture the canonical WorldEntityId, the recipe/content key that produced it, current authoritative fidelity, and the physical root Instance (if realized). Duplicate or missing IDs are failures.

## Deterministic reconstruction

Run this against the exact same commit and inputs at least three times from a fresh server process or equivalent clean lab bootstrap.

1. Start from no pre-existing Physics Lab representation.
2. Build the canonical lab using its normal production bootstrap.
3. Capture the ordered canonical recipe identity/fingerprint and the complete set of lab WorldEntityIds/content keys.
4. Stop the process and repeat from a clean start twice more.
5. Compare canonical data, not Explorer insertion order or Instance debug IDs.

Pass conditions:

- the recipe identity/fingerprint is byte-for-byte equal on all runs,
- the WorldEntityId/content-key set is exactly equal on all runs,
- no unrelated subsystem activity changes those IDs,
- reconstruction does not require reading a previously serialized Workspace tree.

Any procedural failure report must include the deterministic repro key once the lab exposes one.

## Representation lifecycle / state survival

The lab must prove that Roblox representation is disposable while WorldEntity identity and meaningful state remain authoritative outside the Instance tree.

For at least one structural entity and one interactive ObjectGenome-backed placeholder:

1. Record WorldEntityId, authoritative fidelity, persistent mutable state, and physical root.
2. Demote/teardown through the production lifecycle boundary. Do not call `Destroy()` as a substitute for the project's demotion/state-capture path.
3. Verify the old physical representation is gone and there is no duplicate live representation for the same WorldEntityId.
4. Promote/re-realize through the production lifecycle boundary.
5. Verify the same WorldEntityId returns and captured meaningful mutable state is preserved according to the landed WorldEntity/ObjectGenome contract.
6. Repeat the lifecycle cycle 20 times while recording lab-root counts described below.

Pass conditions:

- identity never changes because an Instance was destroyed/recreated,
- demotion cannot silently discard required state,
- promotion does not register duplicate WorldEntityIds,
- repeated cycles return to a stable resource-count envelope instead of monotonically leaking descendants/constraints/registrations.

If the first shell has no safe development path to trigger lifecycle teardown/rebuild, record that as a validation blocker rather than manually deleting Instances and calling the result representative.

## Fidelity ownership

For each lab entity, prove the displayed/diagnosed fidelity is the authoritative WorldEntity fidelity coordinated through the production Fidelity Manager, not a local Physics Lab enum or Instance attribute that becomes a second truth source.

Exercise at least one promotion and one demotion where the existing policy can do so without inventing lab-specific rules. Capture:

- WorldEntityId,
- authoritative fidelity before/after,
- Fidelity Manager requested target/reason when exposed by existing diagnostics,
- whether state capture was required,
- representation before/after.

A local lab-only fidelity state machine is an architecture failure even if the visual transition looks correct.

## MaterialDNA / ObjectGenome boundary

For each ObjectGenome-backed placeholder:

- resolve its authored material references through the exact landed MaterialDNA identity/revision pair,
- verify the realized object does not replace canonical material identity with a hard-coded Roblox asset ID or duplicated physical/acoustic literals,
- verify ObjectGenome identity/state remains plain data and does not retain Roblox Instance references,
- verify placeholder mechanisms use the landed ObjectGenome mechanism/state contract rather than a second door/chair/drawer state schema.

Project-owned realization adapters may map canonical material families to Roblox properties/assets. That adapter mapping is representation data, not canonical material identity.

## Studio realization matrix

Run the matrix in a real Roblox Studio test session on the exact commit. The first shell is not required to be a finished Reality-Grade door/chair feature; these checks validate production-contract realization and basic physical sanity only.

| Scenario | Required observation | Result |
| --- | --- | --- |
| initial bootstrap | exactly one canonical lab root/realization; all required content appears | UNVERIFIED |
| floor/walls/ceiling | contiguous usable test bay; no obvious spawn-through or missing collision surfaces | UNVERIFIED |
| door placeholder | hinge representation is physically valid for the authored placeholder; no detached/exploding assembly on start | UNVERIFIED |
| chair placeholder | realizes as the intended ObjectGenome placeholder with stable identity; no spontaneous instability | UNVERIFIED |
| table placeholder | stable support/contact and canonical identity | UNVERIFIED |
| rolling cart placeholder | realizes with intended rolling/mechanism proxy without orphaned pieces | UNVERIFIED |
| cabinet/drawer placeholder | authored mechanism proxy realizes without invalid constraint state | UNVERIFIED |
| stairs | traversable collision geometry at expected scale | UNVERIFIED |
| ramp | traversable collision geometry at expected scale | UNVERIFIED |
| ledge | collision/edge geometry exists and is usable for later body tests | UNVERIFIED |
| spawn anchor | present as production-identified lab content; does not introduce a parallel character controller | UNVERIFIED |
| teardown/rebuild | production teardown removes old representation; rebuild restores same IDs without duplicates | UNVERIFIED |
| diagnostics off | release/default path does not create unbounded development labels/log spam | UNVERIFIED |
| diagnostics on | WorldEntityId and fidelity are inspectable for lab entities | UNVERIFIED |

Record visible physics failures with the exact entity ID and recipe/repro identity. Screenshots/video may support the observation but do not replace the textual repro.

## Lab-root resource counts

Resource counts are evidence, not budgets. Do not invent a permanent “allowed count” from this first shell.

In Studio, select exactly one Physics Lab physical root in Explorer and run this in the Command Bar to capture a scoped snapshot:

```luau
local Selection = game:GetService("Selection")
local selected = Selection:Get()
assert(#selected == 1, "select exactly one Physics Lab physical root")

local root = selected[1]
local counts = {
    instances = 1,
    models = if root:IsA("Model") then 1 else 0,
    parts = if root:IsA("BasePart") then 1 else 0,
    attachments = if root:IsA("Attachment") then 1 else 0,
    constraints = if root:IsA("Constraint") then 1 else 0,
    joints = if root:IsA("JointInstance") then 1 else 0,
}
local assemblies = {}

local function inspect(instance: Instance)
    counts.instances += 1
    if instance:IsA("Model") then
        counts.models += 1
    elseif instance:IsA("BasePart") then
        counts.parts += 1
    elseif instance:IsA("Attachment") then
        counts.attachments += 1
    elseif instance:IsA("Constraint") then
        counts.constraints += 1
    elseif instance:IsA("JointInstance") then
        counts.joints += 1
    end

    if instance:IsA("BasePart") then
        local assemblyRoot = instance.AssemblyRootPart
        if assemblyRoot ~= nil then
            assemblies[assemblyRoot] = true
        end
    end
end

for _, descendant in root:GetDescendants() do
    inspect(descendant)
end
if root:IsA("BasePart") and root.AssemblyRootPart ~= nil then
    assemblies[root.AssemblyRootPart] = true
end

local assemblyCount = 0
for _ in pairs(assemblies) do
    assemblyCount += 1
end

print(string.format(
    "PhysicsLab counts: instances=%d models=%d parts=%d assemblies=%d attachments=%d constraints=%d joints=%d",
    counts.instances,
    counts.models,
    counts.parts,
    assemblyCount,
    counts.attachments,
    counts.constraints,
    counts.joints
))
```

Capture the snapshot after initial settle, after a production teardown, and after rebuild cycles 1, 5, 10, and 20. Compare only the selected lab root plus production registration/diagnostic metrics; unrelated Studio/plugin/player Instances are noise.

A monotonic increase tied to each teardown/rebuild is a blocker until explained or fixed. A one-time warm-up allocation is not automatically a leak; report measurements instead of guessing.

## Diagnostics / boundedness

Development diagnostics must make WorldEntityId and fidelity inspectable without becoming canonical state or an unbounded history store.

Audit that:

- diagnostics read production state rather than owning a second state copy,
- repeated rebuilds do not accumulate duplicate labels/connections/registrations,
- logs include stable IDs/repro identity where useful,
- diagnostics can be disabled for the normal path,
- no world-sized queue/cache/history is introduced by the lab.

## Multiplayer/server-authority smoke

The first Physics Lab is not a full multiplayer feature, but physical realization and critical shared state must not silently become client authority.

When a two-client local-server Studio run is available:

1. Start one server with two clients.
2. Verify both clients observe the same canonical lab identities/realized structure.
3. Interact with any currently supported shared placeholder only through its production path.
4. Confirm clients do not each create divergent canonical lab recipes or authoritative WorldEntity state.

Do not claim server-authority correctness for mechanics the shell does not yet implement. Record unsupported interaction as UNVERIFIED, not PASS.

## Evidence report template

Use this template in #151/#10 or the integrating PR:

```text
Commit:
Lab recipe/schema version:
Recipe fingerprint / repro key:
Studio version/channel:
OS:
Topology (server + clients):
Flags/diagnostics:

Automated CI: PASS | FAIL (run URL / exact head)
Source contract audit: PASS | FAIL | UNVERIFIED
Deterministic reconstruction: PASS | FAIL | UNVERIFIED
Lifecycle/state survival: PASS | FAIL | UNVERIFIED
Fidelity ownership: PASS | FAIL | UNVERIFIED
MaterialDNA/ObjectGenome boundary: PASS | FAIL | UNVERIFIED
Studio realization matrix: PASS | FAIL | UNVERIFIED
Resource-count/rebuild check: PASS | FAIL | UNVERIFIED
Two-client smoke: PASS | FAIL | UNVERIFIED

Measured counts/repro evidence:
Blockers/findings:
Unverified items:
```

A #151 closeout must contain concrete findings or focused tests against the primary Physics Lab shell. This protocol alone is preparation, not proof that #10 has passed Reality-Grade validation.
