#!/usr/bin/env python3
"""Finite Git-bound normalization for one repaired lane priority defect.

Only disposable first-parent replay snapshots are changed. Live and future lane
validation keeps the strict priorityBoost range; exact commit, path, blob, slot,
invalid value, canonical value, and repair identities are required.
"""
from __future__ import annotations

import json
from pathlib import Path, PurePosixPath

import swarm_worker_status_replay as worker_replay


RULES = (
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
)


def _destination(root: Path, relative: str) -> Path:
    path = PurePosixPath(relative)
    if len(path.parts) != 2 or path.parts[0] != "lanes" or any(part in {"", ".", ".."} for part in path.parts):
        raise RuntimeError(f"unsafe finite lane path {relative!r}")
    return Path(root).joinpath(*path.parts)


def _slot(obj: dict, rule: dict) -> dict:
    matches = [slot for slot in obj.get("slots", []) if isinstance(slot, dict) and slot.get("slotId") == rule["slotId"]]
    if len(matches) != 1:
        raise RuntimeError(f"{rule['path']}: finite lane slot identity mismatch")
    return matches[0]


def _assert_repair(git_root: Path, commit_sha: str, rule: dict) -> None:
    blob_sha, raw = worker_replay.git_blob_identity(git_root, commit_sha, rule["path"])
    if blob_sha != rule["repairGitBlobSha1"]:
        raise RuntimeError(f"{rule['path']}: finite lane repair blob mismatch")
    obj = json.loads(raw)
    if _slot(obj, rule).get("priorityBoost") != rule["repairPriorityBoost"]:
        raise RuntimeError(f"{rule['path']}: finite lane repair value mismatch")


def normalize_active_snapshot(hardening_module, git_root: Path, commit_sha: str, root: Path, active: dict[str, dict]) -> list[str]:
    normalized: list[str] = []
    for relative, rule in sorted(active.items()):
        blob_sha, raw = worker_replay.git_blob_identity(git_root, commit_sha, relative)
        if blob_sha != rule["invalidGitBlobSha1"]:
            raise hardening_module.core.ControlError(
                f"{relative}: active finite lane blob changed before exact repair"
            )
        obj = json.loads(raw)
        slot = _slot(obj, rule)
        if slot.get("priorityBoost") != rule["invalidPriorityBoost"]:
            raise hardening_module.core.ControlError(
                f"{relative}: finite lane invalid value identity mismatch"
            )
        slot["priorityBoost"] = rule["canonicalPriorityBoost"]
        destination = _destination(root, relative)
        if not destination.is_file():
            raise hardening_module.core.ControlError(f"{relative}: finite lane snapshot path missing")
        destination.write_text(json.dumps(obj, indent=2) + "\n", encoding="utf-8")
        hardening_module.core.validate_lane(destination)
        normalized.append(relative)
    return normalized


def advance_transition(
    hardening_module,
    git_root: Path,
    before_sha: str,
    after_sha: str,
    changed_paths: tuple[str, ...],
    after_root: Path,
    active: dict[str, dict],
) -> dict:
    changed = set(changed_paths)
    repaired: list[str] = []
    activated: list[str] = []

    for rule in RULES:
        if after_sha != rule["repairCommitSha"]:
            continue
        relative = rule["path"]
        if active.get(relative) != rule:
            raise hardening_module.core.ControlError(f"{relative}: finite lane repair has no matching active defect")
        if f".swarm/{relative}" not in changed:
            raise hardening_module.core.ControlError(f"{relative}: finite lane repair path was not changed")
        try:
            _assert_repair(git_root, after_sha, rule)
        except (RuntimeError, json.JSONDecodeError) as exc:
            raise hardening_module.core.ControlError(str(exc)) from exc
        del active[relative]
        repaired.append(relative)

    for rule in RULES:
        if after_sha != rule["introductionCommitSha"]:
            continue
        relative = rule["path"]
        if before_sha != rule["introductionPredecessorSha"]:
            raise hardening_module.core.ControlError(f"{relative}: finite lane introduction predecessor mismatch")
        if relative in active:
            raise hardening_module.core.ControlError(f"{relative}: overlapping finite lane defect")
        if f".swarm/{relative}" not in changed:
            raise hardening_module.core.ControlError(f"{relative}: finite lane introduction path was not changed")
        active[relative] = rule
        activated.append(relative)

    introduction_paths = {rule["path"] for rule in RULES if after_sha == rule["introductionCommitSha"]}
    for relative in active:
        if f".swarm/{relative}" in changed and relative not in introduction_paths:
            raise hardening_module.core.ControlError(
                f"{relative}: finite lane blob changed before registered repair"
            )

    try:
        normalized = normalize_active_snapshot(hardening_module, git_root, after_sha, after_root, active)
    except (RuntimeError, json.JSONDecodeError) as exc:
        raise hardening_module.core.ControlError(str(exc)) from exc
    return {"activated": activated, "normalized": normalized, "repaired": repaired}


def is_boundary(commit_sha: str) -> bool:
    return any(
        commit_sha in {rule["introductionCommitSha"], rule["repairCommitSha"]}
        for rule in RULES
    )
