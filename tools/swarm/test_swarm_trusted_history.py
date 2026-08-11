#!/usr/bin/env python3
"""Adversarial regressions for the append-only trusted-history recovery."""
from pathlib import Path
import unittest
from unittest.mock import patch

from test_swarmctl_hardening_base import Fx, NOW, core, write
import swarmctl_hardening as hard


class QuarantinedHistoryTests(unittest.TestCase):
    EVENT_ID = "evt-20260811-073500-test-quarantined-history"

    def setUp(self):
        self.fx = Fx()
        self.now = core.parse_time(NOW)

    def tearDown(self):
        self.fx.close()

    def legacy_event(self, event_id=None):
        return {
            "schemaVersion": 1,
            "eventId": event_id or self.EVENT_ID,
            "timestamp": "2026-08-11T07:35:00+00:00",
            "fromWorker": "sol-20260811-a81f",
            "eventType": "REVIEW_RESULT",
            "laneId": "LANE-A",
            "slotId": "reviewer-1",
            "severity": "normal",
            "summary": "Historical rewritten review bytes are inert after explicit quarantine.",
            "affects": ["LANE-A"],
            "metadata": {"pr": 1, "headSha": "a" * 40, "verdict": "APPROVE"},
        }

    def path(self, root=None):
        root = root or self.fx.root
        return root / "events" / "2026-08-11" / f"{self.EVENT_ID}.json"

    def quarantine_rule(self, path):
        return {
            "date": "2026-08-11",
            "filename": path.name,
            "canonicalGitBlobSha1": "1" * 40,
            "quarantinedGitBlobSha1": hard._git_blob_sha1(path),
        }

    def test_exact_quarantined_blob_is_inert_not_authoritative(self):
        path = self.path()
        write(path, self.legacy_event())
        rule = self.quarantine_rule(path)
        before = path.read_bytes()
        with patch.dict(hard._CANONICAL_IMMUTABLE_EVENTS, {self.EVENT_ID: rule}, clear=True):
            result = hard.validate_all(self.fx.root, self.now)
            tree = hard.read_tree(self.fx.root)
        self.assertEqual(result["events"], 0)
        self.assertEqual(tree[6], [])
        self.assertEqual(path.read_bytes(), before)

    def test_quarantine_is_exact_blob_not_shape_or_timestamp_compatibility(self):
        path = self.path()
        write(path, self.legacy_event())
        rule = self.quarantine_rule(path)
        changed = self.legacy_event()
        changed["summary"] = "One semantic byte change must fail closed."
        write(path, changed)
        with patch.dict(hard._CANONICAL_IMMUTABLE_EVENTS, {self.EVENT_ID: rule}, clear=True):
            with self.assertRaises(core.ControlError):
                hard.validate_all(self.fx.root, self.now)

    def test_quarantined_event_id_remains_reserved_against_replay(self):
        path = self.path()
        write(path, self.legacy_event())
        rule = self.quarantine_rule(path)
        replay = {
            "schemaVersion": 1,
            "eventId": self.EVENT_ID,
            "timestamp": "2026-08-11T09:00:00+00:00",
            "fromWorker": "sol-20260811-bb22",
            "eventType": "FINDING",
            "laneId": "LANE-A",
            "severity": "normal",
            "summary": "Replay must not recover quarantined authority.",
            "affects": ["LANE-A"],
        }
        write(self.fx.root / "events" / "2026-08-12" / "replay.json", replay)
        with patch.dict(hard._CANONICAL_IMMUTABLE_EVENTS, {self.EVENT_ID: rule}, clear=True):
            with self.assertRaises(core.ControlError):
                hard.validate_all(self.fx.root, self.now)

    def test_transition_can_append_after_exact_quarantine_but_cannot_rewrite_it(self):
        before_fx = Fx()
        after_fx = Fx()
        try:
            before_path = self.path(before_fx.root)
            after_path = self.path(after_fx.root)
            write(before_path, self.legacy_event())
            write(after_path, self.legacy_event())
            rule = self.quarantine_rule(before_path)
            strict = {
                "schemaVersion": 1,
                "eventId": "evt-20260811-090000-new-strict-after-reset",
                "timestamp": "2026-08-11T09:00:00+00:00",
                "fromWorker": "sol-20260811-bb22",
                "eventType": "RECOVERY",
                "laneId": "LANE-A",
                "severity": "normal",
                "summary": "Fresh strict event after explicit trusted reset.",
                "affects": ["LANE-A"],
            }
            write(after_fx.root / "events" / "2026-08-11" / "new.json", strict)
            with patch.dict(hard._CANONICAL_IMMUTABLE_EVENTS, {self.EVENT_ID: rule}, clear=True):
                result = hard.transition_check(before_fx.root, after_fx.root)
            self.assertTrue(result["trustedHistoryBaseline"])
            self.assertEqual(result["quarantinedHistoricalEvents"], 1)

            changed = self.legacy_event()
            changed["summary"] = "rewrite"
            write(after_path, changed)
            with patch.dict(hard._CANONICAL_IMMUTABLE_EVENTS, {self.EVENT_ID: rule}, clear=True):
                with self.assertRaises(core.ControlError):
                    hard.transition_check(before_fx.root, after_fx.root)
        finally:
            before_fx.close()
            after_fx.close()

    def test_objectgenome_rewrite_pair_is_pinned_as_inert_quarantine(self):
        rule = hard._CANONICAL_IMMUTABLE_EVENTS[
            "evt-20260811-083640-ogm5x8q2-objectgenome-support-stack"
        ]
        self.assertEqual(rule["canonicalGitBlobSha1"], "9ef4e62ffb0aac9d4b18cb19911d8d3a25535158")
        self.assertEqual(rule["quarantinedGitBlobSha1"], "c2b99475cdb95940d9a7ca329440880865da02cb")


class SeparateTrustLedgerTests(unittest.TestCase):
    def setUp(self):
        self.fx = Fx()

    def tearDown(self):
        self.fx.close()

    def trust(self, digest=None, bootstrap=False):
        return {
            "schemaVersion": 1,
            "controlBranch": "swarm-control",
            "trustedControlSha": "a" * 40,
            "trustedStateDigest": digest or hard.state_digest(self.fx.root),
            "validatedAt": "2026-08-11T09:15:00+00:00",
            "validatorMainSha": "b" * 40,
            "resetId": "reset-20260811-history-continuity",
            "resetReason": "Reviewed finite history recovery fixture.",
            "bootstrap": bootstrap,
        }

    def test_exact_separate_trust_digest_accepts_and_later_state_change_rejects(self):
        trust_path = self.fx.root.parent / "trust.json"
        write(trust_path, self.trust())
        result = hard.verify_trusted_state(self.fx.root, trust_path)
        self.assertEqual(result["trustedStateDigest"], hard.state_digest(self.fx.root))

        config_path = self.fx.root / "config.json"
        config = core.load_json(config_path)
        config["description"] = "authoritative mutation after last trust advance"
        write(config_path, config)
        with self.assertRaises(core.ControlError):
            hard.verify_trusted_state(self.fx.root, trust_path)

    def test_cross_paired_valid_sha_and_digest_fail_atomic_snapshot_binding(self):
        other = Fx()
        try:
            config_path = other.root / "config.json"
            config = core.load_json(config_path)
            config["description"] = "different authoritative snapshot"
            write(config_path, config)
            trust_path = self.fx.root.parent / "trust-cross-paired.json"
            write(trust_path, self.trust(digest=hard.state_digest(other.root)))
            with self.assertRaises(core.ControlError):
                hard.verify_trusted_snapshot(self.fx.root, trust_path)
        finally:
            other.close()

    def test_bootstrap_trust_record_never_authorizes_pr_state(self):
        trust_path = self.fx.root.parent / "trust-bootstrap.json"
        write(trust_path, self.trust(bootstrap=True))
        with self.assertRaises(core.ControlError):
            hard.verify_trusted_state(self.fx.root, trust_path)

    def test_bootstrap_snapshot_may_be_checked_only_when_explicitly_requested(self):
        trust_path = self.fx.root.parent / "trust-bootstrap-snapshot.json"
        write(trust_path, self.trust(bootstrap=True))
        result = hard.verify_trusted_snapshot(self.fx.root, trust_path, allow_bootstrap=True)
        self.assertTrue(result["bootstrap"])

    def test_invalid_trust_sha_or_digest_fails_closed(self):
        trust_path = self.fx.root.parent / "trust-bad.json"
        value = self.trust()
        value["trustedControlSha"] = "not-a-sha"
        write(trust_path, value)
        with self.assertRaises(core.ControlError):
            hard.validate_trust_record(trust_path)


class TrustedHistoryWorkflowTests(unittest.TestCase):
    INVALID_WORKER_TRANSITIONS = {
        "fa5b8f163603fa918c21b28c63bd20e6c25a2add": "7c62ff9a7b92c4ebe43c38323a5946e04881d3b7",
        "a99ff757b842fa91ddd893d19fd1d826890ce306": "a193dd686323c27a7191d525b064c4257120de21",
        "57245c334fdc19cae855796066f783fb64492c51": "db830924aa0b65a74c60ee345448f57381bbe137",
    }

    def workflow(self):
        path = Path(__file__).resolve().parents[2] / ".github" / "workflows" / "swarm-control.yml"
        return path.read_text(encoding="utf-8")

    def test_pr_ownership_requires_separate_trust_digest(self):
        workflow = self.workflow()
        self.assertIn("swarm-trust:refs/remotes/origin/swarm-trust", workflow)
        self.assertIn("verify_trusted_state", workflow)
        self.assertIn("trustedStateDigest", workflow)

    def test_control_transition_binds_digest_to_archived_trusted_sha_before_transition(self):
        workflow = self.workflow()
        self.assertIn("TRUSTED_CONTROL_SHA", workflow)
        self.assertIn('git archive "$TRUSTED_CONTROL_SHA" .swarm', workflow)
        self.assertIn("verify_trusted_snapshot", workflow)
        self.assertIn("allow_bootstrap=True", workflow)
        self.assertLess(workflow.index("verify_trusted_snapshot"), workflow.index("transition-check"))
        self.assertNotIn("BEFORE_SHA: ${{ github.event.before }}", workflow)
        self.assertIn("refusing stale trust advance", workflow)

    def test_bootstrap_candidate_proves_known_invalid_worker_transitions_are_explicitly_crossed(self):
        workflow = self.workflow()
        self.assertIn("git merge-base --is-ancestor", workflow)
        for invalid_sha, repair_sha in self.INVALID_WORKER_TRANSITIONS.items():
            self.assertIn(invalid_sha, workflow)
            self.assertIn(repair_sha, workflow)

    def test_health_mutation_is_not_hidden_as_generated_only_commit(self):
        workflow = self.workflow()
        self.assertIn("[swarm-health]", workflow)
        health = workflow.split("  sync-main-health:\n", 1)[1]
        self.assertNotIn("sync canonical main CI health and validation fence [swarm-generated]", health)


if __name__ == "__main__":
    unittest.main()
