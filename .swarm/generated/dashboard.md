# UNRENDERED Swarm Control Plane

Generated: `2026-08-11T05:57:29.051088+00:00`

Canonical main: **GREEN** `10d3f6992ff243a9268ed8629893faf4fc40791c`

State digest: `40878f74b42d9cf536dcc7b4ebc98beabaa9496dd53a7307f6c8394ad5067e82`

## Summary

- ready slots: **35**
- active claims: **1**
- stale claims: **0**
- blocked-external lanes: **1**

## Ready slots

- `HG-BACKFILL-WORLDENTITY/primary` — **WorldEntity source hardening** — score 5500 — dependencies satisfied; resources available
- `HG-BACKFILL-OBJECTGENOME/primary` — **ObjectGenome source hardening** — score 5450 — dependencies satisfied; resources available
- `HG-BACKFILL-WORLDENTITY/test-adversary` — **WorldEntity adversarial regression author** — score 5420 — dependencies satisfied
- `HG-BACKFILL-MATERIALDNA/primary` — **MaterialDNA source hardening** — score 5400 — dependencies satisfied; resources available
- `HG-BACKFILL-OBJECTGENOME/test-adversary` — **ObjectGenome malformed-input and identity tests** — score 5370 — dependencies satisfied
- `HG-BACKFILL-FIDELITY/primary` — **FidelityManager source hardening** — score 5350 — dependencies satisfied; resources available
- `HG-BACKFILL-MATERIALDNA/test-adversary` — **MaterialDNA schema and hostile-input tests** — score 5320 — dependencies satisfied
- `HG-BACKFILL-WORLDENTITY/audit` — **WorldEntity invariant and aliasing auditor** — score 5320 — dependencies satisfied
- `HG-BACKFILL-REALITY/primary` — **Reality/replay source hardening** — score 5300 — dependencies satisfied; resources available
- `HG-BACKFILL-FIDELITY/test-adversary` — **Fidelity transition and atomicity tests** — score 5270 — dependencies satisfied
- `HG-BACKFILL-OBJECTGENOME/audit` — **ObjectGenome contract and ownership auditor** — score 5270 — dependencies satisfied
- `HG-BACKFILL-PHYSICS-RUNTIME/primary` — **Physics runtime lifecycle hardening** — score 5250 — dependencies satisfied; resources available
- `HG-BACKFILL-MATERIALDNA/audit` — **MaterialDNA contract and fixture auditor** — score 5220 — dependencies satisfied
- `HG-BACKFILL-REALITY/test-adversary` — **Reality version and deterministic replay tests** — score 5220 — dependencies satisfied
- `HG-BACKFILL-PHYSICS-GEOMETRY/primary` — **Physics recipe and geometry hardening** — score 5200 — dependencies satisfied; resources available
- `HG-BACKFILL-FIDELITY/audit` — **Fidelity state-machine auditor** — score 5170 — dependencies satisfied
- `HG-BACKFILL-PHYSICS-RUNTIME/test-adversary` — **Long-cycle lifecycle and teardown regression tests** — score 5170 — dependencies satisfied
- `HG-BACKFILL-DIAGNOSTICS/primary` — **Diagnostics source hardening** — score 5150 — dependencies satisfied; resources available
- `HG-BACKFILL-PHYSICS-GEOMETRY/test-adversary` — **Geometry, clearance, and reachability property tests** — score 5120 — dependencies satisfied
- `HG-BACKFILL-REALITY/audit` — **WorldId, seed, and replay invariant auditor** — score 5120 — dependencies satisfied
- `HG-BACKFILL-AUTHORITY/primary` — **Server/client authority source hardening** — score 5100 — dependencies satisfied; resources available
- `HG-BACKFILL-DIAGNOSTICS/test-adversary` — **Diagnostics lifecycle and no-drift test author** — score 5070 — dependencies satisfied
- `HG-BACKFILL-PHYSICS-RUNTIME/audit` — **Runtime ownership and drift auditor** — score 5070 — dependencies satisfied
- `HG-BACKFILL-AUTHORITY/test-adversary` — **Canonical agreement and teardown fixture author** — score 5020 — dependencies satisfied
- `HG-BACKFILL-PHYSICS-GEOMETRY/audit` — **Physics recipe realism and validation auditor** — score 5020 — dependencies satisfied
- `HG-BACKFILL-DIAGNOSTICS/audit` — **Diagnostics failure-path and capture-contract auditor** — score 4970 — dependencies satisfied
- `HG-BACKFILL-AUTHORITY/audit` — **Two-client authority and trust-boundary auditor** — score 4920 — dependencies satisfied
- `HG-CAPACITY-MINING/mine-worldentity` — **Mine WorldEntity for next concrete depth lane** — score 3680 — dependencies satisfied
- `HG-CAPACITY-MINING/mine-objectgenome` — **Mine ObjectGenome for next concrete depth lane** — score 3670 — dependencies satisfied
- `HG-CAPACITY-MINING/mine-materialdna` — **Mine MaterialDNA for next concrete depth lane** — score 3660 — dependencies satisfied

## Active claims

- `SWARM-V21-CAPACITY/primary` → `sol-20260811-v21fix`; lease to `2026-08-11T06:26:30+00:00`

## Blocked lanes

- `HERO-DOOR` — **LOCKED** — waiting for HG151-FINAL-AUDIT (READY)
- `OPS-STUDIO-DISPLAY` — **BLOCKED_EXTERNAL** — External Mac GUI/display recovery is required before fresh diagnostics or two-client evidence retries.

> Generated state is disposable. Atomic claims/resource leases are ownership authority.
