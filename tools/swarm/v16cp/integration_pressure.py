from __future__ import annotations

"""Swarm V16.2 integration-throughput layer.

V16.1 keeps burst workers alive. V16.2 makes accepted/reviewed work outside MAIN
consume swarm capacity before new capacity-mining work. It never relaxes the
existing V2.1 ownership/trust plane or V16 runtime-truth authority.
"""

import hashlib
from typing import Any, Mapping, Sequence

from . import persistence as _persist
from . import scheduler as _sched

MissionPacket = _sched.MissionPacket
V16_2_POLICY_VERSION = "16.2"
HEAVY_BACKLOG = 4


def _stable_slot(worker_id: str, size: int) -> int:
    if size <= 0:
        return 0
    return int.from_bytes(hashlib.sha256(worker_id.encode()).digest()[:8], "big") % size


def integration_candidates(graph: Mapping[str, Any]) -> list[tuple[float, Mapping[str, Any]]]:
    weights = {"INTEGRATING": 1600.0, "REVIEW": 1050.0}
    severity = {"P0": 900.0, "P1": 550.0, "P2": 180.0, "P3": 40.0}
    out: list[tuple[float, Mapping[str, Any]]] = []
    for item in graph.get("workItems", {}).values():
        state = str(item.get("status") or "")
        if state not in weights:
            continue
        obj = graph.get("objectives", {}).get(item.get("objectiveId"))
        if not obj or obj.get("status") in {"DONE", "EXTERNAL_BLOCKED"}:
            continue
        blocker = graph.get("blockers", {}).get(item.get("blockerId")) if item.get("blockerId") else None
        if blocker and blocker.get("state") == "EXTERNAL":
            continue
        score = weights[state]
        score += severity.get(str(obj.get("severity") or "P3"), 0.0)
        score += float(obj.get("userValue", 0)) * 25.0
        score += 300.0 if obj.get("releaseBlocking") else 0.0
        score += 180.0 if item.get("integrationWorld") == "NEXT" else 0.0
        score += 160.0 if item.get("branchState") == "SELECTED" else 0.0
        out.append((score, item))
    out.sort(key=lambda pair: (-pair[0], str(pair[1].get("workItemId") or "")))
    return out


def canonical_absorption_plan(graph: Mapping[str, Any]) -> list[dict[str, Any]]:
    plans: list[dict[str, Any]] = []
    for oid, obj in graph.get("objectives", {}).items():
        canonical = str(obj.get("canonicalBranch") or "")
        if not canonical:
            continue
        children = [
            item for item in graph.get("workItems", {}).values()
            if item.get("objectiveId") == oid
            and item.get("status") in {"REVIEW", "INTEGRATING"}
            and item.get("branch")
            and str(item.get("branch")) != canonical
        ]
        if children:
            plans.append({
                "objectiveId": oid,
                "canonicalBranch": canonical,
                "childWorkItemIds": [str(item.get("workItemId")) for item in children],
                "action": "ABSORB_INTO_CANONICAL",
            })
    plans.sort(key=lambda p: (-len(p["childWorkItemIds"]), p["objectiveId"]))
    return plans


def merge_pressure_report(graph: Mapping[str, Any]) -> dict[str, Any]:
    candidates = integration_candidates(graph)
    queue = list((graph.get("mergeTrain") or {}).get("queue") or [])
    absorption = canonical_absorption_plan(graph)
    active = bool(candidates or queue or absorption)
    objectives = sorted({str(item.get("objectiveId")) for _, item in candidates} | {p["objectiveId"] for p in absorption})
    return {
        "policyVersion": V16_2_POLICY_VERSION,
        "active": active,
        "candidateCount": len(candidates),
        "mergeTrainQueue": len(queue),
        "absorptionObjectiveCount": len(absorption),
        "objectives": objectives,
        "heavy": len(candidates) >= HEAVY_BACKLOG or len(queue) >= 2,
    }


def role_allocation(graph: Mapping[str, Any], workers: int = 30) -> dict[str, int]:
    pressure = merge_pressure_report(graph)
    if not pressure["active"]:
        return _sched.role_allocation(graph, workers)
    if workers < 1:
        raise _sched.ValidationError("workers must be positive")
    if pressure["heavy"]:
        builder = round(workers * 0.25)
        reviewer = round(workers * 0.18)
    else:
        builder = round(workers * 0.35)
        reviewer = round(workers * 0.20)
    return {"builder": builder, "reviewer": reviewer, "integrator": workers - builder - reviewer}


def health_report(graph: Mapping[str, Any], workers: int = 30, now=None) -> dict[str, Any]:
    """Preserve the established health model while reporting V16.2 allocation."""
    report = dict(_sched.health_report(graph, workers, now))
    report["allocation"] = role_allocation(graph, workers)
    report["mergePressure"] = merge_pressure_report(graph)
    report["policyVersion"] = V16_2_POLICY_VERSION
    return report


def _pressure_packet(graph: Mapping[str, Any], item: Mapping[str, Any], worker_id: str, score: float) -> MissionPacket:
    obj = graph["objectives"][item["objectiveId"]]
    mission = graph["missions"][item["missionId"]]
    canonical = str(obj.get("canonicalBranch") or item.get("branch") or "")
    source = str(item.get("branch") or canonical)
    duty = ("INTEGRATE", "RED_TEAM", "TEST", "CONFLICT_CHECK")[_stable_slot(worker_id + "::" + item["workItemId"], 4)]
    exclusive = duty == "INTEGRATE"
    # Integration writes target the canonical destination. Review/test/conflict
    # workers must inspect the exact source candidate that contains the changes
    # awaiting absorption; otherwise they can produce false-green evidence on a
    # destination branch that does not contain the candidate yet.
    working_branch = canonical if exclusive else source
    data = {
        "SWARM_POLICY_VERSION": V16_2_POLICY_VERSION,
        "MODE": "MERGE_PRESSURE",
        "MERGE_PRESSURE_DUTY": duty,
        "STOP_AUTHORIZED": False,
        "MISSION": mission["title"],
        "CURRENT_STATE": obj["status"],
        "CANONICAL_BRANCH": canonical,
        "INTEGRATION_DESTINATION": canonical,
        "JOIN_BRANCH": working_branch,
        "SOURCE_BRANCH": source,
        "CANONICAL_ABSORPTION_REQUIRED": bool(source and canonical and source != canonical),
        "CLAIM_REQUIRED": exclusive,
        "WRITE_AUTHORITY": "exact work-item ownership required" if exclusive else False,
        "NON_EXCLUSIVE_ASSIST": not exclusive,
        "MAY_CREATE_BRANCH": False,
        "MAY_CREATE_SUCCESSOR_PR": False,
        "PRIMARY_SCOPE": item.get("primaryScope", []),
        "FORBIDDEN_AREAS": item.get("forbiddenAreas", []),
        "SAFE_ACTIONS": [
            "absorb accepted child work into the canonical branch",
            "resolve compatible conflicts instead of reporting and stopping",
            "run impacted exact-head acceptance on the exact candidate/composed head appropriate to the duty",
            "preserve useful evidence then supersede redundant support branches",
            "promote only after all applicable truth/authority gates remain satisfied",
        ],
        "TRUTH_GATE": "MERGE_PRESSURE cannot promote Studio, multiplayer, device, server-authority, or other external truth without explicit evidence.",
        "AFTER_TASK": "refresh; continue merge pressure while accepted work remains outside MAIN",
    }
    return MissionPacket(item["missionId"], item["objectiveId"], item["workItemId"], "integrator" if exclusive else "reviewer", score, data)


def worker_plan(graph: Mapping[str, Any], worker_id: str, limit: int = 8, now=None) -> list[MissionPacket]:
    base = list(_persist.worker_plan(graph, worker_id, max(limit, 8), now))
    candidates = integration_candidates(graph)
    if not candidates:
        return base[:limit]

    # During pressure reserve 70–80% of burst workers for convergence while
    # retaining builders for true implementation blockers.
    pressure_share = 8 if len(candidates) >= HEAVY_BACKLOG else 7
    if _stable_slot(worker_id + "::v162-pressure", 10) >= pressure_share:
        return base[:limit]

    index = _stable_slot(worker_id + "::v162-candidate", len(candidates))
    score, item = candidates[index]
    first = _pressure_packet(graph, item, worker_id, score + 2500.0)
    out = [first]
    seen = {(first.work_item_id, first.packet.get("MODE"))}
    for packet in base:
        # Capacity mining is intentionally suppressed while merge pressure is
        # active; review/debug/integration fallbacks remain useful.
        if packet.packet.get("MODE") == "CAPACITY_MINING_ASSIST":
            continue
        key = (packet.work_item_id, packet.packet.get("MODE"))
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
        out = []
        for worker in list(worker_ids)[:limit]:
            plan = worker_plan(graph, worker, 8, now)
            if not plan:
                continue
            packet = plan[0]
            data = dict(packet.packet); data["ASSIGNED_WORKER"] = worker
            out.append(MissionPacket(packet.mission_id, packet.objective_id, packet.work_item_id, packet.role, packet.priority_score, data))
        return out

    pressure = integration_candidates(graph)
    if not pressure:
        return _persist.recommend(graph, worker_ids, limit, now)
    out = [_pressure_packet(graph, item, f"operator-{i}", score + 2500.0) for i, (score, item) in enumerate(pressure[:limit])]
    if len(out) < limit:
        for packet in _persist.recommend(graph, (), limit, now):
            if packet.packet.get("MODE") == "CAPACITY_MINING_ASSIST":
                continue
            if any(existing.work_item_id == packet.work_item_id and existing.packet.get("MODE") == packet.packet.get("MODE") for existing in out):
                continue
            out.append(packet)
            if len(out) >= limit:
                break
    return out[:limit]


def continuation_status(graph: Mapping[str, Any], worker_id: str, now=None) -> dict[str, Any]:
    plan = worker_plan(graph, worker_id, 8, now)
    pressure = merge_pressure_report(graph)
    if not plan:
        return {"status": "STOP", "stopAuthorized": True, "next": None, "fallbacks": [], "mergePressure": pressure}
    first = plan[0]
    mode = first.packet.get("MODE", "PRIMARY")
    return {
        "status": "WORK" if mode == "PRIMARY" else "ASSIST",
        "stopAuthorized": False,
        "next": first,
        "fallbacks": plan[1:],
        "mergePressure": pressure,
        "onClaimConflict": "reroute to another merge/review/test duty or fallback; never create a successor merely because integration ownership is occupied",
    }
