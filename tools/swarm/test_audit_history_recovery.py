#!/usr/bin/env python3
from __future__ import annotations

import json
import subprocess
import tempfile
from pathlib import Path
import unittest

import audit_history_recovery as audit
import swarmctl_hardening as hard


class RecoveryInventoryTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.repo = Path(self.tmp.name)
        subprocess.run(["git", "init", "-q", str(self.repo)], check=True)
        subprocess.run(["git", "-C", str(self.repo), "config", "user.name", "test"], check=True)
        subprocess.run(["git", "-C", str(self.repo), "config", "user.email", "test@example.com"], check=True)
        self.root = self.repo / ".swarm"
        self.event = self.root / "events" / "2026-08-11" / "bad.json"
        self.event.parent.mkdir(parents=True)

    def tearDown(self):
        self.tmp.cleanup()

    def commit(self, message: str) -> str:
        subprocess.run(["git", "-C", str(self.repo), "add", ".swarm"], check=True)
        subprocess.run(["git", "-C", str(self.repo), "commit", "-q", "-m", message], check=True)
        return subprocess.check_output(["git", "-C", str(self.repo), "rev-parse", "HEAD"], text=True).strip()

    def write_bad(self, summary: str) -> None:
        self.event.write_text(
            json.dumps(
                {
                    "schemaVersion": 1,
                    "eventId": "evt-20260811-120000-test-invalid",
                    "summary": summary,
                    "unexpected": True,
                },
                indent=2,
            )
            + "\n",
            encoding="utf-8",
        )

    def test_inventory_binds_invalid_event_to_exact_first_write_and_current_blob(self):
        self.write_bad("first")
        first = self.commit("first malformed event")
        inventory = audit.build_inventory(self.root, self.repo, first)
        self.assertEqual(inventory["invalidEventCount"], 1)
        item = inventory["invalidEvents"][0]
        self.assertEqual(item["firstWriteCommit"], first)
        self.assertEqual(item["firstWriteGitBlobSha1"], hard._git_blob_sha1(self.event))
        self.assertEqual(item["currentGitBlobSha1"], item["firstWriteGitBlobSha1"])
        self.assertFalse(item["rewritten"])
        self.assertEqual(item["revisionCount"], 1)
        self.assertIn(".swarm/events/2026-08-11/bad.json", item["path"])

    def test_inventory_exposes_rewritten_malformed_event_without_blessing_it(self):
        self.write_bad("first")
        first = self.commit("first malformed event")
        first_blob = hard._git_blob_sha1(self.event)
        self.write_bad("rewritten")
        head = self.commit("rewrite malformed event")
        inventory = audit.build_inventory(self.root, self.repo, head)
        item = inventory["invalidEvents"][0]
        self.assertEqual(item["firstWriteCommit"], first)
        self.assertEqual(item["firstWriteGitBlobSha1"], first_blob)
        self.assertEqual(item["currentGitBlobSha1"], hard._git_blob_sha1(self.event))
        self.assertNotEqual(item["firstWriteGitBlobSha1"], item["currentGitBlobSha1"])
        self.assertTrue(item["rewritten"])
        self.assertEqual(item["revisionCount"], 2)

    def test_no_execute_error_uses_actual_path_when_filename_differs_from_event_id(self):
        self.event = (
            self.root
            / "events"
            / "2026-08-11"
            / "210500-sol-20260811-c7p4m8v2-handoff-content-reconciliation.json"
        )
        self.event.write_text(
            json.dumps(
                {
                    "schemaVersion": 1,
                    "eventId": "evt-20260811T210500Z-sol-20260811-c7p4m8v2-handoff-content-reconciliation",
                    "validation": [{"command": "never execute this"}],
                },
                indent=2,
            )
            + "\n",
            encoding="utf-8",
        )
        first = self.commit("path-divergent malformed handoff")

        inventory = audit.build_inventory(self.root, self.repo, first)
        self.assertEqual(inventory["invalidEventCount"], 1)
        item = inventory["invalidEvents"][0]
        self.assertEqual(
            item["path"],
            ".swarm/events/2026-08-11/210500-sol-20260811-c7p4m8v2-handoff-content-reconciliation.json",
        )
        self.assertEqual(item["firstWriteCommit"], first)
        self.assertIn("forbidden executable-looking control key validation.0.command", item["error"])
        self.assertIn(str(self.event), item["error"])


if __name__ == "__main__":
    unittest.main()
