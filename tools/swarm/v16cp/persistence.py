from __future__ import annotations

import hashlib
from typing import Any, Mapping, Sequence

from . import scheduler as _base
from .model import MissionPacket

WORKER_PERSISTENCE_VERSION = 1


def _slot(worker_id: str, size: int) -> int:
    if size <= 0:
        return 0
    return int.from_bytes(hashlib.sha256(worker_id.encode()).digest()[:8], "big") % size


def _primary(packet: MissionPacket) -> MissionPacket:
    data = dict(packet.packet)
    data.update({
        "WORKER_PERSISTENCE_VERSION": 1,
        "MODE": "PRIMARY",
        "STOP_AUTHORIZED": False,
        "AFTER_TASK": "refresh and request another continuation",
        "EMPTY_EXCLUSIVE_QUEUE_ACTION": "use assist mode; do not stop",
    })
    return MissionPacket(packet.mission_id, packet.objective_id, packet.work_item_id,
                         packet.role, packet.priority_score, data)


def _assist(graph: Mapping[str, Any]) -> list[MissionPacket]:
    weights = {"INTEGRATING": 500, "REVIEW": 420, "BLOCKED": 320, "QUEUED": 260}
    severity = {"P0": 400, "P1": 250, "P2": 100, "P3": 20}
    packets: list[MissionPacket] = []
    active_objectives: set[str] = set()

    for item in graph.get("workItems", {}).values():
        if item.get("status") not in weights:
            continue
        obj = graph["objectives"].get(item.get("objectiveId"))
        if not obj or obj.get("status") in {"DONE", "EXTERNAL_BLOCKED"}:
            continue
        blocker = graph["blockers"].get(item.get("blockerId")) if item.get("blockerId") else None
        if blocker and blocker.get("state") == "EXTERNAL":
            continue
        active_objectives.add(item["objectiveId"])
        mode = "INTEGRATION_ASSIST" if item["status"] == "INTEGRATING" else (
            "REVIEW_ASSIST" if item["status"] == "REVIEW" else "DEBUG_ASSIST"
        )
        data = {
            "WORKER_PERSISTENCE_VERSION": 1,
            "MODE": mode,
            "NON_EXCLUSIVE_ASSIST": True,
            "CLAIM_REQUIRED": False,
            "WRITE_AUTHORITY": False,
            "MAY_CREATE_BRANCH": False,
            "MAY_CREATE_SUCCESSOR_PR": False,
            "STOP_AUTHORIZED": False,
            "MISSION": graph["missions"][item["missionId"]]["title"],
            "CURRENT_STATE": obj["status"],
            "CANONICAL_BRANCH": obj.get("canonicalBranch", ""),
            "JOIN_BRANCH": item.get("branch") or obj.get("canonicalBranch", ""),
            "PRIMARY_SCOPE": item.get("primaryScope", []),
            "FORBIDDEN_AREAS": item.get("forbiddenAreas", []),
            "SAFE_ASSIST_ACTIONS": [
                "review existing work",
                "inspect CI and isolate a concrete defect",
                "run impacted deterministic or performance tests",
                "help integrate accepted changes",
                "attach a concrete finding to canonical work",
            ],
            "AFTER_TASK": "refresh and request another continuation",
        }
        role = "integrator" if item["status"] == "INTEGRATING" else "reviewer"
        score = weights[item["status"]] + severity.get(obj.get("severity", "P3"), 0) + obj.get("userValue", 0) * 10
        packets.append(MissionPacket(item["missionId"], item["objectiveId"], item["workItemId"], role, score, data))

    for oid, obj in graph.get("objectives", {}).items():
        if oid in active_objectives or obj.get("status") in {"DONE", "EXTERNAL_BLOCKED"}:
            continue
        if any(graph["objectives"].get(dep, {}).get("status") != "DONE" for dep in obj.get("dependencies", [])):
            continue
        missing = [c for c, ok in zip(obj.get("finishConditions", []), obj.get("finishSatisfied", [])) if not ok]
        if not missing:
            continue
        data = {
            "WORKER_PERSISTENCE_VERSION": 1,
            "MODE": "CAPACITY_MINING_ASSIST",
            "NON_EXCLUSIVE_ASSIST": True,
            "CLAIM_REQUIRED": False,
            "WRITE_AUTHORITY": False,
            "MAY_CREATE_BRANCH": False,
            "MAY_CREATE_SUCCESSOR_PR": False,
            "STOP_AUTHORIZED": False,
            "MISSION": graph["missions"][obj["missionId"]]["title"],
            "CURRENT_STATE": obj["status"],
            "CANONICAL_BRANCH": obj.get("canonicalBranch", ""),
            "UNSATISFIED_FINISH_CONDITIONS": missing,
            "DEPTH_BEFORE_BREADTH": "Do not activate another major epic just to occupy a worker.",
            "SAFE_ASSIST_ACTIONS": [
                "inspect existing code for a concrete gap",
                "review current evidence or integration readiness",
                "identify a bounded test or diagnostic that closes an existing finish condition",
            ],
            "AFTER_TASK": "refresh and request another continuation",
        }
        score = 150 + severity.get(obj.get("severity", "P3"), 0) + obj.get("userValue", 0) * 8
        packets.append(MissionPacket(obj["missionId"], oid, f"assist::{oid}", "reviewer", score, data))

    packets.sort(key=lambda p: (-p.priority_score, p.objective_id, p.work_item_id))
    return packets


def worker_plan(graph: Mapping[str, Any], worker_id: str, limit: int = 8, now=None) -> list[MissionPacket]:
    primary = [_primary(p) for p in _base.recommend(graph, (), max(64, len(graph.get("workItems", {})) + 8), now)]
    if primary:
        start = _slot(worker_id, len(primary))
        primary = primary[start:] + primary[:start]
    out: list[MissionPacket] = []
    seen: set[tuple[str, str]] = set()
    for packet in primary + _assist(graph):
        key = (packet.work_item_id, packet.packet.get("MODE", "PRIMARY"))
        if key in seen:
            continue
        seen.add(key)
        out.append(packet)
        if len(out) >= limit:
            break
    return out


def recommend(graph: Mapping[str, Any], worker_ids: Sequence[str] = (), limit: int = 30, now=None) -> list[MissionPacket]:
    if limit < 1:
        return []
    if worker_ids:
        out: list[MissionPacket] = []
        for worker in list(worker_ids)[:limit]:
            plan = worker_plan(graph, worker, 8, now)
            if plan:
                packet = plan[0]
                data = dict(packet.packet)
                data["ASSIGNED_WORKER"] = worker
                out.append(MissionPacket(packet.mission_id, packet.objective_id, packet.work_item_id,
                                         packet.role, packet.priority_score, data))
        return out
    out = [_primary(p) for p in _base.recommend(graph, (), limit, now)]
    seen = {(p.work_item_id, p.packet.get("MODE", "PRIMARY")) for p in out}
    for packet in _assist(graph):
        key = (packet.work_item_id, packet.packet.get("MODE", "ASSIST"))
        if key not in seen:
            out.append(packet)
            seen.add(key)
        if len(out) >= limit:
            break
    return out[:limit]


def continuation_status(graph: Mapping[str, Any], worker_id: str, now=None) -> dict[str, Any]:
    plan = worker_plan(graph, worker_id, 8, now)
    if not plan:
        return {"status": "STOP", "stopAuthorized": True, "next": None, "fallbacks": []}
    first = plan[0]
    mode = first.packet.get("MODE", "PRIMARY")
    return {
        "status": "WORK" if mode == "PRIMARY" else "ASSIST",
        "stopAuthorized": False,
        "next": first,
        "fallbacks": plan[1:],
        "onClaimConflict": "use the next fallback; do not stop or duplicate implementation",
    }
