# Production Physics Lab

The Physics Lab is a permanent development experience for exercising UNRENDERED production contracts before the main world grows. It is not a disposable showcase place and it is not a separate gameplay framework.

## Contract boundary

`src/shared/Physics/PhysicsLabRecipe.luau` is the deterministic, headless lab recipe. It owns stable lab/world/entity identity, semantic material references, ObjectGenome references, placement data and initial WorldEntity state. It contains no Roblox Instances.

`src/server/PhysicsLab/PhysicsLabRealizer.luau` is a Roblox representation adapter. In Studio it realizes the recipe into `Workspace/UNRENDERED_PhysicsLab`, registers every entity with the landed WorldEntity registry and FidelityManager, and exposes development diagnostics as attributes.

Workspace remains representation only. Destroying the realized model does not destroy or redefine the recipe/identity contract.

## Current v1 shell

The deterministic bay contains:

- carpeted floor, ceiling and perimeter walls with a real door opening;
- four-step contact staircase, incline ramp and raised ledge;
- physical-character test spawn anchor;
- the landed office-chair, office-table and filing-cabinet ObjectGenome fixtures;
- a lab commercial-door ObjectGenome with a canonical hinge mechanism;
- a lab two-shelf rolling-cart ObjectGenome with four canonical caster mechanisms.

The first Roblox representation is deliberately `F2-anchored-proxy`. Object components are materialized at real ObjectGenome dimensions and carry their stable entity/component/material metadata, but they are anchored. This prevents an unreviewed pile of unstable constraints from being normalized as the production physics implementation. F3/F4 promotion work should replace that representation through the same entity/genome/state contracts.

## Studio repro

1. Install the pinned tools from `rokit.toml` and run the normal Rojo workflow for `default.project.json`.
2. Open the synced place in Roblox Studio and start a server/play session.
3. Confirm `Workspace/UNRENDERED_PhysicsLab` exists. The server bootstrap only realizes the lab when `RunService:IsStudio()` is true.
4. Inspect the lab model attributes:
   - `UNRENDERED_LabRecipeKey` should be `physics-lab.hero-gate.v1`.
   - `UNRENDERED_EntityCount` should be `20`.
   - all initial fidelity should be represented by `UNRENDERED_FidelityF2 = 20` with F0/F1/F3/F4 at zero.
5. Inspect `door-main`, `chair-a`, `table-a`, `cabinet-a`, and `cart-a`. Each Model should expose `UNRENDERED_WorldEntityId`, `UNRENDERED_ObjectGenomeId`, `UNRENDERED_ObjectRecipeFingerprint`, and `UNRENDERED_RepresentationClass = F2-anchored-proxy`.
6. Inspect component Parts. They should expose `UNRENDERED_ComponentKey`, `UNRENDERED_ComponentRole`, `UNRENDERED_ComponentMassKg`, and `UNRENDERED_MaterialKey`.
7. Stop/start Studio again and confirm the same recipe/entity IDs recur. The realizer owns only a model marked `UNRENDERED_PhysicsLabOwned`; it refuses to delete an unrelated Instance that merely has the same name.

## Automated evidence

`tests/physics_lab_recipe.luau` stays headless and verifies:

- stable world/region/entity IDs and deterministic entity order;
- the complete required bay/object key set;
- duplicate identity detection through WorldEntity;
- exact MaterialDNA reference acceptance for structural primitives;
- valid ObjectGenome recipes, recipe fingerprints and default mutable state;
- explicit initial F2 fidelity.

The normal repository CI remains the acceptance path for format, lint, strict Luau analysis, canonical-randomness/domain audits, pure tests and Rojo build.

## Next Reality-Grade work inside #10

Do not replace this shell. Deepen it in place:

- add a measured F3/F4 representation/promotion adapter for movable bodies and mechanisms;
- implement the door hinge, cabinet slides/latch and cart/chair caster physics with state capture on demotion;
- add Studio evidence for masses, collision stability, contact behavior and repeated promotion/demotion;
- add performance/rigidbody/constraint diagnostics;
- add physical-player test spawn/actuation only through the later physical-character contract.

Fallback primitive materials are adapter-owned and intentionally unlicensed/asset-free. Approved PBR families can replace them later without changing MaterialDNA or lab recipe identity.
