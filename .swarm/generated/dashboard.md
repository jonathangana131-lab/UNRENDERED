# UNRENDERED Swarm Control Plane

Generated: `2026-08-14T12:41:49.439886+00:00`

Canonical main: **GREEN** `472ce18a87847bb2774b7053786f849dda3d6a31`

State digest: `5767dec079961c79577be49fbbda69218dd5959956a31a04ae35d9ce3b2604eb`

## Summary

- ready slots: **15**
- active claims: **0**
- stale claims: **27**
- blocked-external lanes: **1**

## Ready slots

- `SWARM-RECOVERY-EVENT-HISTORY-CONTINUITY/primary` — **Trusted history continuity implementation** — score 11049 — dependencies satisfied; resources available; unblocks 1 downstream lane(s)
- `SWARM-RECOVERY-HEALTH-VALIDATION-FENCE/primary` — **Critical validation-fence repair** — score 11000 — dependencies satisfied; resources available
- `SWARM-V22-THROUGHPUT/primary` — **Implement and prove Swarm V2.2 throughput policy** — score 11000 — dependencies satisfied; resources available
- `HG-BACKFILL-WORLDENTITY/test-adversary` — **WorldEntity adversarial regression author** — score 5420 — dependencies satisfied
- `HG-BACKFILL-WORLDENTITY/audit` — **WorldEntity invariant and aliasing auditor** — score 5320 — dependencies satisfied
- `HG-BACKFILL-DIAGNOSTICS/primary` — **Diagnostics source hardening** — score 5150 — dependencies satisfied; resources available
- `HG-BACKFILL-DIAGNOSTICS/test-adversary` — **Diagnostics lifecycle and no-drift test author** — score 5070 — dependencies satisfied
- `HG-CAPACITY-MINING/mine-worldentity` — **Mine WorldEntity for next concrete depth lane** — score 3680 — dependencies satisfied
- `HG-CAPACITY-MINING/mine-objectgenome` — **Mine ObjectGenome for next concrete depth lane** — score 3670 — dependencies satisfied
- `HG-CAPACITY-MINING/mine-materialdna` — **Mine MaterialDNA for next concrete depth lane** — score 3660 — dependencies satisfied
- `HG-CAPACITY-MINING/mine-fidelity` — **Mine FidelityManager for next concrete depth lane** — score 3650 — dependencies satisfied
- `HG-CAPACITY-MINING/mine-physics-runtime` — **Mine Physics runtime for next concrete depth lane** — score 3640 — dependencies satisfied
- `HG-CAPACITY-MINING/mine-physics-geometry` — **Mine Physics geometry for next concrete depth lane** — score 3630 — dependencies satisfied
- `HG-CAPACITY-MINING/mine-diagnostics` — **Mine diagnostics source for next concrete depth lane** — score 3620 — dependencies satisfied
- `HG-CAPACITY-MINING/mine-authority` — **Mine authority/multiplayer source for next concrete depth lane** — score 3610 — dependencies satisfied

## Active claims

_None._

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
- `SWARM-V16.2-INTEGRATION-THROUGHPUT` — **BLOCKED** — waiting for SWARM-RECOVERY-EVENT-HISTORY-CONTINUITY (READY)

> Generated state is disposable. Atomic claims/resource leases are ownership authority.
