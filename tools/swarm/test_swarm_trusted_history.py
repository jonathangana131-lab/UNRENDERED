#!/usr/bin/env python3
"""Adversarial regressions for the append-only trusted-history recovery."""
import hashlib
from pathlib import Path
import unittest
from unittest.mock import patch

from test_swarmctl_hardening_base import Fx, NOW, core, write
import swarm_history_recovery_manifest as recovery
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
        return (root or self.fx.root) / "events" / "2026-08-11" / f"{self.EVENT_ID}.json"

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
        before_fx, after_fx = Fx(), Fx()
        try:
            before_path, after_path = self.path(before_fx.root), self.path(after_fx.root)
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
        rule = hard._CANONICAL_IMMUTABLE_EVENTS["evt-20260811-083640-ogm5x8q2-objectgenome-support-stack"]
        self.assertEqual(rule["canonicalGitBlobSha1"], "9ef4e62ffb0aac9d4b18cb19911d8d3a25535158")
        self.assertEqual(rule["quarantinedGitBlobSha1"], "c2b99475cdb95940d9a7ca329440880865da02cb")

    def test_complete_malformed_first_write_manifest_is_exact_quarantine_only(self):
        self.assertEqual(len(recovery.MALFORMED_EVENT_QUARANTINE), 63)
        canonical = "\n".join(
            f"{event_id}|{first_write}|{blob_sha}"
            for event_id, first_write, blob_sha in sorted(recovery.MALFORMED_EVENT_QUARANTINE)
        )
        self.assertEqual(
            hashlib.sha256(canonical.encode("utf-8")).hexdigest(),
            "7153dcfb988108bc02f0aea039d89741b9f4f5e4edb04bfdb9ee58435fd4f690",
        )
        self.assertEqual(len({row[0] for row in recovery.MALFORMED_EVENT_QUARANTINE}), 63)
        for event_id, first_write, blob_sha in recovery.MALFORMED_EVENT_QUARANTINE:
            self.assertRegex(first_write, r"^[a-f0-9]{40}$")
            self.assertRegex(blob_sha, r"^[a-f0-9]{40}$")
            rule = hard._CANONICAL_IMMUTABLE_EVENTS[event_id]
            self.assertEqual(rule["date"], "2026-08-11")
            self.assertEqual(rule["filename"], f"{event_id}.json")
            self.assertEqual(rule["quarantineOnlyGitBlobSha1"], blob_sha)
            self.assertNotIn("canonicalGitBlobSha1", rule)
            self.assertNotIn("quarantinedGitBlobSha1", rule)


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
        self.assertTrue(hard.verify_trusted_snapshot(self.fx.root, trust_path, allow_bootstrap=True)["bootstrap"])

    def test_invalid_trust_sha_or_digest_fails_closed(self):
        trust_path = self.fx.root.parent / "trust-bad.json"
        value = self.trust()
        value["trustedControlSha"] = "not-a-sha"
        write(trust_path, value)
        with self.assertRaises(core.ControlError):
            hard.validate_trust_record(trust_path)


class TrustedHistoryWorkflowTests(unittest.TestCase):
    INVALID_WORKER_TRANSITIONS = dict(recovery.FINITE_WORKER_TRANSITIONS)

    def workflow(self):
        return (Path(__file__).resolve().parents[2] / ".github" / "workflows" / "swarm-control.yml").read_text(encoding="utf-8")

    def test_finite_worker_manifest_pins_reviewed_pairs_and_ready_repair(self):
        self.assertEqual(dict(hard.FINITE_WORKER_TRANSITIONS), self.INVALID_WORKER_TRANSITIONS)
        self.assertEqual(len(self.INVALID_WORKER_TRANSITIONS), 16)
        self.assertEqual(
            self.INVALID_WORKER_TRANSITIONS["66e482d3b424c63c4bed277aafa897f0fa051bbc"],
            "96f1bce06bb69738dc737ec01f51170ffdaa3667",
        )

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

    def test_bootstrap_candidate_consumes_canonical_finite_worker_manifest(self):
        workflow = self.workflow()
        self.assertIn("hard.FINITE_WORKER_TRANSITIONS", workflow)
        self.assertIn('git merge-base --is-ancestor "$INVALID_SHA" "$REPAIR_SHA"', workflow)
        self.assertIn('git merge-base --is-ancestor "$REPAIR_SHA" "$CONTROL_SHA"', workflow)
        self.assertIn("Finite worker transition manifest is empty.", workflow)
        self.assertIn("enumerated by FINITE_WORKER_TRANSITIONS", workflow)

    def test_bootstrap_proves_every_quarantine_first_write_from_manifest(self):
        workflow = self.workflow()
        self.assertIn("recovery.MALFORMED_EVENT_QUARANTINE", workflow)
        self.assertIn("FIRST_WRITE_SHA", workflow)
        self.assertIn("FIRST_WRITE_BLOB", workflow)
        self.assertIn("expected exactly one first-add commit", workflow)
        self.assertIn("first-write blob mismatch", workflow)

    def test_health_mutation_is_not_hidden_as_generated_only_commit(self):
        workflow = self.workflow()
        self.assertIn("[swarm-health]", workflow)
        health = workflow.split("  sync-main-health:\n", 1)[1]
        self.assertNotIn("sync canonical main CI health and validation fence [swarm-generated]", health)


if __name__ == "__main__":
    unittest.main()
