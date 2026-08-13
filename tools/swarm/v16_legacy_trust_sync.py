#!/usr/bin/env python3
"""Synchronize V16 Mission Graph writes with the legacy V2.1 trust ledger.

V16 persists inside ``.swarm`` and therefore participates in the legacy authoritative
state digest. Every successful V16 write must keep the older PR-ownership fence
usable without weakening it. This helper:

1. pins current main/control/trust refs;
2. verifies the existing non-bootstrap trust anchor against its exact snapshot;
3. validates the live control snapshot with trusted V2.1 code;
4. replays every first-parent transition from the trusted anchor;
5. rebuilds only disposable generated projections and publishes them with an
   exact-parent fast-forward;
6. replays through that generated-only commit; and
7. CAS-advances ``swarm-trust`` to the exact final control SHA/digest.

A concurrent valid control/trust writer is treated as a CAS miss: the whole proof is
restarted from fresh refs. Invalid history, digest mismatch, malformed trust state,
bootstrap trust, or a moving default branch still fails closed. No immutable event
or product/runtime state is modified here.
"""
from __future__ import annotations

import argparse
import base64
import json
import os
import re
import subprocess
import sys
import tempfile
import time
import urllib.parse
from pathlib import Path
from typing import Any

sys.path.insert(0, str(Path(__file__).resolve().parent))

import swarmctl_hardening as hard
from v16cp.core import ValidationError, fmt, now_utc
from v16cp.store import GitHubContentsStore

SHA40 = re.compile(r"^[0-9a-f]{40}$")
TRUST_PATH = ".swarm/trust.json"


class RefRace(ValidationError):
    """A validated CAS target moved; restart from fresh authoritative refs."""


def _git(*args: str, capture: bool = False) -> str:
    if capture:
        return subprocess.check_output(["git", *args], text=True).strip()
    subprocess.run(["git", *args], check=True)
    return ""


def _api_ref_sha(api: GitHubContentsStore, branch: str) -> str:
    encoded = urllib.parse.quote(branch, safe="")
    payload = api._request("GET", f"/repos/{api.owner}/{api.repo}/git/ref/heads/{encoded}")
    sha = ((payload or {}).get("object") or {}).get("sha") if isinstance(payload, dict) else None
    if not isinstance(sha, str) or not SHA40.fullmatch(sha):
        raise ValidationError(f"invalid GitHub ref for {branch}")
    return sha


def _fetch(branch: str) -> None:
    _git("fetch", "origin", f"{branch}:refs/remotes/origin/{branch}")


def _archive_swarm(sha: str, destination: Path) -> Path:
    if not SHA40.fullmatch(sha):
        raise ValidationError("archive SHA must be exact lowercase 40-hex")
    destination.mkdir(parents=True, exist_ok=True)
    producer = subprocess.Popen(["git", "archive", sha, ".swarm"], stdout=subprocess.PIPE)
    assert producer.stdout is not None
    try:
        subprocess.run(["tar", "-x", "-C", str(destination)], stdin=producer.stdout, check=True)
    finally:
        producer.stdout.close()
    if producer.wait() != 0:
        raise subprocess.CalledProcessError(producer.returncode, ["git", "archive", sha, ".swarm"])
    root = destination / ".swarm"
    if not root.is_dir():
        raise ValidationError("control archive omitted .swarm")
    return root


def _write_trust_file(value: dict[str, Any], directory: Path) -> Path:
    path = directory / "trust.json"
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return path


def _load_exact_trust(api: GitHubContentsStore, trust_branch: str, trust_head: str) -> tuple[dict[str, Any], str]:
    exact = GitHubContentsStore(api.repository, api.token, trust_head, max_retries=api.max_retries)
    stored = exact.get(TRUST_PATH)
    with tempfile.TemporaryDirectory() as temp:
        path = _write_trust_file(stored.value, Path(temp))
        trust = hard.validate_trust_record(path)
    if trust.get("bootstrap", False):
        raise ValidationError("legacy trust ledger is still bootstrap/reset mode")
    if trust.get("controlBranch") != "swarm-control":
        raise ValidationError("legacy trust record targets unexpected control branch")
    return trust, stored.version


def _validate_and_replay(control_root: Path, trusted_root: Path, trust_path: Path, trusted_sha: str, control_sha: str) -> str:
    hard.verify_trusted_snapshot(trusted_root, trust_path, allow_bootstrap=False)
    result = hard.validate_all(control_root, now_utc())
    digest = hard.state_digest(control_root)
    if result.get("stateDigest") != digest:
        raise ValidationError("legacy validator returned inconsistent state digest")
    subprocess.run(
        [
            sys.executable,
            str(Path(__file__).resolve().parent / "trusted_history_chain.py"),
            "--git-root",
            ".",
            "--trusted-sha",
            trusted_sha,
            "--control-sha",
            control_sha,
        ],
        check=True,
    )
    return digest


def _generated_bytes(root: Path) -> dict[str, bytes]:
    generated = root / "generated"
    if not generated.is_dir():
        return {}
    return {
        f".swarm/generated/{path.relative_to(generated).as_posix()}": path.read_bytes()
        for path in sorted(generated.rglob("*"))
        if path.is_file()
    }


def _commit_generated(api: GitHubContentsStore, branch: str, expected_control: str, root: Path) -> str:
    """Publish only rendered generated files, restarting on any control-head race."""
    before = _generated_bytes(root)
    hard.render(root, now_utc())
    hard.validate_marker(root)
    after = _generated_bytes(root)
    if not after:
        raise ValidationError("legacy render produced no generated projection")
    changed = {path: raw for path, raw in after.items() if before.get(path) != raw}
    if not changed:
        return expected_control
    if _api_ref_sha(api, branch) != expected_control:
        raise RefRace("control branch advanced before generated projection publish")
    commit = api._request("GET", f"/repos/{api.owner}/{api.repo}/git/commits/{expected_control}")
    base_tree = ((commit or {}).get("tree") or {}).get("sha") if isinstance(commit, dict) else None
    if not isinstance(base_tree, str):
        raise ValidationError("control commit omitted tree SHA")
    entries = []
    for path, raw in changed.items():
        blob = api._request(
            "POST",
            f"/repos/{api.owner}/{api.repo}/git/blobs",
            {"content": base64.b64encode(raw).decode("ascii"), "encoding": "base64"},
        )
        blob_sha = (blob or {}).get("sha") if isinstance(blob, dict) else None
        if not isinstance(blob_sha, str):
            raise ValidationError("generated blob creation omitted SHA")
        entries.append({"path": path, "mode": "100644", "type": "blob", "sha": blob_sha})
    tree = api._request(
        "POST",
        f"/repos/{api.owner}/{api.repo}/git/trees",
        {"base_tree": base_tree, "tree": entries},
    )
    tree_sha = (tree or {}).get("sha") if isinstance(tree, dict) else None
    if not isinstance(tree_sha, str):
        raise ValidationError("generated tree creation omitted SHA")
    created = api._request(
        "POST",
        f"/repos/{api.owner}/{api.repo}/git/commits",
        {
            "message": "chore(swarm): refresh generated projections after V16 state write [swarm-generated]",
            "tree": tree_sha,
            "parents": [expected_control],
        },
    )
    commit_sha = (created or {}).get("sha") if isinstance(created, dict) else None
    if not isinstance(commit_sha, str) or not SHA40.fullmatch(commit_sha):
        raise ValidationError("generated commit creation omitted SHA")
    if _api_ref_sha(api, branch) != expected_control:
        raise RefRace("control branch advanced during generated projection publish")
    encoded = urllib.parse.quote(branch, safe="")
    api._request(
        "PATCH",
        f"/repos/{api.owner}/{api.repo}/git/refs/heads/{encoded}",
        {"sha": commit_sha, "force": False},
    )
    if _api_ref_sha(api, branch) != commit_sha:
        raise RefRace("generated projection ref advanced after exact publish")
    return commit_sha


def _advance_trust(
    api: GitHubContentsStore,
    *,
    trust_branch: str,
    expected_trust_head: str,
    expected_control: str,
    digest: str,
    validator_main_sha: str,
    trust: dict[str, Any],
) -> str:
    if _api_ref_sha(api, trust_branch) != expected_trust_head:
        raise RefRace("trust branch advanced before CAS update")
    if _api_ref_sha(api, trust["controlBranch"]) != expected_control:
        raise RefRace("control branch advanced before trust CAS update")
    main_payload = api._request("GET", f"/repos/{api.owner}/{api.repo}/git/commits/{expected_trust_head}")
    base_tree = ((main_payload or {}).get("tree") or {}).get("sha") if isinstance(main_payload, dict) else None
    if not isinstance(base_tree, str):
        raise ValidationError("trust commit omitted tree SHA")
    updated = dict(trust)
    updated.update(
        {
            "bootstrap": False,
            "trustedControlSha": expected_control,
            "trustedStateDigest": digest,
            "validatedAt": fmt(now_utc()),
            "validatorMainSha": validator_main_sha,
        }
    )
    with tempfile.TemporaryDirectory() as temp:
        hard.validate_trust_record(_write_trust_file(updated, Path(temp)))
    raw = (json.dumps(updated, indent=2, sort_keys=True) + "\n").encode("utf-8")
    blob = api._request(
        "POST",
        f"/repos/{api.owner}/{api.repo}/git/blobs",
        {"content": base64.b64encode(raw).decode("ascii"), "encoding": "base64"},
    )
    blob_sha = (blob or {}).get("sha") if isinstance(blob, dict) else None
    if not isinstance(blob_sha, str):
        raise ValidationError("trust blob creation omitted SHA")
    tree = api._request(
        "POST",
        f"/repos/{api.owner}/{api.repo}/git/trees",
        {
            "base_tree": base_tree,
            "tree": [{"path": TRUST_PATH, "mode": "100644", "type": "blob", "sha": blob_sha}],
        },
    )
    tree_sha = (tree or {}).get("sha") if isinstance(tree, dict) else None
    if not isinstance(tree_sha, str):
        raise ValidationError("trust tree creation omitted SHA")
    commit = api._request(
        "POST",
        f"/repos/{api.owner}/{api.repo}/git/commits",
        {
            "message": f"chore(swarm): trust V16 control {expected_control[:12]}",
            "tree": tree_sha,
            "parents": [expected_trust_head],
        },
    )
    commit_sha = (commit or {}).get("sha") if isinstance(commit, dict) else None
    if not isinstance(commit_sha, str) or not SHA40.fullmatch(commit_sha):
        raise ValidationError("trust commit creation omitted SHA")
    if _api_ref_sha(api, trust_branch) != expected_trust_head:
        raise RefRace("trust branch advanced during CAS update")
    if _api_ref_sha(api, trust["controlBranch"]) != expected_control:
        raise RefRace("control branch advanced during trust CAS update")
    encoded = urllib.parse.quote(trust_branch, safe="")
    api._request(
        "PATCH",
        f"/repos/{api.owner}/{api.repo}/git/refs/heads/{encoded}",
        {"sha": commit_sha, "force": False},
    )
    if _api_ref_sha(api, trust_branch) != commit_sha:
        raise RefRace("trust ref advanced after exact publish")
    return commit_sha


def _synchronize_once(
    api: GitHubContentsStore,
    *,
    control_branch: str,
    trust_branch: str,
    default_branch: str,
    validator_main_sha: str,
    dry_run: bool,
) -> dict[str, Any]:
    if _api_ref_sha(api, default_branch) != validator_main_sha:
        raise ValidationError("validator checkout is not current default-branch head")
    control_sha = _api_ref_sha(api, control_branch)
    trust_head = _api_ref_sha(api, trust_branch)
    trust, _trust_blob = _load_exact_trust(api, trust_branch, trust_head)
    if trust["controlBranch"] != control_branch:
        raise ValidationError("requested control branch differs from trust authority")
    _fetch(control_branch)
    with tempfile.TemporaryDirectory() as temp:
        temp_root = Path(temp)
        trusted_root = _archive_swarm(trust["trustedControlSha"], temp_root / "trusted")
        control_root = _archive_swarm(control_sha, temp_root / "control")
        trust_path = _write_trust_file(trust, temp_root)
        digest = _validate_and_replay(
            control_root,
            trusted_root,
            trust_path,
            trust["trustedControlSha"],
            control_sha,
        )
        if dry_run:
            hard.render(control_root, now_utc())
            hard.validate_marker(control_root)
            if _api_ref_sha(api, control_branch) != control_sha or _api_ref_sha(api, trust_branch) != trust_head:
                raise RefRace("authority refs advanced during dry-run proof")
            return {
                "status": "PASS",
                "dryRun": True,
                "controlSha": control_sha,
                "trustedFrom": trust["trustedControlSha"],
                "stateDigest": digest,
                "validatorMainSha": validator_main_sha,
            }
        final_control = _commit_generated(api, control_branch, control_sha, control_root)
    _fetch(control_branch)
    with tempfile.TemporaryDirectory() as temp:
        temp_root = Path(temp)
        trusted_root = _archive_swarm(trust["trustedControlSha"], temp_root / "trusted")
        final_root = _archive_swarm(final_control, temp_root / "final")
        trust_path = _write_trust_file(trust, temp_root)
        final_digest = _validate_and_replay(
            final_root,
            trusted_root,
            trust_path,
            trust["trustedControlSha"],
            final_control,
        )
        hard.validate_marker(final_root)
        if final_digest != digest:
            raise ValidationError("generated-only publish changed authoritative state digest")
    if _api_ref_sha(api, default_branch) != validator_main_sha:
        raise ValidationError("default branch advanced before trust authorization")
    trust_commit = _advance_trust(
        api,
        trust_branch=trust_branch,
        expected_trust_head=trust_head,
        expected_control=final_control,
        digest=final_digest,
        validator_main_sha=validator_main_sha,
        trust=trust,
    )
    return {
        "status": "PASS",
        "dryRun": False,
        "controlSha": final_control,
        "trustedFrom": trust["trustedControlSha"],
        "trustCommit": trust_commit,
        "stateDigest": final_digest,
        "validatorMainSha": validator_main_sha,
        "runtimeAuthorityPromoted": False,
    }


def synchronize(
    repository: str,
    token: str,
    *,
    control_branch: str = "swarm-control",
    trust_branch: str = "swarm-trust",
    default_branch: str = "main",
    dry_run: bool = False,
    max_race_retries: int = 6,
) -> dict[str, Any]:
    if max_race_retries < 0:
        raise ValidationError("max_race_retries must be non-negative")
    api = GitHubContentsStore(repository, token, control_branch)
    validator_main_sha = _git("rev-parse", "HEAD", capture=True)
    if not SHA40.fullmatch(validator_main_sha):
        raise ValidationError("checkout HEAD is not exact Git SHA")
    for attempt in range(max_race_retries + 1):
        try:
            result = _synchronize_once(
                api,
                control_branch=control_branch,
                trust_branch=trust_branch,
                default_branch=default_branch,
                validator_main_sha=validator_main_sha,
                dry_run=dry_run,
            )
            result["raceRetries"] = attempt
            return result
        except RefRace:
            if attempt >= max_race_retries:
                raise
            time.sleep(min(0.25 * (attempt + 1), 1.0))
    raise AssertionError("unreachable")


def parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser()
    p.add_argument("--repo", required=True)
    p.add_argument("--token", default="")
    p.add_argument("--control-branch", default="swarm-control")
    p.add_argument("--trust-branch", default="swarm-trust")
    p.add_argument("--default-branch", default="main")
    p.add_argument("--dry-run", action="store_true")
    p.add_argument("--max-race-retries", type=int, default=6)
    return p


def main(argv: list[str] | None = None) -> int:
    args = parser().parse_args(argv)
    token = args.token or os.getenv("GITHUB_TOKEN", "")
    if not token:
        raise SystemExit("GITHUB_TOKEN is required")
    result = synchronize(
        args.repo,
        token,
        control_branch=args.control_branch,
        trust_branch=args.trust_branch,
        default_branch=args.default_branch,
        dry_run=args.dry_run,
        max_race_retries=args.max_race_retries,
    )
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (ValidationError, hard.core.ControlError, subprocess.CalledProcessError, RuntimeError) as exc:
        print(f"SWARM V16 LEGACY TRUST ERROR: {exc}", file=sys.stderr)
        raise SystemExit(2)
