# Swarm V16.2 — Integration Throughput

V16.2 is an additive policy layer over UNRENDERED's V16 Mission Graph and the trusted V2.1 ownership/history plane.

V16.1 fixed premature worker stopping under 20–30 chat bursts. V16.2 addresses the next observed bottleneck: review-green / integration-ready work can accumulate faster than the swarm absorbs it into canonical product state.

## Core invariant

Accepted or near-accepted work outside `MAIN` is unfinished. While such work exists, integration pressure outranks ordinary capacity mining.

The swarm should converge that work to one canonical branch, preserve required evidence, resolve compatible conflicts, rerun impacted acceptance, and supersede redundant support branches. It must not manufacture more successor branches merely because integration is busy.

## MERGE_PRESSURE

V16.2 detects `REVIEW` / `INTEGRATING` work, Merge Train backlog, and accepted child work outside the objective's canonical branch.

When pressure exists, worker allocation shifts toward integration:
- moderate backlog: roughly 35% builders / 20% reviewers / 45% integrators;
- heavy backlog: roughly 25% builders / 18% reviewers / 57% integrators.

Worker duties are deliberately parallel without granting duplicate implementation:
- `INTEGRATE` — exact write ownership required;
- `RED_TEAM` — non-exclusive;
- `TEST` — non-exclusive;
- `CONFLICT_CHECK` — non-exclusive.

Capacity-mining assist is suppressed while merge pressure is active. Release-blocking builders remain available.

## Canonical absorption

For each objective with a canonical branch, V16.2 identifies reviewed/integrating child work on other branches and produces an `ABSORB_INTO_CANONICAL` plan.

The plan is advisory scheduling truth, not merge authority. Normal ownership, CI, independent review, external-runtime evidence, and trust checks still apply.

## Immutable event producer fence

The 20+ worker burst also exposed a different throughput tax: malformed immutable events with unsupported top-level fields forced repeated trusted-history recovery.

V16.2 adds `tools/swarm/event_producer.py`. Candidate event bytes must pass the same strict `swarmctl.validate_event` contract before any publication sink is invoked.

For ordinary events, PR/head/recommendation context belongs under `metadata`. The existing typed top-level `pr`, `headSha`, `verdict` exception remains valid only for a complete `REVIEW_RESULT`.

The producer fence does **not** broaden the schema, rewrite old history, or make quarantined artifacts authoritative. Historical recovery remains exact/finite compatibility only.

## Safety and truth

V16.2 cannot promote external runtime truth. `STUDIO_OBSERVED`, `MULTICLIENT_OBSERVED`, `DEVICE_PROFILED`, and `AUTHORITY_VERIFIED` remain explicit external evidence classes. Merge pressure does not relax server-authority, determinism, persistence, performance, Studio/two-client, security, or trusted-history gates.

## Success metrics

Judge V16.2 by:
- lower time from review-green to canonical integration;
- fewer accepted branches waiting outside MAIN;
- fewer redundant successor/support branches;
- fewer malformed new immutable events;
- persistent productive workers during 20–30 chat bursts;
- no regression in trust or external-runtime authority.
