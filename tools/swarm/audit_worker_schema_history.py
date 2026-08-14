#!/usr/bin/env python3
"""Inventory every historically invalid worker blob as finite Git intervals.

This is a read-only maintenance tool. It validates each worker delta on a
control branch's first-parent chain with the current strict worker validator
and emits compact, reproducible commit/blob identities for reviewed replay
compatibility rules.
"""
from __future__ import annotations

import argparse
import json
import subprocess
import sys
import tempfile
from pathlib import Path

import swarmctl_hardening as hard


WORKER_REQUIRED = {"schemaVersion", "workerId", "model", "status", "startedAt", "lastSeenAt"}
WORKER_ALLOWED = WORKER_REQUIRED | {"laneId", "slotId", "branch", "notes"}


def git(*args: str, text: bool = True) -> str | bytes:
    result = subprocess.run(["git", *args], check=False, capture_output=True, text=text)
    if result.returncode != 0:
        stderr = result.stderr if text else result.stderr.decode("utf-8", errors="replace")
        raise RuntimeError(f"git {' '.join(args)} failed: {stderr.strip()}")
    return result.stdout


def object_at(commit: str, path: str) -> tuple[str, bytes] | None:
    entry = git("ls-tree", "-z", commit, "--", path, text=False)
    assert isinstance(entry, bytes)
    records = [record for record in entry.split(b"\0") if record]
    if not records:
        return None
    if len(records) != 1 or b"\t" not in records[0]:
        raise RuntimeError(f"{commit}: unexpected tree identity for {path}")
    metadata, returned = records[0].split(b"\t", 1)
    mode, kind, blob = metadata.decode("ascii").split(" ", 2)
    if returned.decode("utf-8") != path or mode != "100644" or kind != "blob":
        raise RuntimeError(f"{commit}: invalid worker tree entry for {path}")
    raw = git("cat-file", "blob", blob, text=False)
    assert isinstance(raw, bytes)
    return blob, raw


def changed_worker_paths(before: str, after: str) -> tuple[str, ...]:
    raw = git(
        "diff-tree", "--no-commit-id", "--name-only", "-z", "-r",
        before, after, "--", ".swarm/workers", text=False,
    )
    assert isinstance(raw, bytes)
    return tuple(path.decode("utf-8") for path in raw.split(b"\0") if path)


def describe(raw: bytes, path: str, blob: str) -> dict:
    try:
        obj = json.loads(raw)
    except json.JSONDecodeError as exc:
        return {"blob": blob, "error": f"invalid JSON: {exc.msg}", "status": None, "extraFields": {}}
    if not isinstance(obj, dict):
        return {"blob": blob, "error": "worker root must be object", "status": None, "extraFields": {}}

    relative = Path(path).relative_to(".swarm")
    with tempfile.TemporaryDirectory() as temp:
        destination = Path(temp) / relative
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes(raw)
        try:
            hard.core.validate_worker(destination)
            error = None
        except hard.core.ControlError as exc:
            error = str(exc).replace(str(destination), relative.as_posix())

    extra_keys = sorted(set(obj) - WORKER_ALLOWED)
    return {
        "blob": blob,
        "error": error,
        "status": obj.get("status"),
        "extraFields": {key: obj[key] for key in extra_keys},
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--control-ref", required=True)
    parser.add_argument("--trust-ref", required=True)
    args = parser.parse_args()

    trust_raw = git("show", f"{args.trust_ref}:.swarm/trust.json")
    assert isinstance(trust_raw, str)
    anchor = json.loads(trust_raw)["trustedControlSha"]
    tip_raw = git("rev-parse", args.control_ref)
    assert isinstance(tip_raw, str)
    tip = tip_raw.strip()
    commits_raw = git("rev-list", "--first-parent", "--reverse", f"{anchor}..{tip}")
    assert isinstance(commits_raw, str)
    commits = tuple(line for line in commits_raw.splitlines() if line)

    active: dict[str, dict] = {}
    intervals: list[dict] = []
    worker_deltas = 0
    before = anchor
    for index, after in enumerate(commits, start=1):
        for path in changed_worker_paths(before, after):
            worker_deltas += 1
            current = object_at(after, path)
            current_description = None if current is None else describe(current[1], path, current[0])
            previous = active.pop(path, None)
            if previous is not None:
                previous.update(
                    {
                        "repairCommitSha": after,
                        "repairGitBlobSha1": None if current_description is None else current_description["blob"],
                        "repairStatus": None if current_description is None else current_description["status"],
                        "repairExtraFields": None if current_description is None else current_description["extraFields"],
                    }
                )
                intervals.append(previous)
            if current_description is not None and current_description["error"] is not None:
                active[path] = {
                    "path": path.removeprefix(".swarm/"),
                    "introductionIndex": index,
                    "introductionPredecessorSha": before,
                    "introductionCommitSha": after,
                    "invalidGitBlobSha1": current_description["blob"],
                    "invalidStatus": current_description["status"],
                    "invalidExtraFields": current_description["extraFields"],
                    "error": current_description["error"],
                }
        before = after

    for path, unfinished in sorted(active.items()):
        unfinished["unrepairedAtTip"] = tip
        intervals.append(unfinished)

    payload = {
        "trustedControlSha": anchor,
        "controlSha": tip,
        "transitionCount": len(commits),
        "workerDeltaCount": worker_deltas,
        "invalidIntervalCount": len(intervals),
        "invalidIntervals": intervals,
    }
    print(json.dumps(payload, indent=2, sort_keys=True))
    return 1 if active else 0


if __name__ == "__main__":
    sys.exit(main())
