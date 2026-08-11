#!/usr/bin/env python3
"""V2.1 regression suite layered on the proven hardening tests."""
import unittest

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


if __name__ == "__main__":
    unittest.main()
