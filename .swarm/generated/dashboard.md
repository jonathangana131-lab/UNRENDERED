# UNRENDERED Swarm Control Plane

Generated: `2026-08-11T06:05:12.664088+00:00`

Canonical main: **GREEN** `5ee9091eb9d7af665a990381b0133d8ccedea503`

State digest: `5c902edba9d91e87c00499072e3948cdaf6dc7aca8aa9b8cfe749981de18b916`

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

- `SWARM-V21-DASHBOARD/primary` → `sol-20260811-v21dash`; lease to `2026-08-11T06:34:10+00:00`

## Blocked lanes

- `HERO-DOOR` — **LOCKED** — waiting for HG151-FINAL-AUDIT (READY)
- `OPS-STUDIO-DISPLAY` — **BLOCKED_EXTERNAL** — External Mac GUI/display recovery is required before fresh diagnostics or two-client evidence retries.

> Generated state is disposable. Atomic claims/resource leases are ownership authority.
