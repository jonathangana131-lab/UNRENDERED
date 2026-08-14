#!/usr/bin/env python3
"""Adversarial tests for post-reset first-parent trusted-history continuity."""
from __future__ import annotations

import hashlib
import json
import subprocess
import tempfile
from pathlib import Path
import unittest

from test_swarmctl_hardening_base import Fx, NOW, core, lane as lane_fixture, write
import swarm_burst_event_replay as burst_replay
import swarm_burst_takeover_recovery as burst_takeover
import swarm_failed_control_recovery as failed_recovery
import swarm_history_recovery_extension as extension
import swarm_history_recovery_manifest as recovery
import swarm_lane_history_replay as lane_replay
import swarm_worker_status_replay as worker_replay
import swarmctl_hardening as hard
import trusted_history_chain as chain


class BurstReplayHardeningFake:
    def __init__(self, registry: dict, event_id: str, relative: Path):
        self._CANONICAL_IMMUTABLE_EVENTS = registry
        self.event_id = event_id
        self.relative = relative
        self.core = core
        self.authoritative = False

    def _git_blob_sha1(self, path: Path) -> str:
        raw = Path(path).read_bytes()
        header = f"blob {len(raw)}\0".encode("ascii")
        return hashlib.sha1(header + raw).hexdigest()

    def transition_check(self, before: Path, after: Path) -> dict:
        before_exists = (Path(before) / self.relative).exists()
        after_exists = (Path(after) / self.relative).exists()
        if before_exists != after_exists:
            raise core.ControlError("strict immutable event addition rejected")
        return {"status": "PASS"}

    def _validate_event_with_immutable_compat(self, path: Path) -> dict:
        rule = self._CANONICAL_IMMUTABLE_EVENTS.get(self.event_id)
        if not isinstance(rule, dict):
            raise core.ControlError("missing quarantine identity")
        if rule.get("quarantineOnlyGitBlobSha1") != self._git_blob_sha1(path):
            raise core.ControlError("quarantine identity blob mismatch")
        return {
            "eventId": self.event_id,
            "_quarantined": not self.authoritative,
            "quarantineOnly": not self.authoritative,
        }

    def quarantined_history(self, root: Path) -> list[str]:
        return [self.event_id] if (Path(root) / self.relative).is_file() else []


class FiniteTakeoverHardeningFake:
    def __init__(self, relative: Path, previous_worker: str):
        self.relative = relative
        self.previous_worker = previous_worker
        self.core = core

    @staticmethod
    def _git_blob_sha1(path: Path) -> str:
        return hard._git_blob_sha1(path)

    def transition_check(self, _before: Path, after: Path) -> dict:
        claim = core.load_json(Path(after) / self.relative, max_bytes=32_000)
        if claim.get("takeoverOf") != self.previous_worker:
            raise core.ControlError("takeoverOf must identify previous worker")
        return {"status": "PASS"}


class TrustedHistoryChainTests(unittest.TestCase):
    def valid_event(self, summary: str) -> dict:
        return {"schemaVersion":1,"eventId":"evt-20260811-214000-chain-regression","timestamp":NOW,"fromWorker":"sol-20260811-a81f","eventType":"FINDING","severity":"normal","summary":summary,"affects":[]}

    def test_restored_descendant_cannot_launder_invalid_middle_commit(self):
        trusted, invalid, restored = Fx(), Fx(), Fx()
        try:
            event_path = Path("events/2026-08-11/chain.json")
            write(trusted.root / event_path, self.valid_event("trusted bytes"))
            write(invalid.root / event_path, self.valid_event("rewritten invalid bytes"))
            write(restored.root / event_path, self.valid_event("trusted bytes"))
            self.assertEqual(hard.transition_check(trusted.root, restored.root)["status"], "PASS")
            with self.assertRaises(core.ControlError): chain.validate_snapshot_chain([trusted.root, invalid.root, restored.root])
        finally:
            trusted.close(); invalid.close(); restored.close()

    def test_add_then_delete_cannot_disappear_between_trusted_endpoints(self):
        trusted, added, deleted = Fx(), Fx(), Fx()
        try:
            event_path = Path("events/2026-08-11/transient.json")
            event = self.valid_event("transient append"); event["eventId"] = "evt-20260811-214100-chain-transient"
            write(added.root / event_path, event)
            self.assertEqual(hard.transition_check(trusted.root, deleted.root)["status"], "PASS")
            with self.assertRaises(core.ControlError): chain.validate_snapshot_chain([trusted.root, added.root, deleted.root])
        finally:
            trusted.close(); added.close(); deleted.close()

    def test_first_parent_commit_order_is_deterministic(self):
        with tempfile.TemporaryDirectory() as temp:
            repo = Path(temp); subprocess.run(["git","init","-q",str(repo)], check=True)
            subprocess.run(["git","-C",str(repo),"config","user.name","test"], check=True)
            subprocess.run(["git","-C",str(repo),"config","user.email","test@example.invalid"], check=True)
            def commit(value: str) -> str:
                (repo / "marker.txt").write_text(value, encoding="utf-8")
                subprocess.run(["git","-C",str(repo),"add","marker.txt"], check=True)
                subprocess.run(["git","-C",str(repo),"commit","-q","-m",value], check=True)
                return subprocess.check_output(["git","-C",str(repo),"rev-parse","HEAD"], text=True).strip()
            trusted_sha = commit("trusted"); middle_sha = commit("middle"); control_sha = commit("control")
            self.assertEqual(chain.first_parent_commits(repo, trusted_sha, control_sha), [middle_sha, control_sha])

    def test_worldentity_takeover_bridge_is_exact_git_and_blob_pinned(self):
        relative = Path("claims/HG-BACKFILL-WORLDENTITY/primary.json")
        rule = burst_takeover.GIT_RULES[relative.as_posix()]
        self.assertEqual(
            rule,
            {
                "predecessorSha": "2e354e477e0ed7566b5832ed2a16a7dafa0c027f",
                "commitSha": "72c2530d3cfe8d8fdff08c06472e67b52266e217",
                "beforeGitBlobSha1": "b1deb0f37009dd90d7b2f120dd78f6ef43aaa8a4",
                "afterGitBlobSha1": "13edc7064471e5e8705b1f04a2f2a7ad8a75191f",
                "takeoverOf": "sol-20260812-q6n9v2m4",
            },
        )
        before_raw = b'''{
  "schemaVersion": 1,
  "laneId": "HG-BACKFILL-WORLDENTITY",
  "slotId": "primary",
  "workerId": "sol-20260812-q6n9v2m4",
  "claimToken": "e5c27a914bd3608f",
  "claimedAt": "2026-08-12T10:45:45+00:00",
  "heartbeatAt": "2026-08-12T11:06:30+00:00",
  "leaseSeconds": 1800,
  "generation": 9,
  "resources": ["REALITY-CONTRACT"],
  "branch": "agent/reality/HG-BACKFILL-WORLDENTITY-origin-evidence-q6n9v2m4",
  "pr": 437
}
'''
        after_raw = b'''{
  "schemaVersion": 1,
  "laneId": "HG-BACKFILL-WORLDENTITY",
  "slotId": "primary",
  "workerId": "sol-20260814-k8m2q6v4",
  "claimToken": "5a9c2e7d4b1f8063",
  "claimedAt": "2026-08-14T07:40:00+00:00",
  "heartbeatAt": "2026-08-14T07:40:00+00:00",
  "leaseSeconds": 1800,
  "generation": 10,
  "resources": ["REALITY-CONTRACT"],
  "branch": "agent/reality/HG-BACKFILL-WORLDENTITY-primary-k8m2q6v4-g10",
  "pr": null
}
'''

        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            before = root / "before"
            after = root / "after"
            before_path = before / relative
            after_path = after / relative
            before_path.parent.mkdir(parents=True)
            after_path.parent.mkdir(parents=True)
            before_path.write_bytes(before_raw)
            after_path.write_bytes(after_raw)
            fake = FiniteTakeoverHardeningFake(relative, rule["takeoverOf"])
            changed = (f".swarm/{relative.as_posix()}",)

            with self.assertRaises(core.ControlError):
                fake.transition_check(before, after)
            result = burst_takeover.validate_git_transition(
                fake,
                rule["predecessorSha"],
                rule["commitSha"],
                changed,
                before,
                after,
            )
            self.assertEqual(result["status"], "PASS")
            self.assertEqual(result["finiteHistoricalTakeoverCompat"], [relative.as_posix()])
            self.assertEqual(
                result["historicalGitTransition"],
                {"predecessorSha": rule["predecessorSha"], "commitSha": rule["commitSha"]},
            )
            self.assertIsNone(
                burst_takeover.validate_git_transition(
                    fake,
                    "f" * 40,
                    rule["commitSha"],
                    changed,
                    before,
                    after,
                )
            )
            with self.assertRaises(core.ControlError):
                burst_takeover.validate_git_transition(
                    fake,
                    rule["predecessorSha"],
                    rule["commitSha"],
                    changed + (".swarm/workers/unrelated.json",),
                    before,
                    after,
                )
            after_path.write_bytes(after_raw + b" ")
            with self.assertRaises(core.ControlError):
                burst_takeover.validate_git_transition(
                    fake,
                    rule["predecessorSha"],
                    rule["commitSha"],
                    changed,
                    before,
                    after,
                )

    def test_git_takeover_compatibility_inventory_is_complete_and_finite(self):
        expected = {
            "claims/HG-CAPACITY-MINING/mine-diagnostics.json": {
                "predecessorSha": "1a9cfdbbb82ca9a799e8579667a2fba0b6d1402c",
                "commitSha": "97e5c7d4643c0cee914983c3eeb2f523be90c484",
                "beforeGitBlobSha1": "487b795f6e33e40c78686eccca7e7737a03348a4",
                "afterGitBlobSha1": "76072a219b5a5989fd0dc0f3eade316befff6c83",
                "takeoverOf": "sol-20260812-am0s2f7s",
            },
            "claims/HG-BACKFILL-WORLDENTITY/primary.json": {
                "predecessorSha": "2e354e477e0ed7566b5832ed2a16a7dafa0c027f",
                "commitSha": "72c2530d3cfe8d8fdff08c06472e67b52266e217",
                "beforeGitBlobSha1": "b1deb0f37009dd90d7b2f120dd78f6ef43aaa8a4",
                "afterGitBlobSha1": "13edc7064471e5e8705b1f04a2f2a7ad8a75191f",
                "takeoverOf": "sol-20260812-q6n9v2m4",
            },
            "claims/HG-CAPACITY-MINING/mine-authority.json": {
                "predecessorSha": "8c11228ad0295b4262df1dfd458dce730e8fa4b2",
                "commitSha": "55f5013b11d76ae056519a87027b63760b816c6f",
                "beforeGitBlobSha1": "0fd887f2f7ace8cae0d823126b508cee5ea593bd",
                "afterGitBlobSha1": "19cc4c10387b7d6d56026b560b327b1d884090fd",
                "takeoverOf": "sol-20260814-r6h3n9v2",
            },
            "claims/HG-BACKFILL-DIAGNOSTICS/primary.json": {
                "predecessorSha": "90a5e01349aa3aec0debeff621e3ee75cc6d19d9",
                "commitSha": "ce2324bd22af80993ceb92e9af61e39ab8ccfc6d",
                "beforeGitBlobSha1": "9cca8772895351c6f7b04c3717aadd1f0cfcd231",
                "afterGitBlobSha1": "263c0d08c7f8ea2417aadb0d811503b8ee254cee",
                "takeoverOf": "sol-20260814-t5n8q3v6",
            },
            "claims/SWARM-RECOVERY-EVENT-HISTORY-CONTINUITY/primary.json": {
                "predecessorSha": "b578b42b0f5fc34e46c6d8d0f07e3136badd4ed7",
                "commitSha": "8a2c4e26000fa3cefdd233a04ffdf2b8cf0b1add",
                "beforeGitBlobSha1": "4d0f1a35cf4d8d6384b209f103c6183b1504ad93",
                "afterGitBlobSha1": "1e9908edec975a41c2a5ddcf3ec867f516c3fbe5",
                "takeoverOf": "sol-20260814-q5n8v2c4",
            },
            "claims/HG-BACKFILL-DIAGNOSTICS/audit.json": {
                "predecessorSha": "1c886c3aa3d9a7ae9e502ad4c838ff32f2483eb7",
                "commitSha": "5f3c31707482a6b3992b9815545b3c0eb8061381",
                "beforeGitBlobSha1": "fdd42664e3bfa2d1b6f28cd6d6cd8902ac149f84",
                "afterGitBlobSha1": "ed12ece93e9749dab92b0da8e222dbbf700708c0",
                "takeoverOf": "sol-20260814-r6h3n9v2",
            },
        }
        self.assertEqual(burst_takeover.GIT_RULES, expected)

    def test_worker_schema_replay_is_exact_finite_and_history_only(self):
        inventory = json.dumps(worker_replay.RULES, sort_keys=True, separators=(",", ":")).encode()
        self.assertEqual(len(worker_replay.RULES), 9)
        self.assertEqual(
            hashlib.sha256(inventory).hexdigest(),
            "8a984e5f2ff1aec297caf77fce216da310a400fe1aac5ef55fcaa1529cb3c1f1",
        )
        self.assertEqual(
            {(rule["invalidStatus"], rule["canonicalStatus"]) for rule in worker_replay.RULES},
            {
                ("READY", "IDLE"),
                ("READY", "WORKING"),
                ("READY", "REVIEWING"),
                ("MINING", "WORKING"),
                ("WORKING", "WORKING"),
            },
        )
        self.assertEqual(len({rule["introductionCommitSha"] for rule in worker_replay.RULES}), 9)
        self.assertEqual(len({rule["repairCommitSha"] for rule in worker_replay.RULES}), 9)

        with tempfile.TemporaryDirectory() as temp:
            repo = Path(temp) / "repo"
            subprocess.run(["git", "init", "-q", str(repo)], check=True)
            subprocess.run(["git", "-C", str(repo), "config", "user.name", "test"], check=True)
            subprocess.run(["git", "-C", str(repo), "config", "user.email", "test@example.invalid"], check=True)
            relative = Path("workers/sol-20990101-test1234.json")
            git_relative = Path(".swarm") / relative
            worker_path = repo / git_relative
            worker_path.parent.mkdir(parents=True)

            def commit_worker(status: str, message: str, extra: dict | None = None) -> str:
                worker = {
                    "schemaVersion": core.SCHEMA_VERSION,
                    "workerId": relative.stem,
                    "model": "gpt-5.6-sol",
                    "status": status,
                    "startedAt": "2099-01-01T00:00:00Z",
                    "lastSeenAt": "2099-01-01T00:01:00Z",
                    **(extra or {}),
                }
                worker_path.write_text(json.dumps(worker, indent=2) + "\n", encoding="utf-8")
                subprocess.run(["git", "-C", str(repo), "add", str(git_relative)], check=True)
                subprocess.run(["git", "-C", str(repo), "commit", "-q", "-m", message], check=True)
                return subprocess.check_output(["git", "-C", str(repo), "rev-parse", "HEAD"], text=True).strip()

            base_sha = commit_worker("IDLE", "base")
            invalid_extra = {"claimToken": "test-token", "generation": 3}
            intro_sha = commit_worker("READY", "invalid introduction", invalid_extra)
            marker = repo / ".swarm" / "marker.json"
            marker.write_text('{"middle":true}\n', encoding="utf-8")
            subprocess.run(["git", "-C", str(repo), "add", ".swarm/marker.json"], check=True)
            subprocess.run(["git", "-C", str(repo), "commit", "-q", "-m", "middle"], check=True)
            middle_sha = subprocess.check_output(["git", "-C", str(repo), "rev-parse", "HEAD"], text=True).strip()
            repair_sha = commit_worker("WORKING", "repair")
            invalid_blob = subprocess.check_output(
                ["git", "-C", str(repo), "rev-parse", f"{intro_sha}:{git_relative.as_posix()}"],
                text=True,
            ).strip()
            repair_blob = subprocess.check_output(
                ["git", "-C", str(repo), "rev-parse", f"{repair_sha}:{git_relative.as_posix()}"],
                text=True,
            ).strip()
            rule = {
                "path": relative.as_posix(),
                "introductionPredecessorSha": base_sha,
                "introductionCommitSha": intro_sha,
                "invalidGitBlobSha1": invalid_blob,
                "invalidStatus": "READY",
                "canonicalStatus": "WORKING",
                "invalidExtraFields": invalid_extra,
                "repairCommitSha": repair_sha,
                "repairGitBlobSha1": repair_blob,
                "repairStatus": "WORKING",
                "repairExtraFields": {},
            }

            def snapshot(sha: str, name: str) -> Path:
                root = Path(temp) / name
                destination = root / relative
                destination.parent.mkdir(parents=True)
                destination.write_bytes(
                    subprocess.check_output(["git", "-C", str(repo), "show", f"{sha}:{git_relative.as_posix()}"])
                )
                return root

            original_rules = worker_replay.RULES
            worker_replay.RULES = (rule,)
            try:
                with self.assertRaises(core.ControlError):
                    worker_replay.advance_transition(
                        hard,
                        repo,
                        "f" * 40,
                        intro_sha,
                        (git_relative.as_posix(),),
                        snapshot(intro_sha, "wrong-parent"),
                        {},
                    )

                active = {}
                intro_root = snapshot(intro_sha, "intro")
                intro = worker_replay.advance_transition(
                    hard,
                    repo,
                    base_sha,
                    intro_sha,
                    (git_relative.as_posix(),),
                    intro_root,
                    active,
                )
                self.assertEqual(intro["activated"], [relative.as_posix()])
                normalized_intro = json.loads((intro_root / relative).read_text())
                self.assertEqual(normalized_intro["status"], "WORKING")
                self.assertNotIn("claimToken", normalized_intro)
                self.assertNotIn("generation", normalized_intro)

                middle_root = snapshot(middle_sha, "middle")
                middle = worker_replay.advance_transition(
                    hard,
                    repo,
                    intro_sha,
                    middle_sha,
                    (".swarm/marker.json",),
                    middle_root,
                    active,
                )
                self.assertEqual(middle["normalized"], [relative.as_posix()])
                normalized_middle = json.loads((middle_root / relative).read_text())
                self.assertEqual(normalized_middle["status"], "WORKING")
                self.assertNotIn("claimToken", normalized_middle)
                self.assertNotIn("generation", normalized_middle)

                repair_root = snapshot(repair_sha, "repair")
                repaired = worker_replay.advance_transition(
                    hard,
                    repo,
                    middle_sha,
                    repair_sha,
                    (git_relative.as_posix(),),
                    repair_root,
                    active,
                )
                self.assertEqual(repaired["repaired"], [relative.as_posix()])
                self.assertEqual(active, {})
                self.assertEqual(json.loads((repair_root / relative).read_text())["status"], "WORKING")

                future_root = snapshot(intro_sha, "future-strict")
                strict = worker_replay.advance_transition(
                    hard,
                    repo,
                    repair_sha,
                    "e" * 40,
                    (git_relative.as_posix(),),
                    future_root,
                    active,
                )
                self.assertEqual(strict["normalized"], [])
                future = json.loads((future_root / relative).read_text())
                self.assertEqual(future["status"], "READY")
                self.assertEqual(future["claimToken"], "test-token")
                self.assertEqual(future["generation"], 3)
            finally:
                worker_replay.RULES = original_rules

    def test_lane_priority_replay_is_exact_finite_and_history_only(self):
        self.assertEqual(
            lane_replay.RULES,
            (
                {
                    "path": "lanes/SWARM-V16.2-INTEGRATION-THROUGHPUT.json",
                    "introductionPredecessorSha": "01000bcf7f3e1c91b5e03f6e192d96840826681c",
                    "introductionCommitSha": "57024a8dac6533ffe6906db96409b21393dcfe77",
                    "invalidGitBlobSha1": "3d0bd0536ec2caf0c39958124effb9ef6a2a74a8",
                    "slotId": "primary",
                    "invalidPriorityBoost": 1200,
                    "canonicalPriorityBoost": 1000,
                    "repairCommitSha": "d694e5b6b32e92535428d97592ddedf9a9da8a66",
                    "repairGitBlobSha1": "ca2f3f46506855f436f2491ee0e474927368fdac",
                    "repairPriorityBoost": 1000,
                },
            ),
        )

        with tempfile.TemporaryDirectory() as temp:
            repo = Path(temp) / "repo"
            subprocess.run(["git", "init", "-q", str(repo)], check=True)
            subprocess.run(["git", "-C", str(repo), "config", "user.name", "test"], check=True)
            subprocess.run(["git", "-C", str(repo), "config", "user.email", "test@example.invalid"], check=True)
            relative = Path("lanes/SYNTH-LANE.json")
            git_relative = Path(".swarm") / relative
            lane_path = repo / git_relative
            lane_path.parent.mkdir(parents=True)
            value = lane_fixture("SYNTH-LANE")

            def commit_lane(boost: int, message: str) -> str:
                value["slots"][0]["priorityBoost"] = boost
                lane_path.write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8")
                subprocess.run(["git", "-C", str(repo), "add", str(git_relative)], check=True)
                subprocess.run(["git", "-C", str(repo), "commit", "-q", "-m", message], check=True)
                return subprocess.check_output(["git", "-C", str(repo), "rev-parse", "HEAD"], text=True).strip()

            base_sha = commit_lane(1000, "base")
            intro_sha = commit_lane(1200, "invalid introduction")
            marker = repo / ".swarm" / "marker.json"
            marker.write_text('{"middle":true}\n', encoding="utf-8")
            subprocess.run(["git", "-C", str(repo), "add", ".swarm/marker.json"], check=True)
            subprocess.run(["git", "-C", str(repo), "commit", "-q", "-m", "middle"], check=True)
            middle_sha = subprocess.check_output(["git", "-C", str(repo), "rev-parse", "HEAD"], text=True).strip()
            repair_sha = commit_lane(1000, "repair")
            invalid_blob = subprocess.check_output(
                ["git", "-C", str(repo), "rev-parse", f"{intro_sha}:{git_relative.as_posix()}"],
                text=True,
            ).strip()
            repair_blob = subprocess.check_output(
                ["git", "-C", str(repo), "rev-parse", f"{repair_sha}:{git_relative.as_posix()}"],
                text=True,
            ).strip()
            rule = {
                "path": relative.as_posix(),
                "introductionPredecessorSha": base_sha,
                "introductionCommitSha": intro_sha,
                "invalidGitBlobSha1": invalid_blob,
                "slotId": "primary",
                "invalidPriorityBoost": 1200,
                "canonicalPriorityBoost": 1000,
                "repairCommitSha": repair_sha,
                "repairGitBlobSha1": repair_blob,
                "repairPriorityBoost": 1000,
            }

            def snapshot(sha: str, name: str) -> Path:
                root = Path(temp) / name
                destination = root / relative
                destination.parent.mkdir(parents=True)
                destination.write_bytes(
                    subprocess.check_output(["git", "-C", str(repo), "show", f"{sha}:{git_relative.as_posix()}"])
                )
                return root

            original_rules = lane_replay.RULES
            lane_replay.RULES = (rule,)
            try:
                active = {}
                intro_root = snapshot(intro_sha, "lane-intro")
                introduced = lane_replay.advance_transition(
                    hard,
                    repo,
                    base_sha,
                    intro_sha,
                    (git_relative.as_posix(),),
                    intro_root,
                    active,
                )
                self.assertEqual(introduced["activated"], [relative.as_posix()])
                self.assertEqual(json.loads((intro_root / relative).read_text())["slots"][0]["priorityBoost"], 1000)

                middle_root = snapshot(middle_sha, "lane-middle")
                middle = lane_replay.advance_transition(
                    hard,
                    repo,
                    intro_sha,
                    middle_sha,
                    (".swarm/marker.json",),
                    middle_root,
                    active,
                )
                self.assertEqual(middle["normalized"], [relative.as_posix()])

                repair_root = snapshot(repair_sha, "lane-repair")
                repaired = lane_replay.advance_transition(
                    hard,
                    repo,
                    middle_sha,
                    repair_sha,
                    (git_relative.as_posix(),),
                    repair_root,
                    active,
                )
                self.assertEqual(repaired["repaired"], [relative.as_posix()])
                self.assertEqual(active, {})

                future_root = snapshot(intro_sha, "lane-future-strict")
                lane_replay.advance_transition(
                    hard,
                    repo,
                    repair_sha,
                    "e" * 40,
                    (git_relative.as_posix(),),
                    future_root,
                    active,
                )
                with self.assertRaises(core.ControlError):
                    core.validate_lane(future_root / relative)
            finally:
                lane_replay.RULES = original_rules

    def test_incremental_snapshot_matches_exact_git_tree(self):
        with tempfile.TemporaryDirectory() as temp:
            repo = Path(temp) / "repo"
            subprocess.run(["git", "init", "-q", str(repo)], check=True)
            subprocess.run(["git", "-C", str(repo), "config", "user.name", "test"], check=True)
            subprocess.run(["git", "-C", str(repo), "config", "user.email", "test@example.invalid"], check=True)
            swarm = repo / ".swarm"
            (swarm / "nested").mkdir(parents=True)
            (swarm / "config.json").write_text('{"revision":1}\n', encoding="utf-8")
            (swarm / "nested" / "delete.json").write_text('{"delete":true}\n', encoding="utf-8")
            subprocess.run(["git", "-C", str(repo), "add", ".swarm"], check=True)
            subprocess.run(["git", "-C", str(repo), "commit", "-q", "-m", "trusted"], check=True)
            trusted_sha = subprocess.check_output(["git", "-C", str(repo), "rev-parse", "HEAD"], text=True).strip()

            (swarm / "config.json").write_text('{"revision":2}\n', encoding="utf-8")
            (swarm / "nested" / "delete.json").unlink()
            (swarm / "nested" / "added.json").write_text('{"added":true}\n', encoding="utf-8")
            (swarm / "config-link").symlink_to("config.json")
            subprocess.run(["git", "-C", str(repo), "add", "-A", ".swarm"], check=True)
            subprocess.run(["git", "-C", str(repo), "commit", "-q", "-m", "candidate"], check=True)
            candidate_sha = subprocess.check_output(["git", "-C", str(repo), "rev-parse", "HEAD"], text=True).strip()

            snapshots = Path(temp) / "snapshots"
            actual = chain._archive_swarm(repo, trusted_sha, snapshots / "actual")
            expected = chain._archive_swarm(repo, candidate_sha, snapshots / "expected")
            changed = chain._sync_swarm_snapshot(repo, actual, trusted_sha, candidate_sha)
            self.assertEqual(
                changed,
                (
                    ".swarm/config-link",
                    ".swarm/config.json",
                    ".swarm/nested/added.json",
                    ".swarm/nested/delete.json",
                ),
            )

            def inventory(root: Path) -> dict[str, tuple[str, bytes | str]]:
                result: dict[str, tuple[str, bytes | str]] = {}
                for path in sorted(root.rglob("*")):
                    relative = path.relative_to(root).as_posix()
                    if path.is_symlink():
                        result[relative] = ("symlink", path.readlink().as_posix())
                    elif path.is_file():
                        result[relative] = ("file", path.read_bytes())
                return result

            self.assertEqual(inventory(actual), inventory(expected))

    def test_failed_control_recovery_is_exact_finite_and_event_fenced(self):
        self.assertEqual(len(failed_recovery.FAILED_CONTROL_RECOVERY_PAIRS), 1)
        row = failed_recovery.FAILED_CONTROL_RECOVERY_PAIRS[0]
        self.assertEqual(row["predecessorSha"], "d7bc6b94419c26e11ba56f920635fc784b9dffa3")
        self.assertEqual(row["invalidSha"], "69836b4ac25576138c95cd0794204c639bd234f4")
        self.assertEqual(row["repairSha"], "6e38cee9ae4d4c2d71b36a944cd22aca232f3497")
        self.assertIs(row, chain._recovery_pair(row["predecessorSha"], row["invalidSha"], row["repairSha"]))
        self.assertIsNone(chain._recovery_pair(row["predecessorSha"], row["invalidSha"], "f" * 40))
        self.assertFalse(any(path.startswith(".swarm/events/") for path in row["invalidChangedPaths"] + row["repairChangedPaths"]))
        self.assertEqual(set(row["repairChangedPaths"]), {".swarm/claims/SWARM-RECOVERY-HEALTH-VALIDATION-FENCE/primary.json", ".swarm/resource-claims/SWARM-PROTOCOL.json"})

    def test_path_divergent_malformed_handoffs_are_finitely_pinned(self):
        rows = recovery.malformed_event_quarantine_rows()
        expected = {
            ("evt-20260811T210500Z-sol-20260811-c7p4m8v2-handoff-content-reconciliation","210500-sol-20260811-c7p4m8v2-handoff-content-reconciliation.json","be4caea3394068a2883045842bf1d132e37cd157","713d54c453faa65e89875e69499444d5a7644d3f"),
            ("evt-20260811T211000Z-sol-20260811-m5q8v2c4-handoff-physics-reconciliation","211000-sol-20260811-m5q8v2c4-handoff-physics-reconciliation.json","da63fb468a9af4ff4b1767df7c985335b5e45b08","f3ed0bc34d02a0db011ca612853c7b797201194d"),
        }
        self.assertTrue(expected.issubset(set(rows)))
        rules = recovery.quarantine_rules()
        for event_id, filename, _first_write, blob_sha in expected:
            self.assertEqual(rules[event_id]["filename"], filename); self.assertEqual(rules[event_id]["quarantineOnlyGitBlobSha1"], blob_sha)

    def test_burst_quarantine_inventory_is_existing_manifest_only(self):
        expected = {
            "evt-20260813-225000-8fa445-authority-current-main-no-new-gap": {
                "date": "2026-08-13",
                "filename": "evt-20260813-225000-8fa445-authority-current-main-no-new-gap.json",
                "quarantineOnlyGitBlobSha1": "6503ee1458957314660adab6ef1e56793e775175",
                "introductionPredecessorSha": "a3ec4ac5ca87ab5fd7058c22a33af44d69fd51bd",
                "introductionCommitSha": "47e9d65cb46852f396cfe109836623f4063d0d03",
            },
            "evt-20260813-224945-f4q9n2c7-fidelity-extra-keys": {
                "date": "2026-08-13",
                "filename": "evt-20260813-224945-f4q9n2c7-fidelity-extra-keys.json",
                "quarantineOnlyGitBlobSha1": "0dd395b2757e7e3685b5c79aa6d6852ee50e85f3",
                "introductionPredecessorSha": "9857896b91f14e402c869cbd873cfa1bd158b738",
                "introductionCommitSha": "407732f50438acc4f11da30cca17c348936e73f8",
            },
            "evt-20260813-225110-j4n7q2v9-diagnostics-docs-g3-review-request": {
                "date": "2026-08-13",
                "filename": "225110-sol-20260813-j4n7q2v9-review-request-diagnostics-docs-g3.json",
                "quarantineOnlyGitBlobSha1": "835076ffce9bf4f355aa9f9b6d85f54177543421",
                "introductionPredecessorSha": "ebf8b6e120b2ec4a684fa4c365aaafc87b144f22",
                "introductionCommitSha": "af25c84703c1bde8beb84cdb1853ebd07aea6bea",
            },
            "evt-20260814-083730-h7v2m9c5-filing-cabinet-drawer-enclosure": {
                "date": "2026-08-14",
                "filename": "083730-sol-20260814-h7v2m9c5-finding-filing-cabinet-drawer-enclosure.json",
                "quarantineOnlyGitBlobSha1": "2611077927a39ae20b172a579d2bb901a797f885",
                "introductionPredecessorSha": "a62115cc5a8e552147c947b4e2b778065fb2bedc",
                "introductionCommitSha": "ec007fde435a380e5ea25ba48354007acab5b208",
            },
            "evt-20260814-085700-q8m4n7v2-worldentity-current-main-convergence-pr504": {
                "date": "2026-08-14",
                "filename": "085700-sol-20260814-q8m4n7v2-worldentity-current-main-convergence-pr504.json",
                "quarantineOnlyGitBlobSha1": "eb01bde52bc7f284271c7fab40485fc7ab8b04ce",
                "introductionPredecessorSha": "9355633299fc8523ba6ef86f4b362c2c02db1c0f",
                "introductionCommitSha": "8de5bcceb9c7f341f384a7419bd2e6ce9685d9c3",
            },
        }
        self.assertEqual(burst_replay.QUARANTINE_ONLY_RULES, expected)
        manifest = extension.quarantine_rules()
        for event_id, rule in expected.items():
            self.assertEqual(
                manifest[event_id],
                {
                    "date": rule["date"],
                    "filename": rule["filename"],
                    "quarantineOnlyGitBlobSha1": rule["quarantineOnlyGitBlobSha1"],
                },
            )
        burst_replay.install(hard)

    def test_repaired_invalid_event_ids_are_exact_and_blob_fenced(self):
        expected = {
            "evt-5845475e-runtime-recipe-order-authenticity": {
                "date": "2026-08-14",
                "filename": "082920-sol-20260814-5845475e-runtime-recipe-order-authenticity.json",
                "quarantinedGitBlobSha1": "c23d073c2325ab49b7517242504f40afdcd0f967",
                "quarantinedEventId": "082920-sol-20260814-5845475e-runtime-recipe-order-authenticity",
                "canonicalGitBlobSha1": "5e8ea154e6e78e4e2b97466e39aa154dc2bc50b7",
                "introductionPredecessorSha": "dc2b293615ce4c0899e7abb2c04fd6c211e241f0",
                "introductionCommitSha": "2fdfd3f477ec8ce2c0fb25d2ebdab9151b4c658e",
                "repairPredecessorSha": "5759e566b9f0b72566171c455361c59f39b1d909",
                "repairCommitSha": "6bde0422287494324a4ce797d26f9135da9e295c",
            },
            "evt-5845475e-runtime-order-review-request": {
                "date": "2026-08-14",
                "filename": "083040-sol-20260814-5845475e-runtime-order-review-request.json",
                "quarantinedGitBlobSha1": "e74d33e697bdfd552ba1f16593658a3f2665e9bd",
                "quarantinedEventId": "083040-sol-20260814-5845475e-runtime-order-review-request",
                "canonicalGitBlobSha1": "4d15e5d9f3ab9a8e8d9a4bb558ab681bcb76ebb9",
                "introductionPredecessorSha": "ff9212fb1212c0c95e26d56bd166b39296d78df5",
                "introductionCommitSha": "ab4a4e206ffb8539e16d6b40a76d427ad72d21a5",
                "repairPredecessorSha": "e588ad047aec2cca9bb8ffefe4ff4c8bdc029307",
                "repairCommitSha": "ed73d49d7168bc6c6deb2d586db7725e9b4b7902",
            },
        }
        self.assertEqual(len(burst_replay.RULES), 7)
        for event_id, rule in expected.items():
            self.assertEqual(burst_replay.RULES[event_id], rule)

        canonical_id = "evt-20990101-000000-repaired-id"
        malformed_id = "000000-sol-20990101-repaired-id"
        date = "2099-01-01"
        filename = "000000-sol-20990101-repaired-id.json"
        relative = Path("events") / date / filename
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / relative
            path.parent.mkdir(parents=True)
            event = self.valid_event("finite malformed id")
            event["eventId"] = malformed_id
            write(path, event)
            quarantined_blob = hard._git_blob_sha1(path)
            event["eventId"] = canonical_id
            write(path, event)
            canonical_blob = hard._git_blob_sha1(path)
            event["eventId"] = malformed_id
            write(path, event)

            registry_rule = {
                "date": date,
                "filename": filename,
                "quarantinedGitBlobSha1": quarantined_blob,
                "quarantinedEventId": malformed_id,
                "canonicalGitBlobSha1": canonical_blob,
            }
            hard._CANONICAL_IMMUTABLE_EVENTS[canonical_id] = registry_rule
            try:
                quarantined = hard._validate_event_with_immutable_compat(path)
                self.assertTrue(quarantined["_quarantined"])
                self.assertEqual(quarantined["eventId"], canonical_id)

                event["summary"] = "changed unlisted bytes"
                write(path, event)
                with self.assertRaises(core.ControlError):
                    hard._validate_event_with_immutable_compat(path)

                event["summary"] = "finite malformed id"
                event["eventId"] = canonical_id
                write(path, event)
                canonical = hard._validate_event_with_immutable_compat(path)
                self.assertEqual(canonical["eventId"], canonical_id)
                self.assertNotIn("_quarantined", canonical)
            finally:
                del hard._CANONICAL_IMMUTABLE_EVENTS[canonical_id]

    def test_burst_quarantine_introduction_bridge_is_exact_and_inert(self):
        event_id = "evt-20990101-000000-test-quarantine-only"
        date = "2099-01-01"
        filename = "evt-20990101-000000-test-quarantine-only.json"
        relative = Path("events") / date / filename
        git_relative = f".swarm/{relative.as_posix()}"
        predecessor = "1" * 40
        commit = "2" * 40
        raw = b'{"malformed":true}'

        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            before = root / "before"
            after = root / "after"
            before.mkdir()
            (after / relative.parent).mkdir(parents=True)
            after_path = after / relative
            after_path.write_bytes(raw)
            raw_header = f"blob {len(raw)}\0".encode("ascii")
            blob_sha = hashlib.sha1(raw_header + raw).hexdigest()
            rule = {
                "date": date,
                "filename": filename,
                "quarantineOnlyGitBlobSha1": blob_sha,
                "introductionPredecessorSha": predecessor,
                "introductionCommitSha": commit,
            }
            registry_rule = {
                "date": date,
                "filename": filename,
                "quarantineOnlyGitBlobSha1": blob_sha,
            }
            original_rules = burst_replay.QUARANTINE_ONLY_RULES
            burst_replay.QUARANTINE_ONLY_RULES = {event_id: rule}
            try:
                fake = BurstReplayHardeningFake({event_id: registry_rule.copy()}, event_id, relative)
                burst_replay.install(fake)

                def dispatch(
                    before_sha: str = predecessor,
                    after_sha: str = commit,
                    changed_paths: tuple[str, ...] = (git_relative,),
                    before_root: Path = before,
                    after_root: Path = after,
                ) -> dict:
                    result = burst_replay.validate_git_transition(
                        fake,
                        before_sha,
                        after_sha,
                        changed_paths,
                        before_root,
                        after_root,
                    )
                    if result is not None:
                        return result
                    return fake.transition_check(before_root, after_root)

                result = dispatch()
                self.assertEqual(result["status"], "PASS")
                self.assertEqual(
                    result["finiteHistoricalQuarantineOnlyIntroductionCompat"],
                    [relative.as_posix()],
                )
                self.assertEqual(result["quarantinedHistoricalEvents"], 1)
                self.assertEqual(
                    result["historicalGitTransition"],
                    {"predecessorSha": predecessor, "commitSha": commit},
                )

                fake.authoritative = True
                with self.assertRaises(core.ControlError):
                    dispatch()
                fake.authoritative = False

                with self.assertRaises(core.ControlError):
                    dispatch(before_sha="3" * 40)
                with self.assertRaises(core.ControlError):
                    dispatch(after_sha="4" * 40)
                with self.assertRaises(core.ControlError):
                    dispatch(changed_paths=(git_relative, ".swarm/workers/unrelated.json"))
                with self.assertRaises(core.ControlError):
                    dispatch(changed_paths=(".swarm/workers/unrelated.json",))

                malformed_before = root / "malformed-before"
                (malformed_before / relative.parent).mkdir(parents=True)
                (malformed_before / relative).write_bytes(raw)
                with self.assertRaises(core.ControlError):
                    dispatch(before_root=malformed_before)

                missing_after = root / "missing-after"
                missing_after.mkdir()
                with self.assertRaises(core.ControlError):
                    dispatch(after_root=missing_after)

                after_path.write_bytes(raw + b"x")
                with self.assertRaises(core.ControlError):
                    dispatch()
                after_path.write_bytes(raw)

                missing = BurstReplayHardeningFake({}, event_id, relative)
                with self.assertRaises(RuntimeError):
                    burst_replay.install(missing)
                mismatch = BurstReplayHardeningFake(
                    {
                        event_id: {
                            "date": date,
                            "filename": filename,
                            "quarantineOnlyGitBlobSha1": "f" * 40,
                        }
                    },
                    event_id,
                    relative,
                )
                with self.assertRaises(RuntimeError):
                    burst_replay.install(mismatch)

                burst_replay.QUARANTINE_ONLY_RULES = {}
                with self.assertRaises(core.ControlError):
                    dispatch()
            finally:
                burst_replay.QUARANTINE_ONLY_RULES = original_rules

    def test_workflow_replays_chain_and_uses_trusted_base_primitives(self):
        workflow = (Path(__file__).resolve().parents[2] / ".github" / "workflows" / "swarm-control.yml").read_text(encoding="utf-8")
        self.assertIn("test_trusted_history_chain.py", workflow); self.assertIn("trusted_history_chain.py", workflow)
        self.assertIn('--trusted-sha "$TRUSTED_CONTROL_SHA"', workflow); self.assertIn('--control-sha "$CONTROL_SHA"', workflow)
        self.assertIn("malformed_event_quarantine_rows", workflow); self.assertIn("FIRST_WRITE_FILENAME", workflow)
        pr_ownership = workflow.split("  pr-ownership:\n", 1)[1].split("  validate-control-branch:\n", 1)[0]
        self.assertIn("hard.state_digest", pr_ownership); self.assertNotIn("hard.verify_trusted_state", pr_ownership); self.assertIn("bootstrap/reset mode", pr_ownership)


if __name__ == "__main__": unittest.main()
