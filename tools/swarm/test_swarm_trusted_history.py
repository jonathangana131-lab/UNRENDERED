#!/usr/bin/env python3
"""Adversarial regressions for the append-only trusted-history recovery."""
import hashlib
from pathlib import Path
import unittest
from unittest.mock import patch

from test_swarmctl_hardening_base import Fx, NOW, core, write
import swarm_history_recovery_manifest as recovery
import swarmctl_hardening as hard


def _inventory_digest(rows):
    canonical = "\n".join("|".join(row) for row in sorted(rows))
    return hashlib.sha256(canonical.encode("utf-8")).hexdigest()


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

    def test_quarantine_is_exact_blob_not_shape_compatibility(self):
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

    def test_transition_can_append_after_quarantine_but_cannot_rewrite_it(self):
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

    def test_objectgenome_rewrite_pair_is_pinned(self):
        rule = hard._CANONICAL_IMMUTABLE_EVENTS["evt-20260811-083640-ogm5x8q2-objectgenome-support-stack"]
        self.assertEqual(rule["canonicalGitBlobSha1"], "9ef4e62ffb0aac9d4b18cb19911d8d3a25535158")
        self.assertEqual(rule["quarantinedGitBlobSha1"], "c2b99475cdb95940d9a7ca329440880865da02cb")

    def test_complete_malformed_first_write_manifest_is_exact_quarantine_only(self):
        rows = recovery.MALFORMED_EVENT_QUARANTINE
        self.assertEqual(len(rows), 65)
        self.assertEqual(len({row[0] for row in rows}), 65)
        actual_digest = _inventory_digest(rows)
        self.assertEqual(actual_digest, "8c8c77f85c8210cfbca5a804364e3792bec347f7d62b994dee83a6870181bdfe")
        for event_id, first_write, blob_sha in rows:
            self.assertRegex(first_write, r"^[a-f0-9]{40}$")
            self.assertRegex(blob_sha, r"^[a-f0-9]{40}$")
            rule = hard._CANONICAL_IMMUTABLE_EVENTS[event_id]
            self.assertEqual(rule["date"], "2026-08-11")
            self.assertEqual(rule["filename"], f"{event_id}.json")
            self.assertEqual(rule["quarantineOnlyGitBlobSha1"], blob_sha)
            self.assertNotIn("canonicalGitBlobSha1", rule)
            self.assertNotIn("quarantinedGitBlobSha1", rule)


class FiniteClaimTakeoverHistoryTests(unittest.TestCase):
    RELATIVE = Path("claims/SWARM-RECOVERY-EVENT-IDENTITY-COMPAT/repair.json")
    BEFORE = """{
  \"schemaVersion\": 1,
  \"laneId\": \"SWARM-RECOVERY-EVENT-IDENTITY-COMPAT\",
  \"slotId\": \"repair\",
  \"workerId\": \"sol-20260811-m8q2v7\",
  \"claimToken\": \"7c1e4a9d2f6b8035\",
  \"claimedAt\": \"2026-08-11T08:35:00+00:00\",
  \"heartbeatAt\": \"2026-08-11T08:39:30+00:00\",
  \"leaseSeconds\": 1800,
  \"generation\": 1,
  \"resources\": [\"SWARM-PROTOCOL\"],
  \"branch\": \"agent/swarm/SWARM-RECOVERY-EVENT-IDENTITY-COMPAT-m8q2v7\",
  \"pr\": 328,
  \"notes\": \"PR #328 published on main@dd8f1581. Exact MaterialDNA blob identity/path compat + no-new-legacy transition fence + SYNC_REQUIRED historical verdict regression; canonical CI and independent exact-head review required.\"
}
"""
    AFTER = """{
  \"schemaVersion\": 1,
  \"laneId\": \"SWARM-RECOVERY-EVENT-IDENTITY-COMPAT\",
  \"slotId\": \"repair\",
  \"workerId\": \"sol-20260813-eic7n4p2\",
  \"claimToken\": \"c89a3f56179122d1\",
  \"claimedAt\": \"2026-08-13T22:38:00+00:00\",
  \"heartbeatAt\": \"2026-08-13T22:38:00+00:00\",
  \"leaseSeconds\": 1800,
  \"generation\": 2,
  \"resources\": [\"SWARM-PROTOCOL\"],
  \"branch\": \"agent/control/event-identity-compat-g2-eic7n4p2\",
  \"notes\": \"Generation-2 stale recovery after inspecting expired generation-1 PR #328 and its laundering review blocker. Current main has exact path/blob compatibility; this generation locks the remaining laundering regression and finite identity-compat closure.\"
}
"""

    def write_raw(self, fx, value):
        path = fx.root / self.RELATIVE
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(value, encoding="utf-8")
        return path

    def test_exact_missing_takeover_breadcrumb_is_finite_and_byte_pinned(self):
        before_fx, after_fx = Fx(), Fx()
        try:
            before_path = self.write_raw(before_fx, self.BEFORE)
            after_path = self.write_raw(after_fx, self.AFTER)
            rule = hard._FINITE_CLAIM_TAKEOVER_COMPAT[str(self.RELATIVE)]
            self.assertEqual(hashlib.sha256(before_path.read_bytes()).hexdigest(), rule["beforeSha256"])
            self.assertEqual(hashlib.sha256(after_path.read_bytes()).hexdigest(), rule["afterSha256"])
            with self.assertRaises(core.ControlError):
                hard._STRICT_TRANSITION_CHECK(before_fx.root, after_fx.root)
            result = hard.transition_check(before_fx.root, after_fx.root)
            self.assertEqual(result["finiteClaimTakeoverCompat"], [str(self.RELATIVE)])
            self.assertTrue(result["trustedHistoryBaseline"])
        finally:
            before_fx.close()
            after_fx.close()

    def test_one_byte_variant_does_not_inherit_takeover_compatibility(self):
        before_fx, after_fx = Fx(), Fx()
        try:
            self.write_raw(before_fx, self.BEFORE)
            self.write_raw(after_fx, self.AFTER.replace("finite identity-compat closure.", "finite identity-compat closure!"))
            with self.assertRaises(core.ControlError):
                hard.transition_check(before_fx.root, after_fx.root)
        finally:
            before_fx.close()
            after_fx.close()


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

    def test_exact_trust_digest_accepts_and_state_change_rejects(self):
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

    def test_cross_paired_sha_and_digest_fail_atomic_binding(self):
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

    def test_bootstrap_record_never_authorizes_pr_state(self):
        trust_path = self.fx.root.parent / "trust-bootstrap.json"
        write(trust_path, self.trust(bootstrap=True))
        with self.assertRaises(core.ControlError):
            hard.verify_trusted_state(self.fx.root, trust_path)

    def test_bootstrap_snapshot_requires_explicit_opt_in(self):
        trust_path = self.fx.root.parent / "trust-bootstrap-snapshot.json"
        write(trust_path, self.trust(bootstrap=True))
        self.assertTrue(hard.verify_trusted_snapshot(self.fx.root, trust_path, allow_bootstrap=True)["bootstrap"])

    def test_invalid_trust_sha_fails_closed(self):
        trust_path = self.fx.root.parent / "trust-bad.json"
        value = self.trust()
        value["trustedControlSha"] = "not-a-sha"
        write(trust_path, value)
        with self.assertRaises(core.ControlError):
            hard.validate_trust_record(trust_path)


class TrustedHistoryWorkflowTests(unittest.TestCase):
    def workflow(self):
        return (Path(__file__).resolve().parents[2] / ".github" / "workflows" / "swarm-control.yml").read_text(encoding="utf-8")

    def test_finite_worker_manifest_is_independently_pinned(self):
        rows = recovery.FINITE_WORKER_TRANSITIONS
        self.assertEqual(len(rows), 21)
        self.assertEqual(len({row[0] for row in rows}), 21)
        actual_digest = _inventory_digest(rows)
        self.assertEqual(actual_digest, "165419f1d0e6308a4f55d8c5f87b79fd03d508f477bcbfaaf7622f026e1ceafe")
        self.assertIn(("66e482d3b424c63c4bed277aafa897f0fa051bbc", "96f1bce06bb69738dc737ec01f51170ffdaa3667"), rows)
        self.assertIn(("d37f0480847b77459c3c23d7a020a94a40e69980", "489bb9662be6774bae676c17101c04f1bc74453a"), rows)

    def test_pr_ownership_requires_separate_trust_digest(self):
        workflow = self.workflow()
        self.assertIn("swarm-trust:refs/remotes/origin/swarm-trust", workflow)
        self.assertIn("verify_trusted_state", workflow)
        self.assertIn("trustedStateDigest", workflow)

    def test_transition_binds_archived_trusted_sha_before_transition(self):
        workflow = self.workflow()
        self.assertIn("TRUSTED_CONTROL_SHA", workflow)
        self.assertIn('git archive "$TRUSTED_CONTROL_SHA" .swarm', workflow)
        self.assertIn("verify_trusted_snapshot", workflow)
        self.assertIn("allow_bootstrap=True", workflow)
        self.assertLess(workflow.index("verify_trusted_snapshot"), workflow.index("transition-check"))
        self.assertNotIn("BEFORE_SHA: ${{ github.event.before }}", workflow)
        self.assertIn("refusing stale trust advance", workflow)

    def test_bootstrap_consumes_worker_manifest(self):
        workflow = self.workflow()
        self.assertIn("hard.FINITE_WORKER_TRANSITIONS", workflow)
        self.assertIn('git merge-base --is-ancestor "$INVALID_SHA" "$REPAIR_SHA"', workflow)
        self.assertIn('git merge-base --is-ancestor "$REPAIR_SHA" "$CONTROL_SHA"', workflow)
        self.assertIn("Finite worker transition manifest is empty.", workflow)

    def test_bootstrap_proves_quarantine_first_write_provenance(self):
        workflow = self.workflow()
        self.assertIn("recovery.MALFORMED_EVENT_QUARANTINE", workflow)
        self.assertIn("FIRST_WRITE_SHA", workflow)
        self.assertIn("FIRST_WRITE_BLOB", workflow)
        self.assertIn("expected exactly one first-add commit", workflow)
        self.assertIn("first-write blob mismatch", workflow)

    def test_health_mutation_is_not_hidden_as_generated_only(self):
        workflow = self.workflow()
        self.assertIn("[swarm-health]", workflow)
        health = workflow.split("  sync-main-health:\n", 1)[1]
        self.assertNotIn("sync canonical main CI health and validation fence [swarm-generated]", health)


if __name__ == "__main__":
    unittest.main()
