from __future__ import annotations

import unittest
from pathlib import Path

from v16cp import integration_pressure as pressure
from v16cp.core import (
    add_work_item,
    canonical_absorption_plan,
    health_report,
    merge_pressure_report,
    recommend,
    role_allocation,
    seed_graph,
)


class V16_2IntegrationPressureTests(unittest.TestCase):
    def graph_with_integration(self):
        graph = seed_graph()
        oid = "physics-lab"
        obj = graph["objectives"][oid]
        obj["canonicalBranch"] = "agent/physics/HG-PHYSICS-LAB-primary"
        add_work_item(
            graph,
            work_item_id="v162-physics-child",
            mission_id=obj["missionId"],
            objective_id=oid,
            title="Integrate accepted Physics Lab cleanup",
            outcome="accepted child evidence absorbed into canonical Physics Lab candidate",
            role="integrator",
            branch="agent/physics/HG-PHYSICS-LAB-child",
        )
        item = graph["workItems"]["v162-physics-child"]
        item["status"] = "INTEGRATING"
        item["integrationWorld"] = "NEXT"
        item["branchState"] = "SELECTED"
        return graph

    def test_merge_pressure_detects_integration_candidate(self):
        graph = self.graph_with_integration()
        report = merge_pressure_report(graph)
        self.assertTrue(report["active"])
        self.assertEqual(report["policyVersion"], "16.2")
        self.assertEqual(report["candidateCount"], 1)
        self.assertIn("physics-lab", report["objectives"])

    def test_integration_pressure_outranks_capacity_mining(self):
        graph = self.graph_with_integration()
        packets = recommend(graph, (), 10)
        self.assertTrue(packets)
        self.assertEqual(packets[0].packet["MODE"], "MERGE_PRESSURE")
        self.assertEqual(packets[0].work_item_id, "v162-physics-child")
        self.assertFalse(packets[0].packet["MAY_CREATE_SUCCESSOR_PR"])

    def test_absorption_points_to_canonical_branch(self):
        graph = self.graph_with_integration()
        plan = canonical_absorption_plan(graph)
        self.assertEqual(len(plan), 1)
        self.assertEqual(plan[0]["canonicalBranch"], "agent/physics/HG-PHYSICS-LAB-primary")
        self.assertEqual(plan[0]["action"], "ABSORB_INTO_CANONICAL")
        self.assertEqual(plan[0]["childWorkItemIds"], ["v162-physics-child"])

    def test_absorption_and_candidates_share_actionability_rules(self):
        graph = self.graph_with_integration()
        graph["objectives"]["physics-lab"]["status"] = "EXTERNAL_BLOCKED"
        self.assertEqual(pressure.integration_candidates(graph), [])
        self.assertEqual(canonical_absorption_plan(graph), [])
        self.assertFalse(merge_pressure_report(graph)["active"])

        graph = self.graph_with_integration()
        graph["blockers"]["v162-external"] = {"state": "EXTERNAL"}
        graph["workItems"]["v162-physics-child"]["blockerId"] = "v162-external"
        self.assertEqual(pressure.integration_candidates(graph), [])
        self.assertEqual(canonical_absorption_plan(graph), [])
        self.assertFalse(merge_pressure_report(graph)["active"])

    def test_pressure_shifts_majority_toward_integrators(self):
        graph = self.graph_with_integration()
        allocation = role_allocation(graph, 30)
        self.assertGreater(allocation["integrator"], allocation["builder"])
        self.assertEqual(sum(allocation.values()), 30)

    def test_status_health_uses_pressure_aware_allocation(self):
        graph = self.graph_with_integration()
        expected = role_allocation(graph, 30)
        report = health_report(graph, 30)
        self.assertEqual(report["allocation"], expected)
        self.assertEqual(report["policyVersion"], "16.2")
        self.assertTrue(report["mergePressure"]["active"])

    def test_non_integrator_duties_inspect_exact_source_candidate(self):
        graph = self.graph_with_integration()
        workers = [f"sol-20260814-branch{i:02d}" for i in range(80)]
        packets = recommend(graph, workers, 80)
        seen_non_integrator = 0
        seen_integrator = 0
        for packet in packets:
            if packet.packet.get("MODE") != "MERGE_PRESSURE":
                continue
            duty = packet.packet["MERGE_PRESSURE_DUTY"]
            self.assertEqual(packet.packet["INTEGRATION_DESTINATION"], "agent/physics/HG-PHYSICS-LAB-primary")
            if duty == "INTEGRATE":
                seen_integrator += 1
                self.assertEqual(packet.packet["JOIN_BRANCH"], "agent/physics/HG-PHYSICS-LAB-primary")
            else:
                seen_non_integrator += 1
                self.assertEqual(packet.packet["JOIN_BRANCH"], "agent/physics/HG-PHYSICS-LAB-child")
        self.assertGreater(seen_non_integrator, 0)
        self.assertGreater(seen_integrator, 0)

    def test_capacity_mining_is_suppressed_for_workers_outside_pressure_share(self):
        graph = self.graph_with_integration()
        worker = next(
            f"sol-20260814-outside{i:03d}"
            for i in range(500)
            if pressure._stable_slot(f"sol-20260814-outside{i:03d}::v162-pressure", 10) >= 7
        )
        original_worker_plan = pressure._persist.worker_plan
        pressure._persist.worker_plan = lambda *_args, **_kwargs: [
            pressure.MissionPacket(
                "hero-gate-reality-grade",
                "physics-lab",
                "capacity-mining-fixture",
                "miner",
                1.0,
                {"MODE": "CAPACITY_MINING_ASSIST", "STOP_AUTHORIZED": False},
            )
        ]
        try:
            plan = pressure.worker_plan(graph, worker, 8)
        finally:
            pressure._persist.worker_plan = original_worker_plan
        self.assertFalse(any(packet.packet.get("MODE") == "CAPACITY_MINING_ASSIST" for packet in plan))

    def test_worker_registration_instruction_uses_canonical_status(self):
        root = Path(__file__).resolve().parents[2]
        text = (root / "ProjectSource" / "UNRENDERED_PROJECT_INSTRUCTIONS.txt").read_text()
        self.assertIn("Newly registered, unclaimed workers MUST use `IDLE`.", text)
        self.assertIn("Do not emit `READY` or `MINING` as worker statuses.", text)

    def test_30_worker_burst_remains_productive(self):
        graph = self.graph_with_integration()
        workers = [f"sol-20260814-v162{i:02d}" for i in range(30)]
        packets = recommend(graph, workers, 30)
        self.assertEqual(len(packets), 30)
        pressure_packets = [p for p in packets if p.packet.get("MODE") == "MERGE_PRESSURE"]
        self.assertGreaterEqual(len(pressure_packets), 18)
        self.assertTrue(all(p.packet.get("STOP_AUTHORIZED") is False for p in packets))
        self.assertFalse(any(p.packet.get("MODE") == "CAPACITY_MINING_ASSIST" for p in packets))


if __name__ == "__main__":
    unittest.main()
