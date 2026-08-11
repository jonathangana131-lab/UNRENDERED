#!/usr/bin/env python3
"""V2.1 regression suite layered on the proven hardening tests."""
from pathlib import Path
import runpy
import tempfile
import unittest
from unittest.mock import patch

from test_swarmctl_hardening_base import *  # retain every existing hardening test
import swarmctl_hardening as hard


class CapacityDashboardRegressionTests(unittest.TestCase):
    def test_zero_ready_slots_never_recommend_immediate_idle(self):
        board = {
            "generatedAt": "2026-08-11T06:00:00+00:00",
            "stateDigest": "0" * 64,
            "mainHealth": {"status": "GREEN", "headSha": "a" * 40},
            "summary": {"readySlots": 0, "activeClaims": 0, "staleClaims": 0, "blockedExternalLanes": 1},
            "readySlots": [],
            "activeClaims": [],
            "blockedLanes": [{"laneId": "OPS-STUDIO-DISPLAY", "state": "BLOCKED_EXTERNAL", "reason": "display unavailable"}],
        }
        rendered = hard.dashboard(board)
        self.assertIn("GREEN is not completion", rendered)
        self.assertIn("review/integration", rendered)
        self.assertIn("stale recovery", rendered)
        self.assertIn("active-Epic backfill", rendered)
        self.assertIn("capacity-mining", rendered)
        self.assertNotIn("Idle/review is preferable", rendered)


class CliExitPropagationRegressionTests(unittest.TestCase):
    def test_facade_propagates_base_failure_exit_status(self):
        with patch.object(hard._base, "main", return_value=2):
            with self.assertRaises(SystemExit) as raised:
                runpy.run_module("swarmctl_hardening", run_name="__main__")
        self.assertEqual(raised.exception.code, 2)


class ImmutableHistoricalEventCompatibilityTests(unittest.TestCase):
    EVENT_ID = "evt-20260811-080520-test-legacy-review"

    def setUp(self):
        self.fx = Fx()
        self.now = core.parse_time("2026-08-11T08:24:30+00:00")

    def tearDown(self):
        self.fx.close()

    def canonical_event(self):
        return {
            "schemaVersion": 1,
            "eventId": self.EVENT_ID,
            "timestamp": "2026-08-11T08:05:20+00:00",
            "fromWorker": "sol-20260811-a81f",
            "eventType": "REVIEW_RESULT",
            "laneId": "LANE-A",
            "slotId": "reviewer-1",
            "severity": "normal",
            "summary": "Immutable first-write review fixture.",
            "affects": ["LANE-A"],
            "evidence": ["Historical bytes are canonical."],
            "metadata": {"pr": 315, "headSha": "a" * 40, "verdict": "APPROVE"},
        }

    def strict_laundered_event(self):
        value = self.canonical_event()
        value.pop("slotId")
        value["metadata"] = dict(value["metadata"])
        value["metadata"]["slotId"] = "reviewer-1"
        return value

    def event_path(self, root=None):
        root = self.fx.root if root is None else root
        return root / "events" / "2026-08-11" / f"{self.EVENT_ID}.json"

    def rule_for(self, canonical_path, restorable_from=()):
        return {
            "date": "2026-08-11",
            "filename": canonical_path.name,
            "canonicalGitBlobSha1": hard._git_blob_sha1(canonical_path),
            "restorableFromGitBlobSha1": set(restorable_from),
        }

    def test_audited_production_hashes_match_first_write_evidence(self):
        rules = hard._CANONICAL_IMMUTABLE_EVENTS
        self.assertEqual(
            rules["evt-20260811-073500-q9m4r2-authority-rereview-approve"]["canonicalGitBlobSha1"],
            "2f0b0221b7995b3862ac6c009804ebb66f715fac",
        )
        self.assertEqual(
            rules["evt-20260811-073650-q9m4r2-worldentity-sync-hold"]["canonicalGitBlobSha1"],
            "f9781fd64518c01aa10b460f01aff13adc6635da",
        )
        self.assertEqual(
            rules["evt-20260811-080520-h4v8n2-cart-geometry-review"]["canonicalGitBlobSha1"],
            "a39220b473086229e6b1057b296342175b851af1",
        )
        self.assertEqual(
            rules["evt-20260811-081620-mat8c3r1-materialdna-key-grammar"]["canonicalGitBlobSha1"],
            "9a7f679ea84600d6a28a8bef02436e5f85fd857e",
        )

    def test_exact_canonical_blob_accepts_malformed_historical_event_without_mutation(self):
        path = self.event_path()
        write(path, self.canonical_event())
        before = path.read_bytes()
        rule = self.rule_for(path)
        with patch.dict(hard._CANONICAL_IMMUTABLE_EVENTS, {self.EVENT_ID: rule}, clear=False):
            result = hard.validate_all(self.fx.root, self.now)
        self.assertEqual(result["events"], 1)
        self.assertEqual(path.read_bytes(), before)

    def test_known_event_strict_normalization_is_still_rejected_as_laundered_history(self):
        path = self.event_path()
        write(path, self.canonical_event())
        rule = self.rule_for(path)
        write(path, self.strict_laundered_event())
        with patch.dict(hard._CANONICAL_IMMUTABLE_EVENTS, {self.EVENT_ID: rule}, clear=False):
            with self.assertRaises(core.ControlError):
                hard.validate_all(self.fx.root, self.now)

    def test_known_event_byte_change_fails_closed(self):
        path = self.event_path()
        write(path, self.canonical_event())
        rule = self.rule_for(path)
        changed = self.canonical_event()
        changed["summary"] = "A changed historical summary must not be blessed."
        write(path, changed)
        with patch.dict(hard._CANONICAL_IMMUTABLE_EVENTS, {self.EVENT_ID: rule}, clear=False):
            with self.assertRaises(core.ControlError):
                hard.validate_all(self.fx.root, self.now)

    def test_canonical_path_cannot_swap_to_a_different_strict_event_id(self):
        path = self.event_path()
        write(path, self.canonical_event())
        rule = self.rule_for(path)
        swapped = self.strict_laundered_event()
        swapped["eventId"] = "evt-20260811-080520-forged-strict-review"
        write(path, swapped)
        with patch.dict(hard._CANONICAL_IMMUTABLE_EVENTS, {self.EVENT_ID: rule}, clear=False):
            with self.assertRaises(core.ControlError):
                hard.validate_all(self.fx.root, self.now)

    def test_fresh_backdated_legacy_event_cannot_enter_compatibility(self):
        value = self.canonical_event()
        value["eventId"] = "evt-20260811-080520-forged-backdated-review"
        path = self.fx.root / "events" / "2026-08-11" / f"{value['eventId']}.json"
        write(path, value)
        with self.assertRaises(core.ControlError):
            hard.validate_all(self.fx.root, self.now)

    def test_invalid_affects_does_not_generalize_beyond_exact_materialdna_blob(self):
        value = {
            "schemaVersion": 1,
            "eventId": "evt-20260811-081620-forged-materialdna-finding",
            "timestamp": "2026-08-11T08:16:20+00:00",
            "fromWorker": "sol-20260811-a81f",
            "eventType": "FINDING",
            "laneId": "LANE-A",
            "severity": "medium",
            "summary": "Fresh finding cannot inherit historical affects compatibility.",
            "affects": ["LANE-A", "MaterialDNA"],
        }
        path = self.fx.root / "events" / "2026-08-11" / f"{value['eventId']}.json"
        write(path, value)
        with self.assertRaises(core.ControlError):
            hard.validate_all(self.fx.root, self.now)

    def test_transition_allows_only_exact_laundered_to_canonical_restoration(self):
        with tempfile.TemporaryDirectory() as before_dir, tempfile.TemporaryDirectory() as after_dir:
            before = Path(before_dir)
            after = Path(after_dir)
            before_path = self.event_path(before)
            after_path = self.event_path(after)
            write(before_path, self.strict_laundered_event())
            before_sha = hard._git_blob_sha1(before_path)
            write(after_path, self.canonical_event())
            rule = self.rule_for(after_path, {before_sha})
            with patch.dict(hard._CANONICAL_IMMUTABLE_EVENTS, {self.EVENT_ID: rule}, clear=False):
                result = hard.transition_check(before, after)
            self.assertEqual(result["canonicalRestorations"], [f"events/2026-08-11/{after_path.name}"])

    def test_transition_rejects_unapproved_historical_rewrite(self):
        with tempfile.TemporaryDirectory() as before_dir, tempfile.TemporaryDirectory() as after_dir:
            before = Path(before_dir)
            after = Path(after_dir)
            before_path = self.event_path(before)
            after_path = self.event_path(after)
            unexpected = self.strict_laundered_event()
            unexpected["summary"] = "Different laundered bytes are not restorable."
            write(before_path, unexpected)
            write(after_path, self.canonical_event())
            rule = self.rule_for(after_path, {"0" * 40})
            with patch.dict(hard._CANONICAL_IMMUTABLE_EVENTS, {self.EVENT_ID: rule}, clear=False):
                with self.assertRaises(core.ControlError):
                    hard.transition_check(before, after)

    def test_transition_rejects_readding_known_historical_path(self):
        with tempfile.TemporaryDirectory() as before_dir, tempfile.TemporaryDirectory() as after_dir:
            before = Path(before_dir)
            after = Path(after_dir)
            after_path = self.event_path(after)
            write(after_path, self.canonical_event())
            rule = self.rule_for(after_path)
            with patch.dict(hard._CANONICAL_IMMUTABLE_EVENTS, {self.EVENT_ID: rule}, clear=False):
                with self.assertRaises(core.ControlError):
                    hard.transition_check(before, after)


class WorkflowSnapshotFenceRegressionTests(unittest.TestCase):
    def workflow_text(self):
        workflow_path = Path(__file__).resolve().parents[2] / ".github" / "workflows" / "swarm-control.yml"
        return workflow_path.read_text(encoding="utf-8")

    def test_control_publishers_reuse_materialized_snapshot_sha(self):
        workflow = self.workflow_text()
        self.assertIn("AFTER_SHA: ${{ github.sha }}", workflow)
        self.assertIn('echo "CONTROL_SHA=$AFTER_SHA" >> "$GITHUB_ENV"', workflow)
        self.assertIn('git archive "$AFTER_SHA" .swarm', workflow)
        self.assertIn('CONTROL_SHA="$(git rev-parse origin/swarm-control)"', workflow)
        self.assertIn('git archive "$CONTROL_SHA" .swarm', workflow)
        self.assertGreaterEqual(workflow.count('EXPECTED="${CONTROL_SHA:?'), 2)
        self.assertNotIn('EXPECTED="$(git rev-parse origin/swarm-control)"', workflow)

    def test_main_health_publish_carries_matching_validation_fence(self):
        workflow = self.workflow_text()
        health_job = workflow.split("  sync-main-health:\n", 1)[1]
        self.assertIn('python3 tools/swarm/swarmctl_hardening.py render --root "$RUNNER_TEMP/control-health/.swarm"', health_job)
        self.assertIn('cp -R "$RUNNER_TEMP/control-health/.swarm/generated/." .swarm/generated/', health_job)
        self.assertIn("git add .swarm/health/main.json .swarm/lanes/OPS-MAIN-HEALTH.json .swarm/generated", health_job)
        self.assertIn("validation fence [swarm-generated]", health_job)
        self.assertLess(
            health_job.index('render --root "$RUNNER_TEMP/control-health/.swarm"'),
            health_job.index('cp -R "$RUNNER_TEMP/control-health/.swarm/generated/." .swarm/generated/'),
        )


if __name__ == "__main__":
    unittest.main()
