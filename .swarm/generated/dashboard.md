# UNRENDERED Swarm Control Plane

Generated: `2026-08-11T07:03:50.125267+00:00`

Canonical main: **GREEN** `7de385295dd17112226dd4cd173bd707178e17bc`

State digest: `a091bdb7e06a3cab4c177cc3830184080c5d947d24fcde6119c95cd9129ca1fb`

## Summary

- ready slots: **18**
- active claims: **15**
- stale claims: **0**
- blocked-external lanes: **1**

## Ready slots

- `HG-BACKFILL-OBJECTGENOME/primary` — **ObjectGenome source hardening** — score 5450 — dependencies satisfied; resources available
- `HG-BACKFILL-MATERIALDNA/test-adversary` — **MaterialDNA schema and hostile-input tests** — score 5320 — dependencies satisfied
- `HG-BACKFILL-WORLDENTITY/audit` — **WorldEntity invariant and aliasing auditor** — score 5320 — dependencies satisfied
- `HG-BACKFILL-OBJECTGENOME/audit` — **ObjectGenome contract and ownership auditor** — score 5270 — dependencies satisfied
- `HG-BACKFILL-MATERIALDNA/audit` — **MaterialDNA contract and fixture auditor** — score 5220 — dependencies satisfied
- `HG-BACKFILL-DIAGNOSTICS/primary` — **Diagnostics source hardening** — score 5150 — dependencies satisfied; resources available
- `HG-BACKFILL-PHYSICS-GEOMETRY/test-adversary` — **Geometry, clearance, and reachability property tests** — score 5120 — dependencies satisfied
- `HG-BACKFILL-DIAGNOSTICS/test-adversary` — **Diagnostics lifecycle and no-drift test author** — score 5070 — dependencies satisfied
- `HG-BACKFILL-AUTHORITY/test-adversary` — **Canonical agreement and teardown fixture author** — score 5020 — dependencies satisfied
- `HG-BACKFILL-PHYSICS-GEOMETRY/audit` — **Physics recipe realism and validation auditor** — score 5020 — dependencies satisfied
- `HG-CAPACITY-MINING/mine-worldentity` — **Mine WorldEntity for next concrete depth lane** — score 3680 — dependencies satisfied
- `HG-CAPACITY-MINING/mine-objectgenome` — **Mine ObjectGenome for next concrete depth lane** — score 3670 — dependencies satisfied
- `HG-CAPACITY-MINING/mine-materialdna` — **Mine MaterialDNA for next concrete depth lane** — score 3660 — dependencies satisfied
- `HG-CAPACITY-MINING/mine-fidelity` — **Mine FidelityManager for next concrete depth lane** — score 3650 — dependencies satisfied
- `HG-CAPACITY-MINING/mine-physics-runtime` — **Mine Physics runtime for next concrete depth lane** — score 3640 — dependencies satisfied
- `HG-CAPACITY-MINING/mine-physics-geometry` — **Mine Physics geometry for next concrete depth lane** — score 3630 — dependencies satisfied
- `HG-CAPACITY-MINING/mine-diagnostics` — **Mine diagnostics source for next concrete depth lane** — score 3620 — dependencies satisfied
- `HG-CAPACITY-MINING/mine-authority` — **Mine authority/multiplayer source for next concrete depth lane** — score 3610 — dependencies satisfied

## Active claims

- `HG-BACKFILL-AUTHORITY/audit` → `sol-20260811-q9x4m2`; lease to `2026-08-11T07:18:25+00:00`
- `HG-BACKFILL-AUTHORITY/primary` → `sol-20260811-r6k2p9`; lease to `2026-08-11T07:06:00+00:00`
- `HG-BACKFILL-DIAGNOSTICS/audit` → `sol-20260811-diaga6r2k`; lease to `2026-08-11T07:30:00+00:00`
- `HG-BACKFILL-FIDELITY/audit` → `sol-20260811-x7n4k2`; lease to `2026-08-11T07:22:30+00:00`
- `HG-BACKFILL-FIDELITY/primary` → `sol-20260811-w3n8k2`; lease to `2026-08-11T07:31:17+00:00`
- `HG-BACKFILL-FIDELITY/test-adversary` → `sol-20260811-30a8e397`; lease to `2026-08-11T07:32:00+00:00`
- `HG-BACKFILL-MATERIALDNA/primary` → `sol-20260811-went7k3`; lease to `2026-08-11T07:14:53+00:00`
- `HG-BACKFILL-OBJECTGENOME/test-adversary` → `sol-20260811-q7n4m9`; lease to `2026-08-11T07:20:00+00:00`
- `HG-BACKFILL-PHYSICS-GEOMETRY/primary` → `sol-20260811-j6r2v8`; lease to `2026-08-11T07:15:00+00:00`
- `HG-BACKFILL-REALITY/audit` → `sol-20260811-q7h4n2`; lease to `2026-08-11T07:44:30+00:00`
- `HG-BACKFILL-REALITY/primary` → `sol-20260811-q9m4r2`; lease to `2026-08-11T07:29:00+00:00`
- `HG-BACKFILL-REALITY/test-adversary` → `sol-20260811-r9t4n2`; lease to `2026-08-11T07:08:30+00:00`
- `HG-BACKFILL-WORLDENTITY/primary` → `sol-20260811-ogx9k2`; lease to `2026-08-11T07:37:00+00:00`
- `HG-BACKFILL-WORLDENTITY/test-adversary` → `sol-20260811-w3x7k9`; lease to `2026-08-11T07:27:00+00:00`
- `SWARM-RECOVERY-PR-OWNERSHIP-IMPORT/primary` → `sol-20260811-r4m8z2`; lease to `2026-08-11T07:30:29+00:00`

## Blocked lanes

- `HERO-DOOR` — **LOCKED** — waiting for HG151-FINAL-AUDIT (READY)
- `OPS-STUDIO-DISPLAY` — **BLOCKED_EXTERNAL** — External Mac GUI/display recovery is required before fresh diagnostics or two-client evidence retries.

> Generated state is disposable. Atomic claims/resource leases are ownership authority.
