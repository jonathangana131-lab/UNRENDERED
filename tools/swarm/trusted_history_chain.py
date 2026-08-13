#!/usr/bin/env python3
"""Validate every first-parent control transition after a separately trusted anchor.

This is intentionally strict and contains no recovery exceptions of its own. Snapshot
validation delegates to swarmctl_hardening.transition_check(), so the one-time finite
history reset remains confined to the reviewed hardening/manifest contract.
"""
from __future__ import annotations

import argparse
import json
import re
import subprocess
import tempfile
from pathlib import Path
from typing import Iterable

import swarmctl_hardening as hard

_SHA_RE = re.compile(r"[a-f0-9]{40}")


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


def first_parent_commits(git_root: Path, trusted_sha: str, control_sha: str) -> list[str]:
    """Return candidate commits in deterministic first-parent order after the anchor."""
    for name, value in (("trusted", trusted_sha), ("control", control_sha)):
        if not _SHA_RE.fullmatch(value):
            raise hard.core.ControlError(f"{name} control SHA must be an exact lowercase Git SHA")
        _git(git_root, "cat-file", "-e", f"{value}^{{commit}}")

    if trusted_sha == control_sha:
        return []

    first_parent_ancestry = _git(git_root, "rev-list", "--first-parent", control_sha).splitlines()
    if trusted_sha not in first_parent_ancestry:
        raise hard.core.ControlError(
            "trusted control SHA is not on the candidate control tip's first-parent history"
        )

    commits = _git(
        git_root,
        "rev-list",
        "--first-parent",
        "--reverse",
        f"{trusted_sha}..{control_sha}",
    ).splitlines()
    if not commits or commits[-1] != control_sha:
        raise hard.core.ControlError("first-parent replay did not terminate at the candidate control SHA")
    return commits


def validate_snapshot_chain(snapshot_roots: Iterable[Path]) -> list[dict]:
    """Reject if any consecutive authoritative snapshot transition is invalid."""
    roots = [Path(root) for root in snapshot_roots]
    if not roots:
        raise hard.core.ControlError("trusted history chain requires at least one snapshot")
    results: list[dict] = []
    for before, after in zip(roots, roots[1:]):
        results.append(hard.transition_check(before, after))
    return results


def _archive_swarm(git_root: Path, commit_sha: str, destination: Path) -> Path:
    destination.mkdir(parents=True, exist_ok=True)
    archive = subprocess.Popen(
        ["git", "-C", str(git_root), "archive", commit_sha, ".swarm"],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    assert archive.stdout is not None
    extract = subprocess.run(
        ["tar", "-x", "-C", str(destination)],
        stdin=archive.stdout,
        check=False,
        capture_output=True,
        text=False,
    )
    archive.stdout.close()
    archive_stderr = archive.stderr.read().decode("utf-8", errors="replace") if archive.stderr else ""
    archive_returncode = archive.wait()
    if archive_returncode != 0:
        raise hard.core.ControlError(
            f"git archive {commit_sha} failed ({archive_returncode}): {archive_stderr.strip()}"
        )
    if extract.returncode != 0:
        raise hard.core.ControlError(
            f"tar extraction for {commit_sha} failed ({extract.returncode}): "
            f"{extract.stderr.decode('utf-8', errors='replace').strip()}"
        )
    root = destination / ".swarm"
    if not root.is_dir():
        raise hard.core.ControlError(f"{commit_sha}: archived control snapshot is missing .swarm")
    return root


def validate_git_chain(git_root: Path, trusted_sha: str, control_sha: str) -> dict:
    """Archive and validate every first-parent transition from trusted SHA to control SHA."""
    git_root = git_root.resolve()
    commits = first_parent_commits(git_root, trusted_sha, control_sha)
    with tempfile.TemporaryDirectory(prefix="swarm-history-chain-") as temp:
        temp_root = Path(temp)
        roots = [_archive_swarm(git_root, trusted_sha, temp_root / "000000-trusted")]
        for index, commit_sha in enumerate(commits, start=1):
            roots.append(_archive_swarm(git_root, commit_sha, temp_root / f"{index:06d}-{commit_sha[:12]}"))
        results = validate_snapshot_chain(roots)
    return {
        "status": "PASS",
        "trustedControlSha": trusted_sha,
        "candidateControlSha": control_sha,
        "transitionCount": len(results),
        "validatedCommits": commits,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--git-root", type=Path, default=Path("."))
    parser.add_argument("--trusted-sha", required=True)
    parser.add_argument("--control-sha", required=True)
    args = parser.parse_args()
    result = validate_git_chain(args.git_root, args.trusted_sha, args.control_sha)
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
