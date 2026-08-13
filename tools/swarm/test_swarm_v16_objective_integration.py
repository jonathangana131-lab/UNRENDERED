#!/usr/bin/env python3
from __future__ import annotations

import unittest
from copy import deepcopy

from v16_objective_integrate import record_objective_integration
from v16cp.core import ValidationError, add_blocker, seed_graph, validate_graph


class ObjectiveIntegrationTests(unittest.TestCase):
    def args(self):
        return dict(objective_id="swarm-v16-mission-graph", pr=400, source_head="a"*40, merge_sha="b"*40, acceptance_runs=["12345","12346"], review_refs=["9988"], affected_paths=["tools/swarm/v16cp", "tools/swarm/v16ctl.py", ".github/workflows/swarm-v16-activate.yml"])

    def test_nonexternal_objective_closes(self):
        graph = seed_graph(); result = record_objective_integration(graph, **self.args()); self.assertEqual(result["status"], "DONE"); self.assertFalse(result["runtimeAuthorityPromoted"]); self.assertEqual(graph["objectives"]["swarm-v16-mission-graph"]["integrationState"], "MAIN"); validate_graph(graph)

    def test_external_objective_denied(self):
        graph = seed_graph(); args = self.args(); args["objective_id"] = "studio-runtime-evidence"
        with self.assertRaises(ValidationError): record_objective_integration(graph, **args)

    def test_unfinished_dependency_denied(self):
        graph = seed_graph(); graph["objectives"]["swarm-v16-mission-graph"]["dependencies"] = ["stable-identity"]
        with self.assertRaises(ValidationError): record_objective_integration(graph, **self.args())

    def test_unresolved_p0_denied(self):
        graph = seed_graph(); add_blocker(graph, blocker_id="control-p0", mission_id="swarm-operations", objective_id="swarm-v16-mission-graph", symptom="control invariant red", severity="P0")
        with self.assertRaises(ValidationError): record_objective_integration(graph, **self.args())

    def test_idempotent_exact_same_evidence(self):
        graph = seed_graph(); first = record_objective_integration(graph, **self.args()); second = record_objective_integration(graph, **self.args()); self.assertFalse(first["idempotent"]); self.assertTrue(second["idempotent"])

    def test_conflicting_second_completion_denied(self):
        graph = seed_graph(); record_objective_integration(graph, **self.args()); other = self.args(); other["merge_sha"] = "c"*40
        with self.assertRaises(ValidationError): record_objective_integration(graph, **other)

    def test_unsafe_path_denied(self):
        graph = seed_graph(); args = self.args(); args["affected_paths"] = ["../secrets"]
        with self.assertRaises(ValidationError): record_objective_integration(graph, **args)

    def test_numeric_refs_required(self):
        graph = seed_graph(); args = self.args(); args["acceptance_runs"] = ["run-123"]
        with self.assertRaises(ValidationError): record_objective_integration(graph, **args)

    def test_workflow_source_contract(self):
        from pathlib import Path
        root = Path(__file__).resolve().parents[2]
        text = (root / ".github/workflows/swarm-v16-objective-integrate-command.yml").read_text()
        self.assertIn("github.actor == github.repository_owner", text)
        self.assertIn("contents: write", text)
        self.assertIn("pull-requests: read", text)
        self.assertIn("actions: read", text)
        self.assertIn("persist-credentials: false", text)
        self.assertIn("v16_objective_integrate.py", text)
        self.assertIn("issue_comment:", text)


if __name__ == "__main__": unittest.main(verbosity=2)
