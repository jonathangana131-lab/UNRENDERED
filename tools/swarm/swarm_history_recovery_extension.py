#!/usr/bin/env python3
"""Exact generation-4/5/6/7/8/9 additions to the finite history reset.

These rows were measured from live swarm-control by read-only bootstrap inventory
or exact Git provenance inspection. They are data only: no schema aliasing,
inference, or payload rewrites are permitted. Immutable events remain
quarantine-only authority.
"""

import swarm_history_recovery_generation6 as _generation6
import swarm_history_recovery_generation6_tail as _generation6_tail

# One invalid worker record was first published with the unsupported REVIEWING
# status and later moved through another unsupported alias before a claim-aware
# mutable repair returned it to canonical IDLE. Pin the first invalid commit and
# exact repair commit; all intermediate snapshots remain strict-invalid. Later
# generation-6/7 worker defects are also crossed only by exact bad->repair commits.
GENERATION7_FINITE_WORKER_TRANSITIONS = (
    ("b101e9c156befdc22d89195559f205d0d86b95a1", "512a1fa6051fe956936a203cc81f813f62470336"),
    ("1a1300335ddc57f2913b024260f3c82a17a2916e", "493f9b34cacfcc90a695814434e24b70694566aa"),
    ("ade84dab3f97b7fe022425f5258b95dd36d15e2d", "7f58400bea56171e559867e74ff112285641f1f2"),
    ("81c61efc4eb063f8a5c8ddbfd7029376e2d94953", "15371ed8d9ccb6c917544256482aa9d1241c6a74"),
    ("1fa04ae307f1f7e9a485a849d0ade69a347e1130", "984e83ad9a425e68ffb26b04734c4c330003e651"),
    ("e631f9e1e2681a64cff4d73a3f3d53b8f54e635e", "687c9dbc579f635851dd0e69cbd62dc5736bf44b"),
)

FINITE_WORKER_TRANSITIONS = (
    ("b5bd3a372a4d4f044873c9bedf86d82e7cc92c23", "ef789a2e2e1b56d7a816b8c2be39412f5b6f0ccc"),
) + _generation6.FINITE_WORKER_TRANSITIONS + GENERATION7_FINITE_WORKER_TRANSITIONS

# (eventId, exact filename, exact first-write commit, exact quarantine Git blob SHA-1)
# Every row has exactly one first-add commit and no later byte rewrite in the
# audited control history. The workflow independently re-proves those facts from
# Git before a bootstrap candidate can be trusted.
MALFORMED_EVENT_QUARANTINE_ROWS = (
    (
        "evt-sol-20260811-6v4k9n2c-worldentity-metadata-string-budget-211117",
        "211117-sol-20260811-6v4k9n2c-finding-worldentity-metadata-string-budget.json",
        "3e3f626fccb5638086f96c819fc7414e70e8c91a",
        "b3acafc68679ebb6e331c83a6d1f9b73c8fbb9da",
    ),
    (
        "evt-sol-20260811-6v4k9n2c-worldentity-g5-metadata-budget-211822",
        "211822-sol-20260811-6v4k9n2c-worldentity-g5-metadata-budget-inherited.json",
        "3e54aded07ed8f235104df841026f89cdf4ccf6f",
        "d65ba9dead0b8d870d09ef4a304dbfd4c000dd7e",
    ),
    (
        "evt-20260811T212100Z-sol-20260811-v9q2m7c4-handoff-physics-runtime-entityid-review",
        "212100-sol-20260811-v9q2m7c4-handoff-physics-runtime-entityid-review.json",
        "c6adaac56e4a8d95ed0ddb0f3d350e1455829e31",
        "4f27fb29b455ea3459c1a415655cd2197d36e10f",
    ),
    (
        "evt-20260811T213200Z-sol-20260811-k5m8v2c6-handoff-harness-lifecycle-g2",
        "213200-sol-20260811-k5m8v2c6-handoff-harness-lifecycle-g2.json",
        "d9e4ee7f7755d5b19498f3b37cc1df73bdb793de",
        "074eea30dfd8ebcbf86ffaa9e21cd3f2cb7d0df5",
    ),
    (
        "evt-20260811T210500Z-sol-20260811-c7p4m8v2-handoff-content-reconciliation",
        "210500-sol-20260811-c7p4m8v2-handoff-content-reconciliation.json",
        "be4caea3394068a2883045842bf1d132e37cd157",
        "713d54c453faa65e89875e69499444d5a7644d3f",
    ),
    (
        "evt-20260811-210630-j9v4m2q7-authority-harness-capability-reconfirm",
        "evt-20260811-210630-j9v4m2q7-authority-harness-capability-reconfirm.json",
        "0443c405bcc2f5be7eb5604e778ec45456b5fc54",
        "8ff567f0cacb70b4aa2477b604cfad721f8ca020",
    ),
    (
        "evt-20260811-210810-s56t3v9-worldentity-g5-evidence",
        "evt-20260811-210810-s56t3v9-worldentity-g5-evidence.json",
        "fd66ea9a0dfd5e5c7a7c25c558aecf0de8685e4f",
        "6e95296ab3c41afdcec672de5fecae9016b61505",
    ),
    (
        "evt-20260811-210840-c9v2m7q4-diagnostics-duplicate-root-expected-red",
        "evt-20260811-210840-c9v2m7q4-diagnostics-duplicate-root-expected-red.json",
        "703fe3c4bd4e4547c11bf2f79b22df02bb795a9f",
        "655763e0f76eff22719c8f99e04089e11782af1f",
    ),
    (
        "evt-20260811-210930-s56t3v9-worldentity-g5-handoff",
        "evt-20260811-210930-s56t3v9-worldentity-g5-handoff.json",
        "79f6dbb2728a4882bd7b1cf673252b32170af2ce",
        "fe551bb0f176f18dc21b728ea0933ba386d46f5d",
    ),
    (
        "evt-20260811-211300-r5m8c2q7-authority-mining-convergence",
        "evt-20260811-211300-r5m8c2q7-authority-mining-convergence.json",
        "3994e1ee8256f74e32fe1031bdf53c72629fe296",
        "081dade1e97cd41181be67a37382b2d44c3bf4bb",
    ),
    (
        "evt-20260811-212800-c9v2m7q4-worldentity-retained-text-bounds",
        "evt-20260811-212800-c9v2m7q4-worldentity-retained-text-bounds.json",
        "d6b1a8017384c16aced06d637762e4343da1105e",
        "f841af8c6294ba49b89fec4f106b9bfa4cbdce1c",
    ),
    (
        "evt-20260811-213400-c9v2m7q4-runtime-recipe-entity-container-shape",
        "evt-20260811-213400-c9v2m7q4-runtime-recipe-entity-container-shape.json",
        "5fd3e69bd34f35abd4c03485aed15879163d95e6",
        "6bcb06468953ac55ab2cfec458ecb60b4d98d114",
    ),
) + _generation6.MALFORMED_EVENT_QUARANTINE_ROWS + _generation6_tail.MALFORMED_EVENT_QUARANTINE_ROWS

# Later recovery history must preserve its real event directory rather than being
# forced through the original 2026-08-11 filename-only row shape.
# (eventId, date, exact filename, exact first-write commit, exact quarantine Git blob SHA-1)
DATED_MALFORMED_EVENT_QUARANTINE_ROWS = (
    (
        "evt-20260812T080700Z-sol-20260812-k7m4q9v2-handoff-diagnostics-generation10",
        "2026-08-12",
        "080700-sol-20260812-k7m4q9v2-handoff-diagnostics-generation10.json",
        "3e8d11601444a2681eee5f030a0597fbee55b0bf",
        "706647f87553ce70e796da306afe58216332f0bb",
    ),
    (
        "evt-20260812T105120Z-sol-20260812-g43k9m2v-handoff-diagnostics-generation13",
        "2026-08-12",
        "105120-sol-20260812-g43k9m2v-handoff-diagnostics-generation13.json",
        "d3b3bf56eff635785321e4fce433e5e695bd136a",
        "966a8362e3aebe5cadedee586114ec3ef4618bf5",
    ),
    (
        "evt-20260812T110830Z-sol-20260812-g43k9m2v-handoff-diagnostics-generation14",
        "2026-08-12",
        "110830-sol-20260812-g43k9m2v-handoff-diagnostics-generation14.json",
        "a058912e408b486ea9411b2bfff7359a3c812c5d",
        "cb440ccabb5459252d36b782ba955f8a2aa37abd",
    ),
    (
        "evt-20260812T111830Z-sol-20260812-g43k9m2v-handoff-diagnostics-generation15",
        "2026-08-12",
        "111830-sol-20260812-g43k9m2v-handoff-diagnostics-generation15.json",
        "7cc2c334628dc00197a3f814491c8b3ea6767b72",
        "8eef4f40d414f4f43c03813c3276b8dd095036b9",
    ),
    (
        "evt-20260812T112500Z-sol-20260812-g43k9m2v-handoff-diagnostics-generation16",
        "2026-08-12",
        "112500-sol-20260812-g43k9m2v-handoff-diagnostics-generation16.json",
        "92843914017c38b861b3ecd9cbb758b52d3428eb",
        "b7a4bab4760413bdcd629a1a8e4b0af4e4291964",
    ),
    (
        "evt-20260813-225110-j4n7q2v9-diagnostics-docs-g3-review-request",
        "2026-08-13",
        "225110-sol-20260813-j4n7q2v9-review-request-diagnostics-docs-g3.json",
        "af25c84703c1bde8beb84cdb1853ebd07aea6bea",
        "835076ffce9bf4f355aa9f9b6d85f54177543421",
    ),
    (
        "evt-20260813-224945-f4q9n2c7-fidelity-extra-keys",
        "2026-08-13",
        "evt-20260813-224945-f4q9n2c7-fidelity-extra-keys.json",
        "407732f50438acc4f11da30cca17c348936e73f8",
        "0dd395b2757e7e3685b5c79aa6d6852ee50e85f3",
    ),
    (
        "evt-20260813-225000-8fa445-authority-current-main-no-new-gap",
        "2026-08-13",
        "evt-20260813-225000-8fa445-authority-current-main-no-new-gap.json",
        "47e9d65cb46852f396cfe109836623f4063d0d03",
        "6503ee1458957314660adab6ef1e56793e775175",
    ),
)


def malformed_event_quarantine_rows_with_dates() -> tuple[tuple[str, str, str, str, str], ...]:
    legacy = tuple(
        (event_id, "2026-08-11", filename, first_write_commit, blob_sha)
        for event_id, filename, first_write_commit, blob_sha in MALFORMED_EVENT_QUARANTINE_ROWS
    )
    return legacy + DATED_MALFORMED_EVENT_QUARANTINE_ROWS


def quarantine_rules() -> dict[str, dict[str, str]]:
    rules = {
        event_id: {
            "date": "2026-08-11",
            "filename": filename,
            "quarantineOnlyGitBlobSha1": blob_sha,
        }
        for event_id, filename, _first_write_commit, blob_sha in MALFORMED_EVENT_QUARANTINE_ROWS
    }
    for event_id, date, filename, _first_write_commit, blob_sha in DATED_MALFORMED_EVENT_QUARANTINE_ROWS:
        rules[event_id] = {
            "date": date,
            "filename": filename,
            "quarantineOnlyGitBlobSha1": blob_sha,
        }
    return rules
