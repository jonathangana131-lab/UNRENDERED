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


_STRICT_VALIDATE_EVENT = _base.core.validate_event
_LEGACY_EVENT_CUTOFF = _base.core.parse_time("2026-08-11T08:25:00+00:00")
_LEGACY_EVENT_FIELDS = {"slotId", "pr", "headSha", "verdict", "nextAction"}

# Immutable-event recovery is identity-bound, not a general legacy dialect. These
# records were audited from their first-published commits (or, for the MaterialDNA
# finding, from the still-live immutable bytes). Any other event -- even one with a
# deliberately backdated timestamp -- stays on the strict V2 validator.
_HISTORICAL_EVENT_COMPAT = {
    "evt-20260811-073500-q9m4r2-authority-rereview-approve": {
        "timestamp": "2026-08-11T07:35:00+00:00",
        "fromWorker": "sol-20260811-q9m4r2",
        "eventType": "REVIEW_RESULT",
        "laneId": "HG-BACKFILL-AUTHORITY",
        "legacyFields": {"pr", "headSha", "verdict"},
        "legacyValues": {
            "pr": 297,
            "headSha": "2a14f54ccecae5ea0e88f288f2c9185dbf885a9e",
            "verdict": "APPROVE_CONDITIONAL_OWNERSHIP",
        },
    },
    "evt-20260811-073650-q9m4r2-worldentity-sync-hold": {
        "timestamp": "2026-08-11T07:36:50+00:00",
        "fromWorker": "sol-20260811-q9m4r2",
        "eventType": "REVIEW_RESULT",
        "laneId": "HG-BACKFILL-WORLDENTITY",
        "legacyFields": {"pr", "headSha", "verdict"},
        "legacyValues": {
            "pr": 293,
            "headSha": "c301d8403d3c1b93ee3b2988f80e9d1e689eb33d",
            "verdict": "SYNC_REQUIRED",
        },
    },
    "evt-20260811-080520-h4v8n2-cart-geometry-review": {
        "timestamp": "2026-08-11T08:05:20+00:00",
        "fromWorker": "sol-20260811-h4v8n2",
        "eventType": "REVIEW_RESULT",
        "laneId": "HG-PHYSICS-CART-GEOMETRY",
        "legacyFields": {"slotId"},
        "legacyValues": {"slotId": "audit"},
    },
    "evt-20260811-081620-mat8c3r1-materialdna-key-grammar": {
        "timestamp": "2026-08-11T08:16:20+00:00",
        "fromWorker": "sol-20260811-mat8c3r1",
        "eventType": "FINDING",
        "laneId": "HG-CAPACITY-MINING",
        "legacyFields": set(),
        "legacyValues": {},
        "affects": ["HERO-GATE", "MaterialDNA"],
    },
}


def _validate_historical_event(path, obj, rule):
    event_id = obj.get("eventId")
    if path.stem != event_id:
        raise _base.core.ControlError(f"{path}: eventId does not match immutable event path")
    if _base.core.parse_time(obj.get("timestamp")) > _LEGACY_EVENT_CUTOFF:
        raise _base.core.ControlError(f"{path}: historical compatibility cutoff exceeded")
    for key in ("timestamp", "fromWorker", "eventType", "laneId"):
        if obj.get(key) != rule[key]:
            raise _base.core.ControlError(f"{path}: historical {key} does not match audited first-write identity")

    legacy = set(obj) & _LEGACY_EVENT_FIELDS
    if legacy != rule["legacyFields"]:
        raise _base.core.ControlError(f"{path}: historical legacy field set does not match audited first-write shape")
    for key, expected in rule["legacyValues"].items():
        if obj.get(key) != expected:
            raise _base.core.ControlError(f"{path}: historical {key} does not match audited first-write value")

    required = {
        "schemaVersion", "eventId", "timestamp", "fromWorker", "eventType", "summary", "affects",
    }
    allowed = required | {"laneId", "severity", "evidence", "toWorker", "metadata"} | rule["legacyFields"]
    _base.core.require_schema(obj, path)
    _base.core.require_keys(obj, required, allowed, path)
    if not isinstance(event_id, str) or not re.fullmatch(r"evt-[a-z0-9-]{12,96}", event_id):
        raise _base.core.ControlError(f"{path}: invalid eventId")
    _base.core.ensure_identifier(obj["fromWorker"], _base.core.WORKER_ID_RE, "fromWorker", path)
    if obj["eventType"] not in _base.core.EVENT_TYPES:
        raise _base.core.ControlError(f"{path}: invalid eventType")
    if not isinstance(obj["summary"], str) or not 1 <= len(obj["summary"]) <= 4000:
        raise _base.core.ControlError(f"{path}: invalid summary")
    _base.core.ensure_identifier(obj["laneId"], _base.core.LANE_ID_RE, "laneId", path)
    if "evidence" in obj and (
        not isinstance(obj["evidence"], list)
        or len(obj["evidence"]) > 32
        or any(not isinstance(value, str) or len(value) > 1000 for value in obj["evidence"])
    ):
        raise _base.core.ControlError(f"{path}: invalid evidence")
    metadata = obj.get("metadata", {})
    if not isinstance(metadata, dict):
        raise _base.core.ControlError(f"{path}: metadata must be object")
    for key in rule["legacyFields"]:
        if key in metadata and metadata[key] != obj[key]:
            raise _base.core.ControlError(f"{path}: conflicting historical {key} and metadata.{key}")

    if "affects" in rule:
        if obj["affects"] != rule["affects"]:
            raise _base.core.ControlError(f"{path}: historical affects does not match audited immutable value")
    elif not isinstance(obj["affects"], list) or any(
        not isinstance(value, str) or not _base.core.LANE_ID_RE.fullmatch(value) for value in obj["affects"]
    ):
        raise _base.core.ControlError(f"{path}: invalid affects")
    return obj


def _validate_event_with_immutable_compat(path):
    obj = _base.core.load_json(path, max_bytes=48_000)
    try:
        return _STRICT_VALIDATE_EVENT(path)
    except _base.core.ControlError:
        rule = _HISTORICAL_EVENT_COMPAT.get(obj.get("eventId"))
        if rule is None:
            raise
        return _validate_historical_event(path, obj, rule)


# core.read_tree resolves validate_event dynamically from the core module, so this
# compatibility hook reaches every proven base operation. transition_check still
# compares raw event bytes and therefore rejects rewrites/deletions exactly as before.
_base.core.validate_event = _validate_event_with_immutable_compat


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
        f"- `{x['laneId']}/{x['slotId']}` → `{x['workerId']}`; lease to `{x['expiresAt']}`"
        for x in board["activeClaims"]
    ] or ["_None._"]
    out += ["", "## Blocked lanes", ""]
    out += [
        f"- `{x['laneId']}` — **{x['state']}** — {x['reason']}" for x in board["blockedLanes"]
    ] or ["_None._"]
    out += ["", "> Generated state is disposable. Atomic claims/resource leases are ownership authority.", ""]
    return "\n".join(out)


_base.dashboard = dashboard


if __name__ == "__main__":
    raise SystemExit(_base.main())
