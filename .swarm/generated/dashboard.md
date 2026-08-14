# UNRENDERED Swarm Control Plane

Generated: `2026-08-14T13:22:28.227074+00:00`

Canonical main: **RED** `3b616ff74483bfad7370ab4d98402bc6d7e9d8a4`

State digest: `e0c21e1d9401dd84129e39ef9ade59a205a66808587be3cab400c3b3c4739708`

## Summary

- ready slots: **5**
- active claims: **0**
- stale claims: **27**
- blocked-external lanes: **1**

## Ready slots

- `SWARM-RECOVERY-EVENT-HISTORY-CONTINUITY/primary` — **Trusted history continuity implementation** — score 11049 — dependencies satisfied; resources available; unblocks 1 downstream lane(s)
- `OPS-MAIN-HEALTH/primary` — **Red-main repair implementer** — score 11000 — dependencies satisfied; resources available
- `SWARM-RECOVERY-HEALTH-VALIDATION-FENCE/primary` — **Critical validation-fence repair** — score 11000 — dependencies satisfied; resources available
- `SWARM-V22-THROUGHPUT/primary` — **Implement and prove Swarm V2.2 throughput policy** — score 11000 — dependencies satisfied; resources available
- `OPS-MAIN-HEALTH/tests-1` — **Red-main diagnosis/regression** — score 10700 — dependencies satisfied

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
