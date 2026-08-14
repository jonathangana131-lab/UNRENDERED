#!/usr/bin/env python3
"""Finite Git-bound normalization for malformed post-anchor worker statuses.

The live schema remains strict. During first-parent history replay only, exact
reviewed worker blobs are copied into disposable snapshots and their unsupported
status token is replaced with one canonical status. Commit, path, blob, repair,
and prior-parent identities are all pinned; an unlisted byte or reintroduction
fails closed.
"""
from __future__ import annotations

import hashlib
import json
import re
import subprocess
from pathlib import Path, PurePosixPath


RULES = (
    {
        "path": "workers/sol-20260814-k8m4v2q7.json",
        "introductionPredecessorSha": "7f6387b976c83df6989662c08df90d08ff1e2e80",
        "introductionCommitSha": "5941096926b0605512989650e6d57edf6ff619cd",
        "invalidGitBlobSha1": "f1c95e6ff5e5b135146bc89d14cf1b14575cff3e",
        "invalidStatus": "READY",
        "canonicalStatus": "IDLE",
        "repairCommitSha": "4d6c171cbfc31aa74858cc5011f0852033bdce21",
        "repairGitBlobSha1": "9ff71762597c26d5e67016a221fdbf862fc91bed",
        "repairStatus": "IDLE",
    },
    {
        "path": "workers/sol-20260814-z4p7m3n8.json",
        "introductionPredecessorSha": "bf2e5fa390ace674f732e56e2b8624c5652804db",
        "introductionCommitSha": "9dd355bab6f0d23f966e4979f7ca038f3364828b",
        "invalidGitBlobSha1": "7da1a1497d231489069367d3b16a1a5ba6cfb875",
        "invalidStatus": "READY",
        "canonicalStatus": "IDLE",
        "repairCommitSha": "0420df02434232095ccd3ff6d357654e9418056e",
        "repairGitBlobSha1": "5e0e533f5709ce1ff325969f302d0265866546e7",
        "repairStatus": "IDLE",
    },
    {
        "path": "workers/sol-20260814-z7c2m8q4.json",
        "introductionPredecessorSha": "fd0aa2cecf70882450e4d398a027b79e3154c0fb",
        "introductionCommitSha": "543d5bd4589d602f21d397f3607125c0c5488f58",
        "invalidGitBlobSha1": "7a02398b3166fdda4de9b042b18f3dd79c4eeef9",
        "invalidStatus": "READY",
        "canonicalStatus": "IDLE",
        "repairCommitSha": "08719b81aae1a2a19bcdf8eaaebf1a7ae50ea4bb",
        "repairGitBlobSha1": "25c7e5df39b59f66f787108ca2b49df16e5ae391",
        "repairStatus": "IDLE",
    },
    {
        "path": "workers/sol-20260814-j9v4q6m2.json",
        "introductionPredecessorSha": "4288140476f2cc25e0062f26c19c86e8074f68b4",
        "introductionCommitSha": "aeeb92d5eecd4f82d672851c84980bc1c6624e09",
        "invalidGitBlobSha1": "3b206ef1b1c772b1fceae34a9d4a389a94f75363",
        "invalidStatus": "READY",
        "canonicalStatus": "WORKING",
        "repairCommitSha": "cd2f145fd1f62a684022ae3b21de8918bbe9f51d",
        "repairGitBlobSha1": "22f862cede6672eac54c9fd476543951474a2b86",
        "repairStatus": "WORKING",
    },
    {
        "path": "workers/sol-20260814-z7p3k9m4c2.json",
        "introductionPredecessorSha": "458cc8b35492848a9309d069768b1eada8f73032",
        "introductionCommitSha": "8d45d67916d4af5ed3d5d8176e5987e4f86a5a26",
        "invalidGitBlobSha1": "46ebbeb8e12d5c5726d1d24563c390d3f6800fd8",
        "invalidStatus": "READY",
        "canonicalStatus": "WORKING",
        "repairCommitSha": "d63b9ac41fc5f0d32373dbf3d2158f567becd4ab",
        "repairGitBlobSha1": "e11a7c2234ae5128ea3617cba9f8abfa69428fc8",
        "repairStatus": "WORKING",
    },
    {
        "path": "workers/sol-20260814-z7m2q9c4.json",
        "introductionPredecessorSha": "8d45d67916d4af5ed3d5d8176e5987e4f86a5a26",
        "introductionCommitSha": "68858e24812c2155531e8b3e7cf6623d822d5868",
        "invalidGitBlobSha1": "4e3f2b260f85bf83c178fe385260881146d25543",
        "invalidStatus": "READY",
        "canonicalStatus": "WORKING",
        "repairCommitSha": "0c2953284b834625b62d94738e05cc7a49e69bbc",
        "repairGitBlobSha1": "f7fce509703b681950887570ffae5805f2a0730c",
        "repairStatus": "WORKING",
    },
    {
        "path": "workers/sol-20260814-z7m2q9c4.json",
        "introductionPredecessorSha": "cdffde6049c5ff371ee0dec5965b5e11027a2f3a",
        "introductionCommitSha": "ff67a70c5ded61ae285d921a2e4953e992142eeb",
        "invalidGitBlobSha1": "897db900be7ecac731bdd3b84542499685f0fffc",
        "invalidStatus": "READY",
        "canonicalStatus": "REVIEWING",
        "repairCommitSha": "855110695fac63343f787cd26fd127049b1da577",
        "repairGitBlobSha1": "230fcf8bb7c3461540c6d3566874ebcfe0eeacc6",
        "repairStatus": "REVIEWING",
    },
    {
        "path": "workers/sol-20260814-a6r2m8q5.json",
        "introductionPredecessorSha": "503b4e804791eca56b47a45077be8d0633a1d82e",
        "introductionCommitSha": "f8f5bd61f87cee6f0ec46a9bd44a1e17c07f1e1e",
        "invalidGitBlobSha1": "928c9ebcb063412cb75a3f7cf74c503d01cc4697",
        "invalidStatus": "MINING",
        "canonicalStatus": "WORKING",
        "repairCommitSha": "f08f5d42078623f893dcb3ee11514e79a9559fbc",
        "repairGitBlobSha1": "273db6d6238f1d1a1a98105a860f78c2028b9c48",
        "repairStatus": "WORKING",
    },
)

_SHA_RE = re.compile(r"^[a-f0-9]{40}$")


def _git_bytes(git_root: Path, *args: str) -> bytes:
    result = subprocess.run(
        ["git", "-C", str(git_root), *args],
        check=False,
        capture_output=True,
    )
    if result.returncode != 0:
        raise RuntimeError(
            f"git {' '.join(args)} failed ({result.returncode}): "
            f"{result.stderr.decode('utf-8', errors='replace').strip()}"
        )
    return result.stdout


def git_blob_identity(git_root: Path, commit_sha: str, relative: str) -> tuple[str, bytes]:
    git_path = f".swarm/{relative}"
    raw_entry = _git_bytes(git_root, "ls-tree", "-z", commit_sha, "--", git_path)
    records = [record for record in raw_entry.split(b"\0") if record]
    if len(records) != 1 or b"\t" not in records[0]:
        raise RuntimeError(f"{commit_sha}: expected one worker tree entry for {git_path}")
    metadata, returned = records[0].split(b"\t", 1)
    mode, object_type, blob_sha = metadata.decode("ascii").split(" ", 2)
    if returned.decode("utf-8") != git_path or mode != "100644" or object_type != "blob" or not _SHA_RE.fullmatch(blob_sha):
        raise RuntimeError(f"{commit_sha}: invalid worker tree identity for {git_path}")
    raw = _git_bytes(git_root, "cat-file", "blob", blob_sha)
    actual = hashlib.sha1(f"blob {len(raw)}\0".encode("ascii") + raw).hexdigest()
    if actual != blob_sha:
        raise RuntimeError(f"{commit_sha}: worker blob digest mismatch for {git_path}")
    return blob_sha, raw


def _destination(root: Path, relative: str) -> Path:
    path = PurePosixPath(relative)
    if len(path.parts) != 2 or path.parts[0] != "workers" or any(part in {"", ".", ".."} for part in path.parts):
        raise RuntimeError(f"unsafe finite worker path {relative!r}")
    return Path(root).joinpath(*path.parts)


def _assert_repair(git_root: Path, commit_sha: str, rule: dict) -> None:
    blob_sha, raw = git_blob_identity(git_root, commit_sha, rule["path"])
    if blob_sha != rule["repairGitBlobSha1"]:
        raise RuntimeError(f"{rule['path']}: finite worker repair blob mismatch")
    obj = json.loads(raw)
    if obj.get("status") != rule["repairStatus"]:
        raise RuntimeError(f"{rule['path']}: finite worker repair status mismatch")


def normalize_active_snapshot(hardening_module, git_root: Path, commit_sha: str, root: Path, active: dict[str, dict]) -> list[str]:
    normalized: list[str] = []
    for relative, rule in sorted(active.items()):
        blob_sha, raw = git_blob_identity(git_root, commit_sha, relative)
        if blob_sha != rule["invalidGitBlobSha1"]:
            raise hardening_module.core.ControlError(
                f"{relative}: active finite worker blob changed before exact repair"
            )
        obj = json.loads(raw)
        if obj.get("status") != rule["invalidStatus"]:
            raise hardening_module.core.ControlError(
                f"{relative}: finite worker invalid status identity mismatch"
            )
        obj["status"] = rule["canonicalStatus"]
        destination = _destination(root, relative)
        if not destination.is_file():
            raise hardening_module.core.ControlError(f"{relative}: finite worker snapshot path missing")
        destination.write_text(json.dumps(obj, indent=2) + "\n", encoding="utf-8")
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
            raise hardening_module.core.ControlError(f"{relative}: finite worker repair has no matching active defect")
        if f".swarm/{relative}" not in changed:
            raise hardening_module.core.ControlError(f"{relative}: finite worker repair path was not changed")
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
            raise hardening_module.core.ControlError(f"{relative}: finite worker introduction predecessor mismatch")
        if relative in active:
            raise hardening_module.core.ControlError(f"{relative}: overlapping finite worker defect")
        if f".swarm/{relative}" not in changed:
            raise hardening_module.core.ControlError(f"{relative}: finite worker introduction path was not changed")
        active[relative] = rule
        activated.append(relative)

    introduction_paths = {
        rule["path"] for rule in RULES if after_sha == rule["introductionCommitSha"]
    }
    for relative in active:
        if f".swarm/{relative}" in changed and relative not in introduction_paths:
            raise hardening_module.core.ControlError(
                f"{relative}: finite worker blob changed before registered repair"
            )

    try:
        normalized = normalize_active_snapshot(hardening_module, git_root, after_sha, after_root, active)
    except (RuntimeError, json.JSONDecodeError) as exc:
        raise hardening_module.core.ControlError(str(exc)) from exc
    return {
        "activated": activated,
        "normalized": normalized,
        "repaired": repaired,
    }


def is_boundary(commit_sha: str) -> bool:
    return any(
        commit_sha in {rule["introductionCommitSha"], rule["repairCommitSha"]}
        for rule in RULES
    )
