#!/usr/bin/env python3
import json
import tempfile
import unittest
from pathlib import Path

import sys
sys.path.insert(0, str(Path(__file__).parent))
import swarmctl

NOW = "2026-08-11T04:30:00+00:00"


def write_json(path: Path, obj):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(obj, indent=2) + "\n", encoding="utf-8")


def base_config():
    return {
        "schemaVersion": 1,
        "controlBranch": "swarm-control",
        "description": "test",
        "leaseDefaults": {"primary": 1800, "review": 1200, "evidence": 2400, "integration": 1200},
        "wip": {
            "maxMajorEpics": 5,
            "maxPrimaryImplementationLanes": 8,
            "reviewBacklogThrottle": 4,
        },
        "scheduler": {"redMainOverride": True, "idleAllowed": True},
        "protectedScopes": [
            {"pattern": "Docs/PROJECT_STATE.md", "resource": "PROJECT-STATE"},
            {"pattern": "Docs/SWARM_PROTOCOL.md", "resource": "SWARM-PROTOCOL"},
            {"pattern": "src/shared/Reality/**", "resource": "REALITY-CONTRACT"},
        ],
    }


def lane(lane_id="LANE-A", state="READY", deps=None, resources=None, scopes=None):
    return {
        "schemaVersion": 1,
        "laneId": lane_id,
        "epicId": "EPIC-A",
        "title": lane_id,
        "objective": "Test the control plane.",
        "priority": 1000,
        "state": state,
        "mode": "exclusive",
        "dependencies": deps or [],
        "writeScopes": scopes or ["src/server/Test/**"],
        "resources": resources or [],
        "slots": [
            {
                "slotId": "primary",
                "role": "Primary implementation",
                "exclusive": True,
                "availableWhen": ["READY", "NEEDS_CHANGES"],
                "priorityBoost": 0,
            },
            {
                "slotId": "reviewer-1",
                "role": "Independent review",
                "exclusive": True,
                "availableWhen": ["REVIEW"],
                "requiresIndependentFrom": "primary",
                "priorityBoost": 150,
            },
            {
                "slotId": "integration",
                "role": "Integration",
                "exclusive": True,
                "availableWhen": ["INTEGRATION_READY"],
                "requiresIndependentFrom": "primary",
                "priorityBoost": 250,
            },
        ],
        "acceptance": ["tests pass"],
    }


def resource(rid="RES-A", state="AVAILABLE", order=10):
    return {
        "schemaVersion": 1,
        "resourceId": rid,
        "state": state,
        "mode": "exclusive",
        "order": order,
        "capacity": 1,
        "description": "test resource",
    }


def claim(lane_id="LANE-A", slot="primary", worker="sol-20260811-a81f", token="a"*16,
          heartbeat="2026-08-11T04:20:00+00:00", lease=1800, branch="agent/test/LANE-A-a81f",
          generation=1, resources=None, claimed_at="2026-08-11T04:10:00+00:00"):
    return {
        "schemaVersion": 1,
        "laneId": lane_id,
        "slotId": slot,
        "workerId": worker,
        "claimToken": token,
        "claimedAt": claimed_at,
        "heartbeatAt": heartbeat,
        "leaseSeconds": lease,
        "generation": generation,
        "resources": resources or [],
        "branch": branch,
        "pr": None,
    }


def resource_claim(resource_id="RES-A", lane_id="LANE-A", worker="sol-20260811-a81f",
                   token="a"*16, heartbeat="2026-08-11T04:20:00+00:00",
                   lease=1800, generation=1):
    return {
        "schemaVersion": 1,
        "resourceId": resource_id,
        "workerId": worker,
        "laneId": lane_id,
        "claimToken": token,
        "acquiredAt": "2026-08-11T04:10:00+00:00",
        "heartbeatAt": heartbeat,
        "leaseSeconds": lease,
        "generation": generation,
    }


class Fixture:
    def __init__(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name) / ".swarm"
        for d in ("lanes", "resources", "claims", "resource-claims", "workers", "events", "generated"):
            (self.root / d).mkdir(parents=True, exist_ok=True)
        write_json(self.root / "config.json", base_config())

    def add_lane(self, obj):
        write_json(self.root / "lanes" / f"{obj['laneId']}.json", obj)

    def add_resource(self, obj):
        write_json(self.root / "resources" / f"{obj['resourceId']}.json", obj)

    def add_claim(self, obj):
        write_json(self.root / "claims" / obj["laneId"] / f"{obj['slotId']}.json", obj)

    def add_resource_claim(self, obj):
        write_json(self.root / "resource-claims" / f"{obj['resourceId']}.json", obj)

    def close(self):
        self.tmp.cleanup()


class SwarmControlTests(unittest.TestCase):
    def setUp(self):
        self.fx = Fixture()

    def tearDown(self):
        self.fx.close()

    def now(self):
        return swarmctl.parse_time(NOW)

    def test_ready_lane_recommends_primary(self):
        self.fx.add_lane(lane())
        board = swarmctl.render_board(self.fx.root, self.now())
        self.assertEqual(board["readySlots"][0]["laneId"], "LANE-A")
        self.assertEqual(board["readySlots"][0]["slotId"], "primary")

    def test_active_claim_hides_slot(self):
        self.fx.add_lane(lane())
        self.fx.add_claim(claim())
        board = swarmctl.render_board(self.fx.root, self.now())
        self.assertEqual(board["summary"]["activeClaims"], 1)
        self.assertEqual(board["readySlots"], [])

    def test_stale_claim_releases_slot_and_is_takeover_candidate(self):
        self.fx.add_lane(lane())
        self.fx.add_claim(claim(heartbeat="2026-08-11T03:00:00+00:00", lease=600, claimed_at="2026-08-11T02:50:00+00:00"))
        board = swarmctl.render_board(self.fx.root, self.now())
        self.assertEqual(board["summary"]["staleClaims"], 1)
        self.assertEqual(board["readySlots"][0]["slotId"], "primary")

    def test_dependency_blocks_downstream(self):
        self.fx.add_lane(lane("UPSTREAM", state="BLOCKED_EXTERNAL"))
        self.fx.add_lane(lane("DOWNSTREAM", deps=[{"laneId": "UPSTREAM", "acceptableStates": ["DONE"]}]))
        board = swarmctl.render_board(self.fx.root, self.now())
        self.assertFalse(any(s["laneId"] == "DOWNSTREAM" for s in board["readySlots"]))

    def test_dependency_recovery_releases_downstream(self):
        self.fx.add_lane(lane("UPSTREAM", state="DONE"))
        self.fx.add_lane(lane("DOWNSTREAM", deps=[{"laneId": "UPSTREAM", "acceptableStates": ["DONE"]}]))
        board = swarmctl.render_board(self.fx.root, self.now())
        self.assertTrue(any(s["laneId"] == "DOWNSTREAM" for s in board["readySlots"]))

    def test_dependency_cycle_fails(self):
        self.fx.add_lane(lane("LANE-A", deps=[{"laneId": "LANE-B", "acceptableStates": ["DONE"]}]))
        self.fx.add_lane(lane("LANE-B", deps=[{"laneId": "LANE-A", "acceptableStates": ["DONE"]}]))
        with self.assertRaises(swarmctl.ControlError):
            swarmctl.validate_all(self.fx.root, self.now())

    def test_blocked_resource_hides_primary(self):
        self.fx.add_resource(resource(state="BLOCKED_EXTERNAL"))
        self.fx.add_lane(lane(resources=["RES-A"]))
        board = swarmctl.render_board(self.fx.root, self.now())
        self.assertEqual(board["readySlots"], [])

    def test_resource_capacity_hides_primary(self):
        self.fx.add_resource(resource())
        self.fx.add_lane(lane("LANE-A", resources=["RES-A"]))
        self.fx.add_lane(lane("LANE-B", resources=["RES-A"]))
        self.fx.add_resource_claim(resource_claim(resource_id="RES-A", lane_id="LANE-A"))
        self.fx.add_claim(claim(lane_id="LANE-A", resources=["RES-A"]))
        board = swarmctl.render_board(self.fx.root, self.now())
        self.assertFalse(any(s["laneId"] == "LANE-B" and s["slotId"] == "primary" for s in board["readySlots"]))

    def test_review_backlog_throttles_new_primaries(self):
        for i in range(4):
            self.fx.add_lane(lane(f"REVIEW-{i}", state="REVIEW"))
        self.fx.add_lane(lane("NEW-LANE", state="READY"))
        board = swarmctl.render_board(self.fx.root, self.now())
        self.assertFalse(any(s["laneId"] == "NEW-LANE" and s["slotId"] == "primary" for s in board["readySlots"]))
        self.assertTrue(any(s["slotId"] == "reviewer-1" for s in board["readySlots"]))

    def test_forbidden_executable_key_rejected(self):
        obj = lane()
        obj["command"] = "rm -rf /"
        write_json(self.fx.root / "lanes" / "LANE-A.json", obj)
        with self.assertRaises(swarmctl.ControlError):
            swarmctl.validate_all(self.fx.root, self.now())

    def test_unknown_lane_key_rejected(self):
        obj = lane()
        obj["surprise"] = True
        write_json(self.fx.root / "lanes" / "LANE-A.json", obj)
        with self.assertRaises(swarmctl.ControlError):
            swarmctl.validate_all(self.fx.root, self.now())

    def test_claim_branch_must_be_agent_namespace(self):
        self.fx.add_lane(lane())
        self.fx.add_claim(claim(branch="main"))
        with self.assertRaises(swarmctl.ControlError):
            swarmctl.validate_all(self.fx.root, self.now())

    def test_simulation_30_workers_has_one_winner(self):
        result = swarmctl.simulate(30)
        self.assertEqual(result["status"], "PASS")
        self.assertEqual(result["initialClaimWinners"], 1)
        self.assertEqual(result["initialClaimLosers"], 29)
        self.assertEqual(result["takeoverWinners"], 1)
        self.assertTrue(result["oldOwnerFenced"])

    def test_pr_metadata_parsing(self):
        body = """
Swarm-Lane: LANE-A
Swarm-Slot: primary
Swarm-Worker: sol-20260811-a81f
Swarm-Claim-Token: aaaaaaaaaaaaaaaa
Control-Schema: 1
"""
        meta = swarmctl.metadata_from_pr_body(body)
        self.assertEqual(meta["Swarm-Lane"], "LANE-A")

    def test_pr_scope_rejects_unrelated_production_path(self):
        self.fx.add_lane(lane(scopes=["src/server/Test/**"]))
        self.fx.add_claim(claim())
        event = {"pull_request": {"body": "\n".join([
            "Swarm-Lane: LANE-A", "Swarm-Slot: primary", "Swarm-Worker: sol-20260811-a81f",
            "Swarm-Claim-Token: aaaaaaaaaaaaaaaa", "Control-Schema: 1",
        ]), "head": {"ref": "agent/test/LANE-A-a81f"}}}
        event_path = self.fx.root.parent / "event.json"
        changed = self.fx.root.parent / "changed.txt"
        write_json(event_path, event)
        changed.write_text("src/shared/Reality/StableId.luau\n", encoding="utf-8")
        with self.assertRaises(swarmctl.ControlError):
            swarmctl.pr_check(self.fx.root, event_path, changed, self.now())

    def test_pr_scope_accepts_lane_path_and_tests(self):
        self.fx.add_lane(lane(scopes=["src/server/Test/**"]))
        self.fx.add_claim(claim())
        event = {"pull_request": {"body": "\n".join([
            "Swarm-Lane: LANE-A", "Swarm-Slot: primary", "Swarm-Worker: sol-20260811-a81f",
            "Swarm-Claim-Token: aaaaaaaaaaaaaaaa", "Control-Schema: 1",
        ]), "head": {"ref": "agent/test/LANE-A-a81f"}}}
        event_path = self.fx.root.parent / "event.json"
        changed = self.fx.root.parent / "changed.txt"
        write_json(event_path, event)
        changed.write_text("src/server/Test/Foo.luau\ntests/foo.luau\n", encoding="utf-8")
        result = swarmctl.pr_check(self.fx.root, event_path, changed, self.now())
        self.assertEqual(result["changedFiles"], 2)

    def test_declared_resource_without_atomic_resource_lease_fails(self):
        self.fx.add_resource(resource())
        self.fx.add_lane(lane(resources=["RES-A"]))
        self.fx.add_claim(claim(resources=["RES-A"]))
        with self.assertRaises(swarmctl.ControlError):
            swarmctl.validate_all(self.fx.root, self.now())

    def test_matching_resource_lease_passes(self):
        self.fx.add_resource(resource())
        self.fx.add_lane(lane(resources=["RES-A"]))
        self.fx.add_resource_claim(resource_claim())
        self.fx.add_claim(claim(resources=["RES-A"]))
        result = swarmctl.validate_all(self.fx.root, self.now())
        self.assertEqual(result["resourceClaims"], 1)

    def test_reviewer_cannot_be_same_worker_as_primary(self):
        self.fx.add_lane(lane(state="REVIEW"))
        self.fx.add_claim(claim())
        self.fx.add_claim(claim(slot="reviewer-1", token="b"*16, branch="agent/test/LANE-A-review-a81f"))
        with self.assertRaises(swarmctl.ControlError):
            swarmctl.validate_all(self.fx.root, self.now())

    def test_independent_reviewer_is_allowed(self):
        self.fx.add_lane(lane(state="REVIEW"))
        self.fx.add_claim(claim())
        self.fx.add_claim(claim(slot="reviewer-1", worker="sol-20260811-bb22", token="b"*16, branch="agent/test/LANE-A-review-bb22"))
        result = swarmctl.validate_all(self.fx.root, self.now())
        self.assertEqual(result["claims"], 2)

    def test_protected_scope_requires_named_resource(self):
        self.fx.add_resource(resource("REALITY-CONTRACT"))
        self.fx.add_lane(lane(scopes=["src/shared/Reality/**"], resources=["REALITY-CONTRACT"]))
        self.fx.add_claim(claim(resources=[]))
        event = {"pull_request": {"body": "\n".join([
            "Swarm-Lane: LANE-A", "Swarm-Slot: primary", "Swarm-Worker: sol-20260811-a81f",
            "Swarm-Claim-Token: aaaaaaaaaaaaaaaa", "Control-Schema: 1",
        ]), "head": {"ref": "agent/test/LANE-A-a81f"}}}
        event_path = self.fx.root.parent / "event-protected.json"
        changed = self.fx.root.parent / "changed-protected.txt"
        write_json(event_path, event)
        changed.write_text("src/shared/Reality/StableId.luau\n", encoding="utf-8")
        with self.assertRaises(swarmctl.ControlError):
            swarmctl.pr_check(self.fx.root, event_path, changed, self.now())

    def test_protected_scope_passes_with_atomic_resource_lease(self):
        self.fx.add_resource(resource("REALITY-CONTRACT"))
        self.fx.add_lane(lane(scopes=["src/shared/Reality/**"], resources=["REALITY-CONTRACT"]))
        self.fx.add_resource_claim(resource_claim(resource_id="REALITY-CONTRACT"))
        self.fx.add_claim(claim(resources=["REALITY-CONTRACT"]))
        event = {"pull_request": {"body": "\n".join([
            "Swarm-Lane: LANE-A", "Swarm-Slot: primary", "Swarm-Worker: sol-20260811-a81f",
            "Swarm-Claim-Token: aaaaaaaaaaaaaaaa", "Control-Schema: 1",
        ]), "head": {"ref": "agent/test/LANE-A-a81f"}}}
        event_path = self.fx.root.parent / "event-protected-ok.json"
        changed = self.fx.root.parent / "changed-protected-ok.txt"
        write_json(event_path, event)
        changed.write_text("src/shared/Reality/StableId.luau\n", encoding="utf-8")
        result = swarmctl.pr_check(self.fx.root, event_path, changed, self.now())
        self.assertEqual(result["protectedTouched"], ["src/shared/Reality/StableId.luau"])

    def test_support_slot_scope_override_blocks_production(self):
        obj = lane(state="REVIEW")
        for slot in obj["slots"]:
            if slot["slotId"] == "reviewer-1":
                slot["writeScopes"] = ["Docs/**"]
        self.fx.add_lane(obj)
        self.fx.add_claim(claim(slot="reviewer-1", worker="sol-20260811-bb22", token="b"*16, branch="agent/test/LANE-A-review-bb22"))
        event = {"pull_request": {"body": "\n".join([
            "Swarm-Lane: LANE-A", "Swarm-Slot: reviewer-1", "Swarm-Worker: sol-20260811-bb22",
            "Swarm-Claim-Token: bbbbbbbbbbbbbbbb", "Control-Schema: 1",
        ]), "head": {"ref": "agent/test/LANE-A-review-bb22"}}}
        event_path = self.fx.root.parent / "event-review.json"
        changed = self.fx.root.parent / "changed-review.txt"
        write_json(event_path, event)
        changed.write_text("src/server/Test/Foo.luau\n", encoding="utf-8")
        with self.assertRaises(swarmctl.ControlError):
            swarmctl.pr_check(self.fx.root, event_path, changed, self.now())


class WorkerAndReviewSchemaCompatibilityTests(unittest.TestCase):
    def worker(self, status):
        return {
            "schemaVersion": 1,
            "workerId": "sol-20260812-abcd",
            "model": "gpt-5.6-sol",
            "status": status,
            "startedAt": "2026-08-12T08:00:00+00:00",
            "lastSeenAt": "2026-08-12T08:01:00+00:00",
        }

    def review_event(self, **extra):
        event = {
            "schemaVersion": 1,
            "eventId": "evt-20260812-status-review-contract",
            "timestamp": "2026-08-12T08:00:00+00:00",
            "fromWorker": "sol-20260812-abcd",
            "eventType": "REVIEW_RESULT",
            "summary": "Exact-head independent review result.",
            "affects": ["LANE-A"],
        }
        event.update(extra)
        return event

    def test_evidence_backed_worker_status_aliases_validate(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "sol-20260812-abcd.json"
            for status in ("ACTIVE", "CLAIMING", "DONE"):
                with self.subTest(status=status):
                    write_json(path, self.worker(status))
                    self.assertEqual(swarmctl.validate_worker(path)["status"], status)

    def test_unknown_worker_status_still_fails_closed(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "sol-20260812-abcd.json"
            write_json(path, self.worker("FINISHED"))
            with self.assertRaises(swarmctl.ControlError):
                swarmctl.validate_worker(path)

    def test_unhashable_worker_status_shapes_fail_with_control_error(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "sol-20260812-abcd.json"
            for status in ([], {}):
                with self.subTest(status=status):
                    write_json(path, self.worker(status))
                    with self.assertRaises(swarmctl.ControlError):
                        swarmctl.validate_worker(path)

    def test_typed_review_result_validates_exact_domains(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "review.json"
            event = self.review_event(pr=423, headSha="a" * 40, verdict="APPROVE")
            write_json(path, event)
            validated = swarmctl.validate_event(path)
            self.assertEqual(validated["pr"], 423)
            self.assertEqual(validated["verdict"], "APPROVE")

    def test_typed_review_result_requires_complete_trio(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "review.json"
            write_json(path, self.review_event(pr=423))
            with self.assertRaises(swarmctl.ControlError):
                swarmctl.validate_event(path)

    def test_typed_review_result_rejects_invalid_domains(self):
        invalid = [
            {"pr": True, "headSha": "a" * 40, "verdict": "APPROVE"},
            {"pr": 423, "headSha": "A" * 40, "verdict": "APPROVE"},
            {"pr": 423, "headSha": "a" * 40, "verdict": "MAYBE"},
        ]
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "review.json"
            for fields in invalid:
                with self.subTest(fields=fields):
                    write_json(path, self.review_event(**fields))
                    with self.assertRaises(swarmctl.ControlError):
                        swarmctl.validate_event(path)

    def test_review_fields_do_not_generalize_to_other_events(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "finding.json"
            event = self.review_event(pr=423, headSha="a" * 40, verdict="APPROVE")
            event["eventType"] = "FINDING"
            write_json(path, event)
            with self.assertRaises(swarmctl.ControlError):
                swarmctl.validate_event(path)


if __name__ == "__main__":
    unittest.main()
