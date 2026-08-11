# UNRENDERED Swarm Control Plane

Generated: `2026-08-11T07:19:28.705492+00:00`

Canonical main: **GREEN** `81a13b1138e26e7852c89685de5dbf9bd57753d8`

State digest: `a7ac1434538591fc2a164469bb84dc3169f1f5c63b40da40ac779f19c3a9a730`

## Summary

- ready slots: **15**
- active claims: **15**
- stale claims: **1**
- blocked-external lanes: **1**

## Ready slots

- `HG-BACKFILL-PHYSICS-GEOMETRY/primary` — **Physics recipe and geometry hardening** — score 5200 — dependencies satisfied; resources available
- `HG-BACKFILL-PHYSICS-GEOMETRY/test-adversary` — **Geometry, clearance, and reachability property tests** — score 5120 — dependencies satisfied
- `HG-BACKFILL-DIAGNOSTICS/test-adversary` — **Diagnostics lifecycle and no-drift test author** — score 5070 — dependencies satisfied
- `HG-BACKFILL-AUTHORITY/test-adversary` — **Canonical agreement and teardown fixture author** — score 5020 — dependencies satisfied
- `HG-BACKFILL-PHYSICS-GEOMETRY/audit` — **Physics recipe realism and validation auditor** — score 5020 — dependencies satisfied
- `HG-BACKFILL-DIAGNOSTICS/audit` — **Diagnostics failure-path and capture-contract auditor** — score 4970 — dependencies satisfied
- `HG-BACKFILL-AUTHORITY/audit` — **Two-client authority and trust-boundary auditor** — score 4920 — dependencies satisfied
- `HG-CAPACITY-MINING/mine-worldentity` — **Mine WorldEntity for next concrete depth lane** — score 3680 — dependencies satisfied
- `HG-CAPACITY-MINING/mine-objectgenome` — **Mine ObjectGenome for next concrete depth lane** — score 3670 — dependencies satisfied
- `HG-CAPACITY-MINING/mine-materialdna` — **Mine MaterialDNA for next concrete depth lane** — score 3660 — dependencies satisfied
- `HG-CAPACITY-MINING/mine-fidelity` — **Mine FidelityManager for next concrete depth lane** — score 3650 — dependencies satisfied
- `HG-CAPACITY-MINING/mine-physics-runtime` — **Mine Physics runtime for next concrete depth lane** — score 3640 — dependencies satisfied
- `HG-CAPACITY-MINING/mine-physics-geometry` — **Mine Physics geometry for next concrete depth lane** — score 3630 — dependencies satisfied
- `HG-CAPACITY-MINING/mine-diagnostics` — **Mine diagnostics source for next concrete depth lane** — score 3620 — dependencies satisfied
- `HG-CAPACITY-MINING/mine-authority` — **Mine authority/multiplayer source for next concrete depth lane** — score 3610 — dependencies satisfied

## Active claims

- `HG-BACKFILL-AUTHORITY/primary` → `sol-20260811-q9x4m2`; lease to `2026-08-11T07:48:01+00:00`
- `HG-BACKFILL-DIAGNOSTICS/primary` → `sol-20260811-q7h4n2`; lease to `2026-08-11T07:59:10+00:00`
- `HG-BACKFILL-FIDELITY/audit` → `sol-20260811-x7n4k2`; lease to `2026-08-11T07:34:30+00:00`
- `HG-BACKFILL-FIDELITY/primary` → `sol-20260811-w3n8k2`; lease to `2026-08-11T07:38:00+00:00`
- `HG-BACKFILL-FIDELITY/test-adversary` → `sol-20260811-30a8e397`; lease to `2026-08-11T07:43:36+00:00`
- `HG-BACKFILL-OBJECTGENOME/audit` → `sol-20260811-went7k3`; lease to `2026-08-11T07:48:00+00:00`
- `HG-BACKFILL-OBJECTGENOME/primary` → `sol-20260811-k2m9x7`; lease to `2026-08-11T07:48:00+00:00`
- `HG-BACKFILL-OBJECTGENOME/test-adversary` → `sol-20260811-q7n4m9`; lease to `2026-08-11T07:20:00+00:00`
- `HG-BACKFILL-REALITY/audit` → `sol-20260811-r4m8z2`; lease to `2026-08-11T07:48:20+00:00`
- `HG-BACKFILL-REALITY/primary` → `sol-20260811-q9m4r2`; lease to `2026-08-11T07:45:06+00:00`
- `HG-BACKFILL-REALITY/test-adversary` → `sol-20260811-q8n4z7`; lease to `2026-08-11T07:42:30+00:00`
- `HG-BACKFILL-WORLDENTITY/audit` → `sol-20260811-z4q8n1`; lease to `2026-08-11T07:50:00+00:00`
- `HG-BACKFILL-WORLDENTITY/primary` → `sol-20260811-ogx9k2`; lease to `2026-08-11T07:47:00+00:00`
- `HG-BACKFILL-WORLDENTITY/test-adversary` → `sol-20260811-w3x7k9`; lease to `2026-08-11T07:48:00+00:00`
- `SWARM-RECOVERY-HEALTH-VALIDATION-FENCE/primary` → `sol-20260811-diaga6r2k`; lease to `2026-08-11T07:47:00+00:00`

## Blocked lanes

- `HERO-DOOR` — **LOCKED** — waiting for HG151-FINAL-AUDIT (READY)
- `OPS-STUDIO-DISPLAY` — **BLOCKED_EXTERNAL** — External Mac GUI/display recovery is required before fresh diagnostics or two-client evidence retries.

> Generated state is disposable. Atomic claims/resource leases are ownership authority.
