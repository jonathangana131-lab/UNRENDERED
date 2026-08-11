#!/usr/bin/env python3
"""V2.1 compatibility facade over the proven Swarm V2 hardening engine.

The base module remains byte-for-byte preserved. This facade owns narrowly scoped
compatibility behavior that must wrap the trusted engine without weakening its
ownership, fencing, scheduling, or transition invariants.
"""
from __future__ import annotations

import hashlib
from pathlib import Path

import swarmctl_hardening_base as _base
from swarmctl_hardening_base import *  # re-export the proven engine API


_STRICT_VALIDATE_EVENT = _base.core.validate_event

# Four immutable events were emitted before every writer converged on the strict
# V2 event shape. Three were later rewritten after their first transition failure,
# and a later projection incorrectly blessed those rewritten bytes. Recovery must
# therefore distinguish canonical first-write bytes from the known laundered live
# variants instead of treating a self-authored timestamp as provenance.
#
# The canonical hashes below are Git blob SHA-1 values returned by GitHub for each
# audited first-published event. `restorableFromGitBlobSha1` is deliberately finite:
# it names only the exact laundered blob present when this repair was authored. If
# live bytes change again, restoration fails closed and requires a new audit.
_CANONICAL_IMMUTABLE_EVENTS = {
    "evt-20260811-073500-q9m4r2-authority-rereview-approve": {
        "date": "2026-08-11",
        "filename": "evt-20260811-073500-q9m4r2-authority-rereview-approve.json",
        "canonicalGitBlobSha1": "2f0b0221b7995b3862ac6c009804ebb66f715fac",
        "restorableFromGitBlobSha1": {"8f332b489b9266211ff6c5d2869647eba9b80838"},
    },
    "evt-20260811-073650-q9m4r2-worldentity-sync-hold": {
        "date": "2026-08-11",
        "filename": "evt-20260811-073650-q9m4r2-worldentity-sync-hold.json",
        "canonicalGitBlobSha1": "f9781fd64518c01aa10b460f01aff13adc6635da",
        "restorableFromGitBlobSha1": {"c7615c531b671d10a56d6a93577fc9c81cb15836"},
    },
    "evt-20260811-080520-h4v8n2-cart-geometry-review": {
        "date": "2026-08-11",
        "filename": "evt-20260811-080520-h4v8n2-cart-geometry-review.json",
        "canonicalGitBlobSha1": "a39220b473086229e6b1057b296342175b851af1",
        "restorableFromGitBlobSha1": {"162e42ab9ab08e7976d61e78ad12bbd088ff13a8"},
    },
    "evt-20260811-081620-mat8c3r1-materialdna-key-grammar": {
        "date": "2026-08-11",
        "filename": "evt-20260811-081620-mat8c3r1-materialdna-key-grammar.json",
        "canonicalGitBlobSha1": "9a7f679ea84600d6a28a8bef02436e5f85fd857e",
        "restorableFromGitBlobSha1": set(),
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
            raise _base.core.ControlError(f"{path}: audited immutable event moved from its canonical path")
    return None


def _validate_event_with_immutable_compat(path):
    path = Path(path)
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


# core.read_tree resolves validate_event dynamically from the core module, so this
# exact-blob compatibility hook reaches every proven base operation. Unlisted
# events still use the strict V2 validator; backdating can never opt into legacy
# compatibility.
_base.core.validate_event = _validate_event_with_immutable_compat


def _is_exact_canonical_restoration(relative: str, before_raw: bytes, after_raw: bytes) -> bool:
    before_sha = _git_blob_sha1_bytes(before_raw)
    after_sha = _git_blob_sha1_bytes(after_raw)
    for rule in _CANONICAL_IMMUTABLE_EVENTS.values():
        if relative != _relative_event_path(rule):
            continue
        return (
            before_sha in rule["restorableFromGitBlobSha1"]
            and after_sha == rule["canonicalGitBlobSha1"]
        )
    return False


def transition_check(before: Path, after: Path) -> dict:
    """Preserve V2 lease fencing while allowing only audited byte restoration.

    Base V2 correctly rejects every event rewrite. The live branch already contains
    three known rewrites that were laundered by a later projection, so recovery needs
    one narrower exception: exact known-laundered blob -> exact audited first-write
    blob at the same path. No other changed/deleted historical event is accepted.
    """
    before = Path(before)
    after = Path(after)
    before_claims = _base.raw_map(before, "claims/*/*.json", 32_000)
    after_claims = _base.raw_map(after, "claims/*/*.json", 32_000)
    before_resources = _base.raw_map(before, "resource-claims/*.json", 24_000)
    after_resources = _base.raw_map(after, "resource-claims/*.json", 24_000)

    for key in sorted(before_claims.keys() & after_claims.keys()):
        _base.lease_transition(before_claims[key], after_claims[key], f"claim {key}", "claimedAt", True)
    for key in sorted(before_resources.keys() & after_resources.keys()):
        _base.lease_transition(
            before_resources[key], after_resources[key], f"resource claim {key}", "acquiredAt", False
        )

    before_events = {
        str(path.relative_to(before)): path.read_bytes() for path in before.glob("events/*/*.json")
    }
    after_events = {
        str(path.relative_to(after)): path.read_bytes() for path in after.glob("events/*/*.json")
    }
    deleted = sorted(before_events.keys() - after_events.keys())
    changed = sorted(
        key for key in before_events.keys() & after_events.keys() if before_events[key] != after_events[key]
    )
    added = sorted(after_events.keys() - before_events.keys())

    canonical_paths = {_relative_event_path(rule) for rule in _CANONICAL_IMMUTABLE_EVENTS.values()}
    illegal_added = sorted(key for key in added if key in canonical_paths)
    restored = []
    illegal_changed = []
    for key in changed:
        if _is_exact_canonical_restoration(key, before_events[key], after_events[key]):
            restored.append(key)
        else:
            illegal_changed.append(key)

    if deleted or illegal_added or illegal_changed:
        raise _base.core.ControlError(
            "immutable events changed/deleted outside audited canonical restoration: "
            f"changed={illegal_changed}, deleted={deleted}, historicalAdded={illegal_added}"
        )
    return {
        "status": "PASS",
        "claimTransitions": len(before_claims.keys() & after_claims.keys()),
        "resourceClaimTransitions": len(before_resources.keys() & after_resources.keys()),
        "immutableEventsChecked": len(before_events),
        "canonicalRestorations": restored,
    }


# _base.main resolves transition_check from the base module's globals.
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
        f"- `{x['laneId']}/{x['slotId']}` → `{x['workerId']}`; lease to `{x['expiresAt']}`"
        for x in board["activeClaims"]
    ] or ["_None._"]
    out += ["", "## Blocked lanes", ""]
    out += [f"- `{x['laneId']}` — **{x['state']}** — {x['reason']}" for x in board["blockedLanes"]] or ["_None._"]
    out += ["", "> Generated state is disposable. Atomic claims/resource leases are ownership authority.", ""]
    return "\n".join(out)


_base.dashboard = dashboard


if __name__ == "__main__":
    raise SystemExit(_base.main())
