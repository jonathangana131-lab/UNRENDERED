# Project State

Current phase: **Phase 0 — production foundation**

Last known green main commit: initial repository commit; bootstrap branch pending CI.

Current P0:
1. Land the Roblox/Rojo production foundation and green CI.
2. Prove deterministic core IDs / scoped RNG / generation version contracts.
3. Establish the production Physics Lab shell without throwaway frameworks.
4. Establish MaterialDNA and WorldEntity contracts.
5. Establish test harnesses that future generators can reproduce by seed.

Known blockers:
- No published Roblox universe/place is connected to automated publishing yet.
- Real Studio engine tests, graphics validation, server-authority tests, and device profiling require a Roblox Studio/test-place workflow; CI currently validates source, pure Luau logic, and Rojo builds only.

Architecture migrations: none.

Generation versions:
- reality: 1
- topology: 1
- material: 1
- object: 1
- entity: 1
- persistence: 1

Next critical outcomes:
- CI green on `main`.
- Physics Lab uses production IDs/contracts.
- deterministic region recipe can unload/recreate identically.
- first believable MaterialDNA surface family.
- first construction-grammar furniture family.

Keep this file concise. Git history is the changelog.
