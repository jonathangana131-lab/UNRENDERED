# ADR-0005 — Separate Trusted Swarm History Ledger

Status: **Proposed recovery; one-time bootstrap required**  
Date: 2026-08-11  
Scope: UNRENDERED Swarm Control Plane history integrity only; no Roblox/gameplay authority changes.

## Context

Swarm V2 stores high-churn coordination data on `swarm-control` and treats immutable event files as durable audit memory. Detect-only hardening proved that some already-published event paths were rewritten after first publication, many event first writes were malformed under the strict V2 schema, and several mutable worker records passed through schema-invalid status values before later owner-side repairs.

The old workflow compared each `swarm-control` push only with `github.event.before`. That is insufficient after a failed transition: a malformed or rewritten control commit can remain in first-parent history and become a later candidate's apparent baseline. A descendant that looks valid must not launder an invalid ancestor into trusted history.

This is a control-plane architecture defect. It cannot be repaired by silently editing history, weakening validation, broadening status aliases, or declaring the current branch trusted merely because a later projection succeeds.

## Threat model

The control plane must remain fail closed against:

- a failed `swarm-control` commit becoming a trusted later baseline;
- mutation, deletion, relocation, or replay of immutable event IDs;
- rewritten or malformed historical events regaining review/finding authority through compatibility logic;
- self-authored live defects selecting themselves into a compatibility exception;
- a trust record pairing the SHA of snapshot A with the digest of unrelated snapshot B;
- stale validators, trust publishers, or generated-state publishers overwriting newer state;
- `bootstrap: true` being mistaken for normal PR authorization;
- same-account multi-agent concurrency producing malformed worker records.

GitHub repository permissions remain an external trust assumption. This design prevents ordinary stale/racing writers from silently advancing trusted state; it does not protect against an administrator deliberately rewriting both protected history and review evidence.

## Decision

Introduce a dedicated `swarm-trust` branch. Its authoritative file is `.swarm/trust.json`, containing the last control snapshot that completed strict validation plus its exact authoritative state digest.

`trustedControlSha` and `trustedStateDigest` are one **atomic trust anchor**. Before transition authority is derived, the workflow archives exactly `trustedControlSha`, recomputes the authoritative state digest from that archived snapshot, and requires exact equality with `trustedStateDigest`. A syntactically valid cross-paired SHA/digest record fails closed.

Normal control validation becomes:

1. read `swarm-trust/.swarm/trust.json`;
2. materialize exactly `trustedControlSha` from `swarm-control` history;
3. recompute that snapshot's authoritative state digest and require equality with `trustedStateDigest`;
4. materialize the candidate live `swarm-control` SHA;
5. validate the candidate under current trusted code;
6. run transition checks from the atomically bound trusted snapshot to the candidate, not merely from the candidate's immediate parent;
7. render the candidate and compute its exact authoritative state digest;
8. advance `swarm-trust` only if both live control tip and prior trust-branch head still match their pre-validation values;
9. only after trust advances may generated projection publication proceed.

PR ownership additionally requires current live authoritative state to equal the separately trusted digest and rejects `bootstrap: true`. An unvalidated control mutation therefore cannot authorize a product PR merely because it exists on `swarm-control`.

## Finite immutable-history quarantine

The recovery has two exact historical quarantine classes. Neither class edits or deletes published files.

### Rewritten valid first-write events

These events had an auditable valid first-write blob and a later already-published rewrite. The first-write identity remains pinned for audit; the exact rewritten blob is retained only as inert quarantine.

| Event | Audited first-write Git blob | Published rewritten Git blob |
| --- | --- | --- |
| `evt-20260811-073500-q9m4r2-authority-rereview-approve` | `2f0b0221b7995b3862ac6c009804ebb66f715fac` | `8f332b489b9266211ff6c5d2869647eba9b80838` |
| `evt-20260811-073650-q9m4r2-worldentity-sync-hold` | `f9781fd64518c01aa10b460f01aff13adc6635da` | `c7615c531b671d10a56d6a93577fc9c81cb15836` |
| `evt-20260811-080520-h4v8n2-cart-geometry-review` | `a39220b473086229e6b1057b296342175b851af1` | `162e42ab9ab08e7976d61e78ad12bbd088ff13a8` |
| `evt-20260811-083640-ogm5x8q2-objectgenome-support-stack` | `9ef4e62ffb0aac9d4b18cb19911d8d3a25535158` | `c2b99475cdb95940d9a7ca329440880865da02cb` |

The ObjectGenome first write used mixed-case/non-lane routing. Later normalization changed already-published bytes in place, so the normalized payload cannot regain authority. Its ID/path remain reserved and its exact rewritten blob is inert.

The separate historical event `evt-20260811-081620-mat8c3r1-materialdna-key-grammar` remains at audited first-write blob `9a7f679ea84600d6a28a8bef02436e5f85fd857e`; it is compatibility-pinned but has no quarantine variant.

### Malformed first-write events

Malformed first writes have **no canonical authoritative payload to recover**. Their exact bytes are therefore quarantine-only: the path and event ID remain reserved, but the payload can never become review/finding authority.

The complete reviewed machine-readable source is the **composed finite inventory** consumed by `tools/swarm/swarmctl_hardening.py` and bootstrap CI:

- `tools/swarm/swarm_history_recovery_manifest.py` contains 65 canonical-filename malformed-event tuples plus 2 path-divergent tuples returned by `malformed_event_quarantine_rows()`, for 67 foundational normalized rows;
- `tools/swarm/swarm_history_recovery_extension.py` retains 47 exact legacy extension rows under their real `2026-08-11` directory and adds 1 explicitly dated `2026-08-12` quarantine row;
- `swarmctl_hardening.py` composes both quarantine-rule maps, while bootstrap CI normalizes the foundational rows with date `2026-08-11` and consumes `extension.malformed_event_quarantine_rows_with_dates()` so every later row carries its real directory explicitly.

The exact current recovery boundary therefore pins **115 malformed first-write rows** as:

`eventId + exact date + exact filename + exact first-write commit + exact quarantine-only Git blob SHA-1`

The 65 canonical-filename foundational tuples are independently regression-locked by SHA-256:

`8c8c77f85c8210cfbca5a804364e3792bec347f7d62b994dee83a6870181bdfe`

The two path-divergent foundational rows remain explicit machine-readable path identities. The 47-row legacy extension remains separately count/identity/uniqueness regression-tested, and the generation-7 dated row is pinned independently with its `2026-08-12` directory, first-write commit, and Git blob. This split preserves reviewable provenance without pretending the older foundational digest covers later extensions.

Bootstrap CI does not trust either manifest merely because it is source code. For every composed normalized row it independently proves from Git history that:

1. the exact dated event path has exactly one first-add commit;
2. that commit equals the pinned `firstWriteCommit`;
3. the pinned first-write commit is an ancestor of the exact bootstrap control SHA;
4. the Git blob at `firstWriteCommit:path` equals the pinned quarantine-only blob;
5. strict snapshot validation sees the exact same blob at the canonical dated path.

For every quarantined event:

- the canonical path and event ID remain permanently reserved;
- the quarantined payload is excluded from authoritative event semantics;
- any byte variant other than the exact reviewed blob fails closed;
- replay at another path fails closed;
- fresh authority must be expressed through a new strict append-only event.

No rule is derived dynamically from a live validation failure. Any newly discovered malformed pre-anchor event remains a bootstrap blocker until its exact provenance is independently inventoried and explicitly added to the finite composed inventory.

## Finite mutable-history reset incidents

Invalid worker statuses remain invalid everywhere. The one-time reset only proves that each exact malformed transition is followed by its exact schema-valid owner-side repair before the bootstrap candidate.

The executable source of truth is the composed `FINITE_WORKER_TRANSITIONS` value in `tools/swarm/swarmctl_hardening.py`:

`swarm_history_recovery_manifest.FINITE_WORKER_TRANSITIONS + swarm_history_recovery_extension.FINITE_WORKER_TRANSITIONS`

The foundational manifest contains 21 exact invalid-worker -> repair pairs and is regression-locked by SHA-256:

`165419f1d0e6308a4f55d8c5f87b79fd03d508f477bcbfaaf7622f026e1ceafe`

The extension contains 12 further exact pairs: the previously retained 6 plus 6 generation-7 repairs measured from the August 12 live bootstrap audit. Each generation-7 pair is pinned verbatim by `tools/swarm/test_swarm_history_recovery_extension.py`. The exact current reset boundary therefore contains **33 exact invalid-worker -> repair transitions**. The read-only bootstrap workflow consumes the composed value, emits no trust pair if it is empty, and proves for every row:

`invalid commit -> exact repair commit -> BOOTSTRAP_CONTROL_SHA`

Invalid vocabulary such as historical `ACTIVE`, `CLAIMING`, `DONE`, or `READY` remains rejected by the current validator; the finite transition inventory proves only the exact pre-anchor defect followed by its exact owner-side repair.

This finite list is not a generic “ignore old failures” mechanism. Any newly discovered invalid pre-anchor transition blocks bootstrap until its exact provenance and repair are reviewed and added to the composed manifest.

## One-time bootstrap/reset

`swarm-trust` exists before recovery merge with a bootstrap record so workflow fetches are deterministic. A bootstrap record is deliberately **non-authorizing** for product PRs: `verify_trusted_state()` rejects `bootstrap: true` regardless of the digest field.

Before the recovery merge is accepted, read-only CI:

1. resolves one exact live `swarm-control` SHA;
2. proves every finite invalid-worker -> repair -> candidate ancestry chain;
3. proves exact Git first-write provenance for every malformed-event quarantine tuple using its explicit date/path;
4. emits a read-only residual history inventory so any unlisted malformed event remains visible;
5. validates the exact live snapshot using only the explicit finite quarantine;
6. prints the exact pair `BOOTSTRAP_CONTROL_SHA` and `BOOTSTRAP_STATE_DIGEST`.

The bootstrap ledger may be pinned to that pair only after a fresh CAS check proves `swarm-control` still equals the measured SHA. No moving alias such as `HEAD` or `swarm-control` is accepted as evidence.

During the one explicit bootstrap transition, control validation may read `bootstrap: true` only to verify the archived SHA/digest pair with `verify_trusted_snapshot(..., allow_bootstrap=True)`. That does not authorize product PRs and does not skip digest binding.

Once recovery code is merged to `main`, the next strict `swarm-control` validation starts from the exact bound bootstrap snapshot, validates all later state, and CAS-advances `swarm-trust` to `bootstrap: false`. The resulting reset reason refers to the exact quarantine manifest and complete `FINITE_WORKER_TRANSITIONS` manifest rather than duplicating a stale subset of commit IDs in workflow text.

If control or trust moves during the operation, the advance fails and must restart from fresh truth. There is no recurring reset command. A future reset requires another explicit reviewed architecture recovery.

## Failure and rollback behavior

- Missing `swarm-trust`: PR ownership and control validation fail closed.
- `bootstrap: true`: product PR authorization fails closed.
- Archived `trustedControlSha` digest differs from `trustedStateDigest`: transition validation fails before the trusted baseline is used.
- Trust digest differs from current live state: product PR authorization fails closed.
- Candidate control invalid: trust branch does not move.
- Trusted snapshot invalid under current code: validation fails; no newer baseline is substituted to escape the failure.
- Bootstrap candidate does not descend from every exact worker repair: no bootstrap pair is emitted.
- Any malformed-event first-write commit/blob provenance mismatch: no bootstrap pair is emitted.
- Any residual unlisted malformed event: strict validation fails and no bootstrap pair is emitted.
- Control tip changes during validation: stale trust advance is rejected.
- Trust branch changes during validation: stale trust overwrite is rejected.
- Generated projection races newer control state: stale projection publication is rejected.
- Main-health mutations are authoritative control data and must traverse the same trusted-history path; they are not hidden behind a generated-only skip marker.

Rollback of product `main` does not rewrite `swarm-trust`. A validator rollback must still understand the current trust record and historical quarantine or fail closed. If it cannot, control writes stop until a reviewed forward repair restores compatibility.

## Branch and permission assumptions

- `main` contains trusted validator/workflow code.
- `swarm-control` contains high-churn authoritative coordination data.
- `swarm-trust` contains the last-known-good trust ledger plus ordinary repository history inherited at branch creation.
- Routine workers do not treat `swarm-trust` as a work branch; workflow code advances it only through exact-head CAS after successful validation.
- Repository administrators remain capable of destructive rewrites; Git history and independent review remain the external audit boundary for that class of action.

## Testing and acceptance

Recovery acceptance requires:

- all prior V2/V2.1 hardening tests remain green;
- exact rewritten quarantine blobs remain inert and unchanged;
- all **115** composed malformed-first-write rows remain exact quarantine-only and cannot acquire authority;
- regression tests pin the 65-row foundational canonical inventory digest, the 2 path-divergent foundational identities, the 47-row legacy extension count/identities, the generation-7 dated row, and their uniqueness;
- CI independently proves every composed malformed-event dated path, first-add commit, and first-write blob;
- one-byte quarantine mutation fails;
- quarantined event IDs remain replay-protected;
- strict new events can append after reset;
- SHA/stateDigest cross-pairing is rejected even when both fields are individually well formed;
- workflow binds the digest to archived `trustedControlSha` before transition validation;
- separate trust digest authorizes only when `bootstrap` is false;
- any authoritative state mutation after trust publication fails the trust check;
- bootstrap records cannot authorize PR state;
- regression tests pin all **33** exact invalid->repair worker pairs across the foundational and extension manifests;
- read-only bootstrap CI consumes the executable composed finite manifests rather than maintaining duplicate hard-coded subsets;
- workflow transition validation uses `TRUSTED_CONTROL_SHA`, not `github.event.before`;
- workflow health mutations are not skipped as generated-only state;
- canonical full CI is green on the exact recovery head;
- an independent history-integrity reviewer approves the exact recovery head;
- after merge, a real strict transition produces `bootstrap: false` and a matching live trust digest before normal product PR ownership resumes.

## Measured limitation

This ledger makes trusted-history continuity explicit and prevents failed descendants from laundering their parent, but it is intentionally not a high-throughput external database or Byzantine consensus system. GitHub branch/object integrity, repository permissions, workflow identity, and review history remain trusted infrastructure.

The one-time reset's mutable-history incidents are manually enumerated exact Git commits, and malformed-event quarantine is manually pinned to exact first-write commits and Git blob identities. Any newly discovered invalid pre-anchor artifact therefore blocks bootstrap until this reviewed finite manifest is extended. Normal post-bootstrap history remains strict append-only/trusted state with no compatibility escape hatch.
