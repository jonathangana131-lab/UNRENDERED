#!/usr/bin/env python3
"""UNRENDERED Swarm V2.2 hardening facade.

The proven V2 base engine remains byte-for-byte preserved. This facade carries the
reviewed immutable-event compatibility prerequisite and adds completion-pressure
scheduling plus risk-based review gates without weakening ownership, digest, lease,
resource, exact-head, or transition fences.
"""
from __future__ import annotations

import hashlib
import re
from pathlib import Path

import swarmctl_hardening_base as _base
from swarmctl_hardening_base import *  # re-export the proven engine API


_STRICT_VALIDATE_EVENT = _base.core.validate_event
_STRICT_READ_TREE = _base.read_tree
_STRICT_TRANSITION_CHECK = _base.transition_check

# Four immutable events were emitted before every writer converged on the strict
# V2 event shape. Compatibility identifies only audited first-write bytes. It does
# not normalize, rewrite, quarantine, or bless later variants.
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
        obj = _base.core.load_json(path, max_bytes=48_000)
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
        obj = _base.core.load_json(path, max_bytes=48_000)
        event_id = obj.get("eventId")
        if not isinstance(event_id, str):
            raise _base.core.ControlError(f"{path}: eventId required during transition replay check")
        if event_id in seen:
            raise _base.core.ControlError(f"immutable eventId replayed by new event: {event_id}")
        seen.add(event_id)

    return result


_base.transition_check = transition_check


# --- V2.2 completion throughput -------------------------------------------------
_V21_HARD_CONFIG = _base.hard_config
_V21_READY_SLOTS = _base.ready_slots
_V21_RENDER_BOARD = _base.render_board
_V21_PR_CHECK = _base.pr_check

_SELF_REVIEW_RE = re.compile(r"^Swarm-Self-Review:\s*(\S+)\s*$", re.MULTILINE)
_SELF_REVIEW_HEAD_RE = re.compile(r"^Swarm-Self-Review-Head:\s*([a-f0-9]{40})\s*$", re.MULTILINE)
_COMPLETION_STATES = {"REVIEW", "NEEDS_CHANGES", "INTEGRATION_READY"}
_CRITICAL_TAGS = {
    "authority", "multiplayer", "identity", "persistence", "schema", "trust-boundary",
    "control-repair", "reality", "security",
}


def hard_config(path: Path) -> dict:
    cfg = _V21_HARD_CONFIG(path)
    soft = cfg["wip"].get("completionSoftThrottle", 4)
    hard = cfg["wip"].get("completionHardThrottle", 8)
    if not isinstance(soft, int) or not 1 <= soft <= 100:
        raise _base.core.ControlError(f"{path}: invalid completionSoftThrottle")
    if not isinstance(hard, int) or not soft < hard <= 100:
        raise _base.core.ControlError(f"{path}: invalid completionHardThrottle")
    cfg["wip"]["completionSoftThrottle"] = soft
    cfg["wip"]["completionHardThrottle"] = hard
    activated = cfg["scheduler"].get("v22ActivatedAt")
    if activated is not None:
        if not isinstance(activated, str):
            raise _base.core.ControlError(f"{path}: scheduler.v22ActivatedAt must be timestamp string")
        _base.core.parse_time(activated)
    return cfg


_base.hard_config = hard_config


def _is_completion_lane(lane: dict) -> bool:
    return "completion" in set(lane.get("tags", []))


def _completion_backlog(lanes: dict, claims: list, now) -> tuple[int, int, int]:
    pr_numbers = {
        claim.pr for claim in claims
        if claim.pr is not None and not claim.is_stale(now)
    }
    closing_lanes = sum(
        1 for lane in lanes.values()
        if lane["state"] in _COMPLETION_STATES and not _is_completion_lane(lane)
    )
    return max(len(pr_numbers), closing_lanes), len(pr_numbers), closing_lanes


def _completion_pressure(cfg: dict, backlog: int) -> str:
    if backlog >= cfg["wip"]["completionHardThrottle"]:
        return "HARD"
    if backlog >= cfg["wip"]["completionSoftThrottle"]:
        return "SOFT"
    return "NORMAL"


def _slot_flags(lane: dict, slot_id: str, role: str) -> tuple[bool, bool]:
    text = f"{slot_id} {role}".lower()
    completion = (
        _is_completion_lane(lane)
        or lane["state"] in _COMPLETION_STATES
        or any(token in text for token in ("review", "integrat", "reconcile", "ci-sheriff", "recovery"))
    )
    creation = (
        slot_id == "primary"
        or slot_id == "test-adversary"
        or slot_id.startswith("mine-")
        or "capacity" in text
        or ("audit" in text and lane["state"] == "READY" and not _is_completion_lane(lane))
    )
    return completion, creation


def ready_slots(cfg, lanes, resources, claims, rclaims, now, health=None):
    # V2.1 counted every REVIEW lane toward its legacy throttle. V2.2 completion
    # queues themselves must not permanently deadlock creation after the product
    # backlog drains, so derive the candidate set with that legacy threshold lifted
    # and apply completion pressure explicitly below. Existing primary-WIP and
    # integration/red-main gates remain active in the preserved V2.1 wrapper.
    relaxed = {**cfg, "wip": {**cfg["wip"], "reviewBacklogThrottle": 100}}
    candidates = _V21_READY_SLOTS(relaxed, lanes, resources, claims, rclaims, now, health)
    backlog, _, _ = _completion_backlog(lanes, claims, now)
    pressure = _completion_pressure(cfg, backlog)
    output = []

    for item in candidates:
        lane = lanes[item.lane_id]
        completion, creation = _slot_flags(lane, item.slot_id, item.role)
        tags = set(lane.get("tags", []))
        override = bool(tags & {"red-main", "control-repair"})

        if pressure == "NORMAL" and _is_completion_lane(lane):
            continue
        if pressure == "HARD" and creation and not override and not _is_completion_lane(lane):
            continue

        score = item.score
        reason = item.reason
        if pressure == "SOFT":
            if completion:
                score += 2500
                reason += "; V2.2 completion pressure SOFT"
            elif creation:
                score -= 2000
                reason += "; V2.2 creation deprioritized"
        elif pressure == "HARD":
            if completion:
                score += 5000
                reason += "; V2.2 completion pressure HARD"
            elif not override:
                score -= 3000
        if "integrat" in f"{item.slot_id} {item.role}".lower():
            score += 700 if pressure != "NORMAL" else 0

        output.append(_base.core.ReadySlot(
            item.lane_id, item.slot_id, item.role, score, reason,
            item.resources, item.write_scopes,
        ))

    return sorted(output, key=lambda s: (-s.score, s.lane_id, s.slot_id))


_base.ready_slots = ready_slots


def render_board(root: Path, now) -> dict:
    board = _V21_RENDER_BOARD(root, now)
    cfg, lanes, _, claims, _, _, _ = read_tree(root)
    backlog, pr_claims, closing_lanes = _completion_backlog(lanes, claims, now)
    pressure = _completion_pressure(cfg, backlog)
    board["summary"]["outstandingPRClaims"] = pr_claims
    board["summary"]["completionBacklog"] = backlog
    board["summary"]["completionPressure"] = pressure
    board["summary"]["creationThrottle"] = pressure == "HARD"
    board["metrics"]["outstandingPRClaims"] = pr_claims
    board["metrics"]["completionStateLanes"] = closing_lanes
    board["metrics"]["completionBacklog"] = backlog
    board["metrics"]["completionPressure"] = pressure
    board["metrics"]["creationThrottle"] = pressure == "HARD"
    return board


_base.render_board = render_board


def _created_after_activation(pr: dict, cfg: dict) -> bool:
    activated = cfg["scheduler"].get("v22ActivatedAt")
    if activated is None:
        return False
    created = pr.get("created_at")
    if not isinstance(created, str):
        raise _base.core.ControlError("V2.2 controlled PR requires pull_request.created_at")
    return _base.core.parse_time(created) >= _base.core.parse_time(activated)


def _self_review(body: str, head_sha: str) -> None:
    values = _SELF_REVIEW_RE.findall(body or "")
    heads = _SELF_REVIEW_HEAD_RE.findall(body or "")
    if len(values) != 1 or values[0] != "PASS":
        raise _base.core.ControlError("V2.2 controlled PR requires exactly one Swarm-Self-Review: PASS")
    if len(heads) != 1 or heads[0] != head_sha:
        raise _base.core.ControlError("V2.2 self-review must bind the exact PR head SHA")


def _review_risk(lane: dict, changed: list[str]) -> str:
    tags = set(lane.get("tags", []))
    critical_prefixes = (
        "tools/swarm/", ".github/workflows/", "src/shared/Reality/",
        "src/server/Bootstrap.server.luau", "src/client/Bootstrap.client.luau",
    )
    critical_tokens = ("authority", "multiplayer", "persistence", "identity", "schema", "trust")
    if tags & _CRITICAL_TAGS:
        return "CRITICAL"
    for path in changed:
        lower = path.lower()
        if path.startswith(critical_prefixes) or any(token in lower for token in critical_tokens):
            return "CRITICAL"
    if changed and all(path.startswith("Docs/") or path.startswith("tests/") for path in changed):
        return "LOW"
    return "STANDARD"


def _independent_review(events: list[dict], lane_id: str, worker_id: str, pr_number: int, head_sha: str, risk: str) -> None:
    if risk == "LOW":
        return
    allowed_depths = {"FULL"} if risk == "CRITICAL" else {"SPOT", "FULL"}
    for event in events:
        if event.get("eventType") != "REVIEW_RESULT":
            continue
        if event.get("fromWorker") == worker_id:
            continue
        if event.get("laneId") != lane_id and lane_id not in event.get("affects", []):
            continue
        meta = event.get("metadata")
        if not isinstance(meta, dict):
            continue
        if meta.get("pr") != pr_number or meta.get("headSha") != head_sha or meta.get("verdict") != "APPROVE":
            continue
        if meta.get("depth") in allowed_depths:
            return
    depth = "FULL" if risk == "CRITICAL" else "SPOT or FULL"
    raise _base.core.ControlError(
        f"V2.2 {risk.lower()}-risk PR requires independent exact-head {depth} review"
    )


def pr_check(root: Path, event_path: Path, changed_path: Path, now) -> dict:
    result = _V21_PR_CHECK(root, event_path, changed_path, now)
    cfg, lanes, _, _, _, _, events = read_tree(root)
    event = _base.core.load_json(event_path, 4_000_000)
    pr = event.get("pull_request")
    if not isinstance(pr, dict) or not _created_after_activation(pr, cfg):
        result["reviewPolicy"] = "V2.1_GRANDFATHERED"
        return result

    body = pr.get("body") or ""
    head_sha = pr.get("head", {}).get("sha")
    if not isinstance(head_sha, str) or not re.fullmatch(r"[a-f0-9]{40}", head_sha):
        raise _base.core.ControlError("V2.2 controlled PR requires exact pull_request.head.sha")
    _self_review(body, head_sha)

    lane_id = result["laneId"]
    worker_id = result["workerId"]
    changed = [line.strip() for line in changed_path.read_text(encoding="utf-8").splitlines() if line.strip()]
    risk = _review_risk(lanes[lane_id], changed)
    _independent_review(events, lane_id, worker_id, pr.get("number"), head_sha, risk)
    result["reviewPolicy"] = f"V2.2_{risk}"
    result["selfReviewHead"] = head_sha
    return result


_base.pr_check = pr_check


def dashboard(board: dict) -> str:
    summary = board["summary"]
    out = [
        "# UNRENDERED Swarm Control Plane", "", f"Generated: `{board['generatedAt']}`", "",
        f"Canonical main: **{board['mainHealth']['status']}** `{board['mainHealth']['headSha'] or 'unknown'}`", "",
        f"State digest: `{board['stateDigest']}`", "", "## Summary", "",
        f"- ready slots: **{summary['readySlots']}**", f"- active claims: **{summary['activeClaims']}**",
        f"- stale claims: **{summary['staleClaims']}**", f"- blocked-external lanes: **{summary['blockedExternalLanes']}**",
        f"- outstanding PR claims: **{summary.get('outstandingPRClaims', 0)}**",
        f"- completion backlog: **{summary.get('completionBacklog', 0)}**",
        f"- completion pressure: **{summary.get('completionPressure', 'NORMAL')}**",
        f"- new creation throttle: **{'ON' if summary.get('creationThrottle') else 'OFF'}**",
        "", "## Ready slots", "",
    ]
    out += [
        f"- `{x['laneId']}/{x['slotId']}` — **{x['role']}** — score {x['score']} — {x['reason']}"
        for x in board["readySlots"][:30]
    ] or [
        "_No ordinary ready slot is materialized. GREEN is not completion: re-read live state and exhaust completion/review/integration → stale recovery → active-Epic backfill before idling._"
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
