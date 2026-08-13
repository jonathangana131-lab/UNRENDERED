#!/usr/bin/env python3
"""Exact-data guards for the finite trusted-history recovery extension."""
from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

import swarm_history_recovery_extension as extension
import swarmctl_hardening as hard


class RecoveryExtensionTests(unittest.TestCase):
    def test_worker_transitions_are_exact_and_finite(self):
        generation7 = (
            (
                "b101e9c156befdc22d89195559f205d0d86b95a1",
                "512a1fa6051fe956936a203cc81f813f62470336",
            ),
            (
                "1a1300335ddc57f2913b024260f3c82a17a2916e",
                "493f9b34cacfcc90a695814434e24b70694566aa",
            ),
            (
                "ade84dab3f97b7fe022425f5258b95dd36d15e2d",
                "7f58400bea56171e559867e74ff112285641f1f2",
            ),
            (
                "81c61efc4eb063f8a5c8ddbfd7029376e2d94953",
                "15371ed8d9ccb6c917544256482aa9d1241c6a74",
            ),
            (
                "1fa04ae307f1f7e9a485a849d0ade69a347e1130",
                "984e83ad9a425e68ffb26b04734c4c330003e651",
            ),
            (
                "e631f9e1e2681a64cff4d73a3f3d53b8f54e635e",
                "687c9dbc579f635851dd0e69cbd62dc5736bf44b",
            ),
        )
        self.assertEqual(extension.GENERATION7_FINITE_WORKER_TRANSITIONS, generation7)
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
                (
                    "ad8f78e4996086178541c8674955e894609c576f",
                    "0ab963faea3b6ea554a5172113913ba27be61c25",
                ),
                (
                    "370f6ec7568a78fc98c38a825227f52cb65b6259",
                    "ce4ad38f302fa4b094e3a1e58324352879fce969",
                ),
            ) + generation7,
        )
        self.assertEqual(hard.FINITE_WORKER_TRANSITIONS[-len(generation7) :], generation7)

    def test_measured_quarantine_rows_are_exact_and_unique(self):
        rows = extension.MALFORMED_EVENT_QUARANTINE_ROWS
        self.assertEqual(len(rows), 47)
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
        self.assertIn(
            (
                "evt-sol-20260811-j4r8p2m6-worldentity-no-fresh-gap-231630",
                "231630-sol-20260811-j4r8p2m6-finding-worldentity-no-fresh-gap.json",
                "b166d68aa235be91627a11b5e9b0c1e468f5797a",
                "a013a74d2164d0ad23ec3bbb1640586afde19a28",
            ),
            rows,
        )
        self.assertIn(
            (
                "evt-20260811-232300-g4m8q2v7-geometry-test-lineage-union",
                "evt-20260811-232300-g4m8q2v7-geometry-test-lineage-union.json",
                "7c39519f61b6e82d94fc4f72a5e5443bafd086c5",
                "0431f08b228bef79faa08a20b5e449ccf535eab5",
            ),
            rows,
        )
        rules = extension.quarantine_rules()
        expected_ids = {row[0] for row in rows} | {row[0] for row in extension.DATED_MALFORMED_EVENT_QUARANTINE_ROWS}
        self.assertEqual(len(rules), len(expected_ids))
        self.assertEqual(set(rules), expected_ids)
        for event_id, filename, _first_write, blob_sha in rows:
            self.assertEqual(rules[event_id]["date"], "2026-08-11")
            self.assertEqual(rules[event_id]["filename"], filename)
            self.assertEqual(rules[event_id]["quarantineOnlyGitBlobSha1"], blob_sha)

    def test_generation8_dated_quarantine_is_exact_and_preserves_real_directory(self):
        expected = (
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
        )
        dated_rows = extension.DATED_MALFORMED_EVENT_QUARANTINE_ROWS
        self.assertGreaterEqual(len(dated_rows), len(expected))
        self.assertEqual(dated_rows[: len(expected)], expected)
        normalized = extension.malformed_event_quarantine_rows_with_dates()
        self.assertEqual(len(normalized), len(extension.MALFORMED_EVENT_QUARANTINE_ROWS) + len(dated_rows))
        self.assertEqual(len({row[0] for row in normalized}), len(normalized))
        self.assertEqual(len({(row[1], row[2]) for row in normalized}), len(normalized))
        for row in expected:
            self.assertIn(row, normalized)
            event_id, date, filename, _first_write, blob_sha = row
            rule = extension.quarantine_rules()[event_id]
            self.assertEqual(rule["date"], date)
            self.assertEqual(rule["filename"], filename)
            self.assertEqual(rule["quarantineOnlyGitBlobSha1"], blob_sha)
            self.assertEqual(hard._CANONICAL_IMMUTABLE_EVENTS[event_id], rule)


class ExecutableFieldQuarantineTests(unittest.TestCase):
    EVENT_ID = "evt-20260811T210500Z-test-pinned-command"
    FILENAME = "210500-test-pinned-command.json"

    def _write_fixture(self, root: Path, filename: str | None = None) -> Path:
        path = root / "events" / "2026-08-11" / (filename or self.FILENAME)
        path.parent.mkdir(parents=True, exist_ok=True)
        payload = {
            "schemaVersion": 1,
            "eventId": self.EVENT_ID,
            "validation": [{"command": "inert-fixture"}],
            "summary": "Legacy test record retained as inert bytes.",
        }
        path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
        return path

    def test_exact_blob_can_be_quarantined_before_executable_key_scan(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            path = self._write_fixture(root)
            rule = {
                "date": "2026-08-11",
                "filename": self.FILENAME,
                "quarantineOnlyGitBlobSha1": hard._git_blob_sha1(path),
            }
            with patch.dict(hard._CANONICAL_IMMUTABLE_EVENTS, {self.EVENT_ID: rule}, clear=False):
                event = hard._validate_event_with_immutable_compat(path)
                self.assertTrue(event["_quarantined"])
                self.assertTrue(event["quarantineOnly"])
                history = hard.quarantined_history(root)
                self.assertIn(self.EVENT_ID, {row["eventId"] for row in history})

    def test_changed_or_replayed_executable_payload_still_fails_closed(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            path = self._write_fixture(root)
            rule = {
                "date": "2026-08-11",
                "filename": self.FILENAME,
                "quarantineOnlyGitBlobSha1": hard._git_blob_sha1(path),
            }
            with patch.dict(hard._CANONICAL_IMMUTABLE_EVENTS, {self.EVENT_ID: rule}, clear=False):
                path.write_text(path.read_text(encoding="utf-8") + " ", encoding="utf-8")
                with self.assertRaises(hard._base.core.ControlError):
                    hard._validate_event_with_immutable_compat(path)

                path = self._write_fixture(root)
                replay = root / "events" / "2026-08-12" / "replay.json"
                replay.parent.mkdir(parents=True, exist_ok=True)
                replay.write_bytes(path.read_bytes())
                with self.assertRaises(hard._base.core.ControlError):
                    hard._validate_event_with_immutable_compat(replay)


if __name__ == "__main__":
    unittest.main()
