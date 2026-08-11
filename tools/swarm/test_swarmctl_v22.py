#!/usr/bin/env python3
"""Deterministic/adversarial regressions for Swarm V2.2 completion throughput."""
from pathlib import Path
import unittest

from test_swarmctl_hardening_base import Fx, NOW, claim, config, lane, worker, write, core
import swarmctl_hardening as hard


def v22_config(activated_at=None):
    cfg = config()
    cfg["wip"]["completionSoftThrottle"] = 4
    cfg["wip"]["completionHardThrottle"] = 8
    if activated_at is not None:
        cfg["scheduler"]["v22ActivatedAt"] = activated_at
    return cfg


def active_pr_claim(index: int):
    return core.ActiveClaim(
        Path(f"claim-{index}.json"), f"OLD-{index}", "reviewer-1",
        f"sol-20260811-r{index:02d}x", f"{index + 1:016x}",
        core.parse_time("2026-08-11T04:50:00+00:00"), 1800,
        f"agent/review/OLD-{index}-r{index:02d}x", 1000 + index, 1, (),
    )


def completion_lane(lid="COMP"):
    return lane(lid, state="REVIEW", tags=["completion"])


class CompletionPressureTests(unittest.TestCase):
    def setUp(self):
        self.now = core.parse_time(NOW)

    def test_completion_queue_disappears_when_real_backlog_is_zero(self):
        lanes = {"COMP": completion_lane()}
        slots = hard.ready_slots(v22_config(), lanes, {}, [], [], self.now)
        self.assertFalse(any(slot.lane_id == "COMP" for slot in slots))

    def test_soft_pressure_prioritizes_completion_without_suppressing_primary(self):
        lanes = {"COMP": completion_lane(), "NEW": lane("NEW")}
        claims = [active_pr_claim(i) for i in range(4)]
        slots = hard.ready_slots(v22_config(), lanes, {}, claims, [], self.now)
        by_key = {(slot.lane_id, slot.slot_id): slot for slot in slots}
        self.assertIn(("NEW", "primary"), by_key)
        self.assertIn(("COMP", "reviewer-1"), by_key)
        self.assertGreater(by_key[("COMP", "reviewer-1")].score, by_key[("NEW", "primary")].score)
        self.assertIn("completion pressure SOFT", by_key[("COMP", "reviewer-1")].reason)

    def test_hard_pressure_suppresses_new_primary_test_audit_and_mining(self):
        normal = lane("NEW")
        normal["slots"].append({
            "slotId": "test-adversary", "role": "Adversarial test author", "exclusive": True,
            "availableWhen": ["READY"], "priorityBoost": 20,
        })
        normal["slots"].append({
            "slotId": "audit", "role": "Source auditor", "exclusive": True,
            "availableWhen": ["READY"], "priorityBoost": 10,
        })
        mining = lane("MINE")
        mining["slots"] = [{
            "slotId": "mine-runtime", "role": "Capacity mining", "exclusive": True,
            "availableWhen": ["READY"], "priorityBoost": 0,
        }]
        lanes = {"COMP": completion_lane(), "NEW": normal, "MINE": mining}
        slots = hard.ready_slots(v22_config(), lanes, {}, [active_pr_claim(i) for i in range(8)], [], self.now)
        keys = {(slot.lane_id, slot.slot_id) for slot in slots}
        self.assertIn(("COMP", "reviewer-1"), keys)
        self.assertNotIn(("NEW", "primary"), keys)
        self.assertNotIn(("NEW", "test-adversary"), keys)
        self.assertNotIn(("NEW", "audit"), keys)
        self.assertNotIn(("MINE", "mine-runtime"), keys)

    def test_red_main_control_repair_primary_survives_hard_pressure(self):
        repair = lane("REPAIR", tags=["red-main", "control-repair"])
        lanes = {"COMP": completion_lane(), "REPAIR": repair}
        health = {"status": "RED"}
        slots = hard.ready_slots(v22_config(), lanes, {}, [active_pr_claim(i) for i in range(8)], [], self.now, health)
        self.assertTrue(any(slot.lane_id == "REPAIR" and slot.slot_id == "primary" for slot in slots))

    def test_board_reports_real_pr_backlog_and_hard_throttle(self):
        fx = Fx()
        try:
            write(fx.root / "config.json", v22_config())
            fx.lane(completion_lane())
            for i in range(8):
                lid = f"OLD-{i}"
                fx.lane(lane(lid, state="REVIEW"))
                c = claim(worker=f"sol-20260811-r{i:02d}x", token=f"{i + 1:016x}", pr=1000 + i)
                c["laneId"] = lid
                c["slotId"] = "reviewer-1"
                c["branch"] = f"agent/review/{lid}-r{i:02d}x"
                fx.claim(c)
            board = hard.render_board(fx.root, self.now)
            self.assertEqual(board["summary"]["outstandingPRClaims"], 8)
            self.assertEqual(board["summary"]["completionPressure"], "HARD")
            self.assertTrue(board["summary"]["creationThrottle"])
            self.assertEqual(board["metrics"]["completionBacklog"], 8)
        finally:
            fx.close()


class AdaptiveReviewGateTests(unittest.TestCase):
    HEAD = "b" * 40
    ACTIVATED = "2026-08-11T05:00:00+00:00"

    def setUp(self):
        self.fx = Fx()
        self.now = core.parse_time(NOW)
        write(self.fx.root / "config.json", v22_config(self.ACTIVATED))

    def tearDown(self):
        self.fx.close()

    def setup_pr(self, changed, scopes, tags=None, created="2026-08-11T05:01:00+00:00", self_review=True):
        self.fx.lane(lane(scopes=scopes, tags=tags))
        c = claim(pr=1)
        c["branch"] = "agent/test/LANE-A-a81f"
        self.fx.claim(c)
        self.fx.worker(worker())
        body = (
            "Swarm-Lane: LANE-A\n"
            "Swarm-Slot: primary\n"
            "Swarm-Worker: sol-20260811-a81f\n"
            "Swarm-Claim-Token: aaaaaaaaaaaaaaaa\n"
            "Control-Schema: 1\n"
        )
        if self_review:
            body += f"Swarm-Self-Review: PASS\nSwarm-Self-Review-Head: {self.HEAD}\n"
        event_path = self.fx.root.parent / "event.json"
        changed_path = self.fx.root.parent / "changed.txt"
        write(event_path, {"pull_request": {
            "number": 1, "body": body, "created_at": created,
            "head": {"ref": "agent/test/LANE-A-a81f", "sha": self.HEAD},
        }})
        changed_path.write_text("\n".join(changed) + "\n", encoding="utf-8")
        return event_path, changed_path

    def add_review(self, *, reviewer="sol-20260811-bb22", depth="SPOT", head=None, pr=1):
        write(self.fx.root / "events" / "2026-08-11" / "review.json", {
            "schemaVersion": 1,
            "eventId": "evt-20260811-050100-v22-review-bb22",
            "timestamp": "2026-08-11T05:01:00+00:00",
            "fromWorker": reviewer,
            "eventType": "REVIEW_RESULT",
            "laneId": "LANE-A",
            "severity": "normal",
            "summary": "Independent V2.2 exact-head review.",
            "affects": ["LANE-A"],
            "metadata": {"pr": pr, "headSha": head or self.HEAD, "verdict": "APPROVE", "depth": depth},
        })

    def test_preactivation_pr_is_grandfathered_without_new_review_metadata(self):
        event_path, changed_path = self.setup_pr(
            ["src/server/Test/Foo.luau"], ["src/server/Test/**"],
            created="2026-08-11T04:59:00+00:00", self_review=False,
        )
        result = hard.pr_check(self.fx.root, event_path, changed_path, self.now)
        self.assertEqual(result["reviewPolicy"], "V2.1_GRANDFATHERED")

    def test_low_risk_test_only_pr_needs_self_review_but_no_second_worker(self):
        event_path, changed_path = self.setup_pr(["tests/foo.luau"], ["tests/**"])
        result = hard.pr_check(self.fx.root, event_path, changed_path, self.now)
        self.assertEqual(result["reviewPolicy"], "V2.2_LOW")
        self.assertEqual(result["selfReviewHead"], self.HEAD)

    def test_self_review_must_bind_exact_head(self):
        event_path, changed_path = self.setup_pr(["tests/foo.luau"], ["tests/**"])
        event = core.load_json(event_path)
        event["pull_request"]["body"] = event["pull_request"]["body"].replace(self.HEAD, "c" * 40)
        write(event_path, event)
        with self.assertRaises(core.ControlError):
            hard.pr_check(self.fx.root, event_path, changed_path, self.now)

    def test_standard_source_requires_independent_spot_or_full_review(self):
        event_path, changed_path = self.setup_pr(["src/server/Test/Foo.luau"], ["src/server/Test/**"])
        with self.assertRaises(core.ControlError):
            hard.pr_check(self.fx.root, event_path, changed_path, self.now)
        self.add_review(depth="SPOT")
        result = hard.pr_check(self.fx.root, event_path, changed_path, self.now)
        self.assertEqual(result["reviewPolicy"], "V2.2_STANDARD")

    def test_critical_authority_work_rejects_spot_and_requires_full(self):
        event_path, changed_path = self.setup_pr(["tests/authority_lock.luau"], ["tests/**"], tags=["authority"])
        self.add_review(depth="SPOT")
        with self.assertRaises(core.ControlError):
            hard.pr_check(self.fx.root, event_path, changed_path, self.now)
        self.add_review(depth="FULL")
        result = hard.pr_check(self.fx.root, event_path, changed_path, self.now)
        self.assertEqual(result["reviewPolicy"], "V2.2_CRITICAL")

    def test_same_worker_or_wrong_head_cannot_satisfy_independent_review(self):
        event_path, changed_path = self.setup_pr(["src/server/Test/Foo.luau"], ["src/server/Test/**"])
        self.add_review(reviewer="sol-20260811-a81f", depth="FULL")
        with self.assertRaises(core.ControlError):
            hard.pr_check(self.fx.root, event_path, changed_path, self.now)
        self.add_review(reviewer="sol-20260811-bb22", depth="FULL", head="c" * 40)
        with self.assertRaises(core.ControlError):
            hard.pr_check(self.fx.root, event_path, changed_path, self.now)


if __name__ == "__main__":
    unittest.main()
