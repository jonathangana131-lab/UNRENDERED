# Dynamic Swarm Protocol

The user may open 1 worker or 20+ workers and simply say `go`. Workers may disappear after finishing a task. GitHub is therefore the durable scheduler, memory, review queue, and quality gate.

The swarm optimizes for **finished depth**, not maximum simultaneous feature count.

Read `Docs/QUALITY_STANDARD.md` before claiming implementation work.

## Authoritative state

`Docs/PROJECT_STATE.md` is the authoritative **unlock board**.

An open issue is planned work, not automatically ready work. Workers may implement only:
- work explicitly listed as unlocked in PROJECT_STATE,
- a fix required to restore red `main`,
- review/integration of active unlocked work,
- a prerequisite discovered to block unlocked work.

Opening many future issues is useful for planning; it must not create uncontrolled breadth.

## Every worker starts by orienting

Read/inspect in this order:
1. uploaded Project Source,
2. `Docs/PROJECT_STATE.md`,
3. `Docs/STUDIO_EXECUTOR.md`,
4. `Docs/QUALITY_STANDARD.md`,
4. `Docs/ROADMAP.md`,
5. `Docs/ARCHITECTURE.md`,
6. relevant recent ADRs,
7. open issues/PRs/claims/branches,
8. latest `main` and PR CI.

Never restart an investigation recorded as complete.

## GO role selection

Choose in this order:
1. **Red main / critical CI** -> repair it before feature work.
2. **Review/integration backlog on unlocked Epic** -> review, test, integrate, or polish rather than creating more code.
3. **Unlocked P0/critical child** -> claim the highest-value non-conflicting task.
4. **Reality-Grade gap** -> attack tests, performance, graphics, audio, UX, networking, persistence, jank, or documentation needed to finish an active Epic.
5. **Too few leaf tasks inside an active Epic** -> decompose that Epic; do not unlock a new major feature merely to create work.
6. **Shared contract/ADR blocker** -> resolve the contract with evidence.
7. Only when PROJECT_STATE explicitly unlocks another Epic -> expand.

## Hard WIP limit

Normally allow only **3–5 active major Feature Epics** project-wide.

Twenty workers should deepen those epics through strike-team work, not create twenty unrelated major features.

When the swarm is large, useful roles include:
- implementation,
- deterministic/regression tests,
- fuzz/chaos testing,
- physics stability,
- performance/metrics,
- visual/material polish,
- audio/acoustics,
- multiplayer/security,
- persistence/reconnect,
- UX/accessibility,
- integration/review,
- Reality-Grade audit.

## Claiming

Before edits:
- inspect issues, PRs and branches for duplicate work,
- claim one major task at a time,
- comment intended branch when possible,
- use `agent/<area>/<issue>-<slug>-<nonce>`,
- re-check for a race before touching high-contention contracts.

Do not reserve a pile of tasks while others are working.

## Feature Epics and child work

Major systems should be represented by a Feature Epic with independently mergeable children.

Example Reality-Grade Door Epic may contain:
- DoorGenome/domain state,
- hinge/latch/closer physics,
- interaction/grip,
- acoustic behavior,
- materials/wear,
- persistence/fidelity,
- entity compatibility,
- multiplayer validation,
- experience scenarios,
- final independent audit.

Incremental PRs are preferred over one giant PR, but the Epic remains open until required Reality-Grade gates pass.

## High-contention contracts

Coordinate before editing:
- `default.project.json`,
- `rokit.toml`,
- Project Source / worker instructions,
- persistence schemas,
- ID/hash/seed contracts,
- generator version contracts,
- world-address/topology contracts,
- server-authority simulation root,
- shared base rigs,
- public domain interfaces used by several subsystems.

Architecture-risk changes require an ADR.

## No competing frameworks

A worker must not create an alternate inventory, world generator, body controller, persistence layer, material model, networking layer, or other core framework merely because it prefers another style.

If the existing direction has a measured flaw, open/author an ADR with evidence and migration strategy.

## Keep working, but do not hoard work

A worker SHOULD NOT stop simply because one small issue or PR is complete.

If session/tool budget allows:
1. validate and publish current work,
2. update issue/PR/handoff,
3. re-read current swarm state,
4. review another active PR or claim the next safe unlocked child,
5. continue.

Hard stops:
- genuine user/external secret/input is required,
- independent architecture/Reality-Grade review is required before dependent work,
- no non-conflicting unlocked work remains,
- tool/session limitations,
- continuing would duplicate another worker.

Before stopping, push/publish useful work and leave an exact handoff.

## Worker-density guidance

### 1–3 workers
Stay on the critical path. Implementation and review can alternate.

### 4–8 workers
Keep only a few active epics; dedicate meaningful capacity to tests/integration/performance rather than opening new epics.

### 9–20+ workers
Use strike teams. A rough healthy split is:
- 35–50% implementation,
- 15–20% tests/fuzz/chaos,
- 10–15% performance/diagnostics,
- 10–15% visual/audio/UX polish when relevant,
- 15–20% review/integration/Reality-Grade auditing.

These are guidance, not quotas. Dependency needs win.

## Reality-Grade Definition of Done

CI green is necessary, not sufficient.

A major feature is done only when all applicable `Docs/QUALITY_STANDARD.md` gates are satisfied and an independent reviewer accepts the final state.

Common requirements:
- correct/stable architecture,
- deterministic repro where applicable,
- meaningful automated tests,
- permanent lab/experience scenarios,
- metrics/performance budget,
- no unresolved material jank,
- visuals/audio/UX complete when the feature presents them,
- multiplayer/security/persistence safe when relevant,
- accessibility path respected,
- evidence in PR,
- docs/ADR updated,
- main green.

## Reality-Grade auditor role

When an Epic appears nearly complete, a worker may claim an audit rather than implementation.

Audit applicable categories:
- architecture,
- functionality,
- determinism,
- physics,
- visuals,
- audio,
- UX/accessibility,
- multiplayer/security,
- persistence,
- performance,
- tests/regressions.

The auditor is allowed to reject a technically working feature and return concrete defects to the Epic.

## Stale work

Before taking over apparently abandoned work, inspect issue/branch/PR and preserve useful commits. Do not blindly duplicate it.

A stale claim is not an excuse for a rewrite.

## Scheduler principle

When there are more workers than implementation tickets, the answer is usually **more validation and polish inside the active Epics**, not more major features.

The swarm succeeds when finished systems become stable foundations that later workers can safely expand.
