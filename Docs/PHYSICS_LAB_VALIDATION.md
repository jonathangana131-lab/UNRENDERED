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
- conceptual WorldId and resolved RegionId,
- resolved-region schema version and world-seed provenance reference,
- exact resolved-region fingerprint and deterministic repro key,
- Roblox Studio version/channel,
- OS,
- server/client topology used by the test,
- development diagnostics enabled/disabled state,
- any non-default flags relevant to realization or fidelity.

The realized lab root exposes the resolved-region schema version, world-seed provenance reference, fingerprint, and repro key, and the source-owned validation collector records them in every snapshot. If any required identity field is missing, `PhysicsLabValidation.capture()` / `captureFull()` fails rather than accepting a screenshot or place-file timestamp as a substitute.

Before/after comparisons also reject snapshots with different lab/resolved schema, recipe, WorldId, RegionId, world-seed provenance, fingerprint, or repro identity. Never compare measurements from different canonical lab truth as if they were one lifecycle run.

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

For executable server-Command-Bar lifecycle, teardown/rebuild, snapshot, and recovery procedures, use `Docs/PHYSICS_LAB_STUDIO_RUNBOOK.md`. That runbook drives the landed Studio/server-only `PhysicsLabStudioHarness` and its representation-safe `RealizedLab` handle; it does not expose the raw runtime or create a second lifecycle system.

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

Every procedural failure report must include the deterministic repro key exposed on the lab root and captured by the validation artifact.

## Representation lifecycle / state survival

The lab must prove that Roblox representation is disposable while WorldEntity identity and meaningful state remain authoritative outside the Instance tree.

For at least one structural entity and one interactive ObjectGenome-backed placeholder:

1. Record WorldEntityId, authoritative fidelity, persistent mutable state, and physical root.
2. Demote/teardown through the production lifecycle boundary. Do not call `Destroy()` as a substitute for the project's demotion/state-capture path.
3. Verify the old physical representation is gone and there is no duplicate live representation for the same WorldEntityId.
4. Promote/re-realize through the production lifecycle boundary.
5. Verify the same WorldEntityId returns and captured meaningful mutable state is preserved according to the landed WorldEntity/ObjectGenome contract.
6. Repeat the lifecycle cycle 20 times while recording the source-owned validation snapshots described below.

Pass conditions:

- identity never changes because an Instance was destroyed/recreated,
- demotion cannot silently discard required state,
- promotion does not register duplicate WorldEntityIds,
- repeated cycles return to a stable full-lab physical envelope instead of monotonically leaking descendants/constraints/registrations.

**Current Studio access:** #210 landed `PhysicsLabStudioHarness`, a Studio/server-only owner of the existing representation-safe `RealizedLab` handle. Use `Harness.get()` for entity lifecycle checks and `Harness.stop()/start()/restart()` for whole-lab teardown/rebuild exactly as documented in `Docs/PHYSICS_LAB_STUDIO_RUNBOOK.md`. Do not require the raw `PhysicsLabRuntime`, mutate Instance attributes as authority, manually delete representations, or invent a second validation lifecycle. The procedures remain **UNVERIFIED** until somebody actually runs them in Studio and records the observations.

## Fidelity ownership

For each lab entity, prove the displayed/diagnosed fidelity is the authoritative WorldEntity fidelity coordinated through the production Fidelity Manager, not a local Physics Lab enum or Instance attribute that becomes a second truth source.

Exercise at least one promotion and one demotion through the source-owned `PhysicsLabStudioHarness`/`RealizedLab` path. Capture:

- WorldEntityId,
- authoritative fidelity before/after,
- Fidelity Manager requested target/reason when exposed by existing diagnostics,
- whether state capture was required,
- representation before/after.

A local lab-only fidelity state machine is an architecture failure even if the visual transition looks correct. A harness-driven transition is still UNVERIFIED until it is actually run and observed in Studio; do not promote source inspection or CI expectations to PASS.

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
| door placeholder | F2 anchored proxy matches the authored ObjectGenome construction; no detached/exploding representation on start | UNVERIFIED |
| chair placeholder | realizes as the intended ObjectGenome placeholder with stable identity; no spontaneous instability | UNVERIFIED |
| table placeholder | stable support/contact and canonical identity | UNVERIFIED |
| rolling cart placeholder | realizes with intended F2 proxy construction without orphaned pieces | UNVERIFIED |
| cabinet/drawer placeholder | authored F2 proxy realizes without malformed component state | UNVERIFIED |
| stairs | traversable collision geometry at expected SI→stud scale | UNVERIFIED |
| ramp | traversable collision geometry at expected SI→stud scale | UNVERIFIED |
| ledge | collision/edge geometry exists and is usable for later body tests | UNVERIFIED |
| spawn anchor | present as production-identified lab content; does not introduce a parallel character controller | UNVERIFIED |
| teardown/rebuild | production teardown removes old representation; rebuild restores same IDs without duplicates | UNVERIFIED |
| diagnostics off | release/default path does not create unbounded development labels/log spam | UNVERIFIED |
| diagnostics on | WorldEntityId, fidelity, authoritative `stateRevision` / `representationRevision`, resolved fingerprint, and repro key are inspectable | UNVERIFIED |

Do not describe the current F2 anchored door/cart/cabinet proxies as validated hinges, casters, or drawers. F3/F4 mechanism behavior requires actual articulated realization plus Studio evidence.

Record visible physics failures with the exact entity ID and resolved-region repro identity. Screenshots/video may support the observation but do not replace the textual repro.

## Source-owned lab snapshot / resource deltas

Resource counts are evidence, not budgets. Do not invent a permanent “allowed count” from this first shell.

The canonical collector is `src/server/PhysicsLab/PhysicsLabValidation.luau`; do **not** maintain a second hand-written counting script in the Command Bar. It scopes traversal to one owned lab root, records exact canonical evidence identity, rejects noncanonical direct representations, counts total Instances/Models/BaseParts/unique assemblies/Attachments/Constraints/JointInstances, and computes the world-space BasePart envelope using all eight transformed corners per part. Returned snapshots are plain/frozen data and retain no Instance references.

In a **server-context** Studio Command Bar on the exact Rojo-synced build, capture an initial complete-F2 snapshot with:

```luau
local HttpService = game:GetService("HttpService")
local ServerScriptService = game:GetService("ServerScriptService")
local Validation = require(
    ServerScriptService.UNRENDERED_Server.PhysicsLab.PhysicsLabValidation
)
local root = workspace:WaitForChild("UNRENDERED_PhysicsLab")
local snapshot = Validation.captureFull(root)
print(HttpService:JSONEncode(snapshot))
```

Use `captureFull()` whenever the lab is expected to contain the complete canonical F2 representation set. It fails if any canonical representation is missing and rejects any present representation whose stable identity or canonical recipe/material/object metadata is wrong. Reserve `capture()` for intentional partial F0/F2 lifecycle evidence, where canonical F0 entities are expected to be absent from the Instance tree; every representation that is present is still validated fail-closed.

Store the emitted JSON verbatim with the evidence bundle. It includes:

- lab root name and lab/resolved schema/recipe identity,
- WorldId and resolved RegionId,
- world-seed provenance reference,
- resolved-region fingerprint and deterministic repro key,
- total scoped resource counts,
- full-lab world-space BasePart envelope.

Using the landed source-owned Studio harness, capture complete snapshots after initial settle, after a complete rebuild, and after rebuild cycles 1, 5, 10, and 20 with `captureFull()`. A partially demoted lab is intentionally a different physical representation, so use `capture()` for that partial evidence and record its count delta, but do not apply the **full-lab envelope** assertion until the complete F2 lab has been rebuilt. The exact harness/rebuild command blocks live in `Docs/PHYSICS_LAB_STUDIO_RUNBOOK.md`.

To compare two stored snapshots in a server-context Command Bar, paste their JSON strings into this source-owned comparison path:

```luau
local HttpService = game:GetService("HttpService")
local ServerScriptService = game:GetService("ServerScriptService")
local Validation = require(
    ServerScriptService.UNRENDERED_Server.PhysicsLab.PhysicsLabValidation
)

local baseline = HttpService:JSONDecode([[PASTE_BASELINE_JSON_HERE]])
local checkpoint = HttpService:JSONDecode([[PASTE_CHECKPOINT_JSON_HERE]])
local comparison = Validation.compare(baseline, checkpoint, 0.001)
print(HttpService:JSONEncode(comparison))
Validation.assertFullLabEnvelope(baseline, checkpoint, 0.001)
```

The comparison fails closed if the snapshots describe different canonical lab truth. The signed count delta is measurement only; `assertFullLabEnvelope` is specifically the complete-rebuild envelope check. Keep the explicit tolerance in the evidence report rather than silently changing it until project policy establishes a measured tolerance.

A monotonic resource increase tied to each complete teardown/rebuild is a blocker until explained or fixed. A one-time warm-up allocation is not automatically a leak; report measurements instead of guessing.

## Diagnostics / boundedness

Development diagnostics must make WorldEntityId, fidelity, authoritative `stateRevision` / `representationRevision`, and repro identity inspectable without becoming canonical state or an unbounded history store.

Audit that:

- diagnostics read production state rather than owning a second state copy,
- repeated rebuilds do not accumulate duplicate labels/connections/registrations,
- logs/evidence include stable IDs and exact repro identity,
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
WorldId / RegionId:
Resolved fingerprint / repro key:
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

Baseline snapshot JSON:
Checkpoint snapshot JSON / signed resource delta:
Full-lab envelope tolerance + result:
Blockers/findings:
Unverified items:
```

A #151 closeout must contain concrete findings or focused tests against the primary Physics Lab shell. This protocol and its source-owned collector/harness are preparation, not proof that #10 has passed Reality-Grade validation.
