#!/usr/bin/env python3
"""Adversarial tests for post-reset first-parent trusted-history continuity."""
from __future__ import annotations

import hashlib
import subprocess
import tempfile
from pathlib import Path
import unittest

from test_swarmctl_hardening_base import Fx, NOW, core, write
import swarm_burst_event_replay as burst_replay
import swarm_failed_control_recovery as failed_recovery
import swarm_history_recovery_extension as extension
import swarm_history_recovery_manifest as recovery
import swarmctl_hardening as hard
import trusted_history_chain as chain


class BurstReplayHardeningFake:
    def __init__(self, registry: dict, event_id: str, relative: Path):
        self._CANONICAL_IMMUTABLE_EVENTS = registry
        self.event_id = event_id
        self.relative = relative
        self.core = core
        self.authoritative = False

    def _git_blob_sha1(self, path: Path) -> str:
        raw = Path(path).read_bytes()
        header = f"blob {len(raw)}\0".encode("ascii")
        return hashlib.sha1(header + raw).hexdigest()

    def transition_check(self, before: Path, after: Path) -> dict:
        before_exists = (Path(before) / self.relative).exists()
        after_exists = (Path(after) / self.relative).exists()
        if before_exists != after_exists:
            raise core.ControlError("strict immutable event addition rejected")
        return {"status": "PASS"}

    def _validate_event_with_immutable_compat(self, path: Path) -> dict:
        rule = self._CANONICAL_IMMUTABLE_EVENTS.get(self.event_id)
        if not isinstance(rule, dict):
            raise core.ControlError("missing quarantine identity")
        if rule.get("quarantineOnlyGitBlobSha1") != self._git_blob_sha1(path):
            raise core.ControlError("quarantine identity blob mismatch")
        return {
            "eventId": self.event_id,
            "_quarantined": not self.authoritative,
            "quarantineOnly": not self.authoritative,
        }

    def quarantined_history(self, root: Path) -> list[str]:
        return [self.event_id] if (Path(root) / self.relative).is_file() else []


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

    def test_burst_quarantine_inventory_is_existing_manifest_only(self):
        expected = {
            "evt-20260813-225000-8fa445-authority-current-main-no-new-gap": {
                "date": "2026-08-13",
                "filename": "evt-20260813-225000-8fa445-authority-current-main-no-new-gap.json",
                "quarantineOnlyGitBlobSha1": "6503ee1458957314660adab6ef1e56793e775175",
                "introductionPredecessorSha": "a3ec4ac5ca87ab5fd7058c22a33af44d69fd51bd",
                "introductionCommitSha": "47e9d65cb46852f396cfe109836623f4063d0d03",
            },
            "evt-20260813-224945-f4q9n2c7-fidelity-extra-keys": {
                "date": "2026-08-13",
                "filename": "evt-20260813-224945-f4q9n2c7-fidelity-extra-keys.json",
                "quarantineOnlyGitBlobSha1": "0dd395b2757e7e3685b5c79aa6d6852ee50e85f3",
                "introductionPredecessorSha": "9857896b91f14e402c869cbd873cfa1bd158b738",
                "introductionCommitSha": "407732f50438acc4f11da30cca17c348936e73f8",
            },
            "evt-20260813-225110-j4n7q2v9-diagnostics-docs-g3-review-request": {
                "date": "2026-08-13",
                "filename": "225110-sol-20260813-j4n7q2v9-review-request-diagnostics-docs-g3.json",
                "quarantineOnlyGitBlobSha1": "835076ffce9bf4f355aa9f9b6d85f54177543421",
                "introductionPredecessorSha": "ebf8b6e120b2ec4a684fa4c365aaafc87b144f22",
                "introductionCommitSha": "af25c84703c1bde8beb84cdb1853ebd07aea6bea",
            },
        }
        self.assertEqual(burst_replay.QUARANTINE_ONLY_RULES, expected)
        manifest = extension.quarantine_rules()
        for event_id, rule in expected.items():
            self.assertEqual(
                manifest[event_id],
                {
                    "date": rule["date"],
                    "filename": rule["filename"],
                    "quarantineOnlyGitBlobSha1": rule["quarantineOnlyGitBlobSha1"],
                },
            )
        burst_replay.install(hard)

    def test_burst_quarantine_introduction_bridge_is_exact_and_inert(self):
        event_id = "evt-20990101-000000-test-quarantine-only"
        date = "2099-01-01"
        filename = "evt-20990101-000000-test-quarantine-only.json"
        relative = Path("events") / date / filename
        git_relative = f".swarm/{relative.as_posix()}"
        predecessor = "1" * 40
        commit = "2" * 40
        raw = b'{"malformed":true}'

        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            before = root / "before"
            after = root / "after"
            before.mkdir()
            (after / relative.parent).mkdir(parents=True)
            after_path = after / relative
            after_path.write_bytes(raw)
            raw_header = f"blob {len(raw)}\0".encode("ascii")
            blob_sha = hashlib.sha1(raw_header + raw).hexdigest()
            rule = {
                "date": date,
                "filename": filename,
                "quarantineOnlyGitBlobSha1": blob_sha,
                "introductionPredecessorSha": predecessor,
                "introductionCommitSha": commit,
            }
            registry_rule = {
                "date": date,
                "filename": filename,
                "quarantineOnlyGitBlobSha1": blob_sha,
            }
            original_rules = burst_replay.QUARANTINE_ONLY_RULES
            burst_replay.QUARANTINE_ONLY_RULES = {event_id: rule}
            try:
                fake = BurstReplayHardeningFake({event_id: registry_rule.copy()}, event_id, relative)
                burst_replay.install(fake)

                def dispatch(
                    before_sha: str = predecessor,
                    after_sha: str = commit,
                    changed_paths: tuple[str, ...] = (git_relative,),
                    before_root: Path = before,
                    after_root: Path = after,
                ) -> dict:
                    result = burst_replay.validate_git_transition(
                        fake,
                        before_sha,
                        after_sha,
                        changed_paths,
                        before_root,
                        after_root,
                    )
                    if result is not None:
                        return result
                    return fake.transition_check(before_root, after_root)

                result = dispatch()
                self.assertEqual(result["status"], "PASS")
                self.assertEqual(
                    result["finiteHistoricalQuarantineOnlyIntroductionCompat"],
                    [relative.as_posix()],
                )
                self.assertEqual(result["quarantinedHistoricalEvents"], 1)
                self.assertEqual(
                    result["historicalGitTransition"],
                    {"predecessorSha": predecessor, "commitSha": commit},
                )

                fake.authoritative = True
                with self.assertRaises(core.ControlError):
                    dispatch()
                fake.authoritative = False

                with self.assertRaises(core.ControlError):
                    dispatch(before_sha="3" * 40)
                with self.assertRaises(core.ControlError):
                    dispatch(after_sha="4" * 40)
                with self.assertRaises(core.ControlError):
                    dispatch(changed_paths=(git_relative, ".swarm/workers/unrelated.json"))
                with self.assertRaises(core.ControlError):
                    dispatch(changed_paths=(".swarm/workers/unrelated.json",))

                malformed_before = root / "malformed-before"
                (malformed_before / relative.parent).mkdir(parents=True)
                (malformed_before / relative).write_bytes(raw)
                with self.assertRaises(core.ControlError):
                    dispatch(before_root=malformed_before)

                missing_after = root / "missing-after"
                missing_after.mkdir()
                with self.assertRaises(core.ControlError):
                    dispatch(after_root=missing_after)

                after_path.write_bytes(raw + b"x")
                with self.assertRaises(core.ControlError):
                    dispatch()
                after_path.write_bytes(raw)

                missing = BurstReplayHardeningFake({}, event_id, relative)
                with self.assertRaises(RuntimeError):
                    burst_replay.install(missing)
                mismatch = BurstReplayHardeningFake(
                    {
                        event_id: {
                            "date": date,
                            "filename": filename,
                            "quarantineOnlyGitBlobSha1": "f" * 40,
                        }
                    },
                    event_id,
                    relative,
                )
                with self.assertRaises(RuntimeError):
                    burst_replay.install(mismatch)

                burst_replay.QUARANTINE_ONLY_RULES = {}
                with self.assertRaises(core.ControlError):
                    dispatch()
            finally:
                burst_replay.QUARANTINE_ONLY_RULES = original_rules

    def test_workflow_replays_chain_and_uses_trusted_base_primitives(self):
        workflow = (Path(__file__).resolve().parents[2] / ".github" / "workflows" / "swarm-control.yml").read_text(encoding="utf-8")
        self.assertIn("test_trusted_history_chain.py", workflow); self.assertIn("trusted_history_chain.py", workflow)
        self.assertIn('--trusted-sha "$TRUSTED_CONTROL_SHA"', workflow); self.assertIn('--control-sha "$CONTROL_SHA"', workflow)
        self.assertIn("malformed_event_quarantine_rows", workflow); self.assertIn("FIRST_WRITE_FILENAME", workflow)
        pr_ownership = workflow.split("  pr-ownership:\n", 1)[1].split("  validate-control-branch:\n", 1)[0]
        self.assertIn("hard.state_digest", pr_ownership); self.assertNotIn("hard.verify_trusted_state", pr_ownership); self.assertIn("bootstrap/reset mode", pr_ownership)


if __name__ == "__main__": unittest.main()
