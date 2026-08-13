#!/usr/bin/env python3
"""Adversarial tests for post-reset first-parent trusted-history continuity."""
from __future__ import annotations

import subprocess
import tempfile
from pathlib import Path
import unittest

from test_swarmctl_hardening_base import Fx, NOW, core, write
import swarm_failed_control_recovery as failed_recovery
import swarm_history_recovery_manifest as recovery
import swarmctl_hardening as hard
import trusted_history_chain as chain


class TrustedHistoryChainTests(unittest.TestCase):
    def valid_event(self, summary: str) -> dict:
        return {"schemaVersion":1,"eventId":"evt-20260811-214000-chain-regression","timestamp":NOW,"fromWorker":"sol-20260811-a81f","eventType":"FINDING","severity":"normal","summary":summary,"affects":[]}

    def test_restored_descendant_cannot_launder_invalid_middle_commit(self):
        trusted, invalid, restored = Fx(), Fx(), Fx()
        try:
            event_path = Path("events/2026-08-11/chain.json")
            write(trusted.root / event_path, self.valid_event("trusted bytes"))
            write(invalid.root / event_path, self.valid_event("rewritten invalid bytes"))
            write(restored.root / event_path, self.valid_event("trusted bytes"))
            self.assertEqual(hard.transition_check(trusted.root, restored.root)["status"], "PASS")
            with self.assertRaises(core.ControlError): chain.validate_snapshot_chain([trusted.root, invalid.root, restored.root])
        finally:
            trusted.close(); invalid.close(); restored.close()

    def test_add_then_delete_cannot_disappear_between_trusted_endpoints(self):
        trusted, added, deleted = Fx(), Fx(), Fx()
        try:
            event_path = Path("events/2026-08-11/transient.json")
            event = self.valid_event("transient append"); event["eventId"] = "evt-20260811-214100-chain-transient"
            write(added.root / event_path, event)
            self.assertEqual(hard.transition_check(trusted.root, deleted.root)["status"], "PASS")
            with self.assertRaises(core.ControlError): chain.validate_snapshot_chain([trusted.root, added.root, deleted.root])
        finally:
            trusted.close(); added.close(); deleted.close()

    def test_first_parent_commit_order_is_deterministic(self):
        with tempfile.TemporaryDirectory() as temp:
            repo = Path(temp); subprocess.run(["git","init","-q",str(repo)], check=True)
            subprocess.run(["git","-C",str(repo),"config","user.name","test"], check=True)
            subprocess.run(["git","-C",str(repo),"config","user.email","test@example.invalid"], check=True)
            def commit(value: str) -> str:
                (repo / "marker.txt").write_text(value, encoding="utf-8")
                subprocess.run(["git","-C",str(repo),"add","marker.txt"], check=True)
                subprocess.run(["git","-C",str(repo),"commit","-q","-m",value], check=True)
                return subprocess.check_output(["git","-C",str(repo),"rev-parse","HEAD"], text=True).strip()
            trusted_sha = commit("trusted"); middle_sha = commit("middle"); control_sha = commit("control")
            self.assertEqual(chain.first_parent_commits(repo, trusted_sha, control_sha), [middle_sha, control_sha])

    def test_failed_control_recovery_is_exact_finite_and_event_fenced(self):
        self.assertEqual(len(failed_recovery.FAILED_CONTROL_RECOVERY_PAIRS), 1)
        row = failed_recovery.FAILED_CONTROL_RECOVERY_PAIRS[0]
        self.assertEqual(row["predecessorSha"], "d7bc6b94419c26e11ba56f920635fc784b9dffa3")
        self.assertEqual(row["invalidSha"], "69836b4ac25576138c95cd0794204c639bd234f4")
        self.assertEqual(row["repairSha"], "6e38cee9ae4d4c2d71b36a944cd22aca232f3497")
        self.assertIs(row, chain._recovery_pair(row["predecessorSha"], row["invalidSha"], row["repairSha"]))
        self.assertIsNone(chain._recovery_pair(row["predecessorSha"], row["invalidSha"], "f" * 40))
        self.assertFalse(any(path.startswith(".swarm/events/") for path in row["invalidChangedPaths"] + row["repairChangedPaths"]))
        self.assertEqual(set(row["repairChangedPaths"]), {".swarm/claims/SWARM-RECOVERY-HEALTH-VALIDATION-FENCE/primary.json", ".swarm/resource-claims/SWARM-PROTOCOL.json"})

    def test_path_divergent_malformed_handoffs_are_finitely_pinned(self):
        rows = recovery.malformed_event_quarantine_rows()
        expected = {
            ("evt-20260811T210500Z-sol-20260811-c7p4m8v2-handoff-content-reconciliation","210500-sol-20260811-c7p4m8v2-handoff-content-reconciliation.json","be4caea3394068a2883045842bf1d132e37cd157","713d54c453faa65e89875e69499444d5a7644d3f"),
            ("evt-20260811T211000Z-sol-20260811-m5q8v2c4-handoff-physics-reconciliation","211000-sol-20260811-m5q8v2c4-handoff-physics-reconciliation.json","da63fb468a9af4ff4b1767df7c985335b5e45b08","f3ed0bc34d02a0db011ca612853c7b797201194d"),
        }
        self.assertTrue(expected.issubset(set(rows)))
        rules = recovery.quarantine_rules()
        for event_id, filename, _first_write, blob_sha in expected:
            self.assertEqual(rules[event_id]["filename"], filename); self.assertEqual(rules[event_id]["quarantineOnlyGitBlobSha1"], blob_sha)

    def test_workflow_replays_chain_and_uses_trusted_base_primitives(self):
        workflow = (Path(__file__).resolve().parents[2] / ".github" / "workflows" / "swarm-control.yml").read_text(encoding="utf-8")
        self.assertIn("test_trusted_history_chain.py", workflow); self.assertIn("trusted_history_chain.py", workflow)
        self.assertIn('--trusted-sha "$TRUSTED_CONTROL_SHA"', workflow); self.assertIn('--control-sha "$CONTROL_SHA"', workflow)
        self.assertIn("malformed_event_quarantine_rows", workflow); self.assertIn("FIRST_WRITE_FILENAME", workflow)
        pr_ownership = workflow.split("  pr-ownership:\n", 1)[1].split("  validate-control-branch:\n", 1)[0]
        self.assertIn("hard.state_digest", pr_ownership); self.assertNotIn("hard.verify_trusted_state", pr_ownership); self.assertIn("bootstrap/reset mode", pr_ownership)


if __name__ == "__main__": unittest.main()
