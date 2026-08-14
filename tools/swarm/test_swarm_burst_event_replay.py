#!/usr/bin/env python3
from __future__ import annotations

import shutil
import tempfile
from pathlib import Path
import unittest
from unittest.mock import patch

from test_swarmctl_hardening_base import Fx, core, write
import swarm_burst_event_replay as replay
import swarmctl_hardening as hard


class QuarantineOnlyIntroductionReplayTests(unittest.TestCase):
    EVENT_ID = "evt-20260813-225000-test-quarantine-only-intro"
    PREDECESSOR = "a" * 40
    COMMIT = "b" * 40
    RELATIVE = Path("events/2026-08-13/evt-20260813-225000-test-quarantine-only-intro.json")

    def setUp(self):
        self.fx = Fx()
        self.temp = tempfile.TemporaryDirectory(prefix="swarm-burst-quarantine-test-")
        self.after = Path(self.temp.name) / "after"
        shutil.copytree(self.fx.root, self.after)
        self.path = self.after / self.RELATIVE
        write(self.path, self.malformed_event())
        self.blob = hard._git_blob_sha1(self.path)
        self.rule = {
            "date": "2026-08-13",
            "filename": self.RELATIVE.name,
            "quarantineOnlyGitBlobSha1": self.blob,
            "introductionPredecessorSha": self.PREDECESSOR,
            "introductionCommitSha": self.COMMIT,
        }
        self.registry_rule = {
            "date": self.rule["date"],
            "filename": self.rule["filename"],
            "quarantineOnlyGitBlobSha1": self.blob,
        }
        self.changed_path = f".swarm/{self.RELATIVE.as_posix()}"

    def tearDown(self):
        self.temp.cleanup()
        self.fx.close()

    def malformed_event(self):
        return {
            "schemaVersion": 1,
            "eventId": self.EVENT_ID,
            "timestamp": "2026-08-13T22:50:00+00:00",
            "fromWorker": "sol-20260813-a1b2c3d4",
            "eventType": "FINDING",
            "laneId": "LANE-A",
            "severity": "normal",
            "summary": "Exact historical bytes are inert only at the reviewed Git boundary.",
            "affects": ["LANE-A"],
            "recommendation": "This legacy top-level field must remain invalid outside quarantine.",
        }

    def compat(self, *, registry_rule=None):
        registry_rule = self.registry_rule if registry_rule is None else registry_rule
        return patch.dict(replay.QUARANTINE_ONLY_INTRODUCTIONS, {self.EVENT_ID: self.rule}, clear=True), patch.dict(
            hard._CANONICAL_IMMUTABLE_EVENTS, {self.EVENT_ID: registry_rule}, clear=False
        )

    def test_exact_quarantine_only_introduction_crosses_only_git_boundary(self):
        replay_patch, registry_patch = self.compat()
        with replay_patch, registry_patch:
            with self.assertRaises(core.ControlError):
                hard.transition_check(self.fx.root, self.after)
            result = replay.validate_git_transition(
                hard,
                self.PREDECESSOR,
                self.COMMIT,
                (self.changed_path,),
                self.fx.root,
                self.after,
            )
        self.assertEqual(result["finiteHistoricalQuarantineIntroductionCompat"], [self.RELATIVE.as_posix()])
        self.assertEqual(result["historicalGitTransition"]["predecessorSha"], self.PREDECESSOR)
        self.assertEqual(result["historicalGitTransition"]["commitSha"], self.COMMIT)
        self.assertGreaterEqual(result["quarantinedHistoricalEvents"], 1)

    def test_matching_commit_with_extra_changed_path_fails_closed(self):
        replay_patch, registry_patch = self.compat()
        with replay_patch, registry_patch:
            with self.assertRaisesRegex(core.ControlError, "changed-path mismatch"):
                replay.validate_git_transition(
                    hard,
                    self.PREDECESSOR,
                    self.COMMIT,
                    (self.changed_path, ".swarm/config.json"),
                    self.fx.root,
                    self.after,
                )

    def test_matching_commit_with_one_byte_event_variant_fails_closed(self):
        changed = self.malformed_event()
        changed["summary"] += "!"
        write(self.path, changed)
        replay_patch, registry_patch = self.compat()
        with replay_patch, registry_patch:
            with self.assertRaisesRegex(core.ControlError, "blob mismatch"):
                replay.validate_git_transition(
                    hard,
                    self.PREDECESSOR,
                    self.COMMIT,
                    (self.changed_path,),
                    self.fx.root,
                    self.after,
                )

    def test_registry_identity_must_match_existing_quarantine_contract(self):
        wrong_registry = dict(self.registry_rule)
        wrong_registry["quarantineOnlyGitBlobSha1"] = "c" * 40
        replay_patch, registry_patch = self.compat(registry_rule=wrong_registry)
        with replay_patch, registry_patch:
            with self.assertRaisesRegex(core.ControlError, "registry identity mismatch"):
                replay.validate_git_transition(
                    hard,
                    self.PREDECESSOR,
                    self.COMMIT,
                    (self.changed_path,),
                    self.fx.root,
                    self.after,
                )

    def test_wrong_git_identity_receives_no_compatibility(self):
        replay_patch, registry_patch = self.compat()
        with replay_patch, registry_patch:
            self.assertIsNone(
                replay.validate_git_transition(
                    hard,
                    "d" * 40,
                    self.COMMIT,
                    (self.changed_path,),
                    self.fx.root,
                    self.after,
                )
            )

    def test_production_authority_rule_is_exact_and_already_quarantined(self):
        event_id = "evt-20260813-225000-8fa445-authority-current-main-no-new-gap"
        rule = replay.QUARANTINE_ONLY_INTRODUCTIONS[event_id]
        self.assertEqual(rule["introductionPredecessorSha"], "a3ec4ac5ca87ab5fd7058c22a33af44d69fd51bd")
        self.assertEqual(rule["introductionCommitSha"], "47e9d65cb46852f396cfe109836623f4063d0d03")
        self.assertEqual(rule["quarantineOnlyGitBlobSha1"], "6503ee1458957314660adab6ef1e56793e775175")
        registered = hard._CANONICAL_IMMUTABLE_EVENTS[event_id]
        self.assertEqual(registered["date"], rule["date"])
        self.assertEqual(registered["filename"], rule["filename"])
        self.assertEqual(registered["quarantineOnlyGitBlobSha1"], rule["quarantineOnlyGitBlobSha1"])
        self.assertNotIn("canonicalGitBlobSha1", registered)
        self.assertNotIn("quarantinedGitBlobSha1", registered)


if __name__ == "__main__":
    unittest.main(verbosity=2)
