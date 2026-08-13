#!/usr/bin/env python3
"""Exact generation-6 additions to the finite 2026-08-11 history reset.

Rows are pinned to the live control-plane inventory and Git provenance. This
module is data only: it does not accept schema aliases, rewrite immutable event
bytes, or weaken canonical worker-status validation.
"""

# Invalid worker records are crossed only by exact bad->canonical repair commits.
FINITE_WORKER_TRANSITIONS = (
    ("0231453262d5ab6e12664e4c89fab3f90bdd28cd", "7bf593ab9fc7100905e90fda0d810bca6644b427"),
    ("2e770074c4a06d9e242fded0f137bba6f053ae0e", "1b5e69abcfd888d5378772eb1c0761800cb8f169"),
    ("274179bd30b8ad8c1c43130bf3fde99addc6cc12", "6d906215dd94f48eda00a5030fb6dc8694e3bf99"),
    ("ad8f78e4996086178541c8674955e894609c576f", "0ab963faea3b6ea554a5172113913ba27be61c25"),
    ("370f6ec7568a78fc98c38a825227f52cb65b6259", "ce4ad38f302fa4b094e3a1e58324352879fce969"),
)

# (eventId, exact filename, exact first-write commit, exact quarantine Git blob SHA-1)
MALFORMED_EVENT_QUARANTINE_ROWS = (
    (
        "evt-20260811T211000Z-sol-20260811-m5q8v2c4-handoff-physics-reconciliation",
        "211000-sol-20260811-m5q8v2c4-handoff-physics-reconciliation.json",
        "da63fb468a9af4ff4b1767df7c985335b5e45b08",
        "f3ed0bc34d02a0db011ca612853c7b797201194d",
    ),
    (
        "evt-sol-20260811-s6p2d9k4-diagnostics-revision-parity-213650",
        "213650-sol-20260811-s6p2d9k4-finding-diagnostics-revision-parity.json",
        "f2637e8ae910b5521a4102fd67ea877da69585a8",
        "2ced05f3d0f82d2fc42bec067bb06b6a1c1b22f3",
    ),
    (
        "evt-sol-20260811-r5k8m3q7-runtime-synthesis-required-213700",
        "213700-sol-20260811-r5k8m3q7-finding-runtime-synthesis-required.json",
        "0962c935fdc83d860c9bf7300724f94519ae57e2",
        "329e61e7e93824d669df34328d00b2893711a2f4",
    ),
    (
        "evt-20260811T213800Z-sol-20260811-g7m4q9v2-harness-lifecycle-audit-request-changes",
        "213800-sol-20260811-g7m4q9v2-harness-lifecycle-audit-request-changes.json",
        "48f6e93d2401abdcf217d6a10a8ece92e567073f",
        "6ee7fa8e55cf9291cfdcbfac6f68962cef37dfd0",
    ),
    (
        "evt-20260811-213900-81idx1th-physics-runtime-synthesis",
        "213900-sol-20260811-81idx1th-dependency-physics-runtime-synthesis.json",
        "02b28a1ba0ce2525a7dada93a26398198402d2ec",
        "4b2ad689d0ad9c0eba985f89eb6c3aae58b70929",
    ),
    (
        "evt-20260811T213950Z-sol-20260811-s56x7q2m-physics-runtime-synthesis",
        "213950-sol-20260811-s56x7q2m-handoff-physics-runtime-synthesis.json",
        "6372bc5f3578efd0885c0030ec9b4cb15825b8ce",
        "f5e2f3e8506ca09a5dcae149fcdca9f8ceddd92b",
    ),
    (
        "evt-sol-20260811-p7d4x9m2-geometry-audit-state-stale-214232",
        "214232-sol-20260811-p7d4x9m2-finding-geometry-audit-state-stale.json",
        "19c5ee7413f238701f9cf98d7a47bd7062537888",
        "9837e9381516873f4d2988920fa4b125ab10a0b5",
    ),
    (
        "evt-20260811T214244Z-sol-20260811-n6c4q8v2-review-result-diagnostics-instance-binding",
        "214244-sol-20260811-n6c4q8v2-review-result-diagnostics-instance-binding.json",
        "b6c8a5352a54c5ffd0df938f8db0a20eb980b943",
        "b451efe7bbb792ac6f8c55f0b3eca2d3aed0871d",
    ),
    (
        "evt-20260811T214300Z-sol-20260811-g7m4q9v2-diagnostics-g6-audit-request-changes",
        "214300-sol-20260811-g7m4q9v2-diagnostics-g6-audit-request-changes.json",
        "279e121fb2a1ddcaba8950c7b0bd1b94166d68c8",
        "c18172e4e5916ee89445bc562f38d7db26e213f8",
    ),
    (
        "evt-sol-20260811-m6r2x9v4-materialdna-validation-diagnostic-bounds-214416",
        "214416-sol-20260811-m6r2x9v4-finding-materialdna-validation-diagnostic-bounds.json",
        "316cd8247439965cec95cc5f44b0bab7ae570f0b",
        "a091cf9b1e3f7f15cc08556fee5e1dd595171655",
    ),
    (
        "evt-sol-20260811-h7k3v9m2-worldentity-no-new-gap-214430",
        "214430-sol-20260811-h7k3v9m2-finding-worldentity-no-new-gap.json",
        "003dc1e238ec1de7fa09cc76de7ea4f4959a9e43",
        "4224b7c4c0911b057f62504a2dfbbe1c457b22c9",
    ),
    (
        "20260811T214731Z-sol-20260811-y7k4m2p9-fidelitymanager-capability-seal",
        "214731-sol-20260811-y7k4m2p9-finding-fidelitymanager-capability-seal.json",
        "dc5b008bd2e5daa7d48661b0c4b8fbd745e4c553",
        "9f7698984027af3a9811f5852083d5f25d98b5ba",
    ),
    (
        "evt-sol-20260811-m6r2x9v4-worldentity-no-additional-gap-214811",
        "214811-sol-20260811-m6r2x9v4-finding-worldentity-no-additional-gap.json",
        "a86199b507d73c9b7faeda332923362868bc3e7f",
        "80fb10563e4587cbfcff8883e9a33617a3e120b1",
    ),
    (
        "evt-sol-20260811-r5n8c2w6-diagnostics-visibility-integrity-214815",
        "214815-sol-20260811-r5n8c2w6-finding-diagnostics-visibility-integrity.json",
        "a931eafa61cd56afafdba989beada98519895a20",
        "4c1a57aa607651a15df9b1a717ad5a2a69d45180",
    ),
    (
        "evt-20260811-215154-81idx1th-harness-lifecycle-g3-review",
        "215154-sol-20260811-81idx1th-harness-lifecycle-g3-review.json",
        "171e86ccf01d35110bfecaed1a0a9a3061c1c9c5",
        "3d6185171f788e97bac8187c7bd51aab2b1f5f45",
    ),
    (
        "evt-sol-20260811-m6r2x9v4-physics-runtime-no-additional-gap-215331",
        "215331-sol-20260811-m6r2x9v4-finding-physics-runtime-no-additional-gap.json",
        "5d4cfbcd7128b5308f29856c3cdcdb719c5d2e33",
        "a75f513bd6cda8d12929038379627d25b7916219",
    ),
    (
        "evt-20260811T215509Z-sol-20260811-n6c4q8v2-handoff-diagnostics-instance-binding-g2",
        "215509-sol-20260811-n6c4q8v2-handoff-diagnostics-instance-binding-g2.json",
        "ad40ffe1b8cfa375534ec0d2c5807d9b681600c4",
        "10829d98d342a75cbec383adfd80df867175a0a9",
    ),
    (
        "evt-sol-20260811-m6r2x9v4-authority-harness-generation-fence-215924",
        "215924-sol-20260811-m6r2x9v4-review-authority-harness-generation-fence.json",
        "aaba5bcab66985052070ed6693111ef05860bff0",
        "d9d4f8b6699e2d4390b7771c73e8fa4dc60676ae",
    ),
    (
        "evt-sol-20260811-v2c7m9q4-authority-no-new-gap-220045",
        "220045-sol-20260811-v2c7m9q4-finding-authority-no-new-gap.json",
        "fde4b0f285ca5770b1b222ed92534f74b1b5bee4",
        "7013bc705835602504bd6231af6f245ad5a04cb5",
    ),
    (
        "evt-20260811T220338Z-sol-20260811-n6c4q8v2-review-result-diagnostics-g7",
        "220338-sol-20260811-n6c4q8v2-review-result-diagnostics-g7.json",
        "69b91ab51d222b70f27d9359edb2a4aa62d8da12",
        "94ba1f9f761ff3d09a4e5d48068facb28cbd4465",
    ),
    (
        "evt-sol-20260811-m6r2x9v4-authority-harness-g4-evidence-220715",
        "220715-sol-20260811-m6r2x9v4-evidence-authority-harness-g4.json",
        "34515074ffb0ca65688a179e5793eb7f885578d0",
        "83a95ccdb6d2f4bb7474a8a04274f82885f94775",
    ),
    (
        "evt-sol-20260811-k3p8v6m1-objectgenome-canonical-payload-budget-221845",
        "221845-sol-20260811-k3p8v6m1-finding-objectgenome-canonical-payload-budget.json",
        "a33c54be083aa67116a8025ddd0be81ff36d7beb",
        "8092d9c66cde37ecc46383f5fb3e37d4f56f122f",
    ),
    (
        "evt-sol-20260811-f8q3m6v2-fidelity-capacity-ceiling-222245",
        "222245-sol-20260811-f8q3m6v2-finding-fidelity-capacity-ceiling.json",
        "a5a58c6776ce93798f811935c1a1c5fe7e3e8852",
        "e8cc5dda0194f2228c310e276ddec397e6ae00ec",
    ),
    (
        "evt-sol-20260811-r4c9m2v7-physics-runtime-no-new-gap-222520",
        "222520-sol-20260811-r4c9m2v7-finding-physics-runtime-no-new-gap.json",
        "adc2ef091b288fbd3628bad5a6a1c323d6e48a42",
        "a32802fc6752c10629160b3b37c3f5e5b714c5b9",
    ),
    (
        "evt-20260811-214300-p6r4n8x2-physics-geometry-mining-no-gap",
        "evt-20260811-214300-p6r4n8x2-physics-geometry-mining-no-gap.json",
        "9b111255cbbdcdf4d5412cb867d8f0562f086d40",
        "4fe8fd8700c6eb0370180d629ed8fc21e7ec1155",
    ),
    (
        "evt-20260811-214900-p6r4n8x2-authority-mining-no-new-gap",
        "evt-20260811-214900-p6r4n8x2-authority-mining-no-new-gap.json",
        "ed0c1773b2d8c691086c49f1812751c932b100fb",
        "4984b8aad95c1b4bd05bb4ce5f63b4e7359c432f",
    ),
    (
        "evt-20260811-215400-p6r4n8x2-physics-geometry-review-request-changes",
        "evt-20260811-215400-p6r4n8x2-physics-geometry-review-request-changes.json",
        "3964c9e9781df8f9d98c34a27c03a64d567d080b",
        "80be391a2a962980f4dca5c7e9915f6532bba764",
    ),
    (
        "evt-sol-20260811-r4k9v2m7-diagnostics-authoritative-projection-231510",
        "231510-sol-20260811-r4k9v2m7-finding-diagnostics-authoritative-projection.json",
        "cced0f689ba5bd0871d0cdb4270d4881acf54a75",
        "3725bbfd2ae3d9b838e2be51f65dcdba2f90e330",
    ),
    (
        "evt-sol-20260811-j4r8p2m6-worldentity-no-fresh-gap-231630",
        "231630-sol-20260811-j4r8p2m6-finding-worldentity-no-fresh-gap.json",
        "b166d68aa235be91627a11b5e9b0c1e468f5797a",
        "a013a74d2164d0ad23ec3bbb1640586afde19a28",
    ),
    (
        "evt-20260811-230901-v6n2q8c4-physics-scale-g6-review",
        "evt-20260811-230901-v6n2q8c4-physics-scale-g6-review.json",
        "b936ea18bbba6fe32a36c61219370812d56622c4",
        "43156457d3cadb0a231e832d4f7d6c8a3efe553f",
    ),
    (
        "evt-20260811-231030-r8n4m2q6-fidelity-registration-capacity-ceiling",
        "evt-20260811-231030-r8n4m2q6-fidelity-registration-capacity-ceiling.json",
        "f41fb79aa5a8d1e26aaf03c5f2a6a7ebdef5446d",
        "0e1a1d36ae2658bb090c7a401f6fe7909f8ef640",
    ),
)


def quarantine_rules() -> dict[str, dict[str, str]]:
    return {
        event_id: {
            "date": "2026-08-11",
            "filename": filename,
            "quarantineOnlyGitBlobSha1": blob_sha,
        }
        for event_id, filename, _first_write_commit, blob_sha in MALFORMED_EVENT_QUARANTINE_ROWS
    }
