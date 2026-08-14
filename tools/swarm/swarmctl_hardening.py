#!/usr/bin/env python3
"""V2.1 trusted-history facade over the proven Swarm V2 hardening engine.

The base module remains byte-for-byte preserved. This facade owns narrowly scoped
compatibility and history-continuity behavior without weakening ownership, leases,
resources, state-digest fencing, or immutable-event append-only semantics.
"""
from __future__ import annotations

import hashlib
import json
import re
import shutil
import tempfile
from pathlib import Path

import swarm_history_recovery_extension as _extension
import swarm_history_recovery_manifest as _recovery
import swarmctl_hardening_base as _base
from swarmctl_hardening_base import *  # re-export the proven engine API


# Keep the first strict engine anchors on the shared base module. Re-executing this
# facade in-process must never capture a prior facade wrapper as the new "strict"
# authority or split compatibility state across module instances.
if not hasattr(_base, "_V21_STRICT_VALIDATE_EVENT"):
    _base._V21_STRICT_VALIDATE_EVENT = _base.core.validate_event
if not hasattr(_base, "_V21_STRICT_READ_TREE"):
    _base._V21_STRICT_READ_TREE = _base.read_tree
if not hasattr(_base, "_V21_STRICT_TRANSITION_CHECK"):
    _base._V21_STRICT_TRANSITION_CHECK = _base.transition_check

_STRICT_VALIDATE_EVENT = _base._V21_STRICT_VALIDATE_EVENT
_STRICT_READ_TREE = _base._V21_STRICT_READ_TREE
_STRICT_TRANSITION_CHECK = _base._V21_STRICT_TRANSITION_CHECK

# Exact pre-anchor worker-state defects crossed by the one-time reset. Each row is
# an invalid commit followed by the exact schema-valid repair that must also be in
# the reviewed bootstrap candidate ancestry. This is data, not compatibility: the
# invalid statuses remain rejected everywhere.
FINITE_WORKER_TRANSITIONS = _recovery.FINITE_WORKER_TRANSITIONS + _extension.FINITE_WORKER_TRANSITIONS

# One post-anchor stale-claim takeover was written without the required takeoverOf
# breadcrumb before the error was observed. The old lease was already expired by
# more than two days and generation advanced exactly once. Git history is immutable,
# so trusted replay may cross only this exact path + before/after byte identity. The
# disposable replay copy receives the missing breadcrumb before the proven strict
# transition engine runs; no live control bytes or general takeover rule are changed.
_FINITE_CLAIM_TAKEOVER_COMPAT = {
    "claims/SWARM-RECOVERY-EVENT-IDENTITY-COMPAT/repair.json": {
        "beforeSha256": "ed68427c1b4b4e75a079432ff7e27ffd9b03985c3e5f00842f9fc64a91d9fabb",
        "afterSha256": "328b733ef56d7392b1cb3aa1267bb1c377344a1abaf8f359cdb7b66ac930fdb4",
        "takeoverOf": "sol-20260811-m8q2v7",
    },
}

# Pre-convergence immutable history has two distinct recovery classes:
# 1) valid first-write bytes that were later rewritten; the rewritten bytes are
#    inert quarantine while the audited first-write identity stays pinned;
# 2) malformed first-write bytes that were never valid V2 authority; those exact
#    bytes are quarantine-only and can never be returned as an authoritative event.
# No event file is edited/deleted by this recovery. Any unlisted byte variant fails.
_LOCAL_CANONICAL_IMMUTABLE_EVENTS = {
    "evt-20260811-073500-q9m4r2-authority-rereview-approve": {
        "date": "2026-08-11",
        "filename": "evt-20260811-073500-q9m4r2-authority-rereview-approve.json",
        "canonicalGitBlobSha1": "2f0b0221b7995b3862ac6c009804ebb66f715fac",
        "quarantinedGitBlobSha1": "8f332b489b9266211ff6c5d2869647eba9b80838",
    },
    "evt-20260811-073650-q9m4r2-worldentity-sync-hold": {
        "date": "2026-08-11",
        "filename": "evt-20260811-073650-q9m4r2-worldentity-sync-hold.json",
        "canonicalGitBlobSha1": "f9781fd64518c01aa10b460f01aff13adc6635da",
        "quarantinedGitBlobSha1": "c7615c531b671d10a56d6a93577fc9c81cb15836",
    },
    "evt-20260811-080520-h4v8n2-cart-geometry-review": {
        "date": "2026-08-11",
        "filename": "evt-20260811-080520-h4v8n2-cart-geometry-review.json",
        "canonicalGitBlobSha1": "a39220b473086229e6b1057b296342175b851af1",
        "quarantinedGitBlobSha1": "162e42ab9ab08e7976d61e78ad12bbd088ff13a8",
    },
    "evt-20260811-081620-mat8c3r1-materialdna-key-grammar": {
        "date": "2026-08-11",
        "filename": "evt-20260811-081620-mat8c3r1-materialdna-key-grammar.json",
        "canonicalGitBlobSha1": "9a7f679ea84600d6a28a8bef02436e5f85fd857e",
    },
    "evt-20260811-083640-ogm5x8q2-objectgenome-support-stack": {
        "date": "2026-08-11",
        "filename": "evt-20260811-083640-ogm5x8q2-objectgenome-support-stack.json",
        "canonicalGitBlobSha1": "9ef4e62ffb0aac9d4b18cb19911d8d3a25535158",
        "quarantinedGitBlobSha1": "c2b99475cdb95940d9a7ca329440880865da02cb",
    },
    **_recovery.quarantine_rules(),
    **_extension.quarantine_rules(),
}

# The registry itself is shared authority. A second facade execution must reuse the
# same object so exact immutable-history identities cannot diverge between wrappers.
if not hasattr(_base, "_V21_CANONICAL_IMMUTABLE_EVENTS"):
    _base._V21_CANONICAL_IMMUTABLE_EVENTS = _LOCAL_CANONICAL_IMMUTABLE_EVENTS
_CANONICAL_IMMUTABLE_EVENTS = _base._V21_CANONICAL_IMMUTABLE_EVENTS

TRUST_BRANCH = "swarm-trust"
TRUST_SCHEMA = 1


def _git_blob_sha1_bytes(raw: bytes) -> str:
    header = f"blob {len(raw)}\0".encode("ascii")
    return hashlib.sha1(header + raw).hexdigest()


def _git_blob_sha1(path: Path) -> str:
    return _git_blob_sha1_bytes(path.read_bytes())


def _relative_event_path(rule: dict) -> str:
    return f"events/{rule['date']}/{rule['filename']}"


def _canonical_rule_for_path(path: Path) -> tuple[str, dict] | None:
    for expected_id, rule in _CANONICAL_IMMUTABLE_EVENTS.items():
        if path.name == rule["filename"] and path.parent.name == rule["date"]:
            return expected_id, rule
    return None


def _quarantine_only_identity(path: Path) -> tuple[str, dict, str] | None:
    """Recognize only exact byte-pinned inert history without parsing its payload."""
    match = _canonical_rule_for_path(path)
    if match is None:
        return None
    expected_id, rule = match
    expected_blob = rule.get("quarantineOnlyGitBlobSha1")
    if expected_blob is None:
        return None
    actual = _git_blob_sha1(path)
    if actual != expected_blob:
        return None
    return expected_id, rule, actual


def _canonical_rule(path: Path, obj: dict) -> tuple[str, dict] | None:
    event_id = obj.get("eventId")
    path_match = _canonical_rule_for_path(path)
    if path_match is not None:
        expected_id, rule = path_match
        if event_id != expected_id:
            raise _base.core.ControlError(
                f"{path}: audited immutable event path contains unexpected eventId {event_id!r}"
            )
        return expected_id, rule
    for expected_id, rule in _CANONICAL_IMMUTABLE_EVENTS.items():
        if event_id == expected_id:
            raise _base.core.ControlError(f"{path}: audited immutable event moved/replayed from its canonical path")
    return None


def _validate_event_with_immutable_compat(path):
    path = Path(path)
    quarantine_identity = _quarantine_only_identity(path)
    if quarantine_identity is not None:
        expected_id, _rule, actual = quarantine_identity
        return {
            "_quarantined": True,
            "eventId": expected_id,
            "gitBlobSha1": actual,
            "quarantineOnly": True,
        }

    obj = _base.core.load_json(path, max_bytes=48_000)
    match = _canonical_rule(path, obj)
    if match is not None:
        expected_id, rule = match
        actual = _git_blob_sha1(path)
        quarantine_only = rule.get("quarantineOnlyGitBlobSha1")
        if quarantine_only is not None:
            raise _base.core.ControlError(
                f"{path}: quarantine-only immutable event changed: {actual} != {quarantine_only}"
            )
        canonical = rule["canonicalGitBlobSha1"]
        if actual == canonical:
            return obj
        quarantined = rule.get("quarantinedGitBlobSha1")
        if quarantined is not None and actual == quarantined:
            return {
                "_quarantined": True,
                "eventId": expected_id,
                "gitBlobSha1": actual,
                "canonicalGitBlobSha1": canonical,
                "quarantineOnly": False,
            }
        raise _base.core.ControlError(
            f"{path}: audited immutable event bytes are neither canonical nor the finite quarantined recovery blob: {actual}"
        )
    return _STRICT_VALIDATE_EVENT(path)


_base.core.validate_event = _validate_event_with_immutable_compat


def _invalid_worker_statuses(root: Path) -> list[str]:
    """Enumerate every parseable worker status violation without accepting aliases."""
    errors: list[str] = []
    workers_dir = root / "workers"
    if not workers_dir.is_dir():
        return errors
    for path in sorted(workers_dir.glob("*.json")):
        try:
            obj = _base.core.load_json(path, max_bytes=24_000)
        except _base.core.ControlError:
            continue
        status = obj.get("status")
        if status not in _base.core.WORKER_STATUSES:
            errors.append(f"{path}: invalid worker status: {status!r}")
    return errors


def _invalid_event_errors(root: Path) -> list[str]:
    """Enumerate every event schema/identity defect while honoring exact quarantine rules."""
    errors: list[str] = []
    events_dir = root / "events"
    if not events_dir.is_dir():
        return errors
    for path in sorted(events_dir.glob("*/*.json")):
        try:
            _validate_event_with_immutable_compat(path)
        except _base.core.ControlError as exc:
            errors.append(str(exc))
    return errors


def read_tree(root: Path):
    """Read authoritative state, reserve all event IDs, and drop inert quarantine artifacts."""
    errors = _invalid_worker_statuses(root) + _invalid_event_errors(root)
    if errors:
        raise _base.core.ControlError("\n".join(errors))
    result = _STRICT_READ_TREE(root)
    raw_events = result[6]
    seen: set[str] = set()
    events: list[dict] = []
    for event in raw_events:
        event_id = event["eventId"]
        if event_id in seen:
            raise _base.core.ControlError(f"duplicate immutable eventId {event_id}")
        seen.add(event_id)
        if event.get("_quarantined") is True:
            continue
        events.append(event)
    return (*result[:6], events)


_base.read_tree = read_tree


def quarantined_history(root: Path) -> list[dict]:
    """Return exact known inert historical artifacts present in this snapshot."""
    records = []
    for event_id, rule in _CANONICAL_IMMUTABLE_EVENTS.items():
        path = root / "events" / rule["date"] / rule["filename"]
        if not path.exists():
            continue

        quarantine_identity = _quarantine_only_identity(path)
        if quarantine_identity is not None:
            _expected_id, _rule, actual = quarantine_identity
            records.append({
                "eventId": event_id,
                "path": _relative_event_path(rule),
                "quarantinedGitBlobSha1": actual,
                "quarantineOnly": True,
            })
            continue

        obj = _base.core.load_json(path, max_bytes=48_000)
        _canonical_rule(path, obj)
        actual = _git_blob_sha1(path)
        quarantine_only = rule.get("quarantineOnlyGitBlobSha1")
        if quarantine_only is not None:
            raise _base.core.ControlError(
                f"{path}: quarantine-only immutable event changed: {actual} != {quarantine_only}"
            )
        bad = rule.get("quarantinedGitBlobSha1")
        if bad is None or actual == rule["canonicalGitBlobSha1"]:
            continue
        if actual != bad:
            raise _base.core.ControlError(f"{path}: quarantined immutable event changed: {actual} != {bad}")
        records.append({
            "eventId": event_id,
            "path": _relative_event_path(rule),
            "quarantinedGitBlobSha1": bad,
            "canonicalGitBlobSha1": rule["canonicalGitBlobSha1"],
            "quarantineOnly": False,
        })
    return records


def validate_trust_record(path: Path) -> dict:
    obj = _base.core.load_json(path, max_bytes=24_000)
    required = {
        "schemaVersion", "controlBranch", "trustedControlSha", "trustedStateDigest",
        "validatedAt", "validatorMainSha", "resetId", "resetReason",
    }
    allowed = required | {"bootstrap"}
    _base.core.require_schema(obj, path)
    _base.core.require_keys(obj, required, allowed, path)
    if obj["controlBranch"] != "swarm-control":
        raise _base.core.ControlError(f"{path}: trust record targets wrong control branch")
    for key in ("trustedControlSha", "validatorMainSha"):
        if not isinstance(obj[key], str) or not re.fullmatch(r"[a-f0-9]{40}", obj[key]):
            raise _base.core.ControlError(f"{path}: invalid {key}")
    if not isinstance(obj["trustedStateDigest"], str) or not re.fullmatch(r"[a-f0-9]{64}", obj["trustedStateDigest"]):
        raise _base.core.ControlError(f"{path}: invalid trustedStateDigest")
    _base.core.parse_time(obj["validatedAt"])
    if not isinstance(obj["resetId"], str) or not re.fullmatch(r"reset-[a-z0-9-]{8,64}", obj["resetId"]):
        raise _base.core.ControlError(f"{path}: invalid resetId")
    if not isinstance(obj["resetReason"], str) or not 1 <= len(obj["resetReason"]) <= 1000:
        raise _base.core.ControlError(f"{path}: invalid resetReason")
    if "bootstrap" in obj and not isinstance(obj["bootstrap"], bool):
        raise _base.core.ControlError(f"{path}: bootstrap must be bool")
    return obj


def verify_trusted_snapshot(root: Path, trust_path: Path, *, allow_bootstrap: bool = False) -> dict:
    """Bind one archived control snapshot to the trust record's digest as one atomic anchor."""
    trust = validate_trust_record(trust_path)
    if trust.get("bootstrap", False) and not allow_bootstrap:
        raise _base.core.ControlError("swarm trust branch is still in bootstrap/reset mode")
    actual = _base.state_digest(root)
    if actual != trust["trustedStateDigest"]:
        raise _base.core.ControlError(
            "trusted control SHA snapshot does not match its separately recorded state digest: "
            f"{actual} != {trust['trustedStateDigest']}"
        )
    return trust


def verify_trusted_state(root: Path, trust_path: Path) -> dict:
    """Require current authoritative JSON state to equal a non-bootstrap separate trust anchor."""
    return verify_trusted_snapshot(root, trust_path, allow_bootstrap=False)


def _strict_transition_check_with_finite_claim_compat(before: Path, after: Path) -> dict:
    """Cross one byte-pinned missing-takeoverOf transition without weakening strict leases."""
    try:
        return _STRICT_TRANSITION_CHECK(before, after)
    except _base.core.ControlError:
        matched: list[tuple[str, dict]] = []
        for relative, rule in _FINITE_CLAIM_TAKEOVER_COMPAT.items():
            before_path = Path(before) / relative
            after_path = Path(after) / relative
            if not before_path.is_file() or not after_path.is_file():
                continue
            before_digest = hashlib.sha256(before_path.read_bytes()).hexdigest()
            after_digest = hashlib.sha256(after_path.read_bytes()).hexdigest()
            if before_digest == rule["beforeSha256"] and after_digest == rule["afterSha256"]:
                matched.append((relative, rule))
        if len(matched) != 1:
            raise

        relative, rule = matched[0]
        with tempfile.TemporaryDirectory() as temp_dir:
            temp_root = Path(temp_dir)
            compat_before = temp_root / "before"
            compat_after = temp_root / "after"
            shutil.copytree(before, compat_before)
            shutil.copytree(after, compat_after)
            compat_path = compat_after / relative
            obj = _base.core.load_json(compat_path, max_bytes=32_000)
            if "takeoverOf" in obj:
                raise _base.core.ControlError(f"{compat_path}: finite takeover compatibility bytes unexpectedly contain takeoverOf")
            obj["takeoverOf"] = rule["takeoverOf"]
            compat_path.write_text(json.dumps(obj, indent=2) + "\n", encoding="utf-8")
            result = _STRICT_TRANSITION_CHECK(compat_before, compat_after)
        result["finiteClaimTakeoverCompat"] = [relative]
        return result


def transition_check(before: Path, after: Path) -> dict:
    """Compare from the last separately trusted snapshot, never merely the immediate parent."""
    before = Path(before)
    after = Path(after)
    read_tree(before)
    read_tree(after)
    result = _strict_transition_check_with_finite_claim_compat(before, after)

    before_paths = {str(path.relative_to(before)): path for path in before.glob("events/*/*.json")}
    after_paths = {str(path.relative_to(after)): path for path in after.glob("events/*/*.json")}
    added = sorted(after_paths.keys() - before_paths.keys())
    canonical_paths = {_relative_event_path(rule) for rule in _CANONICAL_IMMUTABLE_EVENTS.values()}

    seen: set[str] = set()
    for path in before_paths.values():
        event = _validate_event_with_immutable_compat(path)
        event_id = event.get("eventId")
        if not isinstance(event_id, str):
            raise _base.core.ControlError(f"{path}: eventId required during transition replay check")
        if event_id in seen:
            raise _base.core.ControlError(f"duplicate immutable eventId {event_id} in trusted transition baseline")
        seen.add(event_id)

    for relative in added:
        if relative in canonical_paths:
            raise _base.core.ControlError(f"historical immutable event path cannot be re-added: {relative}")
        path = after_paths[relative]
        obj = _base.core.load_json(path, max_bytes=48_000)
        event_id = obj.get("eventId")
        if not isinstance(event_id, str):
            raise _base.core.ControlError(f"{path}: eventId required during transition replay check")
        if event_id in seen:
            raise _base.core.ControlError(f"immutable eventId replayed by new event: {event_id}")
        seen.add(event_id)

    result["trustedHistoryBaseline"] = True
    result["quarantinedHistoricalEvents"] = len(quarantined_history(after))
    return result


_base.transition_check = transition_check


def dashboard(board: dict) -> str:
    out = [
        "# UNRENDERED Swarm Control Plane", "", f"Generated: `{board['generatedAt']}`", "",
        f"Canonical main: **{board['mainHealth']['status']}** `{board['mainHealth']['headSha'] or 'unknown'}`", "",
        f"State digest: `{board['stateDigest']}`", "", "## Summary", "",
        f"- ready slots: **{board['summary']['readySlots']}**", f"- active claims: **{board['summary']['activeClaims']}**",
        f"- stale claims: **{board['summary']['staleClaims']}**", f"- blocked-external lanes: **{board['summary']['blockedExternalLanes']}**",
        "", "## Ready slots", "",
    ]
    out += [
        f"- `{x['laneId']}/{x['slotId']}` — **{x['role']}** — score {x['score']} — {x['reason']}"
        for x in board["readySlots"][:30]
    ] or [
        "_No ordinary ready slot is materialized. GREEN is not completion: re-read live state and exhaust review/integration → stale recovery → active-Epic backfill → tests/audit → capacity-mining before idling._"
    ]
    out += ["", "## Active claims", ""]
    out += [
        f"- `{x['laneId']}/{x['slotId']}` → `{x['workerId']}`; lease to `{x['expiresAt']}`" for x in board["activeClaims"]
    ] or ["_None._"]
    out += ["", "## Blocked lanes", ""]
    out += [f"- `{x['laneId']}` — **{x['state']}** — {x['reason']}" for x in board["blockedLanes"]] or ["_None._"]
    out += ["", "> Generated state is disposable. Atomic claims/resource leases are ownership authority.", ""]
    return "\n".join(out)


_base.dashboard = dashboard


if __name__ == "__main__":
    raise SystemExit(_base.main())
