# UNRENDERED Swarm Control Plane

Generated: `2026-08-14T07:33:54.593466+00:00`

Canonical main: **GREEN** `bc7e667b5bd13b37cc534a3ac2ea78cb4dcb6170`

State digest: `c86b2363da0e8af163e0de27201bd906935cb6bc21c4801b42a0cd8c8bfacf8f`

## Summary

- ready slots: **9**
- active claims: **5**
- stale claims: **11**
- blocked-external lanes: **1**

## Ready slots

- `HG-BACKFILL-WORLDENTITY/primary` — **WorldEntity source hardening** — score 5500 — dependencies satisfied; resources available
- `HG-BACKFILL-WORLDENTITY/test-adversary` — **WorldEntity adversarial regression author** — score 5420 — dependencies satisfied
- `HG-CAPACITY-MINING/mine-worldentity` — **Mine WorldEntity for next concrete depth lane** — score 3680 — dependencies satisfied
- `HG-CAPACITY-MINING/mine-objectgenome` — **Mine ObjectGenome for next concrete depth lane** — score 3670 — dependencies satisfied
- `HG-CAPACITY-MINING/mine-materialdna` — **Mine MaterialDNA for next concrete depth lane** — score 3660 — dependencies satisfied
- `HG-CAPACITY-MINING/mine-fidelity` — **Mine FidelityManager for next concrete depth lane** — score 3650 — dependencies satisfied
- `HG-CAPACITY-MINING/mine-physics-geometry` — **Mine Physics geometry for next concrete depth lane** — score 3630 — dependencies satisfied
- `HG-CAPACITY-MINING/mine-diagnostics` — **Mine diagnostics source for next concrete depth lane** — score 3620 — dependencies satisfied
- `HG-CAPACITY-MINING/mine-authority` — **Mine authority/multiplayer source for next concrete depth lane** — score 3610 — dependencies satisfied

## Active claims

- `HG-BACKFILL-DIAGNOSTICS/audit` → `sol-20260814-y7q3m5v8`; lease to `2026-08-14T08:01:40+00:00`
- `HG-BACKFILL-DIAGNOSTICS/primary` → `sol-20260814-t5n8q3v6`; lease to `2026-08-14T08:00:30+00:00`
- `HG-BACKFILL-DIAGNOSTICS/test-adversary` → `sol-20260814-v4q7m2c9`; lease to `2026-08-14T08:03:00+00:00`
- `HG-CAPACITY-MINING/mine-physics-runtime` → `sol-20260814-x4m9p2c7`; lease to `2026-08-14T07:52:30+00:00`
- `SWARM-RECOVERY-WORKER-STATUS-CONTRACT/primary` → `sol-20260814-r6h3n9v2`; lease to `2026-08-14T08:01:00+00:00`

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
- `HG-PHYSICS-RUNTIME-ENTITYID-FENCE` — **SUPERSEDED** — dependencies satisfied
- `HG-PHYSICS-RUNTIME-SYNTHESIS` — **BLOCKED** — dependencies satisfied
- `OPS-STUDIO-DISPLAY` — **BLOCKED_EXTERNAL** — External Mac GUI/display recovery is required before fresh diagnostics or two-client evidence retries.
- `SWARM-RECOVERY-EVENT-HISTORY-CONTINUITY` — **BLOCKED** — waiting for SWARM-RECOVERY-WORKER-STATUS-CONTRACT (NEEDS_CHANGES)

> Generated state is disposable. Atomic claims/resource leases are ownership authority.
