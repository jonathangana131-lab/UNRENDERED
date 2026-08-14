#!/usr/bin/env python3
"""Validate first-parent control history after a separately trusted anchor.

Normal history is strict. Finite recovery may cross only exact reviewed Git
transitions whose predecessor, commit, changed paths, and immutable byte identities
all match. Disposable compatibility snapshots never become authority.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import subprocess
import sys
import tempfile
from pathlib import Path, PurePosixPath
from typing import Callable, Iterable

import swarm_burst_event_replay as burst_event_replay
import swarm_burst_takeover_recovery as burst_takeover_recovery
import swarm_failed_control_recovery as failed_recovery
import swarm_lane_history_replay as lane_history_replay
import swarm_worker_status_replay as worker_status_replay
import swarmctl_hardening as hard

# Register only exact historical byte identities. New Git-bound takeover/event
# compatibility is invoked explicitly below with exact first-parent identities;
# install() does not make those new transitions snapshot-global.
burst_takeover_recovery.install(hard)

_SHA_RE = re.compile(r"[a-f0-9]{40}")


def _git(git_root: Path, *args: str) -> str:
    result = subprocess.run(["git", "-C", str(git_root), *args], check=False, capture_output=True, text=True)
    if result.returncode != 0:
        raise hard.core.ControlError(f"git {' '.join(args)} failed ({result.returncode}): {result.stderr.strip()}")
    return result.stdout.strip()


def _git_bytes(git_root: Path, *args: str) -> bytes:
    result = subprocess.run(["git", "-C", str(git_root), *args], check=False, capture_output=True)
    if result.returncode != 0:
        error = result.stderr.decode("utf-8", errors="replace").strip()
        raise hard.core.ControlError(f"git {' '.join(args)} failed ({result.returncode}): {error}")
    return result.stdout


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
    """Pure snapshot replay is deliberately exception-free."""
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
    if archive.stderr:
        archive.stderr.close()
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


def _changed_entries(git_root: Path, before_sha: str, after_sha: str) -> tuple[tuple[str, str], ...]:
    raw = _git_bytes(
        git_root,
        "diff",
        "--name-status",
        "-z",
        "--no-renames",
        before_sha,
        after_sha,
        "--",
        ".swarm",
    )
    fields = raw.split(b"\0")
    if fields and fields[-1] == b"":
        fields.pop()
    if len(fields) % 2:
        raise hard.core.ControlError("malformed NUL-delimited Git path delta")
    entries: list[tuple[str, str]] = []
    for offset in range(0, len(fields), 2):
        try:
            status = fields[offset].decode("ascii")
            path = fields[offset + 1].decode("utf-8")
        except UnicodeDecodeError as exc:
            raise hard.core.ControlError("control history contains a non-UTF-8 path delta") from exc
        if status not in {"A", "D", "M", "T"}:
            raise hard.core.ControlError(f"unsupported control history path status {status!r}")
        relative = PurePosixPath(path)
        if (
            len(relative.parts) < 2
            or relative.parts[0] != ".swarm"
            or any(part in {"", ".", ".."} for part in relative.parts)
        ):
            raise hard.core.ControlError(f"unsafe control history path {path!r}")
        entries.append((status, path))
    return tuple(entries)


def _tree_entry(git_root: Path, commit_sha: str, path: str) -> tuple[str, str, str]:
    raw = _git_bytes(git_root, "ls-tree", "-z", commit_sha, "--", path)
    records = [record for record in raw.split(b"\0") if record]
    if len(records) != 1 or b"\t" not in records[0]:
        raise hard.core.ControlError(f"{commit_sha}: expected one Git tree entry for {path}")
    metadata, returned_path = records[0].split(b"\t", 1)
    try:
        mode, object_type, object_sha = metadata.decode("ascii").split(" ", 2)
        decoded_path = returned_path.decode("utf-8")
    except (UnicodeDecodeError, ValueError) as exc:
        raise hard.core.ControlError(f"{commit_sha}: malformed Git tree entry for {path}") from exc
    if decoded_path != path or not _SHA_RE.fullmatch(object_sha):
        raise hard.core.ControlError(f"{commit_sha}: Git tree identity mismatch for {path}")
    return mode, object_type, object_sha


def _blob(git_root: Path, object_sha: str) -> bytes:
    return _git_bytes(git_root, "cat-file", "blob", object_sha)


def _git_blob_sha1(raw: bytes) -> str:
    return hashlib.sha1(f"blob {len(raw)}\0".encode("ascii") + raw).hexdigest()


def _destination(snapshot_root: Path, path: str) -> Path:
    relative = PurePosixPath(path)
    return snapshot_root.joinpath(*relative.parts[1:])


def _remove_path(snapshot_root: Path, destination: Path, path: str) -> None:
    if destination.is_dir() and not destination.is_symlink():
        raise hard.core.ControlError(f"refusing directory deletion for control file delta {path}")
    if not destination.exists() and not destination.is_symlink():
        raise hard.core.ControlError(f"control file delta deletes missing path {path}")
    destination.unlink()
    parent = destination.parent
    while parent != snapshot_root:
        try:
            parent.rmdir()
        except OSError:
            break
        parent = parent.parent


def _replace_path(snapshot_root: Path, destination: Path, path: str, mode: str, object_type: str, raw: bytes) -> None:
    if object_type != "blob" or mode not in {"100644", "100755", "120000"}:
        raise hard.core.ControlError(f"unsupported Git object {mode} {object_type} for {path}")
    destination.parent.mkdir(parents=True, exist_ok=True)
    if destination.is_dir() and not destination.is_symlink():
        raise hard.core.ControlError(f"refusing file replacement over directory for {path}")
    descriptor, temporary_name = tempfile.mkstemp(prefix=".history-sync-", dir=destination.parent)
    temporary = Path(temporary_name)
    try:
        if mode == "120000":
            os.close(descriptor)
            temporary.unlink()
            try:
                target = raw.decode("utf-8")
            except UnicodeDecodeError as exc:
                raise hard.core.ControlError(f"non-UTF-8 symlink target for {path}") from exc
            temporary.symlink_to(target)
        else:
            with os.fdopen(descriptor, "wb") as handle:
                handle.write(raw)
                handle.flush()
            temporary.chmod(0o755 if mode == "100755" else 0o644)
        os.replace(temporary, destination)
    finally:
        if temporary.exists() or temporary.is_symlink():
            temporary.unlink()
    materialized = os.readlink(destination).encode("utf-8") if destination.is_symlink() else destination.read_bytes()
    if _git_blob_sha1(materialized) != _git_blob_sha1(raw):
        raise hard.core.ControlError(f"materialized Git blob mismatch for {path}")


def _sync_swarm_snapshot(git_root: Path, snapshot_root: Path, before_sha: str, after_sha: str) -> tuple[str, ...]:
    """Move one disposable snapshot to an exact commit using byte-checked Git deltas."""

    changed: list[str] = []
    for status, path in _changed_entries(git_root, before_sha, after_sha):
        destination = _destination(snapshot_root, path)
        if status == "D":
            _remove_path(snapshot_root, destination, path)
        else:
            mode, object_type, object_sha = _tree_entry(git_root, after_sha, path)
            raw = _blob(git_root, object_sha)
            if _git_blob_sha1(raw) != object_sha:
                raise hard.core.ControlError(f"Git blob digest mismatch for {path}")
            _replace_path(snapshot_root, destination, path, mode, object_type, raw)
        changed.append(path)
    return tuple(sorted(changed))


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


def validate_git_chain(
    git_root: Path,
    trusted_sha: str,
    control_sha: str,
    progress: Callable[[int, int, str], None] | None = None,
) -> dict:
    git_root = git_root.resolve()
    commits = first_parent_commits(git_root, trusted_sha, control_sha)
    recovered: list[str] = []
    with tempfile.TemporaryDirectory(prefix="swarm-history-chain-") as temp:
        temp_root = Path(temp)
        root_a = _archive_swarm(git_root, trusted_sha, temp_root / "snapshot-a")
        root_b = _archive_swarm(git_root, trusted_sha, temp_root / "snapshot-b")
        snapshot_sha = {root_a: trusted_sha, root_b: trusted_sha}

        results: list[dict] = []
        active_lane_compat: dict[str, dict] = {}
        active_worker_compat: dict[str, dict] = {}
        last_valid_sha = trusted_sha
        last_valid_root = root_a
        standby_root = root_b
        index = 0
        while index < len(commits):
            current_sha = commits[index]
            next_sha = commits[index + 1] if index + 1 < len(commits) else ""
            row = _recovery_pair(last_valid_sha, current_sha, next_sha) if next_sha else None
            if row is not None:
                if any(
                    replay.is_boundary(commit_sha)
                    for replay in (lane_history_replay, worker_status_replay)
                    for commit_sha in (current_sha, next_sha)
                ):
                    raise hard.core.ControlError("finite failed-control bridge overlaps snapshot compatibility boundary")
                _sync_swarm_snapshot(git_root, standby_root, snapshot_sha[standby_root], next_sha)
                snapshot_sha[standby_root] = next_sha
                lane_history_replay.normalize_active_snapshot(
                    hard,
                    git_root,
                    next_sha,
                    standby_root,
                    active_lane_compat,
                )
                worker_status_replay.normalize_active_snapshot(
                    hard,
                    git_root,
                    next_sha,
                    standby_root,
                    active_worker_compat,
                )
                results.append(_validate_recovery_bridge(git_root, row, last_valid_root, standby_root))
                recovered.append(current_sha)
                last_valid_sha = next_sha
                last_valid_root, standby_root = standby_root, last_valid_root
                index += 2
                if progress:
                    progress(index, len(commits), next_sha)
                continue

            _sync_swarm_snapshot(
                git_root,
                standby_root,
                snapshot_sha[standby_root],
                current_sha,
            )
            snapshot_sha[standby_root] = current_sha
            changed_paths = _changed_paths(git_root, last_valid_sha, current_sha)
            lane_compat = lane_history_replay.advance_transition(
                hard,
                git_root,
                last_valid_sha,
                current_sha,
                changed_paths,
                standby_root,
                active_lane_compat,
            )
            worker_compat = worker_status_replay.advance_transition(
                hard,
                git_root,
                last_valid_sha,
                current_sha,
                changed_paths,
                standby_root,
                active_worker_compat,
            )
            finite_takeover = burst_takeover_recovery.validate_git_transition(
                hard,
                last_valid_sha,
                current_sha,
                changed_paths,
                last_valid_root,
                standby_root,
            )
            if finite_takeover is not None:
                result = finite_takeover
            else:
                finite_event = burst_event_replay.validate_git_transition(
                    hard,
                    last_valid_sha,
                    current_sha,
                    changed_paths,
                    last_valid_root,
                    standby_root,
                )
                if finite_event is not None:
                    result = finite_event
                else:
                    result = hard.transition_check(last_valid_root, standby_root)
            if worker_compat["activated"] or worker_compat["normalized"] or worker_compat["repaired"]:
                result["finiteHistoricalWorkerStatusCompat"] = worker_compat
            if lane_compat["activated"] or lane_compat["normalized"] or lane_compat["repaired"]:
                result["finiteHistoricalLaneCompat"] = lane_compat
            results.append(result)
            last_valid_sha = current_sha
            last_valid_root, standby_root = standby_root, last_valid_root
            index += 1
            if progress and (index == len(commits) or index % 25 == 0):
                progress(index, len(commits), current_sha)

        if active_lane_compat or active_worker_compat:
            raise hard.core.ControlError(
                "candidate control tip still contains active finite snapshot compatibility"
            )

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
    def report(completed: int, total: int, commit_sha: str) -> None:
        print(
            f"trusted-history progress {completed}/{total} at {commit_sha}",
            file=sys.stderr,
            flush=True,
        )

    print(
        json.dumps(
            validate_git_chain(args.git_root, args.trusted_sha, args.control_sha, progress=report),
            indent=2,
            sort_keys=True,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
