#!/usr/bin/env python3
"""UNRENDERED Swarm Control Plane V2.

Pure-stdlib deterministic validator/scheduler for GitHub-native swarm state.

Correctness boundary:
- GitHub file creation / SHA-conditional update provides atomic ownership.
- This module validates state, derives ready slots, renders observability, and
  enforces PR metadata/scope against the current control branch snapshot.
- It never executes request-supplied commands or code.
"""

from __future__ import annotations

import argparse
import fnmatch
import json
import re
import sys
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any, Iterable

SCHEMA_VERSION = 1
LANE_STATES = {
    "PROPOSED", "READY", "CLAIMED", "IMPLEMENTING", "BLOCKED", "REVIEW",
    "NEEDS_CHANGES", "INTEGRATION_READY", "MERGED", "VERIFYING", "DONE",
    "SUPERSEDED", "CANCELLED", "BLOCKED_EXTERNAL", "LOCKED",
}
TERMINAL_LANE_STATES = {"DONE", "SUPERSEDED", "CANCELLED"}
BLOCKING_LANE_STATES = {"BLOCKED", "BLOCKED_EXTERNAL", "LOCKED", "SUPERSEDED", "CANCELLED"}
RESOURCE_STATES = {"AVAILABLE", "BLOCKED_EXTERNAL", "MAINTENANCE"}
EVENT_TYPES = {
    "FINDING", "BLOCKER", "QUESTION", "ANSWER", "DECISION",
    "DEPENDENCY_DISCOVERED", "REVIEW_REQUEST", "REVIEW_RESULT", "HANDOFF",
    "SCOPE_CHANGE", "SUPERSEDED", "EVIDENCE_RESULT", "EXTERNAL_BLOCKER",
    "INTEGRATION_RESULT", "RECOVERY",
}
CANONICAL_WORKER_STATUSES = {"WORKING", "WAITING", "REVIEWING", "INTEGRATING", "BLOCKED", "IDLE", "STOPPED"}
LEGACY_WORKER_STATUS_ALIASES = {"ACTIVE", "CLAIMING", "DONE"}
WORKER_STATUSES = CANONICAL_WORKER_STATUSES | LEGACY_WORKER_STATUS_ALIASES
REVIEW_VERDICTS = {"APPROVE", "REQUEST_CHANGES", "BLOCK", "SUPERSEDE"}
REVIEW_RESULT_FIELDS = {"pr", "headSha", "verdict"}
LANE_ID_RE = re.compile(r"^[A-Z0-9][A-Z0-9._-]{2,63}$")
SLOT_ID_RE = re.compile(r"^[a-z0-9][a-z0-9._-]{1,47}$")
WORKER_ID_RE = re.compile(r"^sol-[0-9]{8}-[a-z0-9]{4,16}$")
TOKEN_RE = re.compile(r"^[a-f0-9]{16,64}$")
BRANCH_RE = re.compile(r"^agent/[A-Za-z0-9._/-]{3,160}$")
FORBIDDEN_CONTROL_KEYS = {
    "command", "commands", "shell", "bash", "script", "python", "luau", "lua",
    "applescript", "executable", "localPath", "filesystemPath",
}
ALLOWED_PR_METADATA = {
    "Swarm-Lane", "Swarm-Slot", "Swarm-Worker", "Swarm-Claim-Token", "Control-Schema",
}
META_LINE_RE = re.compile(
    r"^(Swarm-Lane|Swarm-Slot|Swarm-Worker|Swarm-Claim-Token|Control-Schema):\s*(\S+)\s*$",
    re.MULTILINE,
)


class ControlError(ValueError):
    pass


@dataclass(frozen=True)
class ActiveClaim:
    path: Path
    lane_id: str
    slot_id: str
    worker_id: str
    claim_token: str
    heartbeat_at: datetime
    lease_seconds: int
    branch: str | None
    pr: int | None
    generation: int
    resources: tuple[str, ...]

    def expires_at(self) -> datetime:
        return self.heartbeat_at + timedelta(seconds=self.lease_seconds)

    def is_stale(self, now: datetime) -> bool:
        return now >= self.expires_at()


@dataclass(frozen=True)
class ActiveResourceClaim:
    path: Path
    resource_id: str
    worker_id: str
    lane_id: str
    claim_token: str
    heartbeat_at: datetime
    lease_seconds: int
    generation: int

    def expires_at(self) -> datetime:
        return self.heartbeat_at + timedelta(seconds=self.lease_seconds)

    def is_stale(self, now: datetime) -> bool:
        return now >= self.expires_at()


@dataclass(frozen=True)
class ReadySlot:
    lane_id: str
    slot_id: str
    role: str
    score: int
    reason: str
    resources: tuple[str, ...]
    write_scopes: tuple[str, ...]


def parse_time(value: str) -> datetime:
    if not isinstance(value, str):
        raise ControlError("timestamp must be a string")
    normalized = value[:-1] + "+00:00" if value.endswith("Z") else value
    try:
        dt = datetime.fromisoformat(normalized)
    except ValueError as exc:
        raise ControlError(f"invalid ISO-8601 timestamp: {value}") from exc
    if dt.tzinfo is None:
        raise ControlError("timestamp must include timezone")
    return dt.astimezone(timezone.utc)


def now_utc() -> datetime:
    return datetime.now(timezone.utc)


def load_json(path: Path, max_bytes: int = 128_000) -> dict[str, Any]:
    if not path.is_file():
        raise ControlError(f"missing JSON file: {path}")
    size = path.stat().st_size
    if size <= 0 or size > max_bytes:
        raise ControlError(f"invalid JSON size for {path}: {size}")
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        raise ControlError(f"invalid JSON {path}: {exc}") from exc
    if not isinstance(data, dict):
        raise ControlError(f"top-level JSON object required: {path}")
    assert_no_executable_fields(data, path)
    return data


def assert_no_executable_fields(value: Any, path: Path, trail: tuple[str, ...] = ()) -> None:
    if isinstance(value, dict):
        for key, nested in value.items():
            if not isinstance(key, str):
                raise ControlError(f"non-string key in {path}")
            if key in FORBIDDEN_CONTROL_KEYS:
                where = ".".join((*trail, key))
                raise ControlError(f"forbidden executable-looking control key {where} in {path}")
            assert_no_executable_fields(nested, path, (*trail, key))
    elif isinstance(value, list):
        for idx, nested in enumerate(value):
            assert_no_executable_fields(nested, path, (*trail, str(idx)))
    elif isinstance(value, str):
        if "\x00" in value:
            raise ControlError(f"NUL byte in {path}")
        if len(value) > 8000:
            raise ControlError(f"oversized string in {path}")


def require_schema(obj: dict[str, Any], path: Path) -> None:
    if obj.get("schemaVersion") != SCHEMA_VERSION:
        raise ControlError(f"{path}: schemaVersion must be {SCHEMA_VERSION}")


def require_keys(obj: dict[str, Any], required: set[str], allowed: set[str], path: Path) -> None:
    missing = required - obj.keys()
    unknown = obj.keys() - allowed
    if missing:
        raise ControlError(f"{path}: missing keys {sorted(missing)}")
    if unknown:
        raise ControlError(f"{path}: unknown keys {sorted(unknown)}")


def ensure_identifier(value: Any, regex: re.Pattern[str], label: str, path: Path) -> str:
    if not isinstance(value, str) or not regex.fullmatch(value):
        raise ControlError(f"{path}: invalid {label}: {value!r}")
    return value


def validate_config(path: Path) -> dict[str, Any]:
    obj = load_json(path)
    require_schema(obj, path)
    require_keys(
        obj,
        {"schemaVersion", "controlBranch", "leaseDefaults", "wip", "scheduler", "protectedScopes"},
        {"schemaVersion", "controlBranch", "leaseDefaults", "wip", "scheduler", "protectedScopes", "description"},
        path,
    )
    if obj["controlBranch"] != "swarm-control":
        raise ControlError(f"{path}: controlBranch must be swarm-control")
    leases = obj["leaseDefaults"]
    if not isinstance(leases, dict):
        raise ControlError(f"{path}: leaseDefaults must be object")
    for role, seconds in leases.items():
        if not isinstance(role, str) or not isinstance(seconds, int) or not 300 <= seconds <= 14_400:
            raise ControlError(f"{path}: invalid lease default {role}={seconds!r}")
    wip = obj["wip"]
    if not isinstance(wip, dict):
        raise ControlError(f"{path}: wip must be object")
    for key in ("maxMajorEpics", "maxPrimaryImplementationLanes", "reviewBacklogThrottle"):
        if not isinstance(wip.get(key), int) or not 1 <= wip[key] <= 100:
            raise ControlError(f"{path}: invalid WIP setting {key}")
    protected = obj["protectedScopes"]
    if not isinstance(protected, list):
        raise ControlError(f"{path}: protectedScopes must be list")
    for entry in protected:
        if not isinstance(entry, dict) or set(entry) != {"pattern", "resource"}:
            raise ControlError(f"{path}: protectedScopes entries require pattern/resource")
        if not isinstance(entry["pattern"], str) or not 1 <= len(entry["pattern"]) <= 200:
            raise ControlError(f"{path}: invalid protected scope pattern")
        ensure_identifier(entry["resource"], LANE_ID_RE, "protected resource", path)
    if not isinstance(obj["scheduler"], dict):
        raise ControlError(f"{path}: scheduler must be object")
    return obj


def validate_lane(path: Path) -> dict[str, Any]:
    obj = load_json(path)
    require_schema(obj, path)
    required = {
        "schemaVersion", "laneId", "epicId", "title", "objective", "priority", "state",
        "mode", "dependencies", "writeScopes", "resources", "slots", "acceptance",
    }
    allowed = required | {"issue", "pr", "notes", "blockers", "tags"}
    require_keys(obj, required, allowed, path)
    lane_id = ensure_identifier(obj["laneId"], LANE_ID_RE, "laneId", path)
    if path.stem != lane_id:
        raise ControlError(f"{path}: filename must equal laneId")
    ensure_identifier(obj["epicId"], LANE_ID_RE, "epicId", path)
    if not isinstance(obj["title"], str) or not 1 <= len(obj["title"]) <= 140:
        raise ControlError(f"{path}: invalid title")
    if not isinstance(obj["objective"], str) or not 1 <= len(obj["objective"]) <= 2000:
        raise ControlError(f"{path}: invalid objective")
    if not isinstance(obj["priority"], int) or not 0 <= obj["priority"] <= 10_000:
        raise ControlError(f"{path}: priority out of range")
    if obj["state"] not in LANE_STATES:
        raise ControlError(f"{path}: invalid state {obj['state']}")
    if obj["mode"] not in {"exclusive", "tournament"}:
        raise ControlError(f"{path}: invalid mode")
    deps = obj["dependencies"]
    if not isinstance(deps, list):
        raise ControlError(f"{path}: dependencies must be list")
    for dep in deps:
        if not isinstance(dep, dict) or set(dep) != {"laneId", "acceptableStates"}:
            raise ControlError(f"{path}: malformed dependency")
        ensure_identifier(dep["laneId"], LANE_ID_RE, "dependency laneId", path)
        states = dep["acceptableStates"]
        if not isinstance(states, list) or not states or any(s not in LANE_STATES for s in states):
            raise ControlError(f"{path}: invalid dependency acceptableStates")
    for key in ("writeScopes", "resources", "acceptance"):
        value = obj[key]
        if not isinstance(value, list) or any(not isinstance(x, str) or not x for x in value):
            raise ControlError(f"{path}: {key} must be non-empty strings")
    slots = obj["slots"]
    if not isinstance(slots, list) or not slots:
        raise ControlError(f"{path}: slots must be non-empty list")
    seen: set[str] = set()
    primary_count = 0
    for slot in slots:
        if not isinstance(slot, dict):
            raise ControlError(f"{path}: malformed slot")
        require_keys(
            slot,
            {"slotId", "role", "exclusive", "availableWhen"},
            {"slotId", "role", "exclusive", "availableWhen", "requiresIndependentFrom", "priorityBoost", "writeScopes"},
            path,
        )
        sid = ensure_identifier(slot["slotId"], SLOT_ID_RE, "slotId", path)
        if sid in seen:
            raise ControlError(f"{path}: duplicate slotId {sid}")
        seen.add(sid)
        if not isinstance(slot["role"], str) or not 1 <= len(slot["role"]) <= 80:
            raise ControlError(f"{path}: invalid slot role")
        if not isinstance(slot["exclusive"], bool):
            raise ControlError(f"{path}: slot exclusive must be bool")
        if not isinstance(slot["availableWhen"], list) or not slot["availableWhen"] or any(
            state not in LANE_STATES for state in slot["availableWhen"]
        ):
            raise ControlError(f"{path}: invalid availableWhen")
        if sid == "primary":
            primary_count += 1
        if "priorityBoost" in slot and (
            not isinstance(slot["priorityBoost"], int) or not -1000 <= slot["priorityBoost"] <= 1000
        ):
            raise ControlError(f"{path}: invalid priorityBoost")
        if "writeScopes" in slot and (
            not isinstance(slot["writeScopes"], list)
            or any(not isinstance(x, str) or not x for x in slot["writeScopes"])
        ):
            raise ControlError(f"{path}: invalid slot writeScopes")
    if obj["mode"] == "exclusive" and primary_count > 1:
        raise ControlError(f"{path}: exclusive lane may define at most one primary")
    return obj


def validate_resource(path: Path) -> dict[str, Any]:
    obj = load_json(path)
    require_schema(obj, path)
    require_keys(
        obj,
        {"schemaVersion", "resourceId", "state", "mode", "order", "capacity", "description"},
        {"schemaVersion", "resourceId", "state", "mode", "order", "capacity", "description", "blockedReason"},
        path,
    )
    rid = ensure_identifier(obj["resourceId"], LANE_ID_RE, "resourceId", path)
    if path.stem != rid:
        raise ControlError(f"{path}: filename must equal resourceId")
    if obj["state"] not in RESOURCE_STATES:
        raise ControlError(f"{path}: invalid resource state")
    if obj["mode"] not in {"exclusive", "shared"}:
        raise ControlError(f"{path}: invalid resource mode")
    if not isinstance(obj["order"], int) or not 0 <= obj["order"] <= 10_000:
        raise ControlError(f"{path}: invalid resource order")
    if not isinstance(obj["capacity"], int) or not 1 <= obj["capacity"] <= 64:
        raise ControlError(f"{path}: invalid resource capacity")
    if obj["mode"] == "exclusive" and obj["capacity"] != 1:
        raise ControlError(f"{path}: exclusive resource capacity must equal 1")
    return obj


def validate_claim(path: Path) -> ActiveClaim:
    obj = load_json(path, max_bytes=32_000)
    require_schema(obj, path)
    required = {
        "schemaVersion", "laneId", "slotId", "workerId", "claimToken", "claimedAt",
        "heartbeatAt", "leaseSeconds", "generation", "resources",
    }
    allowed = required | {"branch", "pr", "takeoverOf", "notes"}
    require_keys(obj, required, allowed, path)
    lane = ensure_identifier(obj["laneId"], LANE_ID_RE, "laneId", path)
    slot = ensure_identifier(obj["slotId"], SLOT_ID_RE, "slotId", path)
    worker = ensure_identifier(obj["workerId"], WORKER_ID_RE, "workerId", path)
    token = ensure_identifier(obj["claimToken"], TOKEN_RE, "claimToken", path)
    claimed = parse_time(obj["claimedAt"])
    heartbeat = parse_time(obj["heartbeatAt"])
    if heartbeat < claimed:
        raise ControlError(f"{path}: heartbeat before claim")
    lease = obj["leaseSeconds"]
    if not isinstance(lease, int) or not 300 <= lease <= 14_400:
        raise ControlError(f"{path}: leaseSeconds out of bounds")
    gen = obj["generation"]
    if not isinstance(gen, int) or not 1 <= gen <= 1_000_000:
        raise ControlError(f"{path}: invalid generation")
    branch = obj.get("branch")
    if branch is not None and (not isinstance(branch, str) or not BRANCH_RE.fullmatch(branch)):
        raise ControlError(f"{path}: invalid branch")
    pr = obj.get("pr")
    if pr is not None and (not isinstance(pr, int) or pr <= 0):
        raise ControlError(f"{path}: invalid pr")
    resources = obj["resources"]
    if not isinstance(resources, list) or any(not isinstance(x, str) or not LANE_ID_RE.fullmatch(x) for x in resources):
        raise ControlError(f"{path}: invalid resources")
    return ActiveClaim(path, lane, slot, worker, token, heartbeat, lease, branch, pr, gen, tuple(resources))


def validate_resource_claim(path: Path) -> ActiveResourceClaim:
    obj = load_json(path, max_bytes=24_000)
    require_schema(obj, path)
    required = {
        "schemaVersion", "resourceId", "workerId", "laneId", "claimToken",
        "acquiredAt", "heartbeatAt", "leaseSeconds", "generation",
    }
    allowed = required | {"notes"}
    require_keys(obj, required, allowed, path)
    rid = ensure_identifier(obj["resourceId"], LANE_ID_RE, "resourceId", path)
    worker = ensure_identifier(obj["workerId"], WORKER_ID_RE, "workerId", path)
    lane = ensure_identifier(obj["laneId"], LANE_ID_RE, "laneId", path)
    token = ensure_identifier(obj["claimToken"], TOKEN_RE, "claimToken", path)
    acquired = parse_time(obj["acquiredAt"])
    heartbeat = parse_time(obj["heartbeatAt"])
    if heartbeat < acquired:
        raise ControlError(f"{path}: heartbeat before resource acquisition")
    lease = obj["leaseSeconds"]
    if not isinstance(lease, int) or not 300 <= lease <= 14_400:
        raise ControlError(f"{path}: leaseSeconds out of bounds")
    generation = obj["generation"]
    if not isinstance(generation, int) or not 1 <= generation <= 1_000_000:
        raise ControlError(f"{path}: invalid generation")
    return ActiveResourceClaim(path, rid, worker, lane, token, heartbeat, lease, generation)


def validate_worker(path: Path) -> dict[str, Any]:
    obj = load_json(path, max_bytes=32_000)
    require_schema(obj, path)
    required = {"schemaVersion", "workerId", "model", "status", "startedAt", "lastSeenAt"}
    allowed = required | {"laneId", "slotId", "branch", "notes"}
    require_keys(obj, required, allowed, path)
    wid = ensure_identifier(obj["workerId"], WORKER_ID_RE, "workerId", path)
    if path.stem != wid:
        raise ControlError(f"{path}: filename must equal workerId")
    if obj["model"] != "gpt-5.6-sol":
        raise ControlError(f"{path}: worker model must be gpt-5.6-sol")
    status = obj["status"]
    if not isinstance(status, str) or status not in WORKER_STATUSES:
        raise ControlError(f"{path}: invalid worker status")
    started, seen = parse_time(obj["startedAt"]), parse_time(obj["lastSeenAt"])
    if seen < started:
        raise ControlError(f"{path}: lastSeenAt before startedAt")
    return obj


def validate_event(path: Path) -> dict[str, Any]:
    obj = load_json(path, max_bytes=48_000)
    require_schema(obj, path)
    required = {"schemaVersion", "eventId", "timestamp", "fromWorker", "eventType", "summary", "affects"}
    allowed = required | {"laneId", "severity", "evidence", "toWorker", "metadata"}
    if obj.get("eventType") == "REVIEW_RESULT":
        allowed |= REVIEW_RESULT_FIELDS
    require_keys(obj, required, allowed, path)
    if not isinstance(obj["eventId"], str) or not re.fullmatch(r"evt-[a-z0-9-]{12,96}", obj["eventId"]):
        raise ControlError(f"{path}: invalid eventId")
    parse_time(obj["timestamp"])
    ensure_identifier(obj["fromWorker"], WORKER_ID_RE, "fromWorker", path)
    if obj["eventType"] not in EVENT_TYPES:
        raise ControlError(f"{path}: invalid eventType")
    if not isinstance(obj["summary"], str) or not 1 <= len(obj["summary"]) <= 4000:
        raise ControlError(f"{path}: invalid summary")
    if not isinstance(obj["affects"], list) or any(not isinstance(x, str) or not LANE_ID_RE.fullmatch(x) for x in obj["affects"]):
        raise ControlError(f"{path}: invalid affects")
    if "laneId" in obj:
        ensure_identifier(obj["laneId"], LANE_ID_RE, "laneId", path)
    if "evidence" in obj and (
        not isinstance(obj["evidence"], list)
        or len(obj["evidence"]) > 32
        or any(not isinstance(x, str) or len(x) > 1000 for x in obj["evidence"])
    ):
        raise ControlError(f"{path}: invalid evidence")
    typed_review_fields = REVIEW_RESULT_FIELDS & obj.keys()
    if typed_review_fields:
        if typed_review_fields != REVIEW_RESULT_FIELDS:
            raise ControlError(f"{path}: typed REVIEW_RESULT requires pr, headSha, and verdict together")
        if type(obj["pr"]) is not int or obj["pr"] <= 0:
            raise ControlError(f"{path}: invalid REVIEW_RESULT pr")
        if not isinstance(obj["headSha"], str) or not re.fullmatch(r"[a-f0-9]{40}", obj["headSha"]):
            raise ControlError(f"{path}: invalid REVIEW_RESULT headSha")
        verdict = obj["verdict"]
        if not isinstance(verdict, str) or verdict not in REVIEW_VERDICTS:
            raise ControlError(f"{path}: invalid REVIEW_RESULT verdict")
    return obj


def read_tree(root: Path) -> tuple[
    dict[str, Any], dict[str, dict], dict[str, dict], list[ActiveClaim],
    list[ActiveResourceClaim], dict[str, dict], list[dict],
]:
    config = validate_config(root / "config.json")
    lanes: dict[str, dict] = {}
    for path in sorted((root / "lanes").glob("*.json")):
        lane = validate_lane(path)
        if lane["laneId"] in lanes:
            raise ControlError(f"duplicate lane {lane['laneId']}")
        lanes[lane["laneId"]] = lane
    resources: dict[str, dict] = {}
    for path in sorted((root / "resources").glob("*.json")):
        res = validate_resource(path)
        if res["resourceId"] in resources:
            raise ControlError(f"duplicate resource {res['resourceId']}")
        resources[res["resourceId"]] = res
    claims = [validate_claim(p) for p in sorted((root / "claims").glob("*/*.json"))]
    resource_claim_paths = list((root / "resource-claims").glob("*.json"))
    resource_claim_paths += list((root / "resource-claims").glob("*/*.json"))
    resource_claims = [validate_resource_claim(p) for p in sorted(resource_claim_paths)]
    workers = {p.stem: validate_worker(p) for p in sorted((root / "workers").glob("*.json"))}
    events: list[dict] = []
    for path in sorted((root / "events").glob("*/*.json")):
        events.append(validate_event(path))
    return config, lanes, resources, claims, resource_claims, workers, events


def dependency_cycles(lanes: dict[str, dict]) -> list[list[str]]:
    graph = {lane_id: [d["laneId"] for d in lane["dependencies"] if d["laneId"] in lanes] for lane_id, lane in lanes.items()}
    visiting: set[str] = set()
    visited: set[str] = set()
    stack: list[str] = []
    cycles: list[list[str]] = []

    def dfs(node: str) -> None:
        if node in visiting:
            idx = stack.index(node)
            cycles.append(stack[idx:] + [node])
            return
        if node in visited:
            return
        visiting.add(node)
        stack.append(node)
        for dep in graph[node]:
            dfs(dep)
        stack.pop()
        visiting.remove(node)
        visited.add(node)

    for node in graph:
        dfs(node)
    return cycles


def validate_relations(
    lanes: dict[str, dict], resources: dict[str, dict], claims: list[ActiveClaim],
    resource_claims: list[ActiveResourceClaim], now: datetime,
) -> list[str]:
    errors: list[str] = []
    for lane_id, lane in lanes.items():
        for dep in lane["dependencies"]:
            if dep["laneId"] not in lanes:
                errors.append(f"{lane_id}: unknown dependency {dep['laneId']}")
        for rid in lane["resources"]:
            if rid not in resources:
                errors.append(f"{lane_id}: unknown resource {rid}")
        if lane["state"] == "DONE" and any(
            lanes.get(dep["laneId"], {}).get("state") not in dep["acceptableStates"] for dep in lane["dependencies"]
        ):
            errors.append(f"{lane_id}: DONE while dependency is unsatisfied")
    for cyc in dependency_cycles(lanes):
        errors.append("dependency cycle: " + " -> ".join(cyc))

    seen_slot: dict[tuple[str, str], ActiveClaim] = {}
    for claim in claims:
        if claim.lane_id not in lanes:
            errors.append(f"{claim.path}: claim references unknown lane")
            continue
        lane = lanes[claim.lane_id]
        valid_slots = {s["slotId"] for s in lane["slots"]}
        if claim.slot_id not in valid_slots:
            errors.append(f"{claim.path}: claim references unknown slot")
        for rid in claim.resources:
            if rid not in resources:
                errors.append(f"{claim.path}: claim references unknown resource {rid}")
        key = (claim.lane_id, claim.slot_id)
        if not claim.is_stale(now) and key in seen_slot:
            errors.append(f"duplicate active claim for {claim.lane_id}/{claim.slot_id}")
        elif not claim.is_stale(now):
            seen_slot[key] = claim

    active_resource_users: dict[str, list[ActiveResourceClaim]] = {}
    for rclaim in resource_claims:
        if rclaim.resource_id not in resources:
            errors.append(f"{rclaim.path}: resource claim references unknown resource")
            continue
        if rclaim.lane_id not in lanes:
            errors.append(f"{rclaim.path}: resource claim references unknown lane")
            continue
        if not rclaim.is_stale(now):
            active_resource_users.setdefault(rclaim.resource_id, []).append(rclaim)
    for rid, users in active_resource_users.items():
        res = resources[rid]
        if len(users) > res["capacity"]:
            errors.append(f"resource {rid}: active users {len(users)} exceed capacity {res['capacity']}")
        if res["mode"] == "exclusive" and len(users) > 1:
            errors.append(f"resource {rid}: exclusive resource has multiple active owners")
    active_rkeys = {
        (rc.resource_id, rc.worker_id, rc.lane_id, rc.claim_token)
        for rc in resource_claims if not rc.is_stale(now)
    }
    for claim in claims:
        if claim.is_stale(now):
            continue
        orders = [resources[r]["order"] for r in claim.resources if r in resources]
        if orders != sorted(orders):
            errors.append(f"{claim.path}: resource list must follow deterministic acquisition order")
        for rid in claim.resources:
            if (rid, claim.worker_id, claim.lane_id, claim.claim_token) not in active_rkeys:
                errors.append(f"{claim.path}: missing matching active resource lease for {rid}")
    active_by_lane_slot = {(c.lane_id, c.slot_id): c for c in claims if not c.is_stale(now)}
    for lane_id, lane in lanes.items():
        for slot in lane["slots"]:
            required = slot.get("requiresIndependentFrom")
            if not required:
                continue
            current = active_by_lane_slot.get((lane_id, slot["slotId"]))
            primary = active_by_lane_slot.get((lane_id, required))
            if current and primary and current.worker_id == primary.worker_id:
                errors.append(f"{lane_id}/{slot['slotId']}: reviewer/support worker must differ from {required}")
    return errors


def dependencies_satisfied(lane: dict, lanes: dict[str, dict]) -> tuple[bool, str]:
    for dep in lane["dependencies"]:
        target = lanes.get(dep["laneId"])
        if target is None:
            return False, f"unknown dependency {dep['laneId']}"
        if target["state"] not in dep["acceptableStates"]:
            return False, f"waiting for {dep['laneId']} ({target['state']})"
    return True, "dependencies satisfied"


def resources_available(
    lane: dict, resources: dict[str, dict], resource_claims: list[ActiveResourceClaim], now: datetime,
) -> tuple[bool, str]:
    active_usage: dict[str, int] = {}
    for claim in resource_claims:
        if claim.is_stale(now):
            continue
        active_usage[claim.resource_id] = active_usage.get(claim.resource_id, 0) + 1
    for rid in lane["resources"]:
        res = resources.get(rid)
        if not res:
            return False, f"unknown resource {rid}"
        if res["state"] != "AVAILABLE":
            return False, f"resource {rid} is {res['state']}"
        if active_usage.get(rid, 0) >= res["capacity"]:
            return False, f"resource {rid} at capacity"
    return True, "resources available"


def derive_ready_slots(
    config: dict[str, Any], lanes: dict[str, dict], resources: dict[str, dict],
    claims: list[ActiveClaim], resource_claims: list[ActiveResourceClaim], now: datetime,
) -> list[ReadySlot]:
    active_claim_by_slot = {(c.lane_id, c.slot_id): c for c in claims if not c.is_stale(now)}
    review_backlog = sum(1 for lane in lanes.values() if lane["state"] in {"REVIEW", "NEEDS_CHANGES"})
    active_primary = sum(1 for c in active_claim_by_slot.values() if c.slot_id == "primary")
    throttle_implementation = (
        review_backlog >= config["wip"]["reviewBacklogThrottle"]
        or active_primary >= config["wip"]["maxPrimaryImplementationLanes"]
    )
    ready: list[ReadySlot] = []
    for lane_id, lane in lanes.items():
        if lane["state"] in TERMINAL_LANE_STATES | BLOCKING_LANE_STATES:
            continue
        deps_ok, deps_reason = dependencies_satisfied(lane, lanes)
        if not deps_ok:
            continue
        resources_ok, resource_reason = resources_available(lane, resources, resource_claims, now)
        for slot in lane["slots"]:
            if lane["state"] not in slot["availableWhen"]:
                continue
            key = (lane_id, slot["slotId"])
            if active_claim_by_slot.get(key):
                continue
            role = slot["role"]
            is_primary = slot["slotId"] == "primary"
            if is_primary and throttle_implementation:
                continue
            if is_primary and not resources_ok:
                continue
            boost = int(slot.get("priorityBoost", 0))
            score = int(lane["priority"]) + boost
            if lane["state"] == "REVIEW" and "review" in role.lower():
                score += 300
            if lane["state"] == "INTEGRATION_READY" and "integrat" in role.lower():
                score += 500
            fanout = sum(1 for other in lanes.values() for dep in other["dependencies"] if dep["laneId"] == lane_id)
            score += min(fanout * 50, 500)
            reason_parts = [deps_reason]
            if is_primary:
                reason_parts.append(resource_reason)
            if fanout:
                reason_parts.append(f"unblocks {fanout} downstream lane(s)")
            ready.append(ReadySlot(
                lane_id, slot["slotId"], role, score, "; ".join(reason_parts),
                tuple(lane["resources"]), tuple(lane["writeScopes"]),
            ))
    ready.sort(key=lambda s: (-s.score, s.lane_id, s.slot_id))
    return ready


def active_and_stale_claims(claims: Iterable[ActiveClaim], now: datetime) -> tuple[list[ActiveClaim], list[ActiveClaim]]:
    active, stale = [], []
    for claim in claims:
        (stale if claim.is_stale(now) else active).append(claim)
    return active, stale


def render_board(root: Path, now: datetime) -> dict[str, Any]:
    config, lanes, resources, claims, resource_claims, workers, events = read_tree(root)
    relation_errors = validate_relations(lanes, resources, claims, resource_claims, now)
    if relation_errors:
        raise ControlError("\n".join(relation_errors))
    active, stale = active_and_stale_claims(claims, now)
    ready = derive_ready_slots(config, lanes, resources, claims, resource_claims, now)
    board = {
        "schemaVersion": SCHEMA_VERSION,
        "generatedAt": now.isoformat(),
        "controlBranch": config["controlBranch"],
        "summary": {
            "lanes": len(lanes), "readySlots": len(ready), "activeClaims": len(active),
            "staleClaims": len(stale),
            "activeResourceClaims": sum(1 for c in resource_claims if not c.is_stale(now)),
            "workers": len(workers),
            "blockedExternalLanes": sum(1 for x in lanes.values() if x["state"] == "BLOCKED_EXTERNAL"),
        },
        "readySlots": [
            {"laneId": s.lane_id, "slotId": s.slot_id, "role": s.role, "score": s.score,
             "reason": s.reason, "resources": list(s.resources), "writeScopes": list(s.write_scopes)}
            for s in ready
        ],
        "activeClaims": [
            {"laneId": c.lane_id, "slotId": c.slot_id, "workerId": c.worker_id,
             "branch": c.branch, "pr": c.pr, "expiresAt": c.expires_at().isoformat()}
            for c in sorted(active, key=lambda c: (c.lane_id, c.slot_id))
        ],
        "staleClaims": [
            {"laneId": c.lane_id, "slotId": c.slot_id, "workerId": c.worker_id,
             "generation": c.generation, "expiredAt": c.expires_at().isoformat(),
             "branch": c.branch, "pr": c.pr}
            for c in sorted(stale, key=lambda c: (c.lane_id, c.slot_id))
        ],
        "blockedLanes": [
            {"laneId": lane_id, "state": lane["state"],
             "reason": (lane.get("blockers", ["explicit lane state"])[0] if lane.get("blockers") else dependencies_satisfied(lane, lanes)[1])}
            for lane_id, lane in sorted(lanes.items()) if lane["state"] in BLOCKING_LANE_STATES
        ],
        "resources": [
            {"resourceId": rid, "state": res["state"], "capacity": res["capacity"], "mode": res["mode"],
             "activeOwners": sum(1 for c in resource_claims if c.resource_id == rid and not c.is_stale(now))}
            for rid, res in sorted(resources.items(), key=lambda item: item[1]["order"])
        ],
        "recentEvents": events[-20:],
    }
    return board


def board_markdown(board: dict[str, Any]) -> str:
    out = [
        "# UNRENDERED Swarm Control Plane", "", f"Generated: `{board['generatedAt']}`", "",
        "## Summary", "", f"- ready slots: **{board['summary']['readySlots']}**",
        f"- active claims: **{board['summary']['activeClaims']}**",
        f"- stale claims: **{board['summary']['staleClaims']}**",
        f"- blocked-external lanes: **{board['summary']['blockedExternalLanes']}**", "", "## Ready slots", "",
    ]
    if not board["readySlots"]:
        out.append("_No currently runnable slot. Idle/review is preferable to duplicate implementation._")
    else:
        for slot in board["readySlots"][:30]:
            out.append(f"- `{slot['laneId']}/{slot['slotId']}` — **{slot['role']}** — score {slot['score']} — {slot['reason']}")
    out += ["", "## Active claims", ""]
    if not board["activeClaims"]:
        out.append("_None._")
    else:
        for claim in board["activeClaims"]:
            suffix = f" PR #{claim['pr']}" if claim["pr"] else ""
            out.append(f"- `{claim['laneId']}/{claim['slotId']}` → `{claim['workerId']}`{suffix}; lease to `{claim['expiresAt']}`")
    out += ["", "## Stale / takeover candidates", ""]
    if not board["staleClaims"]:
        out.append("_None._")
    else:
        for claim in board["staleClaims"]:
            out.append(f"- `{claim['laneId']}/{claim['slotId']}` from `{claim['workerId']}` expired `{claim['expiredAt']}`; preserve branch/PR before takeover.")
    out += ["", "## Blocked lanes", ""]
    if not board["blockedLanes"]:
        out.append("_None._")
    else:
        for lane in board["blockedLanes"]:
            out.append(f"- `{lane['laneId']}` — **{lane['state']}** — {lane['reason']}")
    out += ["", "## Scarce resources", ""]
    for res in board["resources"]:
        out.append(f"- `{res['resourceId']}` — **{res['state']}** — {res['mode']} capacity {res['capacity']} — active {res['activeOwners']}")
    out += ["", "> Generated state is observability, not ownership authority. Claim files + GitHub conditional writes are authoritative.", ""]
    return "\n".join(out)


def validate_all(root: Path, now: datetime) -> dict[str, Any]:
    config, lanes, resources, claims, resource_claims, workers, events = read_tree(root)
    errors = validate_relations(lanes, resources, claims, resource_claims, now)
    if errors:
        raise ControlError("\n".join(errors))
    return {
        "config": config, "lanes": len(lanes), "resources": len(resources), "claims": len(claims),
        "resourceClaims": len(resource_claims), "workers": len(workers), "events": len(events),
        "readySlots": len(derive_ready_slots(config, lanes, resources, claims, resource_claims, now)),
    }


def metadata_from_pr_body(body: str) -> dict[str, str]:
    found: dict[str, str] = {}
    for match in META_LINE_RE.finditer(body or ""):
        key, value = match.group(1), match.group(2)
        if key in found and found[key] != value:
            raise ControlError(f"duplicate conflicting PR metadata {key}")
        found[key] = value
    missing = ALLOWED_PR_METADATA - found.keys()
    if missing:
        raise ControlError(f"missing PR metadata: {sorted(missing)}")
    return found


def path_matches_scope(path: str, patterns: list[str]) -> bool:
    return any(fnmatch.fnmatchcase(path, pattern) for pattern in patterns)


def pr_check(root: Path, event_path: Path, changed_files_path: Path, now: datetime) -> dict[str, Any]:
    config, lanes, resources, claims, resource_claims, _, _ = read_tree(root)
    event = load_json(event_path, max_bytes=4_000_000)
    pr = event.get("pull_request")
    if not isinstance(pr, dict):
        raise ControlError("pull_request event required")
    body = pr.get("body") or ""
    meta = metadata_from_pr_body(body)
    if meta["Control-Schema"] != str(SCHEMA_VERSION):
        raise ControlError("unsupported Control-Schema")
    lane_id = ensure_identifier(meta["Swarm-Lane"], LANE_ID_RE, "Swarm-Lane", event_path)
    slot_id = ensure_identifier(meta["Swarm-Slot"], SLOT_ID_RE, "Swarm-Slot", event_path)
    worker_id = ensure_identifier(meta["Swarm-Worker"], WORKER_ID_RE, "Swarm-Worker", event_path)
    claim_token = ensure_identifier(meta["Swarm-Claim-Token"], TOKEN_RE, "Swarm-Claim-Token", event_path)
    lane = lanes.get(lane_id)
    if lane is None:
        raise ControlError(f"unknown Swarm-Lane {lane_id}")
    if lane["state"] in BLOCKING_LANE_STATES | TERMINAL_LANE_STATES:
        raise ControlError(f"lane {lane_id} is not writable in state {lane['state']}")
    claim = next((c for c in claims if c.lane_id == lane_id and c.slot_id == slot_id and c.worker_id == worker_id and c.claim_token == claim_token), None)
    if claim is None:
        raise ControlError("no matching authoritative claim")
    if claim.is_stale(now):
        raise ControlError("claim lease is stale")
    head_ref = pr.get("head", {}).get("ref")
    if claim.branch and head_ref != claim.branch:
        raise ControlError(f"PR head {head_ref!r} does not match claimed branch {claim.branch!r}")
    changed_files = [line.strip() for line in changed_files_path.read_text(encoding="utf-8").splitlines() if line.strip()]
    slot = next(s for s in lane["slots"] if s["slotId"] == slot_id)
    if "writeScopes" in slot:
        allowed_patterns = list(slot["writeScopes"])
    elif slot_id == "primary" or "integrat" in slot["role"].lower() or "implement" in slot["role"].lower():
        allowed_patterns = list(lane["writeScopes"])
    else:
        allowed_patterns = []
    allowed_patterns += ["tests/**", "Docs/**", ".github/pull_request_template.md"]
    bad = [path for path in changed_files if not path_matches_scope(path, allowed_patterns)]
    if bad:
        raise ControlError("PR exceeds lane/slot write scope: " + ", ".join(sorted(bad)[:20]))
    protected_touched: list[str] = []
    required_resources: set[str] = set()
    for path in changed_files:
        for protected in config["protectedScopes"]:
            if path_matches_scope(path, [protected["pattern"]]):
                protected_touched.append(path)
                required_resources.add(protected["resource"])
    missing_resources = sorted(required_resources - set(claim.resources))
    if missing_resources:
        raise ControlError(f"protected-scope PR lacks declared resources: {missing_resources}")
    active_rkeys = {
        (rc.resource_id, rc.worker_id, rc.lane_id, rc.claim_token)
        for rc in resource_claims if not rc.is_stale(now)
    }
    missing_leases = sorted(rid for rid in required_resources if (rid, worker_id, lane_id, claim_token) not in active_rkeys)
    if missing_leases:
        raise ControlError(f"protected-scope PR lacks active resource leases: {missing_leases}")
    return {"laneId": lane_id, "slotId": slot_id, "workerId": worker_id, "changedFiles": len(changed_files), "protectedTouched": protected_touched}


def simulate(worker_count: int = 30) -> dict[str, Any]:
    """Deterministic in-memory adversarial model of ownership semantics."""
    if worker_count < 2:
        raise ControlError("simulation needs at least two workers")
    claim_path: dict[str, dict] = {}
    winners: list[str] = []
    losers: list[str] = []
    for i in range(worker_count):
        worker = f"sol-20260811-{i:04x}"
        key = "LANE/primary"
        if key not in claim_path:
            claim_path[key] = {"worker": worker, "generation": 1}
            winners.append(worker)
        else:
            losers.append(worker)
    if len(winners) != 1 or len(losers) != worker_count - 1:
        raise AssertionError("atomic create invariant failed")
    observed_generation = claim_path["LANE/primary"]["generation"]
    takeover_winners = []
    for worker in ("sol-20260811-aa11", "sol-20260811-bb22"):
        current = claim_path["LANE/primary"]
        if current["generation"] == observed_generation:
            claim_path["LANE/primary"] = {"worker": worker, "generation": observed_generation + 1}
            takeover_winners.append(worker)
    if len(takeover_winners) != 1:
        raise AssertionError("CAS takeover invariant failed")
    old_owner_rejected = claim_path["LANE/primary"]["generation"] != 1
    if not old_owner_rejected:
        raise AssertionError("old owner was not fenced")
    return {
        "workers": worker_count, "initialClaimWinners": len(winners),
        "initialClaimLosers": len(losers), "takeoverWinners": len(takeover_winners),
        "oldOwnerFenced": old_owner_rejected, "status": "PASS",
    }


def cmd_validate(args: argparse.Namespace) -> int:
    root = Path(args.root)
    result = validate_all(root, parse_time(args.now) if args.now else now_utc())
    print(json.dumps({"status": "PASS", **result}, indent=2))
    return 0


def cmd_render(args: argparse.Namespace) -> int:
    root = Path(args.root)
    now = parse_time(args.now) if args.now else now_utc()
    board = render_board(root, now)
    generated = root / "generated"
    generated.mkdir(parents=True, exist_ok=True)
    (generated / "board.json").write_text(json.dumps(board, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    (generated / "dashboard.md").write_text(board_markdown(board), encoding="utf-8")
    print(json.dumps(board["summary"], indent=2))
    return 0


def cmd_recommend(args: argparse.Namespace) -> int:
    root = Path(args.root)
    now = parse_time(args.now) if args.now else now_utc()
    config, lanes, resources, claims, resource_claims, _, _ = read_tree(root)
    errors = validate_relations(lanes, resources, claims, resource_claims, now)
    if errors:
        raise ControlError("\n".join(errors))
    ready = derive_ready_slots(config, lanes, resources, claims, resource_claims, now)
    limit = max(1, min(args.limit, 20))
    payload = [
        {"laneId": s.lane_id, "slotId": s.slot_id, "role": s.role, "score": s.score,
         "reason": s.reason, "resources": list(s.resources), "writeScopes": list(s.write_scopes)}
        for s in ready[:limit]
    ]
    print(json.dumps(payload, indent=2))
    return 0


def cmd_simulate(args: argparse.Namespace) -> int:
    print(json.dumps(simulate(args.workers), indent=2))
    return 0


def cmd_pr_check(args: argparse.Namespace) -> int:
    result = pr_check(Path(args.root), Path(args.event), Path(args.changed_files), parse_time(args.now) if args.now else now_utc())
    print(json.dumps({"status": "PASS", **result}, indent=2))
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    validate = sub.add_parser("validate")
    validate.add_argument("--root", default=".swarm")
    validate.add_argument("--now")
    validate.set_defaults(func=cmd_validate)
    render = sub.add_parser("render")
    render.add_argument("--root", default=".swarm")
    render.add_argument("--now")
    render.set_defaults(func=cmd_render)
    recommend = sub.add_parser("recommend")
    recommend.add_argument("--root", default=".swarm")
    recommend.add_argument("--now")
    recommend.add_argument("--limit", type=int, default=5)
    recommend.set_defaults(func=cmd_recommend)
    sim = sub.add_parser("simulate")
    sim.add_argument("--workers", type=int, default=30)
    sim.set_defaults(func=cmd_simulate)
    prc = sub.add_parser("pr-check")
    prc.add_argument("--root", required=True)
    prc.add_argument("--event", required=True)
    prc.add_argument("--changed-files", required=True)
    prc.add_argument("--now")
    prc.set_defaults(func=cmd_pr_check)
    return parser


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()
    try:
        return args.func(args)
    except ControlError as exc:
        print(f"SWARM CONTROL ERROR: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
