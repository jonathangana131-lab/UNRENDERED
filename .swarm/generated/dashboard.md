# UNRENDERED Swarm Control Plane

Generated: `2026-08-11T08:14:05.585216+00:00`

Canonical main: **GREEN** `064e28f2306095dadd6a514b96f397cd810ac556`

State digest: `be2171f7e12c97c0daf017aba6de8ac0856caa5d37c0ccedd78195670ab1b979`

## Summary

- ready slots: **12**
- active claims: **21**
- stale claims: **7**
- blocked-external lanes: **1**

## Ready slots

- `HG-BACKFILL-OBJECTGENOME/primary` — **ObjectGenome source hardening** — score 5450 — dependencies satisfied; resources available
- `HG-BACKFILL-WORLDENTITY/test-adversary` — **WorldEntity adversarial regression author** — score 5420 — dependencies satisfied
- `HG-BACKFILL-OBJECTGENOME/test-adversary` — **ObjectGenome malformed-input and identity tests** — score 5370 — dependencies satisfied
- `HG-BACKFILL-FIDELITY/test-adversary` — **Fidelity transition and atomicity tests** — score 5270 — dependencies satisfied
- `HG-PHYSICS-CART-GEOMETRY/audit` — **Independent rolling-cart geometry audit** — score 5210 — dependencies satisfied
- `HG-BACKFILL-DIAGNOSTICS/primary` — **Diagnostics source hardening** — score 5150 — dependencies satisfied; resources available
- `HG-BACKFILL-PHYSICS-GEOMETRY/audit` — **Physics recipe realism and validation auditor** — score 5020 — dependencies satisfied
- `HG-CAPACITY-MINING/mine-worldentity` — **Mine WorldEntity for next concrete depth lane** — score 3680 — dependencies satisfied
- `HG-CAPACITY-MINING/mine-fidelity` — **Mine FidelityManager for next concrete depth lane** — score 3650 — dependencies satisfied
- `HG-CAPACITY-MINING/mine-physics-geometry` — **Mine Physics geometry for next concrete depth lane** — score 3630 — dependencies satisfied
- `HG-CAPACITY-MINING/mine-diagnostics` — **Mine diagnostics source for next concrete depth lane** — score 3620 — dependencies satisfied
- `HG-CAPACITY-MINING/mine-authority` — **Mine authority/multiplayer source for next concrete depth lane** — score 3610 — dependencies satisfied

## Active claims

- `HG-BACKFILL-AUTHORITY/audit` → `sol-20260811-n7c4p2`; lease to `2026-08-11T08:38:20+00:00`
- `HG-BACKFILL-AUTHORITY/primary` → `sol-20260811-s56r7n2`; lease to `2026-08-11T08:40:50+00:00`
- `HG-BACKFILL-AUTHORITY/test-adversary` → `sol-20260811-b7n5q2x8`; lease to `2026-08-11T08:42:00+00:00`
- `HG-BACKFILL-DIAGNOSTICS/audit` → `sol-20260811-z5r8m2`; lease to `2026-08-11T08:35:02+00:00`
- `HG-BACKFILL-DIAGNOSTICS/test-adversary` → `sol-20260811-v6m4q9t2`; lease to `2026-08-11T08:36:20+00:00`
- `HG-BACKFILL-FIDELITY/audit` → `sol-20260811-e08449`; lease to `2026-08-11T08:39:30+00:00`
- `HG-BACKFILL-FIDELITY/primary` → `sol-20260811-v6r2k9`; lease to `2026-08-11T08:40:00+00:00`
- `HG-BACKFILL-MATERIALDNA-COUNTERS/audit` → `sol-20260811-h4v8n2`; lease to `2026-08-11T08:40:20+00:00`
- `HG-BACKFILL-MATERIALDNA-COUNTERS/primary` → `sol-20260811-492051ed`; lease to `2026-08-11T08:32:40+00:00`
- `HG-BACKFILL-OBJECTGENOME/audit` → `sol-20260811-96d0cf`; lease to `2026-08-11T08:36:15+00:00`
- `HG-BACKFILL-PHYSICS-GEOMETRY/primary` → `sol-20260811-v8k3p6`; lease to `2026-08-11T08:38:30+00:00`
- `HG-BACKFILL-PHYSICS-GEOMETRY/test-adversary` → `sol-20260811-p4x7d9`; lease to `2026-08-11T08:40:54+00:00`
- `HG-BACKFILL-PHYSICS-RUNTIME-RECIPE-FENCE/primary` → `sol-20260811-z4m8p2`; lease to `2026-08-11T08:30:00+00:00`
- `HG-BACKFILL-REALITY/audit` → `sol-20260811-8d9cde53`; lease to `2026-08-11T08:38:15+00:00`
- `HG-BACKFILL-REALITY/primary` → `sol-20260811-r8v2c6`; lease to `2026-08-11T08:38:20+00:00`
- `HG-BACKFILL-REALITY/test-adversary` → `sol-20260811-m8q2v7`; lease to `2026-08-11T08:32:00+00:00`
- `HG-BACKFILL-WORLDENTITY/audit` → `sol-20260811-e3a71c9d`; lease to `2026-08-11T08:39:18+00:00`
- `HG-CAPACITY-MINING/mine-materialdna` → `sol-20260811-mat8c3r1`; lease to `2026-08-11T08:41:53+00:00`
- `HG-CAPACITY-MINING/mine-objectgenome` → `sol-20260811-h8v5c1`; lease to `2026-08-11T08:40:05+00:00`
- `HG-CAPACITY-MINING/mine-physics-runtime` → `sol-20260811-r8v2k6`; lease to `2026-08-11T08:42:44+00:00`
- `SWARM-RECOVERY-HEALTH-VALIDATION-FENCE/primary` → `sol-20260811-s5q8m4`; lease to `2026-08-11T08:39:00+00:00`

## Blocked lanes

- `HERO-DOOR` — **LOCKED** — waiting for HG151-FINAL-AUDIT (READY)
- `HG-MATERIALDNA-REPAIRCOUNT-BOUND` — **SUPERSEDED** — dependencies satisfied
- `HG-ONESHOT-PHYSICS-CART-GEOMETRY` — **SUPERSEDED** — dependencies satisfied
- `OPS-STUDIO-DISPLAY` — **BLOCKED_EXTERNAL** — External Mac GUI/display recovery is required before fresh diagnostics or two-client evidence retries.

> Generated state is disposable. Atomic claims/resource leases are ownership authority.
