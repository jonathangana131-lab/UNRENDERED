#!/usr/bin/env python3
import sys
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools" / "swarm"))
from v16cp.core import continuation_status, recommend, seed_graph


class WorkerPersistenceTests(unittest.TestCase):
    def test_burst_workers_receive_continuations(self):
        graph = seed_graph()
        workers = [f"sol-20260813-burst-{i}" for i in range(30)]
        packets = recommend(graph, workers, 30)
        self.assertEqual(len(packets), 30)
        self.assertTrue(all(not p.packet["STOP_AUTHORIZED"] for p in packets))

    def test_sparse_exclusive_work_uses_assist(self):
        graph = seed_graph()
        for item in graph["workItems"].values():
            item["status"] = "DONE"
        result = continuation_status(graph, "sol-20260813-assist")
        self.assertEqual(result["status"], "ASSIST")
        self.assertFalse(result["stopAuthorized"])
        self.assertTrue(result["next"].packet["NON_EXCLUSIVE_ASSIST"])
        self.assertFalse(result["next"].packet["MAY_CREATE_BRANCH"])

    def test_stop_needs_internal_exhaustion(self):
        graph = seed_graph()
        for item in graph["workItems"].values():
            item["status"] = "DONE"
        for objective in graph["objectives"].values():
            objective["status"] = "DONE"
        result = continuation_status(graph, "sol-20260813-stop")
        self.assertEqual(result["status"], "STOP")
        self.assertTrue(result["stopAuthorized"])


if __name__ == "__main__":
    unittest.main()
