# Production Physics Lab

Issue: #10

The Physics Lab is the permanent Hero-Gate experience harness for physical systems. It is deliberately small. It uses production identity/material/object/fidelity contracts and a narrow Roblox realization adapter; it is not a second world model or a manually authored canonical Workspace.

## Contract boundary

`src/shared/Physics/PhysicsLabRecipe.luau` is the deterministic plain-data source for the lab shell. It owns the lab recipe/version, stable WorldId/RegionId, WorldEntity records, transforms, production MaterialDNA references, fidelity targets, and optional landed ObjectGenome identity bindings.

`src/server/PhysicsLab/PhysicsLabRealizer.luau` is the Roblox adapter. It consumes the recipe and creates temporary physical representation under `Workspace/UNRENDERED_PhysicsLab`. Workspace attributes are development diagnostics only; deleting the folder does not delete canonical lab truth. Re-running realization reconstructs it from the recipe.

The server bootstrap realizes the lab only in Studio. A published/live server does not automatically spawn this development harness.

## Current lab content

The deterministic shell contains:

- carpeted floor, ceiling, and split walls with a real door opening;
- a physical hinged-panel door proxy;
- chair and table proxies bound to the landed production ObjectGenome fixture identities and their default ObjectState snapshots;
- a filing-cabinet proxy bound to the landed ObjectGenome fixture identity plus a prismatic drawer mechanism placeholder;
- a dynamic rolling-cart mass proxy;
- four actual stair steps;
- a wedge ramp and raised ledge;
- a physical-character spawn anchor for later body work.

Primitive geometry is intentional at this gate. The door/cart mechanism proxies are WorldEntities with production material/fidelity identity, but they are **not** new permanent ObjectGenome families. Reality-Grade door/chair/cart construction belongs in their later explicitly unlocked work, not in this lab bootstrap.

## Studio repro

1. Install the Rokit-pinned toolchain with `rokit install --no-trust-check`.
2. Start Rojo with `rojo serve default.project.json` (configured port: 34872).
3. Open a Roblox Studio place and connect the Rojo plugin to the project.
4. Press **Play** so the server bootstrap runs.
5. Inspect `Workspace/UNRENDERED_PhysicsLab`.
6. In Studio, each realized entity gets a visible diagnostic billboard and attributes including `WorldEntityId`, `WorldId`, `RegionId`, `Fidelity`, `RecipeKey`, exact material recipe id/revision, and `ObjectGenomeId` where one exists.
7. Stop and Play again. The same recipe keys and WorldEntityIds should be reconstructed; Workspace itself is not read back as truth.

Useful interaction checks in Studio:

- push the unanchored chair/table/cart proxies and confirm they are actual physics bodies;
- push the door panel and confirm the hinge constrains it to the frame anchor and limits travel;
- pull/push the filing-cabinet drawer proxy and confirm the prismatic constraint retains it on its slide axis;
- walk the four steps, wedge ramp, and ledge to expose contact/controller problems once the physical-character work is unlocked.

## Automated evidence

`tests/physics_lab_recipe.luau` is headless and verifies that repeated recipe builds produce the same ordered keys/IDs/transforms, every entity passes WorldEntity/FidelityManager boundaries, material references pass MaterialDNA, chair/table/cabinet use the landed ObjectGenome identities, all required lab roles exist, and nested resolved data is immutable.

CI additionally runs format/lint/Luau analysis, architecture/randomness audits, the complete pure-Luau suite, and a Rojo build. CI cannot replace Studio physics/contact/constraint inspection; record Studio evidence separately when that environment is available.
