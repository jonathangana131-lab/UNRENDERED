# Production Physics Lab

Issue #10 is the permanent Roblox realization bay for proving UNRENDERED domain contracts against physical representation. It is not a disposable demo and it is not canonical world storage.

## Architecture boundary

`src/shared/PhysicsLab/PhysicsLabRecipe.luau` is the deterministic source recipe. It owns stable semantic item keys, WorldEntity records, initial fidelity, plain transforms/dimensions, MaterialDNA references, and ObjectGenome bindings for the existing office chair/table/filing-cabinet fixtures.

`src/server/PhysicsLab/PhysicsLabRealizer.luau` is the Roblox-only adapter. It converts the recipe into Workspace Instances and fallback Roblox materials. Destroying the generated Model does not destroy canonical lab identity; rerunning realization reconstructs the same recipe and WorldEntity IDs.

`src/server/PhysicsLab/PhysicsLabRuntime.luau` registers every lab entity through the production WorldEntity registry and FidelityManager before realization. Development attributes on the root Model and realized Instances expose IDs, roles, recipe keys, material references, ObjectGenome identity/fingerprint, and F0-F4 counts.

The lab scale contract is `0.28 meters/stud`. That conversion belongs to the lab recipe and is explicit rather than inferred from Instance dimensions.

## Current shell

The deterministic shell contains:

- enclosed floor/wall/ceiling test bay with an ordinary door opening,
- actual HingeConstraint door probe,
- production ObjectGenome office chair, office table, and filing cabinet realizations,
- filing-cabinet slide constraints derived from its existing ObjectGenome mechanism specs,
- four-wheel HingeConstraint rolling-cart probe,
- ramp, four-step stair block, and raised ledge,
- physical-character SpawnLocation anchor.

The door and cart are deliberately lab mechanism probes, not final hero object contracts. The chair/table/cabinet use the landed ObjectGenome contract. Primitive fallback colors/materials are diagnostic placeholders only; they are not Reality-Grade visual signoff and do not introduce asset IDs into domain data.

## Studio repro

1. Install the pinned toolchain with `rokit install --no-trust-check`.
2. Run `rojo serve default.project.json` and connect Roblox Studio to the project.
3. Start a local server/play session. Studio enables the Physics Lab automatically.
4. Inspect `Workspace.UNRENDERED_PhysicsLab`.
5. Verify the root attributes include `UNRENDERED_WorldId`, `UNRENDERED_RegionId`, `UNRENDERED_RecipeVersion`, `UNRENDERED_EntityCount`, and F0-F4 counts.
6. Inspect any realized part/model and verify `UNRENDERED_WorldEntityId`, `UNRENDERED_Fidelity`, `UNRENDERED_RecipeKey`, and `UNRENDERED_Role` are present.
7. Push the door panel and confirm it remains hinge-constrained to the frame within its limits.
8. Push the rolling cart and confirm its four wheels are hinge-constrained rather than welded to the chassis.
9. Inspect the filing cabinet and confirm its drawer PrismaticConstraints exist and carry the ObjectGenome mechanism keys.
10. Destroy `Workspace.UNRENDERED_PhysicsLab`, stop, and run again; the same semantic items must return with the same WorldEntity IDs.

For an intentional non-Studio test server, set the Workspace attribute `UNRENDERED_EnablePhysicsLab` to `true` before server bootstrap. The lab is otherwise not automatically injected into non-Studio runtime.

## Automated validation

The pure suite includes `tests/physics_lab_recipe.luau`, which checks deterministic ordering/IDs, required shell content, WorldEntity origin binding, MaterialDNA references, ObjectGenome validity, recipe fingerprints, and default mutable object state without Roblox Studio.

The repository CI remains the acceptance path:

- Rojo sourcemap,
- StyLua check,
- Selene,
- Roblox Luau analysis,
- canonical-randomness audit,
- shared-domain boundary audit,
- `lune run tests/run`,
- `rojo build default.project.json --output build/UNRENDERED.rbxlx`.

Studio physics behavior still requires the manual repro above because current GitHub CI does not run the Roblox engine.
