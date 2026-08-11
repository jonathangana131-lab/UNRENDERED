# ADR-0005 — Separate Trusted Swarm History Ledger

Status: **Proposed recovery; one-time bootstrap required**  
Date: 2026-08-11  
Scope: UNRENDERED Swarm Control Plane history integrity only; no Roblox/gameplay authority changes.

## Context

Swarm V2 stores high-churn coordination data on `swarm-control` and treats immutable event files as durable audit memory. Detect-only hardening proved that some already-published event paths were rewritten after first publication and that several mutable worker records passed through schema-invalid status values before later owner-side repairs.

The old workflow compared each `swarm-control` push only with `github.event.before`. That is insufficient after a failed transition: a malformed or rewritten control commit can otherwise remain in first-parent history and become a later candidate's apparent baseline. A descendant that looks valid must not launder an invalid ancestor into trusted history.

This is a control-plane architecture defect. It cannot be repaired by silently editing history, weakening validation, broadening status aliases, or declaring the current branch trusted merely because a later projection succeeds.

## Threat model

The control plane must remain fail closed against:

- a failed `swarm-control` commit becoming a trusted later baseline;
- mutation, deletion, relocation, or replay of immutable event IDs;
- rewritten or malformed historical events regaining review/finding authority through compatibility logic;
- a trust record pairing the SHA of snapshot A with the digest of unrelated snapshot B;
- a stale validator, stale trust publisher, or stale generated-state publisher overwriting newer state;
- `bootstrap: true` being mistaken for normal PR authorization;
- self-authored control data selecting itself into a compatibility exception;
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

### Rewritten first-write events

These events had an auditable first-write blob and a later already-published rewrite. The first-write identity remains pinned for audit; the exact rewritten blob is retained only as inert quarantine.

| Event | Audited first-write Git blob | Published rewritten Git blob |
| --- | --- | --- |
| `evt-20260811-073500-q9m4r2-authority-rereview-approve` | `2f0b0221b7995b3862ac6c009804ebb66f715fac` | `8f332b489b9266211ff6c5d2869647eba9b80838` |
| `evt-20260811-073650-q9m4r2-worldentity-sync-hold` | `f9781fd64518c01aa10b460f01aff13adc6635da` | `c7615c531b671d10a56d6a93577fc9c81cb15836` |
| `evt-20260811-080520-h4v8n2-cart-geometry-review` | `a39220b473086229e6b1057b296342175b851af1` | `162e42ab9ab08e7976d61e78ad12bbd088ff13a8` |
| `evt-20260811-083640-ogm5x8q2-objectgenome-support-stack` | `9ef4e62ffb0aac9d4b18cb19911d8d3a25535158` | `c2b99475cdb95940d9a7ca329440880865da02cb` |

The ObjectGenome first write used mixed-case/non-lane routing. Later normalization changed the already-published bytes in place, so the normalized payload cannot regain authority. Its ID/path remain reserved and its exact rewritten blob is inert.

### Malformed first-write events

Two later events were malformed at first publication under the strict V2 schema. They have no valid canonical payload to recover. Their exact first-write/live blobs are therefore **quarantine-only**: the IDs and paths remain reserved, but the payloads can never become review/finding authority.

| Event | First-write commit | Exact quarantine-only Git blob |
| --- | --- | --- |
| `evt-20260811-115302-a05c9683-runtime-transition-audit` | `ba22d42a68b8da027b9c614f25c27ebfa2a19706` | `aa5b394feb3dbb6773beab3c504f8f7100c43f42` |
| `evt-20260811-120452-a05c9683-worldentity-capacity-finding` | `61c781bade06aec2b36c472acc7b336c1c8ce423` | `f45217b586595660161bfaff88ac39ba135d8881` |

For every quarantined event:

- the canonical path and event ID remain permanently reserved;
- the quarantined payload is excluded from authoritative event semantics;
- any byte variant other than the exact reviewed blob fails closed;
- replay at another path fails closed;
- fresh authority must be expressed through a new strict append-only event.

The separate historical event `evt-20260811-081620-mat8c3r1-materialdna-key-grammar` remains at its audited first-write blob `9a7f679ea84600d6a28a8bef02436e5f85fd857e`; it is compatibility-pinned but has no quarantine variant.

## Finite mutable-history reset incidents

Invalid worker statuses remain invalid everywhere. The one-time reset only proves that each exact malformed transition is followed by its exact schema-valid owner-side repair before the bootstrap candidate.

The executable source of truth is `FINITE_WORKER_TRANSITIONS` in `tools/swarm/swarmctl_hardening.py`. The read-only bootstrap workflow imports that manifest directly, emits no trust pair if it is empty, and for **every** row proves:

`invalid commit -> exact repair commit -> BOOTSTRAP_CONTROL_SHA`

The reviewed generation-3 manifest is:

| Invalid commit | Exact repair commit |
| --- | --- |
| `fa5b8f163603fa918c21b28c63bd20e6c25a2add` | `7c62ff9a7b92c4ebe43c38323a5946e04881d3b7` |
| `a99ff757b842fa91ddd893d19fd1d826890ce306` | `a193dd686323c27a7191d525b064c4257120de21` |
| `57245c334fdc19cae855796066f783fb64492c51` | `db830924aa0b65a74c60ee345448f57381bbe137` |
| `8e631ba0da787af6c1c63f6a6dd96920ea7941f2` | `bf852363faa7328d6707233b72909f6c4958d910` |
| `3c54f6ab741ba91d4fdf617cd24713b51ccd2950` | `d0f00752e9b467d71d6875d3d1008c08f134992e` |
| `448cdc5a955192bb88120f22fb9152c43ca7c854` | `67a12da7ece512c0467be3cdd78b3fcd896c9835` |
| `422ec28fbdffee92bbdceb7c111e46c8c23f234b` | `4255e780384b5f5641e53900f201df03506035fa` |
| `55845e836fdaca1a5b9b89f7af7e8a0a5d2b14f8` | `3ca920ee3e7516f141a7c04cf51a67fc545783c8` |
| `b0732a815ff12f099a9ca88363ffadeddec13172` | `a10bae4a46560dcb707c1eefa1888467816a055b` |
| `504d5e72302c5c814961a4de3fa4aadd458887df` | `b99b1715bc3eec419d2c2db9dc6c31d3e7b7b9fd` |
| `2dead634e81fa77f4c4cf9fc52924daa94e1e10c` | `8a8963f14dbeafc14dbe3153a049226ebbaf5dfb` |
| `849a5c07efb10f7070c8e2e803a64216b26a3486` | `70c7cbaddb31e34e50ec5d0e1a4bea965fc7db67` |
| `fecdd4109e7c0b93dae75ea69c8070c7ce0b7b70` | `430362399ed3e2fa8eedbad63ac0842b75fac4db` |
| `d1aa5e7b12b4d8e9917bb77dab3225e4dee4deb8` | `a888f8d1c25050e26427fb40945002585741d618` |
| `8bca8ca61902faf25efe9ef3a004ec032f132c5d` | `5f0cb1f3d5618c3816e008adb6951b83de5c861e` |

The two `j4m8q2v7` rows are intentionally distinct malformed `CLAIMING` episodes and must not be collapsed into one. Several other rows represent unsupported `ACTIVE` registrations; one records an unsupported terminal `DONE`. None of those vocabulary values are accepted by the current validator.

This finite list is not a generic “ignore old failures” mechanism. Any newly discovered invalid pre-anchor transition blocks bootstrap until its exact provenance and repair are reviewed and added to the manifest.

## One-time bootstrap/reset

`swarm-trust` exists before recovery merge with a bootstrap record so workflow fetches are deterministic. A bootstrap record is deliberately **non-authorizing** for product PRs: `verify_trusted_state()` rejects `bootstrap: true` regardless of the digest field.

Before the recovery merge is accepted, read-only CI:

1. resolves one exact live `swarm-control` SHA;
2. loads every finite worker transition from the executable manifest and proves invalid -> repair -> candidate ancestry;
3. validates the exact live snapshot using only the finite immutable-history quarantine above;
4. prints the exact pair `BOOTSTRAP_CONTROL_SHA` and `BOOTSTRAP_STATE_DIGEST`.

The bootstrap ledger may be pinned to that pair only after a fresh CAS check proves `swarm-control` still equals the measured SHA. No moving alias such as `HEAD` or `swarm-control` is accepted as evidence.

During the one explicit bootstrap transition, control validation may read `bootstrap: true` only to verify the archived SHA/digest pair with `verify_trusted_snapshot(..., allow_bootstrap=True)`. That does not authorize product PRs and does not skip digest binding.

Once recovery code is merged to `main`, the next strict `swarm-control` validation starts from the exact bound bootstrap snapshot, validates all later state, and CAS-advances `swarm-trust` to `bootstrap: false`. The resulting reset reason refers to the exact quarantine manifest and the complete `FINITE_WORKER_TRANSITIONS` manifest rather than duplicating a stale subset of commit IDs in workflow text.

If control or trust moves during the operation, the advance fails and must restart from fresh truth. There is no recurring reset command. A future reset requires another explicit reviewed architecture recovery.

## Failure and rollback behavior

- Missing `swarm-trust`: PR ownership and control validation fail closed.
- `bootstrap: true`: product PR authorization fails closed.
- Archived `trustedControlSha` digest differs from `trustedStateDigest`: transition validation fails before the trusted baseline is used.
- Trust digest differs from current live state: product PR authorization fails closed.
- Candidate control invalid: trust branch does not move.
- Trusted snapshot invalid under current code: validation fails; no newer baseline is substituted to escape the failure.
- Bootstrap candidate does not descend from every exact worker repair: no bootstrap pair is emitted.
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
- exact malformed-first-write blobs remain quarantine-only and cannot acquire authority;
- one-byte quarantine mutation fails;
- quarantined event IDs remain replay-protected;
- strict new events can append after reset;
- SHA/stateDigest cross-pairing is rejected even when both fields are individually well formed;
- workflow binds the digest to archived `trustedControlSha` before transition validation;
- separate trust digest authorizes only when `bootstrap` is false;
- any authoritative state mutation after trust publication fails the trust check;
- bootstrap records cannot authorize PR state;
- regression tests pin all 15 exact invalid->repair pairs;
- read-only bootstrap CI consumes the executable finite manifest rather than maintaining a second hard-coded subset;
- workflow transition validation uses `TRUSTED_CONTROL_SHA`, not `github.event.before`;
- workflow health mutations are not skipped as generated-only state;
- canonical full CI is green on the exact recovery head;
- an independent history-integrity reviewer approves the exact recovery head;
- after merge, a real strict transition produces `bootstrap: false` and a matching live trust digest before normal product PR ownership resumes.

## Measured limitation

This ledger makes trusted-history continuity explicit and prevents failed descendants from laundering their parent, but it is intentionally not a high-throughput external database or Byzantine consensus system. GitHub branch/object integrity, repository permissions, workflow identity, and review history remain trusted infrastructure.

The one-time reset's mutable-history exceptions are manually enumerated exact Git commits, and immutable-event quarantine is manually pinned to exact Git blob identities. Any newly discovered invalid pre-anchor artifact therefore blocks bootstrap until this reviewed finite manifest is extended. Normal post-bootstrap history remains strict append-only/trusted state with no compatibility escape hatch.
