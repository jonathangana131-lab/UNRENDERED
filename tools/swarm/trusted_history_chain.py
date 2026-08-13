#!/usr/bin/env python3
"""Validate first-parent control history after a separately trusted anchor.

Normal history is strict. A finite post-bootstrap recovery row may bridge one exact
known-invalid commit only when its predecessor, immediate repair, and Git changed
paths all match reviewed immutable identities. The invalid snapshot is never passed
to transition_check and never becomes authority; strict transition validation runs
from the last valid predecessor directly to the exact repaired snapshot.
"""
from __future__ import annotations

import argparse
import json
import re
import subprocess
import tempfile
from pathlib import Path
from typing import Iterable

import swarm_failed_control_recovery as failed_recovery
import swarmctl_hardening as hard

_SHA_RE = re.compile(r"[a-f0-9]{40}")


def _git(git_root: Path, *args: str) -> str:
    result = subprocess.run(["git", "-C", str(git_root), *args], check=False, capture_output=True, text=True)
    if result.returncode != 0:
        raise hard.core.ControlError(f"git {' '.join(args)} failed ({result.returncode}): {result.stderr.strip()}")
    return result.stdout.strip()


def first_parent_commits(git_root: Path, trusted_sha: str, control_sha: str) -> list[str]:
    for name, value in (("trusted", trusted_sha), ("control", control_sha)):
        if not _SHA_RE.fullmatch(value):
            raise hard.core.ControlError(f"{name} control SHA must be an exact lowercase Git SHA")
        _git(git_root, "cat-file", "-e", f"{value}^{{commit}}")
    if trusted_sha == control_sha:
        return []
    ancestry = _git(git_root, "rev-list", "--first-parent", control_sha).splitlines()
    if trusted_sha not in ancestry:
        raise hard.core.ControlError("trusted control SHA is not on the candidate control tip's first-parent history")
    commits = _git(git_root, "rev-list", "--first-parent", "--reverse", f"{trusted_sha}..{control_sha}").splitlines()
    if not commits or commits[-1] != control_sha:
        raise hard.core.ControlError("first-parent replay did not terminate at the candidate control SHA")
    return commits


def validate_snapshot_chain(snapshot_roots: Iterable[Path]) -> list[dict]:
    """Pure snapshot replay remains exception-free for adversarial regression tests."""
    roots = [Path(root) for root in snapshot_roots]
    if not roots:
        raise hard.core.ControlError("trusted history chain requires at least one snapshot")
    return [hard.transition_check(before, after) for before, after in zip(roots, roots[1:])]


def _archive_swarm(git_root: Path, commit_sha: str, destination: Path) -> Path:
    destination.mkdir(parents=True, exist_ok=True)
    archive = subprocess.Popen(["git", "-C", str(git_root), "archive", commit_sha, ".swarm"], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    assert archive.stdout is not None
    extract = subprocess.run(["tar", "-x", "-C", str(destination)], stdin=archive.stdout, check=False, capture_output=True, text=False)
    archive.stdout.close()
    archive_stderr = archive.stderr.read().decode("utf-8", errors="replace") if archive.stderr else ""
    archive_returncode = archive.wait()
    if archive_returncode != 0:
        raise hard.core.ControlError(f"git archive {commit_sha} failed ({archive_returncode}): {archive_stderr.strip()}")
    if extract.returncode != 0:
        raise hard.core.ControlError(f"tar extraction for {commit_sha} failed ({extract.returncode}): {extract.stderr.decode('utf-8', errors='replace').strip()}")
    root = destination / ".swarm"
    if not root.is_dir():
        raise hard.core.ControlError(f"{commit_sha}: archived control snapshot is missing .swarm")
    return root


def _changed_paths(git_root: Path, before_sha: str, after_sha: str) -> tuple[str, ...]:
    output = _git(git_root, "diff", "--name-only", before_sha, after_sha)
    return tuple(sorted(line for line in output.splitlines() if line))


def _recovery_pair(predecessor_sha: str, invalid_sha: str, repair_sha: str) -> dict | None:
    matches = [row for row in failed_recovery.FAILED_CONTROL_RECOVERY_PAIRS if row["predecessorSha"] == predecessor_sha and row["invalidSha"] == invalid_sha and row["repairSha"] == repair_sha]
    if len(matches) > 1:
        raise hard.core.ControlError("duplicate failed-control recovery identity")
    return matches[0] if matches else None


def _validate_recovery_bridge(git_root: Path, row: dict, predecessor_root: Path, repair_root: Path) -> dict:
    invalid_paths = _changed_paths(git_root, row["predecessorSha"], row["invalidSha"])
    repair_paths = _changed_paths(git_root, row["invalidSha"], row["repairSha"])
    if invalid_paths != tuple(sorted(row["invalidChangedPaths"])):
        raise hard.core.ControlError("failed-control recovery invalid-commit path set mismatch")
    if repair_paths != tuple(sorted(row["repairChangedPaths"])):
        raise hard.core.ControlError("failed-control recovery repair path set mismatch")
    if any(path.startswith(".swarm/events/") for path in invalid_paths + repair_paths):
        raise hard.core.ControlError("failed-control recovery may not cross immutable event changes")
    # The repair must itself be a fully valid control snapshot, and the only
    # authoritative state transition is predecessor -> repair.
    hard.validate_all(repair_root, hard.core.now_utc())
    strict = hard.transition_check(predecessor_root, repair_root)
    return {
        "status": "PASS",
        "recovery": "FINITE_FAILED_CONTROL_BRIDGE",
        "predecessorSha": row["predecessorSha"],
        "quarantinedInvalidSha": row["invalidSha"],
        "repairSha": row["repairSha"],
        "strictTransition": strict,
    }


def validate_git_chain(git_root: Path, trusted_sha: str, control_sha: str) -> dict:
    git_root = git_root.resolve()
    commits = first_parent_commits(git_root, trusted_sha, control_sha)
    recovered: list[str] = []
    with tempfile.TemporaryDirectory(prefix="swarm-history-chain-") as temp:
        temp_root = Path(temp)
        roots: dict[str, Path] = {trusted_sha: _archive_swarm(git_root, trusted_sha, temp_root / "000000-trusted")}
        for index, commit_sha in enumerate(commits, start=1):
            roots[commit_sha] = _archive_swarm(git_root, commit_sha, temp_root / f"{index:06d}-{commit_sha[:12]}")

        results: list[dict] = []
        last_valid_sha = trusted_sha
        last_valid_root = roots[trusted_sha]
        index = 0
        while index < len(commits):
            current_sha = commits[index]
            next_sha = commits[index + 1] if index + 1 < len(commits) else ""
            row = _recovery_pair(last_valid_sha, current_sha, next_sha) if next_sha else None
            if row is not None:
                results.append(_validate_recovery_bridge(git_root, row, last_valid_root, roots[next_sha]))
                recovered.append(current_sha)
                last_valid_sha = next_sha
                last_valid_root = roots[next_sha]
                index += 2
                continue
            results.append(hard.transition_check(last_valid_root, roots[current_sha]))
            last_valid_sha = current_sha
            last_valid_root = roots[current_sha]
            index += 1

    return {
        "status": "PASS",
        "trustedControlSha": trusted_sha,
        "candidateControlSha": control_sha,
        "transitionCount": len(results),
        "validatedCommits": commits,
        "quarantinedFailedCommits": recovered,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--git-root", type=Path, default=Path("."))
    parser.add_argument("--trusted-sha", required=True)
    parser.add_argument("--control-sha", required=True)
    args = parser.parse_args()
    print(json.dumps(validate_git_chain(args.git_root, args.trusted_sha, args.control_sha), indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
