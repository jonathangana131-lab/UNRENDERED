#!/usr/bin/env python3
"""Exact-data guards for the finite trusted-history recovery extension."""
from __future__ import annotations

import unittest

import swarm_history_recovery_extension as extension


class RecoveryExtensionTests(unittest.TestCase):
    def test_worker_transition_is_exact_and_finite(self):
        self.assertEqual(
            extension.FINITE_WORKER_TRANSITIONS,
            ((
                "b5bd3a372a4d4f044873c9bedf86d82e7cc92c23",
                "ef789a2e2e1b56d7a816b8c2be39412f5b6f0ccc",
            ),),
        )

    def test_measured_quarantine_rows_are_exact_and_unique(self):
        rows = extension.MALFORMED_EVENT_QUARANTINE_ROWS
        self.assertEqual(len(rows), 12)
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
                "evt-20260811T213200Z-sol-20260811-k5m8v2c6-handoff-harness-lifecycle-g2",
                "213200-sol-20260811-k5m8v2c6-handoff-harness-lifecycle-g2.json",
                "d9e4ee7f7755d5b19498f3b37cc1df73bdb793de",
                "074eea30dfd8ebcbf86ffaa9e21cd3f2cb7d0df5",
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
