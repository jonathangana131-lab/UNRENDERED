#!/usr/bin/env python3
"""Exact-data guards for the finite trusted-history recovery extension."""
from __future__ import annotations

import unittest

import swarm_history_recovery_extension as extension


class RecoveryExtensionTests(unittest.TestCase):
    def test_worker_transitions_are_exact_and_finite(self):
        self.assertEqual(
            extension.FINITE_WORKER_TRANSITIONS,
            (
                (
                    "b5bd3a372a4d4f044873c9bedf86d82e7cc92c23",
                    "ef789a2e2e1b56d7a816b8c2be39412f5b6f0ccc",
                ),
                (
                    "0231453262d5ab6e12664e4c89fab3f90bdd28cd",
                    "7bf593ab9fc7100905e90fda0d810bca6644b427",
                ),
                (
                    "2e770074c4a06d9e242fded0f137bba6f053ae0e",
                    "1b5e69abcfd888d5378772eb1c0761800cb8f169",
                ),
                (
                    "274179bd30b8ad8c1c43130bf3fde99addc6cc12",
                    "6d906215dd94f48eda00a5030fb6dc8694e3bf99",
                ),
            ),
        )

    def test_measured_quarantine_rows_are_exact_and_unique(self):
        rows = extension.MALFORMED_EVENT_QUARANTINE_ROWS
        self.assertEqual(len(rows), 39)
        self.assertEqual(len({row[0] for row in rows}), len(rows))
        self.assertEqual(len({row[1] for row in rows}), len(rows))
        self.assertIn(
            (
                "evt-20260811T210500Z-sol-20260811-c7p4m8v2-handoff-content-reconciliation",
                "210500-sol-20260811-c7p4m8v2-handoff-content-reconciliation.json",
                "be4caea3394068a2883045842bf1d132e37cd157",
                "713d54c453faa65e89875e69499444d5a7644d3f",
            ),
            rows,
        )
        self.assertIn(
            (
                "evt-20260811-210840-c9v2m7q4-diagnostics-duplicate-root-expected-red",
                "evt-20260811-210840-c9v2m7q4-diagnostics-duplicate-root-expected-red.json",
                "703fe3c4bd4e4547c11bf2f79b22df02bb795a9f",
                "655763e0f76eff22719c8f99e04089e11782af1f",
            ),
            rows,
        )
        self.assertIn(
            (
                "evt-20260811T211000Z-sol-20260811-m5q8v2c4-handoff-physics-reconciliation",
                "211000-sol-20260811-m5q8v2c4-handoff-physics-reconciliation.json",
                "da63fb468a9af4ff4b1767df7c985335b5e45b08",
                "f3ed0bc34d02a0db011ca612853c7b797201194d",
            ),
            rows,
        )
        self.assertIn(
            (
                "evt-20260811-213900-81idx1th-physics-runtime-synthesis",
                "213900-sol-20260811-81idx1th-dependency-physics-runtime-synthesis.json",
                "02b28a1ba0ce2525a7dada93a26398198402d2ec",
                "4b2ad689d0ad9c0eba985f89eb6c3aae58b70929",
            ),
            rows,
        )
        self.assertIn(
            (
                "20260811T214731Z-sol-20260811-y7k4m2p9-fidelitymanager-capability-seal",
                "214731-sol-20260811-y7k4m2p9-finding-fidelitymanager-capability-seal.json",
                "dc5b008bd2e5daa7d48661b0c4b8fbd745e4c553",
                "9f7698984027af3a9811f5852083d5f25d98b5ba",
            ),
            rows,
        )
        self.assertIn(
            (
                "evt-20260811-215400-p6r4n8x2-physics-geometry-review-request-changes",
                "evt-20260811-215400-p6r4n8x2-physics-geometry-review-request-changes.json",
                "3964c9e9781df8f9d98c34a27c03a64d567d080b",
                "80be391a2a962980f4dca5c7e9915f6532bba764",
            ),
            rows,
        )
        rules = extension.quarantine_rules()
        expected_ids = {row[0] for row in rows}
        self.assertEqual(len(rules), len(rows))
        self.assertEqual(set(rules), expected_ids)
        for event_id, filename, _first_write, blob_sha in rows:
            self.assertEqual(rules[event_id]["filename"], filename)
            self.assertEqual(rules[event_id]["quarantineOnlyGitBlobSha1"], blob_sha)


if __name__ == "__main__":
    unittest.main()
