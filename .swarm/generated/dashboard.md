# UNRENDERED Swarm Control Plane

Generated: `2026-08-14T07:57:27.753156+00:00`

Canonical main: **RED** `af6a17aa7969d40e8b19f7e9d19fe93cc9b1d9a9`

State digest: `e52f8e13dda8aa5857e3c3ab1e23a3f6fe15600102d1428481ec0dacf47422d2`

## Summary

- ready slots: **2**
- active claims: **3**
- stale claims: **13**
- blocked-external lanes: **1**

## Ready slots

- `OPS-MAIN-HEALTH/primary` — **Red-main repair implementer** — score 11000 — dependencies satisfied; resources available
- `OPS-MAIN-HEALTH/tests-1` — **Red-main diagnosis/regression** — score 10700 — dependencies satisfied

## Active claims

- `HG-BACKFILL-DIAGNOSTICS/audit` → `sol-20260814-r6h3n9v2`; lease to `2026-08-14T07:58:00+00:00`
- `HG-BACKFILL-DIAGNOSTICS/primary` → `sol-20260814-t5n8q3v6`; lease to `2026-08-14T08:00:30+00:00`
- `SWARM-RECOVERY-EVENT-HISTORY-CONTINUITY/primary` → `sol-20260814-q5n8v2c4`; lease to `2026-08-14T08:20:00+00:00`

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

> Generated state is disposable. Atomic claims/resource leases are ownership authority.
