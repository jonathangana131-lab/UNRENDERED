from __future__ import annotations

import json
from pathlib import Path
from typing import Any, Mapping

from .model import *
from .coordination import add_blocker, add_work_item, _remember


def _lane_role(raw: str, slot: str) -> str:
    text = (raw + " " + slot).lower()
    if "integrat" in text: return "integrator"
    if "review" in text: return "reviewer"
    if "audit" in text: return "auditor"
    if "test" in text or "advers" in text: return "tester"
    if "mine" in text or "capacity" in text: return "miner"
    if "debug" in text or "recover" in text: return "debugger"
    return "builder"


def _lane_state_to_objective(state: str) -> str:
    return {"DONE":"DONE", "BLOCKED_EXTERNAL":"EXTERNAL_BLOCKED", "LOCKED":"BLOCKED", "REVIEW":"REVIEW", "INTEGRATION_READY":"INTEGRATING", "NEEDS_CHANGES":"ACTIVE", "READY":"READY", "SUPERSEDED":"DONE", "CANCELLED":"DONE"}.get(state, "ACTIVE")


def _mission_for_lane(lane: Mapping[str, Any]) -> str:
    epic = str(lane.get("epicId", "")).upper(); lid = str(lane.get("laneId", "")).upper()
    return "swarm-operations" if epic.startswith("OPS") or lid.startswith("OPS-") or lid.startswith("SWARM-") else "hero-gate-reality-grade"


def _legacy_dependencies(lane: Mapping[str, Any]) -> list[dict[str, Any]]:
    """Read the authoritative V2.1 dependency record without weakening its shape.

    V2.1 stores dependencies as data records, not raw strings:
    {"laneId": "...", "acceptableStates": ["DONE", ...]}.
    V16 currently schedules objective edges conservatively as DONE-only edges, while
    retaining the exact acceptable-state policy as migration metadata for audit and
    future richer dependency policy. Malformed rows fail closed.
    """
    raw = lane.get("dependencies", [])
    lane_id = str(lane.get("laneId") or "<unknown>")
    if not isinstance(raw, list):
        raise ValidationError(f"legacy lane {lane_id} dependencies must be a list")
    result: list[dict[str, Any]] = []
    for index, dep in enumerate(raw):
        if not isinstance(dep, Mapping) or set(dep) != {"laneId", "acceptableStates"}:
            raise ValidationError(f"legacy lane {lane_id} dependency {index} has unsupported shape")
        dependency_lane_id = dep.get("laneId")
        acceptable_states = dep.get("acceptableStates")
        if not isinstance(dependency_lane_id, str) or not dependency_lane_id:
            raise ValidationError(f"legacy lane {lane_id} dependency {index} has invalid laneId")
        if not isinstance(acceptable_states, list) or not acceptable_states or any(not isinstance(state, str) or not state for state in acceptable_states):
            raise ValidationError(f"legacy lane {lane_id} dependency {index} has invalid acceptableStates")
        result.append({"laneId": dependency_lane_id, "acceptableStates": list(acceptable_states)})
    return result


def migrate_legacy_root(root: Path, *, main_sha: str = "", control_sha: str = "", now: dt.datetime | None = None) -> dict[str, Any]:
    graph = seed_graph(now); root = Path(root); lane_files = sorted((root / "lanes").glob("*.json")); lanes = []
    for path in lane_files:
        try: lanes.append(json.loads(path.read_text()))
        except Exception as exc: raise ValidationError(f"invalid legacy lane {path.name}") from exc
    lane_map = {str(l["laneId"]): slug(str(l["laneId"])) for l in lanes if l.get("laneId")}
    board = {}
    board_path = root / "generated" / "board.json"
    if board_path.exists():
        try: board = json.loads(board_path.read_text())
        except Exception: board = {}
    claim_by_lane = {}
    for claim in board.get("activeClaims", []):
        if claim.get("slotId") == "primary": claim_by_lane[str(claim.get("laneId"))] = claim
    for lane in lanes:
        lane_id = str(lane["laneId"]); oid = lane_map[lane_id]; mission_id = _mission_for_lane(lane); state = str(lane.get("state", "READY")); runtime_required = state == "BLOCKED_EXTERNAL" or any(token in (str(lane.get("title", "")) + " " + " ".join(lane.get("tags", []))).lower() for token in ("studio", "two-client", "multiplayer evidence", "viewport", "device"))
        priority_raw = lane.get("priority", 5000)
        try: priority = max(0, min(9, 9 - int(priority_raw) // 1000))
        except Exception: priority = 5
        severity = "P0" if runtime_required or priority <= 2 else "P1" if priority <= 4 else "P2"
        legacy_dependencies = _legacy_dependencies(lane)
        obj = make_objective(oid, mission_id, str(lane.get("title") or lane_id), priority=priority, severity=severity, dependencies=[], finish_conditions=list(lane.get("acceptance", [])) or [str(lane.get("objective") or "legacy objective accepted"), "independent review accepted", "integrated to main", "no unresolved P0/P1 blockers"], canonical_branch=str(claim_by_lane.get(lane_id, {}).get("branch") or ""), user_value=8 if mission_id == "hero-gate-reality-grade" else 6, external_truth_required=runtime_required, release_blocking=runtime_required, safety_critical=runtime_required, primary_scope=list(lane.get("writeScopes", [])), forbidden_areas=["invented Studio/two-client evidence"] if runtime_required else [], now=now)
        obj["legacyDependencyRequirements"] = legacy_dependencies
        obj["status"] = _lane_state_to_objective(state)
        if state == "DONE" or state == "SUPERSEDED":
            obj["finishSatisfied"] = [True] * len(obj["finishConditions"]); obj["integrationState"] = "MAIN"
            for dim in ("functionality","testing","integration","knownBlockers"): obj["featureGenome"][dim]["state"] = "ACCEPTED"
        if runtime_required: obj["featureGenome"]["runtimeTruth"]["state"] = "BLOCKED"
        graph["objectives"][oid] = obj; graph["missions"][mission_id]["objectiveIds"].append(oid)
        graph["migration"]["legacyLaneIds"].append(lane_id); graph["metrics"]["legacyLanesImported"] += 1
    for lane in lanes:
        lane_id = str(lane["laneId"]); oid = lane_map[lane_id]; legacy_dependencies = graph["objectives"][oid].get("legacyDependencyRequirements", [])
        missing = [dep["laneId"] for dep in legacy_dependencies if dep["laneId"] not in lane_map]
        if missing:
            raise ValidationError(f"legacy lane {lane_id} references missing dependencies: {', '.join(sorted(missing))}")
        graph["objectives"][oid]["dependencies"] = [lane_map[dep["laneId"]] for dep in legacy_dependencies]
    for lane in lanes:
        lane_id = str(lane["laneId"]); oid = lane_map[lane_id]; mission_id = graph["objectives"][oid]["missionId"]; state = str(lane.get("state", "READY")); raw_blockers = lane.get("blockers", [])
        if isinstance(raw_blockers, list) and state not in {"DONE", "SUPERSEDED", "CANCELLED"}:
            for index, blocker in enumerate(raw_blockers[:24]):
                text = str(blocker.get("reason") if isinstance(blocker, dict) else blocker)
                if not text: continue
                bid = slug(f"legacy-{lane_id}-blocker-{index}"); external = state == "BLOCKED_EXTERNAL" or "external" in text.lower()
                add_blocker(graph, blocker_id=bid, mission_id=mission_id, objective_id=oid, symptom=text, severity="P0" if external else "P1", external=external, now=now, legitimate_new=False)
        if state not in {"DONE","SUPERSEDED","CANCELLED","LOCKED","BLOCKED_EXTERNAL"}:
            slots = lane.get("slots", []) if isinstance(lane.get("slots", []), list) else []
            if not slots: slots = [{"slotId":"primary","role":"implementation","writeScopes":lane.get("writeScopes", [])}]
            for slot in slots[:12]:
                sid = slug(str(slot.get("slotId", "primary"))); wid = slug(f"legacy-{lane_id}-{sid}"); role = _lane_role(str(slot.get("role", "")), sid); source = {"legacyLaneId": lane_id, "slotId": sid, "pr": lane.get("pr")}
                branch = str(claim_by_lane.get(lane_id, {}).get("branch") or "") if sid == "primary" else ""
                add_work_item(graph, work_item_id=wid, mission_id=mission_id, objective_id=oid, title=f"{lane.get('title', lane_id)} — {slot.get('role', sid)}", outcome=str(lane.get("objective") or "advance accepted lane outcome"), role=role, scope=list(slot.get("writeScopes", lane.get("writeScopes", []))), forbidden_areas=graph["objectives"][oid]["forbiddenAreas"], branch=branch, source=source, now=now, allow_duplicate=True)
                if state == "REVIEW": graph["workItems"][wid]["status"] = "REVIEW"
                elif state == "INTEGRATION_READY": graph["workItems"][wid]["status"] = "INTEGRATING"
        if graph["objectives"][oid]["canonicalBranch"]:
            graph["branches"].setdefault(graph["objectives"][oid]["canonicalBranch"], {"branch": graph["objectives"][oid]["canonicalBranch"], "missionId": mission_id, "objectiveId": oid, "state": "SELECTED", "world": "FRONTIER", "selectedAt": fmt(now), "integratedAt": "", "pr": lane.get("pr"), "source": {"legacyLaneId": lane_id, "pr": lane.get("pr")}})
    # Preserve recent immutable event facts as bounded read-only memory, never rewriting event files.
    for event in board.get("recentEvents", [])[-40:]:
        lane_id = str(event.get("laneId") or ""); oid = lane_map.get(lane_id, "")
        _remember(graph, "LEGACY_EVENT_FACT", str(event.get("summary") or event.get("eventId") or "legacy event"), oid, now, {"eventId": event.get("eventId"), "eventType": event.get("eventType"), "timestamp": event.get("timestamp")})
    graph["migration"].update({"phase": "ACTIVE", "legacyImported": True, "legacyControlSHA": control_sha, "activationMainSHA": main_sha, "liveRefreshMainSHA": main_sha, "destructiveActionsAllowed": False})
    graph["updatedAt"] = fmt(now); graph["revision"] = 1
    _remember(graph, "MIGRATION_ACTIVE", f"Imported {len(lanes)} legacy lanes without rewriting immutable events", now=now, data={"controlSHA": control_sha, "mainSHA": main_sha})
    return validate_graph(graph)


def transition_check(before: Mapping[str, Any], after: Mapping[str, Any]) -> dict[str, Any]:
    before = validate_graph(before); after = validate_graph(after)
    if before["graphId"] != after["graphId"] or before["createdAt"] != after["createdAt"]: raise ValidationError("V16 graph identity changed")
    if after["revision"] != before["revision"] + 1: raise ValidationError("V16 revision must advance exactly once")
    if before["migration"].get("legacyImported") and not after["migration"].get("legacyImported"): raise ValidationError("legacy migration cannot be forgotten")
    for key in before["objectives"]:
        if key not in after["objectives"]: raise ValidationError(f"objective deleted: {key}")
    for key in before["evidence"]:
        if key not in after["evidence"]: raise ValidationError(f"evidence deleted: {key}")
        old, new = before["evidence"][key], after["evidence"][key]
        if old == new: continue
        allowed = old["status"] == "PASS" and new["status"] == "STALE" and old["truthClass"] == new["truthClass"] and old["details"] == new["details"] and old["sourceDigest"] == new["sourceDigest"] and old["dependencyDigest"] == new["dependencyDigest"] and old["environmentDigest"] == new["environmentDigest"] and bool(new.get("invalidatedAt"))
        if not allowed: raise ValidationError(f"existing evidence mutated outside PASS->STALE invalidation: {key}")
    return {"status":"PASS", "revision":after["revision"], "objectives":len(after["objectives"]), "evidence":len(after["evidence"])}
