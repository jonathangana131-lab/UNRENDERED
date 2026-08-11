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
            "summary": {
                "readySlots": 0,
                "activeClaims": 0,
                "staleClaims": 0,
                "blockedExternalLanes": 1,
            },
            "readySlots": [],
            "activeClaims": [],
            "blockedLanes": [
                {"laneId": "OPS-STUDIO-DISPLAY", "state": "BLOCKED_EXTERNAL", "reason": "display unavailable"}
            ],
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


class ImmutableLegacyEventCompatibilityTests(unittest.TestCase):
    def setUp(self):
        self.fx = Fx()
        self.now = core.parse_time("2026-08-11T08:24:30+00:00")

    def tearDown(self):
        self.fx.close()

    def event(self, **overrides):
        value = {
            "schemaVersion": 1,
            "eventId": "evt-20260811-080520-legacy-review",
            "timestamp": "2026-08-11T08:05:20+00:00",
            "fromWorker": "sol-20260811-a81f",
            "eventType": "REVIEW_RESULT",
            "laneId": "LANE-A",
            "slotId": "reviewer-1",
            "severity": "normal",
            "summary": "Independent exact-head review result.",
            "affects": ["LANE-A"],
            "evidence": ["Exact historical evidence remains immutable."],
            "pr": 315,
            "headSha": "a" * 40,
            "verdict": "APPROVE",
            "nextAction": "Preserve the event bytes and continue integration.",
            "metadata": {
                "pr": 315,
                "headSha": "a" * 40,
                "verdict": "APPROVE",
            },
        }
        value.update(overrides)
        return value

    def write_event(self, value):
        path = self.fx.root / "events" / "2026-08-11" / "legacy.json"
        write(path, value)
        return path

    def test_known_historical_review_fields_validate_without_rewriting_bytes(self):
        path = self.write_event(self.event())
        before = path.read_bytes()

        result = hard.validate_all(self.fx.root, self.now)

        self.assertEqual(result["events"], 1)
        self.assertEqual(path.read_bytes(), before)

    def test_post_cutoff_top_level_review_field_fails_closed(self):
        path = self.write_event(self.event(timestamp="2026-08-11T08:25:01+00:00"))
        before = path.read_bytes()

        with self.assertRaises(core.ControlError):
            hard.validate_all(self.fx.root, self.now)

        self.assertEqual(path.read_bytes(), before)

    def test_legacy_fields_are_restricted_to_review_control_event_types(self):
        self.write_event(self.event(eventType="FINDING"))
        with self.assertRaises(core.ControlError):
            hard.validate_all(self.fx.root, self.now)

    def test_malformed_legacy_coordinate_fails_closed(self):
        self.write_event(self.event(pr="315"))
        with self.assertRaises(core.ControlError):
            hard.validate_all(self.fx.root, self.now)

    def test_conflicting_metadata_fails_closed(self):
        self.write_event(self.event(metadata={"pr": 316, "headSha": "a" * 40, "verdict": "APPROVE"}))
        with self.assertRaises(core.ControlError):
            hard.validate_all(self.fx.root, self.now)

    def test_unknown_key_stays_rejected_on_legacy_event(self):
        self.write_event(self.event(unknownCompatibilityEscape=True))
        with self.assertRaises(core.ControlError):
            hard.validate_all(self.fx.root, self.now)

    def test_historical_sync_required_verdict_is_accepted(self):
        self.write_event(
            self.event(
                verdict="SYNC_REQUIRED",
                metadata={"pr": 315, "headSha": "a" * 40, "verdict": "SYNC_REQUIRED"},
            )
        )
        result = hard.validate_all(self.fx.root, self.now)
        self.assertEqual(result["events"], 1)


class ImmutableEventIdentityFenceTests(unittest.TestCase):
    EVENT_ID = "evt-20260811-081620-test-materialdna-key-grammar"

    def malformed_finding(self):
        return {
            "schemaVersion": 1,
            "eventId": self.EVENT_ID,
            "timestamp": "2026-08-11T08:16:20+00:00",
            "fromWorker": "sol-20260811-a81f",
            "eventType": "FINDING",
            "laneId": "HG-CAPACITY-MINING",
            "severity": "medium",
            "summary": "Historical malformed affects fixture.",
            "affects": ["HERO-GATE", "MaterialDNA"],
            "evidence": ["Fixture is accepted only by exact immutable bytes."],
            "metadata": {"proposedLane": {"laneId": "HG-BACKFILL-MATERIALDNA-KEY-GRAMMAR"}},
        }

    def test_exact_blob_compat_accepts_only_audited_bytes(self):
        fx = Fx()
        try:
            path = fx.root / "events" / "2026-08-11" / f"{self.EVENT_ID}.json"
            write(path, self.malformed_finding())
            before = path.read_bytes()
            compat = {
                "date": "2026-08-11",
                "filename": path.name,
                "gitBlobSha1": hard._git_blob_sha1(path),
            }
            with patch.dict(hard._IMMUTABLE_EVENT_BLOB_COMPAT, {self.EVENT_ID: compat}, clear=False):
                result = hard.validate_all(fx.root, core.parse_time("2026-08-11T08:24:30+00:00"))
                self.assertEqual(result["events"], 1)
                self.assertEqual(path.read_bytes(), before)

                changed = self.malformed_finding()
                changed["summary"] = "Changed historical bytes must fail closed."
                write(path, changed)
                with self.assertRaises(core.ControlError):
                    hard.validate_all(fx.root, core.parse_time("2026-08-11T08:24:30+00:00"))
        finally:
            fx.close()

    def test_transition_rejects_new_backdated_legacy_event(self):
        with tempfile.TemporaryDirectory() as before_dir, tempfile.TemporaryDirectory() as after_dir:
            before = Path(before_dir)
            after = Path(after_dir)
            path = after / "events" / "2026-08-11" / "forged.json"
            write(
                path,
                {
                    "schemaVersion": 1,
                    "eventId": "evt-20260811-080520-forged-legacy-review",
                    "timestamp": "2026-08-11T08:05:20+00:00",
                    "fromWorker": "sol-20260811-a81f",
                    "eventType": "REVIEW_RESULT",
                    "summary": "Fresh event with forged historical timestamp.",
                    "affects": ["LANE-A"],
                    "slotId": "reviewer-1",
                },
            )
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

        self.assertIn(
            'python3 tools/swarm/swarmctl_hardening.py render --root "$RUNNER_TEMP/control-health/.swarm"',
            health_job,
        )
        self.assertIn(
            'cp -R "$RUNNER_TEMP/control-health/.swarm/generated/." .swarm/generated/',
            health_job,
        )
        self.assertIn(
            "git add .swarm/health/main.json .swarm/lanes/OPS-MAIN-HEALTH.json .swarm/generated",
            health_job,
        )
        self.assertIn("validation fence [swarm-generated]", health_job)
        self.assertLess(
            health_job.index('render --root "$RUNNER_TEMP/control-health/.swarm"'),
            health_job.index('cp -R "$RUNNER_TEMP/control-health/.swarm/generated/." .swarm/generated/'),
        )


if __name__ == "__main__":
    unittest.main()
