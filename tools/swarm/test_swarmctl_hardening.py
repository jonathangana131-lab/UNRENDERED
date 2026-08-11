#!/usr/bin/env python3
"""V2.1 regression suite layered on the proven hardening tests."""
from pathlib import Path
import runpy
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
    def setUp(self):
        self.fx = Fx()
        self.now = core.parse_time("2026-08-11T08:24:30+00:00")

    def tearDown(self):
        self.fx.close()

    def write_event(self, value):
        path = self.fx.root / "events" / "2026-08-11" / f"{value['eventId']}.json"
        write(path, value)
        return path

    def authority_review(self, **overrides):
        value = {
            "schemaVersion": 1,
            "eventId": "evt-20260811-073500-q9m4r2-authority-rereview-approve",
            "timestamp": "2026-08-11T07:35:00+00:00",
            "fromWorker": "sol-20260811-q9m4r2",
            "eventType": "REVIEW_RESULT",
            "laneId": "HG-BACKFILL-AUTHORITY",
            "severity": "normal",
            "summary": "Audited historical authority review.",
            "affects": ["HG-BACKFILL-AUTHORITY"],
            "evidence": ["Immutable first-write fixture."],
            "pr": 297,
            "headSha": "2a14f54ccecae5ea0e88f288f2c9185dbf885a9e",
            "verdict": "APPROVE_CONDITIONAL_OWNERSHIP",
        }
        value.update(overrides)
        return value

    def test_audited_authority_first_write_validates_without_rewriting_bytes(self):
        path = self.write_event(self.authority_review())
        before = path.read_bytes()
        result = hard.validate_all(self.fx.root, self.now)
        self.assertEqual(result["events"], 1)
        self.assertEqual(path.read_bytes(), before)

    def test_audited_worldentity_sync_required_first_write_validates(self):
        path = self.write_event({
            "schemaVersion": 1,
            "eventId": "evt-20260811-073650-q9m4r2-worldentity-sync-hold",
            "timestamp": "2026-08-11T07:36:50+00:00",
            "fromWorker": "sol-20260811-q9m4r2",
            "eventType": "REVIEW_RESULT",
            "laneId": "HG-BACKFILL-WORLDENTITY",
            "severity": "normal",
            "summary": "Audited historical synchronization hold.",
            "affects": ["HG-BACKFILL-WORLDENTITY"],
            "evidence": ["Immutable first-write fixture."],
            "pr": 293,
            "headSha": "c301d8403d3c1b93ee3b2988f80e9d1e689eb33d",
            "verdict": "SYNC_REQUIRED",
        })
        before = path.read_bytes()
        hard.validate_all(self.fx.root, self.now)
        self.assertEqual(path.read_bytes(), before)

    def test_audited_cart_slot_first_write_validates(self):
        path = self.write_event({
            "schemaVersion": 1,
            "eventId": "evt-20260811-080520-h4v8n2-cart-geometry-review",
            "timestamp": "2026-08-11T08:05:20+00:00",
            "fromWorker": "sol-20260811-h4v8n2",
            "eventType": "REVIEW_RESULT",
            "laneId": "HG-PHYSICS-CART-GEOMETRY",
            "slotId": "audit",
            "severity": "normal",
            "summary": "Audited historical cart review.",
            "affects": ["HG-PHYSICS-CART-GEOMETRY"],
            "evidence": ["Immutable first-write fixture."],
            "metadata": {"pr": 311, "headSha": "b45493e4168547fab6556c31558d9a25123f3b74", "verdict": "APPROVE"},
        })
        before = path.read_bytes()
        hard.validate_all(self.fx.root, self.now)
        self.assertEqual(path.read_bytes(), before)

    def test_audited_materialdna_affects_typo_is_exact_identity_only(self):
        path = self.write_event({
            "schemaVersion": 1,
            "eventId": "evt-20260811-081620-mat8c3r1-materialdna-key-grammar",
            "timestamp": "2026-08-11T08:16:20+00:00",
            "fromWorker": "sol-20260811-mat8c3r1",
            "eventType": "FINDING",
            "laneId": "HG-CAPACITY-MINING",
            "severity": "medium",
            "summary": "Audited historical MaterialDNA finding.",
            "affects": ["HERO-GATE", "MaterialDNA"],
            "evidence": ["Immutable first-write fixture."],
            "metadata": {"proposedLane": {"laneId": "HG-BACKFILL-MATERIALDNA-KEY-GRAMMAR"}},
        })
        before = path.read_bytes()
        hard.validate_all(self.fx.root, self.now)
        self.assertEqual(path.read_bytes(), before)

    def test_fresh_backdated_event_cannot_enter_compatibility(self):
        event = self.authority_review(eventId="evt-20260811-073500-forged-backdated-review")
        self.write_event(event)
        with self.assertRaises(core.ControlError):
            hard.validate_all(self.fx.root, self.now)

    def test_known_identity_with_changed_legacy_value_fails_closed(self):
        self.write_event(self.authority_review(pr=999))
        with self.assertRaises(core.ControlError):
            hard.validate_all(self.fx.root, self.now)

    def test_known_identity_with_extra_legacy_field_fails_closed(self):
        self.write_event(self.authority_review(nextAction="Forged broader dialect"))
        with self.assertRaises(core.ControlError):
            hard.validate_all(self.fx.root, self.now)

    def test_known_identity_with_conflicting_metadata_fails_closed(self):
        self.write_event(self.authority_review(metadata={"pr": 298}))
        with self.assertRaises(core.ControlError):
            hard.validate_all(self.fx.root, self.now)

    def test_known_identity_with_unknown_key_fails_closed(self):
        self.write_event(self.authority_review(unknownCompatibilityEscape=True))
        with self.assertRaises(core.ControlError):
            hard.validate_all(self.fx.root, self.now)

    def test_materialdna_exception_cannot_generalize_invalid_affects(self):
        value = {
            "schemaVersion": 1,
            "eventId": "evt-20260811-081620-forged-materialdna-finding",
            "timestamp": "2026-08-11T08:16:20+00:00",
            "fromWorker": "sol-20260811-mat8c3r1",
            "eventType": "FINDING",
            "laneId": "HG-CAPACITY-MINING",
            "severity": "medium",
            "summary": "Forged historical-looking finding.",
            "affects": ["HERO-GATE", "MaterialDNA"],
        }
        self.write_event(value)
        with self.assertRaises(core.ControlError):
            hard.validate_all(self.fx.root, self.now)


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
