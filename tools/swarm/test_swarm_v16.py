#!/usr/bin/env python3
from __future__ import annotations

import json
import tempfile
import threading
import unittest
from copy import deepcopy
from pathlib import Path

from v16cp.core import (
    ConflictError, ValidationError, add_blocker, add_evidence, add_work_item, complexity_review,
    detect_duplicate, health_report, invalidate_evidence, migrate_legacy_root, momentum_score,
    objective_score, recommend, run_adversarial_simulation, seed_graph, test_impact,
    transition_check, validate_graph,
)
from v16cp.store import MemoryStore, MissionGraphStore


class MissionGraphTests(unittest.TestCase):
    def test_seed_fail_closed_runtime_truth(self):
        graph = seed_graph()
        self.assertFalse(graph["authority"]["automaticExternalTruthPromotion"])
        self.assertTrue(graph["authority"]["immutableEventsRemainAuthoritative"])
        self.assertEqual(graph["objectives"]["studio-runtime-evidence"]["featureGenome"]["runtimeTruth"]["state"], "NOT_STARTED")

    def test_external_truth_requires_explicit_authority(self):
        graph = seed_graph()
        with self.assertRaises(ValidationError):
            add_evidence(graph, evidence_id="fake-studio", objective_id="studio-runtime-evidence", evidence_type="studio", status="PASS", truth_class="STUDIO_OBSERVED", source_digest="a"*64, dependency_digest="b"*64, environment_digest="c"*64, affected_paths=["src"], details={})
        add_evidence(graph, evidence_id="real-studio", objective_id="studio-runtime-evidence", evidence_type="studio", status="PASS", truth_class="STUDIO_OBSERVED", source_digest="a"*64, dependency_digest="b"*64, environment_digest="c"*64, affected_paths=["src"], details={"externalAuthorityExplicit":True,"executor":"fixed Studio runner"})
        graph["objectives"]["studio-runtime-evidence"]["featureGenome"]["runtimeTruth"] = {"state":"ACCEPTED","evidenceIds":["real-studio"],"notes":"explicit external evidence"}
        validate_graph(graph)

    def test_runtime_truth_cannot_be_accepted_without_evidence(self):
        graph = seed_graph(); graph["objectives"]["studio-runtime-evidence"]["featureGenome"]["runtimeTruth"]["state"] = "ACCEPTED"
        with self.assertRaises(ValidationError): validate_graph(graph)

    def test_duplicate_suppression(self):
        graph = seed_graph()
        add_work_item(graph, work_item_id="physics-repair", mission_id="hero-gate-reality-grade", objective_id="physics-lab", title="Repair Physics Lab runtime contract", outcome="restore source contract", scope=["src/server/PhysicsLab"])
        decision = add_work_item(graph, work_item_id="physics-repair-2", mission_id="hero-gate-reality-grade", objective_id="physics-lab", title="Fix Physics Lab runtime source contract", outcome="restore source contract", scope=["src/server/PhysicsLab"])
        self.assertTrue(decision.duplicate); self.assertNotIn("physics-repair-2", graph["workItems"]); self.assertEqual(graph["metrics"]["duplicateTasksPrevented"], 1)

    def test_evidence_invalidation(self):
        graph = seed_graph(); add_evidence(graph, evidence_id="ci-one", objective_id="physics-lab", evidence_type="ci", status="PASS", truth_class="CI_VERIFIED", source_digest="a"*64, dependency_digest="b"*64, environment_digest="c"*64, affected_paths=["src/server/PhysicsLab/PhysicsLabRuntime.luau"])
        self.assertEqual(invalidate_evidence(graph, ["src/server/PhysicsLab/PhysicsLabRuntime.luau"], "main moved"), ["ci-one"]); self.assertEqual(graph["evidence"]["ci-one"]["status"], "STALE")

    def test_test_impact(self):
        suites = test_impact(["src/shared/Reality/WorldEntity.luau", ".github/workflows/ci.yml"], integration_boundary=True)
        self.assertIn("reality-contract", suites); self.assertIn("workflow-source-contract", suites); self.assertIn("integration-suite", suites)

    def test_priority_blocks_dependencies(self):
        graph = seed_graph(); self.assertEqual(objective_score(graph, "physics-lab"), float("-inf"))
        for dep in graph["objectives"]["physics-lab"]["dependencies"]: graph["objectives"][dep]["status"] = "DONE"
        self.assertGreater(objective_score(graph, "physics-lab"), 0)

    def test_complexity_and_momentum(self):
        self.assertTrue(complexity_review(100, 500, 3, 3, 2, 2, 2)["reviewRequired"])
        self.assertGreater(momentum_score(meaningful_code=10, blockers_removed=2, dependencies_unlocked=1, acceptance_gained=1, integration_gained=1, user_visible_improvement=1, regressions=0, duplicate_work=0), 300)

    def test_transition_immutability_and_revision(self):
        before = seed_graph(); after = deepcopy(before); after["revision"] = 1; after["updatedAt"] = "2026-08-12T19:00:00Z"
        self.assertEqual(transition_check(before, after)["status"], "PASS")
        bad = deepcopy(after); bad["revision"] = 2; bad["updatedAt"] = "2026-08-12T19:01:00Z"; bad["authority"]["automaticExternalTruthPromotion"] = True
        with self.assertRaises(ValidationError): transition_check(after, bad)

    def test_store_cas_is_atomic_under_threads(self):
        store = MemoryStore(); service = MissionGraphStore(store); service.ensure(seed_graph())
        successes = 0; lock = threading.Lock()
        def worker():
            nonlocal successes
            def mutate(graph): graph["metrics"]["meaningfulProgressEvents"] += 1
            service.mutate(mutate)
            with lock: successes += 1
        threads = [threading.Thread(target=worker) for _ in range(20)]
        for t in threads: t.start()
        for t in threads: t.join()
        graph, _ = service.load(); self.assertEqual(successes, 20); self.assertEqual(graph["revision"], 20); self.assertEqual(graph["metrics"]["meaningfulProgressEvents"], 20)

    def test_legacy_migration_preserves_external_boundary(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td); (root/"lanes").mkdir(); (root/"generated").mkdir()
            lanes = [
                {"schemaVersion":1,"laneId":"HG-BACKFILL-WORLDENTITY","epicId":"HERO-GATE","title":"WorldEntity depth","objective":"fix concrete gaps","priority":5200,"state":"READY","dependencies":[],"writeScopes":["src/shared/Reality/WorldEntity.luau"],"slots":[{"slotId":"primary","role":"source hardening","writeScopes":["src/shared/Reality/WorldEntity.luau"]}],"acceptance":["source accepted"],"blockers":[],"tags":["source-only"]},
                {"schemaVersion":1,"laneId":"OPS-STUDIO-DISPLAY","epicId":"OPS","title":"Studio display recovery","objective":"restore real Studio runner","priority":9000,"state":"BLOCKED_EXTERNAL","dependencies":[],"writeScopes":["Docs/**"],"slots":[],"acceptance":["real Studio executor available"],"blockers":["External Mac GUI/display recovery required"],"tags":["studio"]},
            ]
            for lane in lanes: (root/"lanes"/f"{lane['laneId']}.json").write_text(json.dumps(lane))
            (root/"generated"/"board.json").write_text(json.dumps({"activeClaims":[],"recentEvents":[{"eventId":"evt-one","eventType":"FINDING","laneId":"HG-BACKFILL-WORLDENTITY","summary":"immutable event fact","timestamp":"2026-08-12T18:00:00Z"}]}))
            graph = migrate_legacy_root(root, main_sha="a"*40, control_sha="b"*40)
            self.assertTrue(graph["migration"]["legacyImported"]); self.assertFalse(graph["migration"]["destructiveActionsAllowed"]); self.assertEqual(graph["metrics"]["legacyLanesImported"], 2)
            studio = graph["objectives"]["ops-studio-display"]; self.assertTrue(studio["externalTruthRequired"]); self.assertEqual(studio["status"], "EXTERNAL_BLOCKED"); self.assertEqual(studio["featureGenome"]["runtimeTruth"]["state"], "BLOCKED")
            self.assertTrue(any(m["type"] == "LEGACY_EVENT_FACT" for m in graph["memory"]))

    def test_adversarial_30(self):
        result = run_adversarial_simulation(30); self.assertTrue(result["passed"], result)


if __name__ == "__main__": unittest.main(verbosity=2)
