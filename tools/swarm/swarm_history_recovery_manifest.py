#!/usr/bin/env python3
"""Finite exact provenance for the one-time 2026-08-11 Swarm history reset.

This module is data only. It must never infer compatibility from live control state.
Malformed immutable events listed here are exact quarantine-only artifacts: their
IDs and paths remain reserved, but their payloads never regain review/finding authority.
"""

FINITE_WORKER_TRANSITIONS = (
    ("fa5b8f163603fa918c21b28c63bd20e6c25a2add", "7c62ff9a7b92c4ebe43c38323a5946e04881d3b7"),
    ("a99ff757b842fa91ddd893d19fd1d826890ce306", "a193dd686323c27a7191d525b064c4257120de21"),
    ("57245c334fdc19cae855796066f783fb64492c51", "db830924aa0b65a74c60ee345448f57381bbe137"),
    ("8e631ba0da787af6c1c63f6a6dd96920ea7941f2", "bf852363faa7328d6707233b72909f6c4958d910"),
    ("3c54f6ab741ba91d4fdf617cd24713b51ccd2950", "d0f00752e9b467d71d6875d3d1008c08f134992e"),
    ("448cdc5a955192bb88120f22fb9152c43ca7c854", "67a12da7ece512c0467be3cdd78b3fcd896c9835"),
    ("422ec28fbdffee92bbdceb7c111e46c8c23f234b", "4255e780384b5f5641e53900f201df03506035fa"),
    ("55845e836fdaca1a5b9b89f7af7e8a0a5d2b14f8", "3ca920ee3e7516f141a7c04cf51a67fc545783c8"),
    ("b0732a815ff12f099a9ca88363ffadeddec13172", "a10bae4a46560dcb707c1eefa1888467816a055b"),
    ("504d5e72302c5c814961a4de3fa4aadd458887df", "b99b1715bc3eec419d2c2db9dc6c31d3e7b7b9fd"),
    ("2dead634e81fa77f4c4cf9fc52924daa94e1e10c", "8a8963f14dbeafc14dbe3153a049226ebbaf5dfb"),
    ("849a5c07efb10f7070c8e2e803a64216b26a3486", "70c7cbaddb31e34e50ec5d0e1a4bea965fc7db67"),
    ("fecdd4109e7c0b93dae75ea69c8070c7ce0b7b70", "430362399ed3e2fa8eedbad63ac0842b75fac4db"),
    ("d1aa5e7b12b4d8e9917bb77dab3225e4dee4deb8", "a888f8d1c25050e26427fb40945002585741d618"),
    ("8bca8ca61902faf25efe9ef3a004ec032f132c5d", "5f0cb1f3d5618c3816e008adb6951b83de5c861e"),
    ("66e482d3b424c63c4bed277aafa897f0fa051bbc", "96f1bce06bb69738dc737ec01f51170ffdaa3667"),
    ("eeb0e1588f1daf3bb1a556b641bd0c46d172b83f", "0b7bd8164ffbc2846a6fe6036965535df7e1edc9"),
    ("d37f0480847b77459c3c23d7a020a94a40e69980", "489bb9662be6774bae676c17101c04f1bc74453a"),
    ("38b8da43ae73ecc2e25159e636811079f75dc984", "d2b77a7eb6924a58b98651a118a12a5ba89f74c3"),
    ("22ebea9fbe0761c34905b1e0cc5a025f2ce32798", "c58b15a40b3a955ac9219a956c9230b0e0eba869"),
    ("23dd0ab94d7773349d7250704c61a9585a771db3", "3b6c6708fb3eed9846ca60b98e1a912c308cb605"),
)

# (eventId, exact first-write commit, exact quarantine-only Git blob SHA-1)
MALFORMED_EVENT_QUARANTINE = (
    ("evt-20260811-083838-v7k3m9-fidelity-review-result", "97f3338e519780ed5207d6c37823399720ed12b1", "d31c8c58ed65da79e4b2ede546261a8bd022ff9d"),
    ("evt-20260811-085000-r4k8m2z7-objectgenome-audit-verdict", "bd37d5e1f17ab24cc111ff49e5c96e8855136acb", "55727687c329a38b89a3fe5bd67e250e7af2bc57"),
    ("evt-20260811-085405-k3m9v6-worldentity-boundary-gap", "82d74248dc5d4f7e3c44bfb6bd21d43944ae61fc", "998cc4bdd689e1e5da64d2aed276455b8fb07bf0"),
    ("evt-20260811-085900-r4k8m2z7-materialdna-counter-audit", "ca7d5f40aa912e7a82ea6b7a4c670548eb3770d3", "4522c5df54a841e3891153b0839a539753570727"),
    ("evt-20260811-090900-r4k8m2z7-physics-geometry-audit", "2bd0cc77dd6902c7e9265b1706f4c82eea9556f3", "fedcf768925c5cf6b4c10aadcef10d2626781940"),
    ("evt-20260811-091130-q8m4v2c7-authority-stale-handle", "8c4c389c4f785739cf2be56ffd7cd45e4a6b71d8", "3de2da2a667ee2893799e1ea19702e6ca24a94dc"),
    ("evt-20260811-091330-q6m2v8k5-fidelity-review-result", "a31773fa31bdc0b29b4e671fce7dcf71e1f722dc", "48dff11db5afc999340a5638829cb0e16617fc18"),
    ("evt-20260811-092100-r4k8m2z7-objectgenome-g2-audit", "629f8d10790ab416513ee4b06a250927895b2af4", "69dfb5172b5fb7f0ac3cba31838f535a4c58e10c"),
    ("evt-20260811-092130-q6m2v8k5-worldentity-diagnostic-byte-bound", "07915faa35d18b10bf9a7f9d5bbb621502ed4f0a", "74568dc211636b4967ba96139c8e5ee1ab2380db"),
    ("evt-20260811-092249-9a2f6c1d-fidelity-mining-no-duplicate", "b2c54ffa9cd516f196313c75540797850b6a55c7", "822c48c61c219bf8526454df21469e7b635df220"),
    ("evt-20260811-092320-9a2f6c1d-fidelity-mining-released", "7f8af7f1564cca360a886539bd8fc2b76c5d7934", "8e1dbeb799f1bb433974122c05423dc89fbfd1f9"),
    ("evt-20260811-092700-q5x8n3z2-diagnostics-instance-binding-prereq", "4d24dc1f46ebd0455593ec7ce6f10d0fea87aa1d", "bd07e3e4f4ccd6361234db771f8930b9755f7b19"),
    ("evt-20260811-092900-r4k8m2z7-worldentity-g3-audit", "b1aa17fc347eeb72bb4bf8cb94ba7f7d3419eff1", "2837d763b43e72e99f7cb4760b31275741c5bcbb"),
    ("evt-20260811-093035-q6m2v8k5-materialdna-validation-budgets", "9e7a41d18cb6a4ccc4259a14057c6eaeb88057c4", "d862707ce0ff9e90de2db129fe6eae316600eba8"),
    ("evt-20260811-093305-4e7b1c9a-cart-audit-sync-required", "9aaf19a222584189199296f144603e085425a67c", "4c589bb2fad2dd8dde1d717dbf4eff6a65949aaa"),
    ("evt-20260811-093435-q6m2v8k5-objectgenome-review-result", "830bd1a89a59d46230edbfb5eeab351eefd0fc55", "71f7162f094c839b67f00418404fb90b89860734"),
    ("evt-20260811-093545-4e7b1c9a-cart-audit-released", "39b6ff508951d86caa6ef6cd6c9d2e23cae3431c", "f5cec635b69e633e2aa070cfd8950322f5f59b8c"),
    ("evt-20260811-093700-r4k8m2z7-reality-audit-handoff", "f34d739996f9c7560b12970ae5bbf4d49eff9a61", "d10f4e39e47b8004f317b30807a89399d9afb6fe"),
    ("evt-20260811-093850-q6m2v8k5-physics-fixture-com-drift", "8ffd8daffacb7e2fa9bda18663b9e5ef63fdf9d6", "35d28445312623b24811e828627c8399889d969e"),
    ("evt-20260811-094300-bbd7b1e6-worldentity-mining-exhausted", "a452866e1127143535e6a37485fbe256f2fe93f5", "2a975e5603396e9b98492a75e2d7dab9dbaec699"),
    ("evt-20260811-094340-7d2a9c4e-diagnostics-audit-released", "f54634b23ba1bab37a136d1933525ba36a6fd1a5", "85f36d00d9f234c9c9ac126843369658a20de27a"),
    ("evt-20260811-094530-q7n2m5x8-fixture-com-closure", "b4cbc7bfed551951f6918ff419912157b3b4ad25", "2a39d87f032a43794dc944c3dc3275d7a84a327d"),
    ("evt-20260811-094700-bbd7b1e6-diagnostics-root-provenance", "114340066d65586514c611641eacfbb202fb5811", "c9bcfeec7f6f72128cc29a529a76342f7c3e7b23"),
    ("evt-20260811-095000-5c8e2a7d-objectgenome-runner-scope", "cb53da99d39d858340ee38bb5784fff1d67ac308", "c8f4e8760bea3ba748d06306e4d0772d2e7e6850"),
    ("evt-20260811-095100-d5a9a48b-physics-root-identity", "3d56eca9274cf24b7997d9963ef7236037b5f48a", "3fb9afb4b2a7eeca21266f3e99a124dfd24bedcd"),
    ("evt-20260811-095200-materialdna-bounded-scan-u7m3c9q4", "98fcd05697b16e04f055794a7918622b2524e7bf", "5f111518872a6eb8a851820b06115b6540d78881"),
    ("evt-20260811-095230-5c8e2a7d-objectgenome-audit-released", "41affc60733d9d953cfae000b7c99179f40c80a6", "a266e6c7e7baee0c8bb71483850c428f6f7d337e"),
    ("evt-20260811-095400-p7q4n8-diagnostics-instance-binding-audit", "174f67e26ff5fbd63300f57877bf6c1a86cc0967", "87493abfe3e6006c1aa077559972102d455adeab"),
    ("evt-20260811-095600-r4k8m2z7-reality-completion-triage", "7aed01b73f85a69a509ad5704a9febb39681c60d", "53362351d24c38c05aed0cfd8e9212c766f229a8"),
    ("evt-20260811-095700-p7q4n8-diagnostics-instance-binding-audit-correction", "7093919754718e9af9eb4ffe775b65afc5bd9638", "37d3007bf43d8246cb36ba451720c16c21808d91"),
    ("evt-20260811-095900-materialdna-counter-audit-u7m3c9q4", "9b1f6f6bba37235a21fcc8ddefcf1f2dab1765f1", "e335d145bf860a24a49ba310e678305b4ec9f151"),
    ("evt-20260811-100300-p7q4n8-reality-audit-approve", "9cb21b0e3d90bbb7efe1b6df6c7dce4e220deae5", "80768413b16840299be3c03e0236aa8cc14d7654"),
    ("evt-20260811-100500-r4k8m2z7-authority-completion-review", "1979564626a02efbcfe2047f8b201704e70173c1", "63af857060c90c466655763da0e6ae93ac18c408"),
    ("evt-20260811-100800-z6m2q8r4-worldentity-mutation-identity-red", "1584dc6827afdc4c5ec830c4e192f28912d1571a", "15bc8ce0b8b0b403442156b085af4c5c0e258e79"),
    ("evt-20260811-100900-z6m2q8r4-objectgenome-diagnostic-red", "c43d52f5cc568965482cae2137db16604dc6d27f", "3007a12e12c8f3d51a757bba5efe962370d0f0f3"),
    ("evt-20260811-101200-z6m2q8r4-fidelity-test-slot-reconciled", "b59a8b0042ec79ab50b1444996a2ebc27821f003", "6b1b3e4fbc54534330aa552fd16feff880cfa45d"),
    ("evt-20260811-101400-r4k8m2z7-content-completion-review", "212e4671b91eab6ce0289a4e6882e6f95a44e1ef", "b844785f28b842bcc64b68de2be4a05bd4121a11"),
    ("evt-20260811-115302-a05c9683-runtime-transition-audit", "ba22d42a68b8da027b9c614f25c27ebfa2a19706", "aa5b394feb3dbb6773beab3c504f8f7100c43f42"),
    ("evt-20260811-115600-j4m8q2v7-physics-envelope-drift-overflow", "0be2df075bc1a4b3d54867952751775535199782", "99530a7ad3e813189301479b83ef57e1e781b258"),
    ("evt-20260811-115603-x9q4m7v2-authority-two-client-schema-provenance", "67594bd1063c5421edc18d65628d629b67593922", "87666bf583275e7c40759886bd045171701ae720"),
    ("evt-20260811-115620-cd3bb0-diagnostics-exact-instance", "ca8c25a58e0ea1bb6eac508197c8072b68cb331c", "f84742074a856715b239917c12f747402e79f020"),
    ("evt-20260811-115804-p6m2x8v4-worldentity-review-result", "feb28b1d7469e34edeb1ce54f4c1c67e37b22e3e", "0c0cc50d60be0eb9e8eea217a1ef06449c8a6fa4"),
    ("evt-20260811-115810-j4m8q2v7-physics-overflow-handoff", "1b670efe403a12cf5f319b9fcc40140195b6d7cb", "fdd47237040f566a59a828bb080ad0dceb27dfd7"),
    ("evt-20260811-115900-cd3bb0-diagnostics-readout-review", "66877e22aacf34f78502014dc1606e402c217fb7", "4ef9034d0e8b4f18dd4418d40df65de055b830b3"),
    ("evt-20260811-120452-a05c9683-worldentity-capacity-finding", "1da5f4fb0dcefed6c8cd5a4c2c0d7fed5429ee9f", "f45217b586595660161bfaff88ac39ba135d8881"),
    ("evt-20260811-120522-p6m2x8v4-authority-review-result", "c66ad753b853d35d61f1b1673a9892d0f107ef58", "3af080afda21f96c3724fc4fc608e7c80badfebb"),
    ("evt-20260811-120700-j4m8q2v7-physics-runtime-mining-handoff", "57d41ff342fcc01a9cc4077e0213611f53b6aee2", "b43acecef3df2790889b6b9a5a7f6da2c7265ebf"),
    ("evt-20260811-120823-p6m2x8v4-diagnostics-instance-review-result", "93c4af4c2bbe4f6ec730e2e976ad15e7f212cbe2", "c9b164a5ddaa082fbe40078d6a5ee15a0e228c9f"),
    ("evt-20260811-121000-cd3bb0-envelope-overflow-review", "7e07aa58620b77ac3bc87dbb49298015980a42b6", "fbb913abae036922481443464cdd6f6ca29e331d"),
    ("evt-20260811-121130-cd3bb0-fidelity-nested-unwind-review", "fc98c7b12aa5f171b1c85dafce1a72a42b5f7b6f", "19ba78c1958e25af0147548541599432f5e89bf0"),
    ("evt-20260811-121300-cd3bb0-diagnostics-adversary-review", "9c09bbf280da171c8735159ea47eb62c7cf202a0", "f0c01426c9ffca58ccc5806436a6cfa56fb2ad91"),
    ("evt-20260811-121404-p6m2x8v4-runtime-transition-review-result", "8f9387f76eddb5b6248720df3edcb8346ac793c7", "b84451c14641d3f96fc2a102fc6e812460ad6926"),
    ("evt-20260811-121520-j4m8q2v7-worldentity-metadata-string-budget", "0fbca6800d1707ca2e659d6be8e70eea312fa4b4", "779ea0b317d301b42da14e830039531acbe59c68"),
    ("evt-20260811-121700-j4m8q2v7-worldentity-mining-handoff", "dd93fc679b2c4c36bd29b148bad95abb9d737b19", "7cecf8d46318d238a505e3761e047f39385b4e65"),
    ("evt-20260811-122440-j4m8q2v7-diagnostics-root-truth-binding", "cacd4e1e934e67c906d302c5b23011443a85fcf8", "b02457f2cab34bb31924c464022d5fa659e344e6"),
    ("evt-20260811-122600-j4m8q2v7-diagnostics-mining-handoff", "6e233e9fdcf21cc6e33ddacde88d3a4f32d0507d", "86f1e06f2875af6258fcef3908af341d19118961"),
    ("evt-20260811-123100-j4m8q2v7-authority-miner-reroute", "5260dd5c9313b7c38063dcdaf656d3b19df22325", "0f6658c14d6c656ea30fbe220a5eb75853ed530a"),
    ("evt-20260811-123820-j4m8q2v7-authority-harness-destroy-capability", "a3412e5171ed84279a5709c8b5a37e4e94b0dd3c", "ff1d24653dce6422856410637c5899bc38a56674"),
    ("evt-20260811-124000-j4m8q2v7-authority-mining-handoff", "ed2072803cd5e3c6d2e5a3cd52ce963734480347", "28f529b39288e152e65b90194dc7a068037a2967"),
    ("evt-20260811-124210-j4m8q2v7-authority-teardown-g2-handoff", "e3c0696a38badd9363d264447faecf12c178f331", "c507c86c094c445f2c8abbb8d506906d11e38549"),
    ("evt-20260811-124820-j4m8q2v7-physics-geometry-mining-no-new-lane", "8f54c1ce9ddfdf1110466ba5e13ca8dc3863fc20", "8f3085b4c1a92293ca33f7debb8ef8a6d4fca1db"),
    ("evt-20260811-201639-befff499-fidelity-review-result", "83fb0a3f9efd522d413807f01cbe352dd4267ae6", "0af357fffacb5a17a64815cabd5ec6150986ef50"),
    ("evt-20260811-202049-befff499-fidelity-generation4-handoff", "92036da7b1f20f7a0fb2e48e0589cbb3be2722cc", "16bea9cb03caea25ac33e0459f6ca822401c639c"),
    ("evt-20260811-203400-q3m7v9c2-objectgenome-bounds-finding", "f6468caadf0675dec0b51e54a7f5a0824be90771", "f2f4e143b91cb105aca9fe404eb7b383ef536f55"),
    ("evt-20260811-203731-b6q1x8v3-physics-geometry-review-result", "332dbb965cdf99bc1b073d2918a67d05611a8bb7", "2744ff918561715243d489a5985bc45f321ecce5"),
)

# Some malformed legacy HANDOFF writers used a filename that does not equal eventId.
# Keep those exact path identities separate so the original 65-row manifest digest
# remains stable and every compatibility expansion stays reviewer-visible.
MALFORMED_EVENT_QUARANTINE_PATHS = (
    (
        "evt-20260811T210500Z-sol-20260811-c7p4m8v2-handoff-content-reconciliation",
        "210500-sol-20260811-c7p4m8v2-handoff-content-reconciliation.json",
        "be4caea3394068a2883045842bf1d132e37cd157",
        "713d54c453faa65e89875e69499444d5a7644d3f",
    ),
    (
        "evt-20260811T211000Z-sol-20260811-m5q8v2c4-handoff-physics-reconciliation",
        "211000-sol-20260811-m5q8v2c4-handoff-physics-reconciliation.json",
        "da63fb468a9af4ff4b1767df7c985335b5e45b08",
        "f3ed0bc34d02a0db011ca612853c7b797201194d",
    ),
)


def malformed_event_quarantine_rows() -> tuple[tuple[str, str, str, str], ...]:
    """Return normalized (eventId, filename, first-write, blob) rows."""
    canonical_paths = tuple(
        (event_id, f"{event_id}.json", first_write, blob_sha)
        for event_id, first_write, blob_sha in MALFORMED_EVENT_QUARANTINE
    )
    return canonical_paths + MALFORMED_EVENT_QUARANTINE_PATHS


def quarantine_rules() -> dict[str, dict[str, str]]:
    """Return validator rules while keeping first-write provenance reviewable separately."""
    return {
        event_id: {
            "date": "2026-08-11",
            "filename": filename,
            "quarantineOnlyGitBlobSha1": blob_sha,
        }
        for event_id, filename, _first_write_commit, blob_sha in malformed_event_quarantine_rows()
    }
