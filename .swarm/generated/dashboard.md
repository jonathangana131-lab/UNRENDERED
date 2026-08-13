# UNRENDERED Swarm Control Plane

Generated: `2026-08-13T03:05:43.021890+00:00`

Canonical main: **GREEN** `8c8bf1348856a1f9aafc7665ef81f7abab0772c7`

State digest: `0506689606d4c07f1aa319fb4ba57410a3d388b4712637c5c1000469203b932c`

## Summary

- ready slots: **13**
- active claims: **2**
- stale claims: **11**
- blocked-external lanes: **1**

## Ready slots

- `SWARM-RECOVERY-EVENT-IDENTITY-COMPAT/repair` — **Critical exact-identity compatibility repair** — score 11000 — dependencies satisfied
- `HG-BACKFILL-WORLDENTITY/test-adversary` — **WorldEntity adversarial regression author** — score 5420 — dependencies satisfied
- `HG-PHYSICS-RUNTIME-ENTITYID-FENCE/audit` — **Independent runtime entity-ID boundary audit** — score 5095 — dependencies satisfied
- `HG-BACKFILL-DIAGNOSTICS/test-adversary` — **Diagnostics lifecycle and no-drift test author** — score 5070 — dependencies satisfied
- `HG-BACKFILL-DIAGNOSTICS/audit` — **Diagnostics failure-path and capture-contract auditor** — score 4970 — dependencies satisfied
- `HG-CAPACITY-MINING/mine-worldentity` — **Mine WorldEntity for next concrete depth lane** — score 3680 — dependencies satisfied
- `HG-CAPACITY-MINING/mine-objectgenome` — **Mine ObjectGenome for next concrete depth lane** — score 3670 — dependencies satisfied
- `HG-CAPACITY-MINING/mine-materialdna` — **Mine MaterialDNA for next concrete depth lane** — score 3660 — dependencies satisfied
- `HG-CAPACITY-MINING/mine-fidelity` — **Mine FidelityManager for next concrete depth lane** — score 3650 — dependencies satisfied
- `HG-CAPACITY-MINING/mine-physics-runtime` — **Mine Physics runtime for next concrete depth lane** — score 3640 — dependencies satisfied
- `HG-CAPACITY-MINING/mine-physics-geometry` — **Mine Physics geometry for next concrete depth lane** — score 3630 — dependencies satisfied
- `HG-CAPACITY-MINING/mine-diagnostics` — **Mine diagnostics source for next concrete depth lane** — score 3620 — dependencies satisfied
- `HG-CAPACITY-MINING/mine-authority` — **Mine authority/multiplayer source for next concrete depth lane** — score 3610 — dependencies satisfied

## Active claims

- `SWARM-RECOVERY-WORKER-STATUS-CONTRACT/primary` → `sol-20260812-v16g4r9x`; lease to `2026-08-13T03:08:00+00:00`
- `SWARM-RECOVERY-WORKER-STATUS-CONTRACT/reviewer-1` → `sol-20260812-rvw16g4a`; lease to `2026-08-13T03:08:00+00:00`

## Blocked lanes

- `HERO-DOOR` — **LOCKED** — waiting for HG151-FINAL-AUDIT (READY)
- `HG-AUTHORITY-HARNESS-LIFECYCLE-CAPABILITY` — **BLOCKED** — dependencies satisfied
- `HG-BACKFILL-AUTHORITY` — **BLOCKED** — dependencies satisfied
- `HG-BACKFILL-DIAGNOSTICS-INSTANCE-BINDING` — **BLOCKED** — dependencies satisfied
- `HG-BACKFILL-FIDELITY` — **BLOCKED** — dependencies satisfied
- `HG-BACKFILL-MATERIALDNA-COUNTERS` — **BLOCKED** — dependencies satisfied
- `HG-BACKFILL-OBJECTGENOME` — **BLOCKED** — dependencies satisfied
- `HG-BACKFILL-PHYSICS-GEOMETRY` — **BLOCKED** — dependencies satisfied
- `HG-BACKFILL-PHYSICS-RUNTIME-RECIPE-FENCE` — **BLOCKED** — dependencies satisfied
- `HG-BACKFILL-PHYSICS-RUNTIME-TRANSITION-FENCE` — **BLOCKED** — dependencies satisfied
- `HG-BACKFILL-REALITY` — **BLOCKED** — dependencies satisfied
- `HG-COMPLETION-AUTHORITY` — **BLOCKED** — dependencies satisfied
- `HG-COMPLETION-CONTENT` — **BLOCKED** — dependencies satisfied
- `HG-COMPLETION-PHYSICS` — **BLOCKED** — dependencies satisfied
- `HG-COMPLETION-REALITY` — **BLOCKED** — dependencies satisfied
- `HG-FIDELITY-REGISTRATION-CAPACITY-CEILING` — **BLOCKED** — dependencies satisfied
- `HG-MATERIALDNA-REPAIRCOUNT-BOUND` — **SUPERSEDED** — dependencies satisfied
- `HG-ONESHOT-PHYSICS-CART-GEOMETRY` — **SUPERSEDED** — dependencies satisfied
- `HG-PHYSICS-CART-GEOMETRY` — **BLOCKED** — dependencies satisfied
- `HG-PHYSICS-CART-SHELF-FRAME` — **BLOCKED** — waiting for HG-PHYSICS-CART-GEOMETRY (BLOCKED)
- `HG-PHYSICS-CHAIR-GEOMETRY` — **BLOCKED** — dependencies satisfied
- `HG-PHYSICS-RUNTIME-SYNTHESIS` — **BLOCKED** — dependencies satisfied
- `OPS-STUDIO-DISPLAY` — **BLOCKED_EXTERNAL** — External Mac GUI/display recovery is required before fresh diagnostics or two-client evidence retries.
- `SWARM-RECOVERY-EVENT-HISTORY-CONTINUITY` — **BLOCKED** — waiting for SWARM-RECOVERY-WORKER-STATUS-CONTRACT (REVIEW)

> Generated state is disposable. Atomic claims/resource leases are ownership authority.
