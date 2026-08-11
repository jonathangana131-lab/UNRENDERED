#!/usr/bin/env python3
"""Exact generation-4/5/6 additions to the finite 2026-08-11 history reset.

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
# generation-6 worker defects are also crossed only by exact bad->repair commits.
FINITE_WORKER_TRANSITIONS = (
    ("b5bd3a372a4d4f044873c9bedf86d82e7cc92c23", "ef789a2e2e1b56d7a816b8c2be39412f5b6f0ccc"),
) + _generation6.FINITE_WORKER_TRANSITIONS

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


def quarantine_rules() -> dict[str, dict[str, str]]:
    return {
        event_id: {
            "date": "2026-08-11",
            "filename": filename,
            "quarantineOnlyGitBlobSha1": blob_sha,
        }
        for event_id, filename, _first_write_commit, blob_sha in MALFORMED_EVENT_QUARANTINE_ROWS
    }
