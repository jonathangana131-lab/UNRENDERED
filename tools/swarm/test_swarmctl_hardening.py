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
