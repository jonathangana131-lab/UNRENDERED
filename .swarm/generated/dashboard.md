# UNRENDERED Swarm Control Plane

Generated: `2026-08-13T23:07:10.547168+00:00`

Canonical main: **GREEN** `b87987ff7c96b8dda894942771283aca86b7cfb6`

State digest: `eb73526e5416992bc12d8c38842b85ef97c7851b2a24af6fc6dd8243b336cbbb`

## Summary

- ready slots: **8**
- active claims: **6**
- stale claims: **10**
- blocked-external lanes: **1**

## Ready slots

- `HG-BACKFILL-WORLDENTITY/test-adversary` — **WorldEntity adversarial regression author** — score 5420 — dependencies satisfied
- `HG-PHYSICS-RUNTIME-ENTITYID-FENCE/audit` — **Independent runtime entity-ID boundary audit** — score 5095 — dependencies satisfied
- `HG-CAPACITY-MINING/mine-worldentity` — **Mine WorldEntity for next concrete depth lane** — score 3680 — dependencies satisfied
- `HG-CAPACITY-MINING/mine-objectgenome` — **Mine ObjectGenome for next concrete depth lane** — score 3670 — dependencies satisfied
- `HG-CAPACITY-MINING/mine-fidelity` — **Mine FidelityManager for next concrete depth lane** — score 3650 — dependencies satisfied
- `HG-CAPACITY-MINING/mine-physics-geometry` — **Mine Physics geometry for next concrete depth lane** — score 3630 — dependencies satisfied
- `HG-CAPACITY-MINING/mine-diagnostics` — **Mine diagnostics source for next concrete depth lane** — score 3620 — dependencies satisfied
- `HG-CAPACITY-MINING/mine-authority` — **Mine authority/multiplayer source for next concrete depth lane** — score 3610 — dependencies satisfied

## Active claims

- `HG-BACKFILL-DIAGNOSTICS/audit` → `sol-20260813-r7k4n9p2`; lease to `2026-08-13T23:07:14+00:00`
- `HG-BACKFILL-DIAGNOSTICS/test-adversary` → `sol-20260813-n4q7v2m9`; lease to `2026-08-13T23:07:30+00:00`
- `HG-CAPACITY-MINING/mine-materialdna` → `sol-20260813-k3r8v1m6`; lease to `2026-08-13T23:19:00+00:00`
- `HG-CAPACITY-MINING/mine-physics-runtime` → `sol-20260813-k2m8v4q7`; lease to `2026-08-13T23:10:00+00:00`
- `SWARM-RECOVERY-EVENT-IDENTITY-COMPAT/repair` → `sol-20260813-eic7n4p2`; lease to `2026-08-13T23:08:00+00:00`
- `SWARM-RECOVERY-WORKER-STATUS-CONTRACT/primary` → `sol-20260813-k7m4v9q2`; lease to `2026-08-13T23:22:00+00:00`

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
- `SWARM-RECOVERY-EVENT-HISTORY-CONTINUITY` — **BLOCKED** — waiting for SWARM-RECOVERY-WORKER-STATUS-CONTRACT (NEEDS_CHANGES)

> Generated state is disposable. Atomic claims/resource leases are ownership authority.
