#!/usr/bin/env python3
from __future__ import annotations

import base64
import json
import unittest
from pathlib import Path
from unittest import mock

import v16_legacy_trust_sync as sync
from v16cp.core import ValidationError


class FakeGitHub:
    owner = "owner"
    repo = "repo"
    repository = "owner/repo"
    token = "token"
    max_retries = 0

    def __init__(self, *, race_control: bool = False):
        self.refs = {"swarm-control": "b" * 40, "swarm-trust": "a" * 40, "main": "d" * 40}
        self.race_control = race_control
        self.control_reads = 0
        self.blobs: list[bytes] = []

    def _request(self, method, path, payload=None):
        marker = "/git/ref/heads/"
        refs_marker = "/git/refs/heads/"
        if method == "GET" and marker in path:
            branch = path.split(marker, 1)[1]
            if branch == "swarm-control":
                self.control_reads += 1
                if self.race_control and self.control_reads >= 2:
                    return {"object": {"sha": "f" * 40}}
            return {"object": {"sha": self.refs[branch]}}
        if method == "GET" and "/git/commits/" in path:
            return {"tree": {"sha": "1" * 40}}
        if method == "POST" and path.endswith("/git/blobs"):
            assert payload is not None
            raw = base64.b64decode(payload["content"]) if payload.get("encoding") == "base64" else payload["content"].encode()
            self.blobs.append(raw)
            return {"sha": "2" * 40}
        if method == "POST" and path.endswith("/git/trees"):
            return {"sha": "3" * 40}
        if method == "POST" and path.endswith("/git/commits"):
            return {"sha": "e" * 40}
        if method == "PATCH" and refs_marker in path:
            branch = path.split(refs_marker, 1)[1]
            if payload.get("force") is not False:
                raise AssertionError("trust/control refs must never force-update")
            self.refs[branch] = payload["sha"]
            return {"object": {"sha": payload["sha"]}}
        raise AssertionError(f"unexpected request {method} {path} {payload}")


def trust_record():
    return {
        "schemaVersion": 1,
        "controlBranch": "swarm-control",
        "trustedControlSha": "9" * 40,
        "trustedStateDigest": "8" * 64,
        "validatedAt": "2026-08-13T09:00:00+00:00",
        "validatorMainSha": "7" * 40,
        "resetId": "reset-test-history",
        "resetReason": "finite test recovery",
        "bootstrap": False,
    }


class LegacyTrustSyncTests(unittest.TestCase):
    def test_trust_advance_preserves_reset_boundary_and_is_non_force(self):
        api = FakeGitHub()
        result = sync._advance_trust(
            api,
            trust_branch="swarm-trust",
            expected_trust_head="a" * 40,
            expected_control="b" * 40,
            digest="c" * 64,
            validator_main_sha="d" * 40,
            trust=trust_record(),
        )
        self.assertEqual(result, "e" * 40)
        self.assertEqual(api.refs["swarm-trust"], "e" * 40)
        written = json.loads(api.blobs[-1].decode())
        self.assertEqual(written["trustedControlSha"], "b" * 40)
        self.assertEqual(written["trustedStateDigest"], "c" * 64)
        self.assertEqual(written["validatorMainSha"], "d" * 40)
        self.assertEqual(written["resetId"], "reset-test-history")
        self.assertFalse(written["bootstrap"])

    def test_control_race_is_retryable_and_never_updates_trust_ref(self):
        api = FakeGitHub(race_control=True)
        with self.assertRaisesRegex(sync.RefRace, "control branch advanced"):
            sync._advance_trust(
                api,
                trust_branch="swarm-trust",
                expected_trust_head="a" * 40,
                expected_control="b" * 40,
                digest="c" * 64,
                validator_main_sha="d" * 40,
                trust=trust_record(),
            )
        self.assertEqual(api.refs["swarm-trust"], "a" * 40)

    def test_synchronize_restarts_entire_proof_after_ref_race(self):
        winner = {"status": "PASS", "controlSha": "b" * 40}
        with mock.patch.object(sync, "GitHubContentsStore", return_value=object()), \
             mock.patch.object(sync, "_git", return_value="d" * 40), \
             mock.patch.object(sync, "_synchronize_once", side_effect=[sync.RefRace("moved"), winner]) as once, \
             mock.patch.object(sync.time, "sleep") as sleep:
            result = sync.synchronize("owner/repo", "token", max_race_retries=2)
        self.assertEqual(once.call_count, 2)
        sleep.assert_called_once()
        self.assertEqual(result["raceRetries"], 1)
        self.assertEqual(result["status"], "PASS")

    def test_non_race_validation_failure_is_not_retried(self):
        with mock.patch.object(sync, "GitHubContentsStore", return_value=object()), \
             mock.patch.object(sync, "_git", return_value="d" * 40), \
             mock.patch.object(sync, "_synchronize_once", side_effect=ValidationError("bad history")) as once:
            with self.assertRaisesRegex(ValidationError, "bad history"):
                sync.synchronize("owner/repo", "token", max_race_retries=6)
        self.assertEqual(once.call_count, 1)

    def test_source_contract_replays_history_and_validates_marker(self):
        source = Path(sync.__file__).read_text(encoding="utf-8")
        self.assertIn("trusted_history_chain.py", source)
        self.assertIn("hard.verify_trusted_snapshot", source)
        self.assertIn("hard.validate_all", source)
        self.assertIn("hard.validate_marker", source)
        self.assertIn('"force": False', source)
        self.assertNotIn('"force": True', source)
        self.assertIn("class RefRace", source)
        self.assertIn("max_race_retries", source)

    def test_all_v16_write_workflows_share_lock_and_reconcile_trust(self):
        root = Path(__file__).resolve().parents[2]
        names = (
            "swarm-v16-activate.yml",
            "swarm-v16-live-refresh.yml",
            "swarm-v16-objective-integrate-command.yml",
        )
        for name in names:
            workflow = (root / ".github/workflows" / name).read_text(encoding="utf-8")
            self.assertIn("group: swarm-v16-state-writes", workflow)
            self.assertIn("cancel-in-progress: false", workflow)
            self.assertIn("v16_legacy_trust_sync.py", workflow)
            self.assertIn("--control-branch swarm-control", workflow)
            self.assertIn("--trust-branch swarm-trust", workflow)
        live_refresh = (root / ".github/workflows" / "swarm-v16-live-refresh.yml").read_text(encoding="utf-8")
        self.assertIn("timeout-minutes: 120", live_refresh)
        self.assertIn("actions/checkout@v6", live_refresh)

    def test_generated_projection_scope_is_only_generated_subtree(self):
        source = Path(sync.__file__).read_text(encoding="utf-8")
        self.assertIn('f".swarm/generated/{path.relative_to(generated).as_posix()}"', source)
        self.assertNotIn(".swarm/events/", source)


if __name__ == "__main__":
    unittest.main(verbosity=2)
