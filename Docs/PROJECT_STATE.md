# Project State

Current phase: **Phase 0 foundation, entering Phase 1**

Bootstrap status:
- PR #1 is merged to `main`.
- Its final PR validation passed tool installation, Rojo sourcemap, StyLua, Selene, Roblox Luau analysis, pure deterministic tests, Rojo build, and artifact upload.
- Every worker must inspect the latest `main` Actions status before feature work. If main is failing, restoring it is the first priority.

Current P0:
1. Keep `main` reproducibly green.
2. Lock deterministic IDs, scoped RNG, and generation-version contracts with golden tests.
3. Define WorldEntity identity and the F0-F4 representation lifecycle.
4. Expand MaterialDNA and ObjectGenome into production contracts.
5. Establish the production Physics Lab shell without throwaway frameworks.
6. Establish deterministic regression and seed-repro tooling.

Known external setup gaps:
- No published Roblox universe/place is connected to automated publishing yet.
- Studio engine tests, graphics validation, server-authority tests, and device profiling still require a Roblox Studio/test-place workflow. Current GitHub CI validates source, pure Luau logic, deterministic contracts, and Rojo builds.
- Approved production PBR, audio, and model libraries do not exist yet; use project-owned fallback references and do not add unlicensed content.

Architecture migrations: none.

Generation versions:
- reality: 1
- topology: 1
- material: 1
- object: 1
- entity: 1
- persistence: 1

Next critical outcomes:
- deterministic core golden contract is locked.
- WorldEntity can promote and demote representations without losing identity/state.
- Physics Lab uses production IDs/contracts.
- a resolved region recipe can unload and recreate identically.
- first believable MaterialDNA surface families exist.
- first construction-grammar furniture family exists.

Keep this file concise. Git history is the changelog.
