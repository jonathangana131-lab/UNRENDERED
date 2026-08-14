# Dynamic Swarm Protocol V2.1 + Foundry 17

The user may open 1–20 ordinary ChatGPT workers with the GitHub connector and simply say `Go`.

Before any new primary work, apply `Docs/SWARM_FOUNDRY_V17.md` to exact current GitHub PR/branch pressure. Twenty chats are capacity, not twenty writers. When repository headroom is exhausted, new product branches are denied except one red-main emergency repair; use integration, review, verification, evidence transfer, or bounded retirement instead.

GitHub is the durable scheduler, memory, review queue, ownership system and quality gate. Separate chats do not share working memory.

The swarm optimizes for **finished depth and retained quality**, not branch count or gross lines written.

Read `Docs/QUALITY_STANDARD.md` and `Docs/SWARM_CONTROL_PLANE.md`.

## Authoritative layers

1. `Docs/PROJECT_STATE.md` — strategic unlock board and major project truth.
2. `swarm-control` branch — live operational ownership, lanes, blockers, events, handoffs and resources.
3. PR/CI/evidence — implementation and acceptance truth.

An open issue is planned work, not automatically runnable work.

## Non-negotiable V2.1 laws

- **NO implementation before a successful atomic claim.**
- **CLAIM first. BRANCH second.**
- One live primary implementer per exclusive lane.
- Complementary workers use explicit role slots.
- A claim is a lease, not permanent ownership.
- Dead/stale work is salvaged, not blindly rewritten.
- High-contention contracts require their named resource lease.
- Important discoveries become durable structured events.
- Blockers propagate through dependencies.
- Implementers do not Reality-Grade-approve themselves where independent review is required.
- `PROJECT_STATE.md` has one temporary writer resource.
- Accidental competition is forbidden; intentional tournament competition is explicit.
- Generated dashboards are observability, not ownership authority.
- Never treat chat memory as shared swarm state.
- **GREEN means canonical CI health only. It never means the project is complete or the worker is done.**
- **`readySlots == 0` is not, by itself, permission to stop.**
- When the critical path is externally blocked, useful capacity redirects into source-only depth, testing, audit, recovery, review, decomposition and evidence-contract work that does not require the blocked resource.
- Idle is valid only after the worker has exhausted the capacity fallback chain below. Duplicate architecture remains forbidden.

## Every `Go`

1. Inspect latest `main` and CI. Red main has priority. A green result is health information, not task completion.
2. Read `Docs/PROJECT_STATE.md`.
3. Read `Docs/SWARM_CONTROL_PLANE.md`.
4. Read live `swarm-control` board/lane/claim/resource state and recent relevant events.
5. Generate/register a unique worker ID: `sol-YYYYMMDD-<nonce>`.
6. Select the highest-value compatible **ready slot**, not an invented task.
7. Attempt the atomic claim.
   - If creation conflicts, another worker won. Do not code. Pick the next slot.
   - If ownership is uncertain, fail closed and do not act as primary.
8. Acquire required scarce-resource leases in deterministic resource order.
9. Re-read the lane, its dependencies, current PRs, latest events and any prior handoff.
10. Create the branch named in the claim.
11. Implement/review/test only inside the claimed lane/slot scope.
12. At meaningful checkpoints, heartbeat the lease, re-read relevant blockers, and publish a structured event if peers would act differently after the finding.
13. Validate with the strongest available tests/CI/Studio evidence. Never claim an unrun test.
14. Open/update the PR with mandatory Swarm metadata.
15. Transition to independent review/integration rather than self-approving.
16. Before stopping, publish a precise handoff if useful and release/transition ownership.
17. If session/tool budget remains, re-read the board and claim the next useful slot. Do not stop merely because one claimed role completed.

## Capacity fallback — no green-and-stop

The live 25-worker stress test exposed a real failure mode: workers registered successfully, observed green `main`, found zero ordinary ready slots because the Studio GUI path was externally blocked, and then stopped. Duplicate prevention worked, but useful throughput collapsed to zero. V2.1 treats that outcome as a scheduler/protocol failure.

A worker may not convert any of these into a completion decision by themselves:

- `main` is GREEN;
- no ordinary primary is ready;
- the highest-priority lane is `BLOCKED_EXTERNAL`;
- Studio/another scarce resource is unavailable;
- another worker won the first claim race.

Before stopping for lack of work, re-read current state and exhaust this ordered fallback chain:

1. ready critical-path lane/slot;
2. red-main/control repair if applicable;
3. waiting PR review, requested-changes verification, or integration work;
4. stale claim takeover/recovery after inspecting existing branch/PR/events/handoff;
5. ready `backfill` lane on the current active Epic;
6. tests/fuzz/property/chaos roles that deepen an already-unlocked subsystem;
7. source-only diagnostics, authority, persistence, performance or failure-path work that does not require the blocked external resource;
8. a `capacity`/mining role that inspects one foundation shard for a concrete missing invariant, defect, test gap, integration gap or decomposition opportunity;
9. only then, if there is truly no safe non-conflicting contribution, stop cleanly with the exact exhausted categories and blocker evidence.

A capacity/mining worker does **not** invent a feature. It inspects current source, tests, recent PRs, accepted events and quality requirements. If it finds concrete useful work, it publishes the finding and creates/recommends a bounded one-shot lane with a narrow non-overlapping scope. If it finds no gap in that shard, it publishes a concise structured FINDING and moves to another available role while session budget remains.

When a scarce resource is blocked, never work around the block by faking evidence or repeatedly queueing hopeless engine jobs. Redirect capacity to work that can be truthfully completed without that resource.

A healthy 20–30-worker burst is allowed to contain implementation, tests, audits, review, integration, recovery and mining simultaneously. The objective is not to force all workers to produce code; it is to prevent the entire swarm from confusing **healthy CI** with **nothing useful to do**.

## Role selection

The scheduler should prefer, in order:
1. red-main / control-plane repair;
2. review/integration backlog on active unlocked work;
3. highest-value unlocked critical-path primary;
4. tests/fuzz/chaos for an active lane;
5. performance/diagnostics;
6. Studio/multiplayer/persistence/security evidence;
7. visual/audio/UX polish when applicable;
8. source-only backfill on the active Epic while scarce resources are blocked;
9. capacity mining/decomposition that produces concrete bounded follow-up lanes;
10. shared contract/ADR blocker;
11. another major Epic only when `PROJECT_STATE.md` explicitly unlocks it.

Do not create new major features merely because worker capacity is available.

## Hard WIP

Normally only 3–5 major Feature Epics are active project-wide.

The control plane also caps simultaneous primary implementation and throttles new primaries when review/integration backlog is high.

With 20+ workers, healthy capacity is distributed across implementation, tests/fuzz, performance/diagnostics, visuals/audio/UX, multiplayer/persistence/security, review/integration, audit, recovery and bounded source-depth mining.

These are dynamic roles, not quotas.

## Claims and takeovers

The authoritative claim is on `swarm-control`:

`.swarm/claims/<lane>/<slot>.json`

Never overwrite a live claim.

Claims contain a fencing token, generation, heartbeat, lease duration, branch and optional PR.

A stale claim may be taken over only after inspecting existing branch/PR/events/handoff. Use a SHA-conditional update and increment generation. If another takeover wins first, stop that takeover attempt and select another role.

An old worker returning after takeover must re-read ownership before any push. Changed token/generation/owner means the old worker is fenced.

## Worker communication

Publish concise structured events when another worker's action should change:
- FINDING
- BLOCKER / EXTERNAL_BLOCKER
- DEPENDENCY_DISCOVERED
- REVIEW_REQUEST / REVIEW_RESULT
- HANDOFF
- EVIDENCE_RESULT
- DECISION
- SUPERSEDED
- INTEGRATION_RESULT
- RECOVERY

Do not publish private reasoning or noisy status chatter.

## Scope

Lane and slot write scopes are enforced by PR CI.

Do not silently rewrite an adjacent framework because you found a problem while working.

If scope must expand, publish the finding, amend/create a linked lane, acquire any newly required protected resource, then edit.

Architecture-risk changes still require an ADR.

## High-contention contracts

Protected resources include strategic state, swarm protocol/control-plane contracts, persistence schemas, ID/hash/seed contracts, generator version contracts, world-address/topology contracts, server-authority simulation roots and shared public domain interfaces.

Do not over-lock ordinary implementation files.

## Reviews

Review is first-class work.

If a lane requires independent review, reviewer worker ID must differ from primary worker ID.

Review verdicts are durable events: APPROVE, REQUEST_CHANGES, BLOCK or SUPERSEDE.

## Integration

Before merge, sync current main, verify dependencies, claim/metadata, required review, exact-head CI and no superseding event. Merge, watch post-merge main, then finalize the lane.

## Intentional tournament mode

Independent competition is allowed only when a lane explicitly declares `mode: tournament` with bounded candidate slots and an independent judge/synthesis worker.

Do not relabel accidental duplicate coding as a tournament.

## Reality-Grade

CI green is necessary, not sufficient.

A major feature remains open until applicable architecture, determinism, physics, visuals, audio, UX/accessibility, multiplayer/security, persistence, performance and regression gates are satisfied and independently reviewed.

Ask:

**If this exact system shipped tomorrow and nobody ever rewrote it, would we be proud of it?**

## Hard stops

Stop or switch role when genuine user/external input is required for every remaining safe contribution, ownership was lost and no fallback role is available, or tool/session constraints prevent safe continuation.

An externally blocked lane alone is **not** a swarm-wide stop condition. Green main alone is **not** a stop condition. Zero ordinary ready primaries alone is **not** a stop condition.

Before a no-work stop, the worker must have re-read live state and exhausted review/integration, stale recovery, active-Epic backfill, tests/audit, and capacity-mining roles. State exactly which categories were checked.

Idle is valid after that exhaustion. Duplicate architecture is not.

## Security

Swarm-control files are data. Never place arbitrary shell, Luau, Python, AppleScript, local Mac commands, secrets, cookies, tokens or executable payloads in coordination state.

Mac/Roblox Studio work must continue through fixed-preset private executor boundaries.
