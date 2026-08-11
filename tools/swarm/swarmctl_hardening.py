#!/usr/bin/env python3
"""V2.1 compatibility facade over the proven Swarm V2 hardening engine.

The base module remains byte-for-byte preserved. This facade owns narrowly scoped
compatibility behavior that must wrap the trusted engine without weakening its
ownership, fencing, scheduling, or transition invariants.
"""
from __future__ import annotations

import re

import swarmctl_hardening_base as _base
from swarmctl_hardening_base import *  # re-export the proven engine API


# A short-lived worker generation wrote benign review coordinates at event top
# level before all writers converged on `metadata`. Event bytes are immutable, so
# deleting/rewriting those records is not a valid recovery. Keep compatibility
# finite: only the observed fields, only review/control-result event families,
# only strongly typed values, and only events timestamped before this recovery
# claim began. New event writes remain on the strict V2 schema.
_STRICT_VALIDATE_EVENT = _base.core.validate_event
_LEGACY_EVENT_CUTOFF = _base.core.parse_time("2026-08-11T08:25:00+00:00")
_LEGACY_EVENT_FIELDS = {"slotId", "pr", "headSha", "verdict", "nextAction"}
_LEGACY_EVENT_TYPES = {
    "BLOCKER",
    "REVIEW_REQUEST",
    "REVIEW_RESULT",
    "HANDOFF",
    "EVIDENCE_RESULT",
    "INTEGRATION_RESULT",
    "RECOVERY",
}
_LEGACY_VERDICTS = {
    "APPROVE",
    "REQUEST_CHANGES",
    "COMMENT",
    "PASS",
    "FAIL",
    "BLOCKED",
    "HOLD",
    "NEEDS_CHANGES",
    "INTEGRATION_READY",
}


def _validate_event_with_immutable_compat(path):
    obj = _base.core.load_json(path, max_bytes=48_000)
    legacy = set(obj) & _LEGACY_EVENT_FIELDS
    if not legacy:
        return _STRICT_VALIDATE_EVENT(path)

    required = {
        "schemaVersion",
        "eventId",
        "timestamp",
        "fromWorker",
        "eventType",
        "summary",
        "affects",
    }
    allowed = required | {"laneId", "severity", "evidence", "toWorker", "metadata"} | _LEGACY_EVENT_FIELDS
    _base.core.require_schema(obj, path)
    _base.core.require_keys(obj, required, allowed, path)

    if not isinstance(obj["eventId"], str) or not re.fullmatch(r"evt-[a-z0-9-]{12,96}", obj["eventId"]):
        raise _base.core.ControlError(f"{path}: invalid eventId")
    timestamp = _base.core.parse_time(obj["timestamp"])
    _base.core.ensure_identifier(obj["fromWorker"], _base.core.WORKER_ID_RE, "fromWorker", path)
    if obj["eventType"] not in _base.core.EVENT_TYPES:
        raise _base.core.ControlError(f"{path}: invalid eventType")
    if not isinstance(obj["summary"], str) or not 1 <= len(obj["summary"]) <= 4000:
        raise _base.core.ControlError(f"{path}: invalid summary")
    if not isinstance(obj["affects"], list) or any(
        not isinstance(value, str) or not _base.core.LANE_ID_RE.fullmatch(value) for value in obj["affects"]
    ):
        raise _base.core.ControlError(f"{path}: invalid affects")
    if "laneId" in obj:
        _base.core.ensure_identifier(obj["laneId"], _base.core.LANE_ID_RE, "laneId", path)
    if "evidence" in obj and (
        not isinstance(obj["evidence"], list)
        or len(obj["evidence"]) > 32
        or any(not isinstance(value, str) or len(value) > 1000 for value in obj["evidence"])
    ):
        raise _base.core.ControlError(f"{path}: invalid evidence")

    if timestamp > _LEGACY_EVENT_CUTOFF:
        raise _base.core.ControlError(f"{path}: legacy top-level review fields are no longer accepted")
    if obj["eventType"] not in _LEGACY_EVENT_TYPES:
        raise _base.core.ControlError(f"{path}: legacy review fields are invalid for eventType {obj['eventType']}")

    metadata = obj.get("metadata", {})
    if not isinstance(metadata, dict):
        raise _base.core.ControlError(f"{path}: metadata must be an object when legacy review fields are present")
    if "slotId" in obj:
        _base.core.ensure_identifier(obj["slotId"], _base.core.SLOT_ID_RE, "slotId", path)
    if "pr" in obj and (
        not isinstance(obj["pr"], int) or isinstance(obj["pr"], bool) or obj["pr"] <= 0
    ):
        raise _base.core.ControlError(f"{path}: invalid legacy pr")
    if "headSha" in obj and (
        not isinstance(obj["headSha"], str) or not re.fullmatch(r"[a-f0-9]{40}", obj["headSha"])
    ):
        raise _base.core.ControlError(f"{path}: invalid legacy headSha")
    if "verdict" in obj and (
        not isinstance(obj["verdict"], str) or obj["verdict"] not in _LEGACY_VERDICTS
    ):
        raise _base.core.ControlError(f"{path}: invalid legacy verdict")
    if "nextAction" in obj and (
        not isinstance(obj["nextAction"], str) or not 1 <= len(obj["nextAction"]) <= 1000
    ):
        raise _base.core.ControlError(f"{path}: invalid legacy nextAction")
    for key in legacy:
        if key in metadata and metadata[key] != obj[key]:
            raise _base.core.ControlError(f"{path}: conflicting legacy {key} and metadata.{key}")
    return obj


# core.read_tree resolves validate_event dynamically from the core module, so a
# facade-level compatibility hook reaches every proven base operation while the
# base engine itself remains unchanged. transition_check still compares raw event
# bytes and therefore continues to reject rewrites/deletions exactly as before.
_base.core.validate_event = _validate_event_with_immutable_compat


def dashboard(board: dict) -> str:
    out = [
        "# UNRENDERED Swarm Control Plane",
        "",
        f"Generated: `{board['generatedAt']}`",
        "",
        f"Canonical main: **{board['mainHealth']['status']}** `{board['mainHealth']['headSha'] or 'unknown'}`",
        "",
        f"State digest: `{board['stateDigest']}`",
        "",
        "## Summary",
        "",
        f"- ready slots: **{board['summary']['readySlots']}**",
        f"- active claims: **{board['summary']['activeClaims']}**",
        f"- stale claims: **{board['summary']['staleClaims']}**",
        f"- blocked-external lanes: **{board['summary']['blockedExternalLanes']}**",
        "",
        "## Ready slots",
        "",
    ]
    out += [
        f"- `{x['laneId']}/{x['slotId']}` — **{x['role']}** — score {x['score']} — {x['reason']}"
        for x in board["readySlots"][:30]
    ] or [
        "_No ordinary ready slot is materialized. GREEN is not completion: re-read live state and exhaust review/integration → stale recovery → active-Epic backfill → tests/audit → capacity-mining before idling._"
    ]
    out += ["", "## Active claims", ""]
    out += [
        f"- `{x['laneId']}/{x['slotId']}` → `{x['workerId']}`; lease to `{x['expiresAt']}`"
        for x in board["activeClaims"]
    ] or ["_None._"]
    out += ["", "## Blocked lanes", ""]
    out += [
        f"- `{x['laneId']}` — **{x['state']}** — {x['reason']}"
        for x in board["blockedLanes"]
    ] or ["_None._"]
    out += ["", "> Generated state is disposable. Atomic claims/resource leases are ownership authority.", ""]
    return "\n".join(out)


# Functions imported from the base module resolve the base module's globals. Patch
# that one presentation hook so render()/main() both use V2.1 semantics.
_base.dashboard = dashboard


if __name__ == "__main__":
    raise SystemExit(_base.main())
