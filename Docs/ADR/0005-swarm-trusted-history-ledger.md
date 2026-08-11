# ADR-0005 — Separate Trusted Swarm History Ledger

Status: **Proposed recovery; one-time bootstrap required**  
Date: 2026-08-11  
Scope: UNRENDERED Swarm Control Plane history integrity only; no Roblox/gameplay authority changes.

## Context

Swarm V2 stores high-churn coordination data on `swarm-control` and treats immutable event files as durable audit memory. Merged detect-only hardening identified historical event paths whose published bytes had been rewritten after their first failed transition. Their original Git blob identities remain externally auditable, but live descendants can contain different bytes at the same immutable paths.

The old workflow compared each `swarm-control` push only with `github.event.before`. That is insufficient after a failed transition: if a malformed or rewritten control commit remains in first-parent history, a later valid-looking descendant can use that failed commit as its apparent baseline and accidentally launder the defect into trusted history.

This is a control-plane architecture defect. It cannot be repaired by silently editing history, by weakening immutable-event validation, or by declaring the current branch trusted merely because a later projection succeeds.

## Threat model

The control plane must remain fail closed against:

- a failed `swarm-control` commit becoming the next generation's trusted baseline;
- mutation, deletion, relocation, or replay of immutable event IDs;
- a historical rewritten review/finding event regaining authority through compatibility logic;
- a trust record that pairs the SHA of snapshot A with the digest of unrelated snapshot B;
- a stale validator, stale trust publisher, or stale generated-state publisher overwriting newer control/trust state;
- a bootstrap/reset record being mistaken for normal PR authorization;
- self-authored control data selecting itself into a compatibility exception;
- a same-account multi-agent swarm accidentally producing malformed control records concurrently.

GitHub repository permissions remain an external trust assumption. The design prevents stale/racing writers from silently advancing trusted state; it does not protect against a repository administrator deliberately rewriting both protected branches and review history.

## Decision

Introduce a dedicated `swarm-trust` branch. Its authoritative file is `.swarm/trust.json` and contains the last control snapshot that completed strict validation plus its exact authoritative state digest.

`trustedControlSha` and `trustedStateDigest` are one **atomic trust anchor**, not two independently useful fields. Before any transition authority is derived, the workflow archives exactly `trustedControlSha`, recomputes the authoritative state digest from that archived snapshot, and requires it to equal `trustedStateDigest`. A syntactically valid but cross-paired SHA/digest record fails closed.

Normal control validation becomes:

1. read `swarm-trust/.swarm/trust.json`;
2. materialize exactly `trustedControlSha` from `swarm-control` history;
3. compute the archived trusted snapshot's state digest and require exact equality with `trustedStateDigest`;
4. materialize the candidate live `swarm-control` SHA;
5. validate the candidate under current trusted code;
6. run transition checks from the atomically bound trusted snapshot to the candidate, not merely from the candidate's immediate parent;
7. render the candidate and compute its exact authoritative state digest;
8. advance `swarm-trust` only if both the live control tip and prior trust-branch head still equal the values observed before validation;
9. only after that advance may the generated projection be published.

PR ownership additionally requires current live authoritative state to equal the separately trusted digest and rejects `bootstrap: true`. Therefore an unvalidated control mutation cannot be consumed by a product PR even if the control branch itself exists.

## Finite immutable-history quarantine

The recovery recognizes exactly these audited immutable histories:

| Event | Audited first-write Git blob | Already-published rewritten Git blob | Recovery treatment |
| --- | --- | --- | --- |
| `evt-20260811-073500-q9m4r2-authority-rereview-approve` | `2f0b0221b7995b3862ac6c009804ebb66f715fac` | `8f332b489b9266211ff6c5d2869647eba9b80838` | rewritten blob is inert quarantine |
| `evt-20260811-073650-q9m4r2-worldentity-sync-hold` | `f9781fd64518c01aa10b460f01aff13adc6635da` | `c7615c531b671d10a56d6a93577fc9c81cb15836` | rewritten blob is inert quarantine |
| `evt-20260811-080520-h4v8n2-cart-geometry-review` | `a39220b473086229e6b1057b296342175b851af1` | `162e42ab9ab08e7976d61e78ad12bbd088ff13a8` | rewritten blob is inert quarantine |
| `evt-20260811-083640-ogm5x8q2-objectgenome-support-stack` | `9ef4e62ffb0aac9d4b18cb19911d8d3a25535158` | `c2b99475cdb95940d9a7ca329440880865da02cb` | rewritten blob is inert quarantine |

The ObjectGenome first write used a mixed-case non-lane `affects` token. Commit `4c4e3b7f84a86e35abc6eabf33e422288fa06ca7` later normalized the published file in place and added sanitation metadata. Because immutable event bytes had already been published, that normalization is itself a history rewrite and cannot regain authority. The current rewritten blob is therefore treated the same way as the three earlier laundered events: its ID/path stay reserved, but its payload is excluded from event authority.

The already-published rewritten files are never edited or deleted by this recovery. Their exact bytes are accepted only as **inert quarantine artifacts**:

- the event IDs and canonical paths remain permanently reserved;
- the rewritten payloads are excluded from authoritative event semantics and cannot satisfy review/approval/finding routing logic;
- any other bytes at those paths fail closed;
- any replay of those event IDs at another path fails closed;
- the audited first-write hashes remain pinned for external audit.

The separate audited historical event `evt-20260811-081620-mat8c3r1-materialdna-key-grammar` remains at its first-write blob `9a7f679ea84600d6a28a8bef02436e5f85fd857e` and has no rewritten/quarantine variant.

Fresh review, finding, or recovery authority after this reset must be expressed through new strict append-only events.

## Finite mutable-history reset incidents

The reset also crosses two concrete malformed worker-state transitions that were repaired in later commits. These are not silently generalized into “all old invalid history”; they are an exact reviewed finite list:

| Worker path | Invalid transition | Defect | Exact repair |
| --- | --- | --- | --- |
| `.swarm/workers/sol-20260811-j7c4m9x2.json` | `fa5b8f163603fa918c21b28c63bd20e6c25a2add` | unsupported `status: "ACTIVE"` | `7c62ff9a7b92c4ebe43c38323a5946e04881d3b7` |
| `.swarm/workers/sol-20260811-u7m3c9q4.json` | `a99ff757b842fa91ddd893d19fd1d826890ce306` | unsupported `status: "ACTIVE"` | `a193dd686323c27a7191d525b064c4257120de21` |

The read-only bootstrap job proves for each row that the invalid transition is an ancestor of the named repair and that the named repair is an ancestor of the exact candidate `BOOTSTRAP_CONTROL_SHA`. If any commit is absent, reordered, or the bootstrap candidate predates a repair, no bootstrap pair is emitted.

This reset does not make either invalid transition valid. It records that the one-time anchor is intentionally established only after the exact reviewed repairs. There is no generic “ignore earlier failures” mechanism.

## One-time bootstrap/reset

`swarm-trust` is created before the recovery merge with a bootstrap record so workflow fetches are deterministic. A bootstrap record is deliberately **non-authorizing** for product PRs: `verify_trusted_state()` rejects `bootstrap: true` regardless of the digest field.

Before the recovery merge is accepted, the recovery candidate's read-only CI:

1. resolves one exact live `swarm-control` SHA;
2. proves the two named invalid worker transitions and exact repairs are in the required ancestry;
3. validates the exact live snapshot using the finite immutable-history compatibility/quarantine above;
4. prints an exact pair:
   - `BOOTSTRAP_CONTROL_SHA` — the reviewed live `swarm-control` snapshot;
   - `BOOTSTRAP_STATE_DIGEST` — the digest computed from that exact snapshot by the recovery validator.

The bootstrap record must be updated only when a fresh CAS check proves `swarm-control` still equals that printed SHA. The PR description records the exact pair. No moving alias such as `swarm-control` or `HEAD` is accepted as bootstrap evidence.

During the one explicit bootstrap transition, control validation may read a `bootstrap: true` record only to verify the archived SHA/digest pair with `verify_trusted_snapshot(..., allow_bootstrap=True)`. That exception does not authorize product PRs and does not skip the digest binding. Once the recovery merge is present on `main`, the next strict `swarm-control` validation compares from that exact bound bootstrap snapshot, proves the finite quarantine and all later strict changes, and CAS-advances `swarm-trust` to `bootstrap: false` with the exact newly validated digest.

If control or trust moves during the operation, the advance fails and must be retried from fresh truth. There is no recurring reset command. A future reset requires another explicit ADR/critical recovery change.

## Failure and rollback behavior

- Missing `swarm-trust`: PR ownership and control validation fail closed.
- `bootstrap: true`: product PR authorization fails closed.
- Archived `trustedControlSha` digest differs from `trustedStateDigest`: transition validation fails before the trusted baseline is used.
- Trust digest differs from current live state: product PR authorization fails closed.
- Candidate control invalid: trust branch does not move.
- Trusted snapshot invalid under current code: validation fails; do not select a newer baseline to escape the failure.
- Bootstrap candidate does not descend from both exact worker repair commits: no bootstrap pair is emitted.
- Control tip changes during validation: stale trust advance is rejected.
- Trust branch changes during validation: stale trust overwrite is rejected.
- Generated projection publication races newer control state: stale projection is rejected.
- Main-health state is authoritative control data and must traverse the same trusted-history path; it is no longer hidden behind a generated-only skip marker.

Rollback of product `main` does not rewrite `swarm-trust`. A validator rollback must still understand the current trust record and historical quarantine or fail closed. If a code rollback cannot validate current trusted state, control writes stop until a reviewed forward repair restores compatibility.

## Branch and permission assumptions

- `main` contains trusted validator/workflow code.
- `swarm-control` contains high-churn authoritative coordination data.
- `swarm-trust` contains only the last-known-good trust ledger plus ordinary repository history inherited at branch creation.
- Production policy should prevent routine workers from directly treating `swarm-trust` as a work branch. The workflow advances it through exact-head CAS after successful validation.
- Repository administrators remain capable of destructive rewrites; Git history/reviews remain the external audit boundary for that class of action.

## Testing and acceptance

Recovery acceptance requires:

- all prior V2/V2.1 hardening tests remain green;
- exact quarantine bytes are inert and unchanged;
- any one-byte quarantine mutation fails;
- quarantined event IDs remain replay-protected;
- strict new events can append after reset;
- SHA+stateDigest cross-pairing is rejected even when both fields are individually well formed;
- the workflow binds the digest to the archived `trustedControlSha` before transition validation;
- separate trust digest matches authorize only when `bootstrap` is false;
- any authoritative state mutation after trust publication fails the trust check;
- bootstrap records cannot authorize PR state;
- the read-only bootstrap job proves the exact two invalid worker transitions are followed by their exact repairs before emitting a candidate;
- workflow source proves transition validation uses `TRUSTED_CONTROL_SHA`, not `github.event.before`;
- workflow source proves health mutations are not skipped as generated-only state;
- canonical full CI is green on the exact recovery head;
- an independent history-integrity review approves the exact recovery head;
- after merge, a real bootstrap transition produces `bootstrap: false` and a matching live trust digest before normal product PR ownership is considered restored.

## Measured limitation

This ledger makes trusted-history continuity explicit and prevents failed descendants from laundering their parent, but it is intentionally not a high-throughput external database or Byzantine consensus system. GitHub branch/object integrity, repository permissions, workflow identity, and review history remain trusted infrastructure. The one-time reset's mutable-history exceptions are manually enumerated exact commits rather than cryptographically discovered from every historical schema generation. Any newly discovered invalid pre-anchor transition therefore blocks the bootstrap until this reviewed finite manifest is updated. The control plane minimizes infrastructure trust by binding every normal advance to exact immutable Git SHAs, state digests, and CAS checks.
