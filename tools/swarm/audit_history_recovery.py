#!/usr/bin/env python3
"""Read-only provenance inventory for finite Swarm trusted-history recovery.

This tool never edits control state and never expands compatibility. It identifies
currently invalid immutable event files under an archived `.swarm` snapshot and
binds each validation defect to Git first-write/current blob evidence so a reviewer
can decide whether an exact quarantine entry is justified.
"""
from __future__ import annotations

import argparse
import json
import re
import subprocess
from pathlib import Path

import swarmctl_hardening as hard


def _git(git_root: Path, *args: str) -> str:
    result = subprocess.run(
        ["git", "-C", str(git_root), *args],
        check=False,
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        raise hard.core.ControlError(
            f"git {' '.join(args)} failed ({result.returncode}): {result.stderr.strip()}"
        )
    return result.stdout.strip()


def _path_from_error(root: Path, error: str) -> Path:
    raw = error.split(":", 1)[0]
    path = Path(raw)
    if not path.is_absolute():
        path = (root / path).resolve()
    else:
        path = path.resolve()
    root_resolved = root.resolve()
    try:
        path.relative_to(root_resolved)
    except ValueError as exc:
        raise hard.core.ControlError(f"validation error escaped recovery root: {error}") from exc
    return path


def _event_provenance(root: Path, git_root: Path, control_sha: str, error: str) -> dict:
    path = _path_from_error(root, error)
    rel = path.relative_to(root.resolve()).as_posix()
    repo_path = f".swarm/{rel}"
    additions = _git(
        git_root,
        "log",
        "--format=%H",
        "--reverse",
        "--diff-filter=A",
        control_sha,
        "--",
        repo_path,
    ).splitlines()
    if len(additions) != 1:
        raise hard.core.ControlError(
            f"{repo_path}: expected exactly one first-add commit, got {len(additions)}"
        )
    first_commit = additions[0]
    first_blob = _git(git_root, "rev-parse", f"{first_commit}:{repo_path}")
    current_blob = hard._git_blob_sha1(path)
    revisions = _git(
        git_root,
        "log",
        "--format=%H",
        control_sha,
        "--",
        repo_path,
    ).splitlines()
    return {
        "path": repo_path,
        "error": error.split(":", 1)[1].strip() if ":" in error else error,
        "firstWriteCommit": first_commit,
        "firstWriteGitBlobSha1": first_blob,
        "currentGitBlobSha1": current_blob,
        "rewritten": first_blob != current_blob,
        "revisionCount": len(revisions),
        "revisionCommitsNewestFirst": revisions,
    }


def build_inventory(root: Path, git_root: Path, control_sha: str) -> dict:
    root = root.resolve()
    git_root = git_root.resolve()
    invalid_events = hard._invalid_event_errors(root)
    invalid_workers = hard._invalid_worker_statuses(root)
    events = [_event_provenance(root, git_root, control_sha, error) for error in invalid_events]
    return {
        "schemaVersion": 1,
        "controlSha": control_sha,
        "invalidEventCount": len(events),
        "invalidWorkerCount": len(invalid_workers),
        "invalidEvents": events,
        "invalidWorkers": invalid_workers,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, required=True, help="Archived authoritative .swarm root")
    parser.add_argument("--git-root", type=Path, required=True, help="Repository checkout containing Git history")
    parser.add_argument("--control-sha", required=True, help="Exact control snapshot commit SHA")
    args = parser.parse_args()
    if not re.fullmatch(r"[a-f0-9]{40}", args.control_sha):
        raise hard.core.ControlError("--control-sha must be an exact 40-character lowercase Git SHA")
    inventory = build_inventory(args.root, args.git_root, args.control_sha)
    print(json.dumps(inventory, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
