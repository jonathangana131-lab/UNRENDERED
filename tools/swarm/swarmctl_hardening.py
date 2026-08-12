#!/usr/bin/env python3
"""V2.1 compatibility facade over the proven Swarm V2 hardening engine.

The base module remains byte-for-byte preserved. This facade owns narrowly scoped
compatibility behavior that must wrap the trusted engine without weakening its
ownership, fencing, scheduling, or transition invariants.
"""
from __future__ import annotations

import hashlib
import json
from pathlib import Path

import swarmctl_hardening_base as _base
from swarmctl_hardening_base import *  # re-export the proven engine API


_STRICT_VALIDATE_EVENT = _base.core.validate_event
_STRICT_READ_TREE = _base.read_tree
_STRICT_TRANSITION_CHECK = _base.transition_check

# Five immutable events were emitted before every writer converged on the strict
# V2 event shape. Three were later rewritten after their first transition failure,
# and a later projection incorrectly blessed those rewritten bytes. Compatibility
# must therefore identify only audited first-write bytes; it must NOT rewrite,
# normalize, quarantine, or bless already-laundered live variants. The fifth event
# is an unchanged first-write HANDOFF whose validation evidence used the legacy
# nested `command` key; only its exact audited blob may cross the executable-key
# fence. All other control JSON remains subject to the strict loader.
_CANONICAL_IMMUTABLE_EVENTS = {
    "evt-20260811-073500-q9m4r2-authority-rereview-approve": {
        "date": "2026-08-11",
        "filename": "evt-20260811-073500-q9m4r2-authority-rereview-approve.json",
        "canonicalGitBlobSha1": "2f0b0221b7995b3862ac6c009804ebb66f715fac",
    },
    "evt-20260811-073650-q9m4r2-worldentity-sync-hold": {
        "date": "2026-08-11",
        "filename": "evt-20260811-073650-q9m4r2-worldentity-sync-hold.json",
        "canonicalGitBlobSha1": "f9781fd64518c01aa10b460f01aff13adc6635da",
    },
    "evt-20260811-080520-h4v8n2-cart-geometry-review": {
        "date": "2026-08-11",
        "filename": "evt-20260811-080520-h4v8n2-cart-geometry-review.json",
        "canonicalGitBlobSha1": "a39220b473086229e6b1057b296342175b851af1",
    },
    "evt-20260811-081620-mat8c3r1-materialdna-key-grammar": {
        "date": "2026-08-11",
        "filename": "evt-20260811-081620-mat8c3r1-materialdna-key-grammar.json",
        "canonicalGitBlobSha1": "9a7f679ea84600d6a28a8bef02436e5f85fd857e",
    },
    "evt-20260811T210500Z-sol-20260811-c7p4m8v2-handoff-content-reconciliation": {
        "date": "2026-08-11",
        "filename": "210500-sol-20260811-c7p4m8v2-handoff-content-reconciliation.json",
        "canonicalGitBlobSha1": "713d54c453faa65e89875e69499444d5a7644d3f",
    },
}


def _git_blob_sha1_bytes(raw: bytes) -> str:
    header = f"blob {len(raw)}\0".encode("ascii")
    return hashlib.sha1(header + raw).hexdigest()


def _git_blob_sha1(path: Path) -> str:
    return _git_blob_sha1_bytes(path.read_bytes())


def _relative_event_path(rule: dict) -> str:
    return f"events/{rule['date']}/{rule['filename']}"


def _canonical_rule(path: Path, obj: dict) -> dict | None:
    event_id = obj.get("eventId")
    for expected_id, rule in _CANONICAL_IMMUTABLE_EVENTS.items():
        at_canonical_path = path.name == rule["filename"] and path.parent.name == rule["date"]
        if at_canonical_path:
            if event_id != expected_id:
                raise _base.core.ControlError(
                    f"{path}: audited immutable event path contains unexpected eventId {event_id!r}"
                )
            return rule
        if event_id == expected_id:
            raise _base.core.ControlError(f"{path}: audited immutable event moved/replayed from its canonical path")
    return None


def _load_exact_immutable_event(path: Path) -> dict | None:
    """Load only an exact audited historical blob before strict key inspection.

    Legacy immutable evidence can contain keys the current control-data schema now
    forbids. The path and Git blob hash are authenticated before JSON decoding, so
    arbitrary control data cannot opt into this compatibility path.
    """
    for expected_id, rule in _CANONICAL_IMMUTABLE_EVENTS.items():
        if path.name != rule["filename"] or path.parent.name != rule["date"]:
            continue
        actual = _git_blob_sha1(path)
        expected = rule["canonicalGitBlobSha1"]
        if actual != expected:
            raise _base.core.ControlError(
                f"{path}: audited immutable event bytes are non-canonical: {actual} != {expected}"
            )
        try:
            obj = json.loads(path.read_text(encoding="utf-8"))
        except json.JSONDecodeError as exc:
            raise _base.core.ControlError(f"invalid audited immutable JSON {path}: {exc}") from exc
        if not isinstance(obj, dict):
            raise _base.core.ControlError(f"top-level JSON object required: {path}")
        if obj.get("eventId") != expected_id:
            raise _base.core.ControlError(
                f"{path}: audited immutable event path contains unexpected eventId {obj.get('eventId')!r}"
            )
        return obj
    return None


def _validate_event_with_immutable_compat(path):
    path = Path(path)
    exact = _load_exact_immutable_event(path)
    if exact is not None:
        return exact
    obj = _base.core.load_json(path, max_bytes=48_000)
    rule = _canonical_rule(path, obj)
    if rule is not None:
        actual = _git_blob_sha1(path)
        expected = rule["canonicalGitBlobSha1"]
        if actual != expected:
            raise _base.core.ControlError(
                f"{path}: audited immutable event bytes are non-canonical: {actual} != {expected}"
            )
        return obj
    return _STRICT_VALIDATE_EVENT(path)


# core.read_tree resolves validate_event dynamically, so exact-blob compatibility
# reaches every proven base operation. Unlisted events still use strict V2; no
# timestamp or self-authored metadata can opt into compatibility.
_base.core.validate_event = _validate_event_with_immutable_compat


def read_tree(root: Path):
    """Retain the proven tree reader and add global eventId uniqueness."""
    result = _STRICT_READ_TREE(root)
    events = result[6]
    seen: set[str] = set()
    for event in events:
        event_id = event["eventId"]
        if event_id in seen:
            raise _base.core.ControlError(f"duplicate immutable eventId {event_id}")
        seen.add(event_id)
    return result


# Base validate/render/pr-check functions resolve read_tree from base globals.
_base.read_tree = read_tree


def transition_check(before: Path, after: Path) -> dict:
    """Keep base byte immutability and additionally reject eventId replay on add."""
    before = Path(before)
    after = Path(after)
    result = _STRICT_TRANSITION_CHECK(before, after)

    before_paths = {str(path.relative_to(before)): path for path in before.glob("events/*/*.json")}
    after_paths = {str(path.relative_to(after)): path for path in after.glob("events/*/*.json")}
    added = sorted(after_paths.keys() - before_paths.keys())
    canonical_paths = {_relative_event_path(rule) for rule in _CANONICAL_IMMUTABLE_EVENTS.values()}

    seen: set[str] = set()
    for path in before_paths.values():
        obj = _validate_event_with_immutable_compat(path)
        event_id = obj.get("eventId")
        if not isinstance(event_id, str):
            raise _base.core.ControlError(f"{path}: eventId required during transition replay check")
        if event_id in seen:
            raise _base.core.ControlError(f"duplicate immutable eventId {event_id} in transition baseline")
        seen.add(event_id)

    for relative in added:
        if relative in canonical_paths:
            raise _base.core.ControlError(f"historical immutable event path cannot be re-added: {relative}")
        path = after_paths[relative]
        obj = _validate_event_with_immutable_compat(path)
        event_id = obj.get("eventId")
        if not isinstance(event_id, str):
            raise _base.core.ControlError(f"{path}: eventId required during transition replay check")
        if event_id in seen:
            raise _base.core.ControlError(f"immutable eventId replayed by new event: {event_id}")
        seen.add(event_id)

    return result


# Base CLI resolves transition_check from base globals. The underlying base check
# still rejects every changed/deleted historical event byte-for-byte.
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
