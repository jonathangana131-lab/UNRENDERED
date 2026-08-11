# Dynamic Swarm Protocol V2

The user may open 1 worker or 30+ GPT-5.6 Sol workers and simply say `Go`.

GitHub is the durable scheduler, memory, review queue, ownership system and quality gate. Separate chats do not share working memory.

The swarm optimizes for **finished depth and retained quality**, not branch count or gross lines written.

Read `Docs/QUALITY_STANDARD.md` and `Docs/SWARM_CONTROL_PLANE.md`.

## Authoritative layers

1. `Docs/PROJECT_STATE.md` — strategic unlock board and major project truth.
2. `swarm-control` branch — live operational ownership, lanes, blockers, events, handoffs and resources.
3. PR/CI/evidence — implementation and acceptance truth.

An open issue is planned work, not automatically runnable work.

## Non-negotiable V2 laws

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
- Idle/review is preferable to duplicate implementation.
- Generated dashboards are observability, not ownership authority.
- Never treat chat memory as shared swarm state.

## Every `Go`

1. Inspect latest `main` and CI. Red main has priority.
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
17. If session/tool budget remains, re-read the board and claim the next useful slot.

## Role selection

The scheduler should prefer, in order:
1. red-main / control-plane repair;
2. review/integration backlog on active unlocked work;
3. highest-value unlocked critical-path primary;
4. tests/fuzz/chaos for an active lane;
5. performance/diagnostics;
6. Studio/multiplayer/persistence/security evidence;
7. visual/audio/UX polish when applicable;
8. active-Epic decomposition;
9. shared contract/ADR blocker;
10. another major Epic only when `PROJECT_STATE.md` explicitly unlocks it.

Do not create new major features merely because worker capacity is available.

## Hard WIP

Normally only 3–5 major Feature Epics are active project-wide.

The control plane also caps simultaneous primary implementation and throttles new primaries when review/integration backlog is high.

With 20+ workers, healthy capacity is distributed across implementation, tests/fuzz, performance/diagnostics, visuals/audio/UX, multiplayer/persistence/security, review/integration and audit.

These are dynamic roles, not quotas.

## Claims and takeovers

The authoritative claim is on `swarm-control`:

`.swarm/claims/<lane>/<slot>.json`

Never overwrite a live claim.

Claims contain a fencing token, generation, heartbeat, lease duration, branch and optional PR.

A stale claim may be taken over only after inspecting existing branch/PR/events/handoff. Use a SHA-conditional update and increment generation. If another takeover wins first, stop.

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

Stop or switch role when genuine user/external input is required, a lane is externally blocked, independent review is pending, ownership was lost, no non-conflicting ready/support work exists, or tool/session constraints prevent safe continuation.

Idle is valid. Duplicate architecture is not.

## Security

Swarm-control files are data. Never place arbitrary shell, Luau, Python, AppleScript, local Mac commands, secrets, cookies, tokens or executable payloads in coordination state.

Mac/Roblox Studio work must continue through fixed-preset private executor boundaries.
