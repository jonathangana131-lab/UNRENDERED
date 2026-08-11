#!/usr/bin/env python3
"""Reality-Grade enforcement layer for UNRENDERED Swarm Control Plane V2.

This module intentionally wraps the small bootstrap `swarmctl.py` engine instead
of replacing it. It adds trusted-state fencing, transition validation, red-main
scheduling, stricter PR integrity, metrics, and a safe canonical-CI health sync.
It is pure stdlib and never executes control-plane supplied code.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from datetime import timedelta
from pathlib import Path
from typing import Any

import swarmctl as core


def validate_config(path: Path) -> dict[str, Any]:
    obj = core.validate_config(path)
    threshold = obj["wip"].get("integrationBacklogThrottle", 3)
    if not isinstance(threshold, int) or not 1 <= threshold <= 100:
        raise core.ControlError(f"{path}: invalid WIP setting integrationBacklogThrottle")
    obj["wip"]["integrationBacklogThrottle"] = threshold
    for key in ("redMainOverride", "idleAllowed", "requireValidatedState"):
        if key in obj["scheduler"] and not isinstance(obj["scheduler"][key], bool):
            raise core.ControlError(f"{path}: scheduler.{key} must be bool")
    return obj


def read_tree(root: Path):
    config, lanes, resources, claims, resource_claims, workers, events = core.read_tree(root)
    # Re-read config through hardened validation because bootstrap read_tree uses
    # bootstrap validation by design.
    config = validate_config(root / "config.json")
    for lane_id, lane in lanes.items():
        tags = lane.get("tags", [])
        if not isinstance(tags, list) or any(
            not isinstance(x, str) or not re.fullmatch(r"[a-z0-9][a-z0-9._-]{0,47}", x)
            for x in tags
        ):
            raise core.ControlError(f"lane {lane_id}: tags must be safe lowercase identifiers")
    return config, lanes, resources, claims, resource_claims, workers, events


def validate_main_health(root: Path) -> dict[str, Any]:
    path = root / "health" / "main.json"
    if not path.exists():
        return {
            "schemaVersion": core.SCHEMA_VERSION,
            "status": "UNKNOWN",
            "headSha": None,
            "workflowRunId": None,
            "updatedAt": None,
            "conclusion": None,
        }
    obj = core.load_json(path, max_bytes=16_000)
    core.require_schema(obj, path)
    core.require_keys(
        obj,
        {"schemaVersion", "status", "headSha", "workflowRunId", "updatedAt", "conclusion"},
        {"schemaVersion", "status", "headSha", "workflowRunId", "updatedAt", "conclusion"},
        path,
    )
    if obj["status"] not in {"GREEN", "RED", "UNKNOWN"}:
        raise core.ControlError(f"{path}: invalid main health status")
    if not isinstance(obj["headSha"], str) or not re.fullmatch(r"[a-f0-9]{40}", obj["headSha"]):
        raise core.ControlError(f"{path}: invalid headSha")
    if not isinstance(obj["workflowRunId"], int) or obj["workflowRunId"] <= 0:
        raise core.ControlError(f"{path}: invalid workflowRunId")
    core.parse_time(obj["updatedAt"])
    if not isinstance(obj["rconclusion"], str) or not re.fullmatch(r"[a-z_]{2,32}", obj["conclusion"]):
        raise core.ControlError(f"{path}: invalid conclusion")
    return obj


def authoritative_state_digest(root: Path) -> str:
    h = hashlib.sha256()
    for path in sorted(root.rglob("*.json")):
        rel = path.relative_to(root)
        if rel.parts and rel.parts[0] == "generated":
            continue
        h.update(str(rel).encode())
        h.update(b"\0")
        h.update(path.read_bytes())
        h.update(b"\0")
    return h.hexdigest()


def validate_state_marker(root: Path) -> dict[str, Any]:
    path = root / "generated" / "validation.json"
    marker = core.load_json(path, max_bytes=16_000)
    core.require_schema(marker, path)
    core.require_keys(
        marker,
        {"schemaVersion", "status", "stateDigest", "validatedAt"},
        {"schemaVersion", "status", "stateDigest", "validatedAt"},
        path,
    )
    if marker["status"] != "PASS":
        raise core.ControlError("control-state validation marker is not PASS")
    if not isinstance(marker["stateDigest"], str) or not re.fullmatch(r"[a-f0-9]{64}", marker["stateDigest"]):
        raise core.ControlError("invalid validation stateDigest")
    core.parse_time(marker["validatedAt"])
    actual = authoritative_state_digest(root)
    if marker["stateDigest"] != actual:
        raise core.ControlError(
            "live control state changed after its last validated marker; fail closed until control CI validates it"
        )
    return marker


def validate_relations(lanes, resources, claims, resource_claims, now):
    # A lane claim is allowed to exist briefly while its declared resources are
    # being acquired. PR acceptance, not claim representation, requires the
    # matching resource leases. This makes CLAIM -> RESOURCES -> BRANCH valid.
    errors = [
        e for e in core.validate_relations(lanes, resources, claims, resource_claims, now)
        if "missing matching active resource lease" not in e
    ]
    for claim in claims:
        if claim.lane_id not in lanes or claim.is_stale(now):
            continue
        lane = lanes[claim.lane_id]
        outside = sorted(set(claim.resources) - set(lane["resources"]))
        if outside:
            errors.append(f"{claim.path}: resources outside lane declaration: {outside}")
        if claim.slot_id == "primary":
            missing = sorted(set(lane["resources"]) - set(claim.resources))
            if missing:
                errors.append(f"{claim.path}: primary claim omits required lane resources: {missing}")
    return errors


def validate_wip(config, lanes, claims, now):
    errors = []
    active_epics = {
        lane["epicId"]
        for lane in lanes.values()
        if lane["state"] not in core.TERMINAL_LANE_STATES | core.BLOCKING_LANE_STATES
    }
    if len(active_epics) > config["wip"]["maxMajorEpics"]:
        errors.append(
            f"active major epics {len(active_epics)} exceed maxMajorEpics {config['wip']['maxMajorEpics']}: {sorted(active_epics)}"
        )
    active_primary = [c for c in claims if c.slot_id == "primary" and not c.is_stale(now)]
    if len(active_primary) > config["wip"]["maxPrimaryImplementationLanes"]:
        errors.append(
            f"active primaries {len(active_primary)} exceed maxPrimaryImplementationLanes {config['wip']['maxPrimaryImplementationLanes']}"
        )
    return errors


def derive_ready_slots(config, lanes, resources, claims, resource_claims, now, main_health=None):
    ready = core.derive_ready_slots(config, lanes, resources, claims, resource_claims, now)
    integration_backlog = sum(1 for lane in lanes.values() if lane["state"] == "INTEGRATION_READY")
    if integration_backlog >= config["wip"].get("integrationBacklogThrottle", 3):
        ready = [slot for slot in ready if slot.slot_id != "primary"]
    if config["scheduler"].get("redMainOverride", True) and main_health and main_health.get("status") == "RED":
        permitted = {
            lane_id for lane_id, lane in lanes.items()
            if set(lane.get("tags", [])) & {"red-main", "control-repair"}
        }
        ready = [slot for slot in ready if slot.lane_id in permitted]
    return ready


def validate_all(root: Path, now):
    config, lanes, resources, claims, resource_claims, workers, events = read_tree(root)
    errors = validate_relations(lanes, resources, claims, resource_claims, now)
    errors += validate_wip(config, lanes, claims, now)
    if errors:
        raise core.ControlError("\n".join(errors))
    health = validate_main_health(root)
    return {
        "config": config,
        "lanes": len(lanes),
        "resources": len(resources),
        "claims": len(claims),
        "resourceClaims": len(resource_claims),
        "workers": len(workers),
        "events": len(events),
        "mainHealth": health["status"],
        "readySlots": len(derive_ready_slots(config, lanes, resources, claims, resource_claims, now, health)),
    }


def _metrics(board, lanes, events):
    event_counts = {}
    for event in events:
        event_counts[event["eventType"]] = event_counts.get(event["eventType"], 0) + 1
    lane_states = {}
    for lane in lanes.values():
        lane_states[lane["state"]] = lane_states.get(lane["state"], 0) + 1
    return {
        "schemaVersion": core.SCHEMA_VERSION,
        "generatedAt": board["generatedAt"],
        "laneStates": lane_states,
        "eventCounts": event_counts,
        "activeClaims": board["summary"]["activeClaims"],
        "staleClaims": board["summary"]["staleClaims"],
        "readySlots": board["summary"]["readySlots"],
        "reviewBacklog": sum(1 for lane in lanes.values() if lane["state"] in {"REVIEW", "NEEDS_CHANGES"}),
        "integrationBacklog": sum(1 for lane in lanes.values() if lane["state"] == "INTEGRATION_READY"),
        "activeEpics": sorted({
            lane["epicId"] for lane in lanes.values()
            if lane["state"] not in core.TERMINAL_LANE_STATES | core.BLOCKING_LANE_STATES
        }),
        "note": "Gross lines written are diagnostic, not a success metric.",
    }


def render_board(root: Path, now):
    config, lanes, resources, claims, resource_claims, workers, events = read_tree(root)
    errors = validate_relations(lanes, resources, claims, resource_claims, now) + validate_wip(config, lanes, claims, now)
    if errors: raise core.ControlError("\n".join(errors))
    health = validate_main_health(root)
    active, stale = core.active_and_stale_claims(claims, now)
    ready = derive_ready_slots(config, lanes, resources, claims, resource_claims, now, health)
    board = {
        "schemaVersion": core.SCHEMA_VERSION,
        "generatedAt": now.isoformat(),
        "controlBranch": config["controlBranch"],
        "stateDigest": authoritative_state_digest(root),
        "mainHealth": health,
        "summary": {"lanes": len(lanes), "readySlots": len(ready), "activeClaims": len(active), "staleClaims": len(stale), "activeResourceClaims": sum(1 for c in resource_claims if not c.is_stale(now)), "workers": len(workers), "blockedExternalLanes": sum(1 for lane in lanes.values() if lane["state"] == "BLOCKED_EXTERNAL")},
        "readySlots": [{"laneId":s.lane_id,"slotId":s.slot_id,"role":s.role,"score":s.score,"reason":s.reason,"resources":list(s.resources),"writeScopes":list(s.write_scopes)} for s in ready],
        "activeClaims": [{"laneId":c.lane_id,"slotId":c.slot_id,"workerId":c.worker_id,"branch":c.branch,"pr":c.pr,"expiresAt":c.expires_at().isoformat()} for c in sorted(active, key=lambda c:(c.lane_id,c.slot_id))],
        "staleClaims": [{"laneId":c.lane_id,"slotId":c.slot_id,"workerId":c.worker_id,"generation":c.generation,"expiredAt":c.expires_at().isoformat(),"branch":c.branch,"pr":c.pr} for c in sorted(stale,key=lambda c:(c.lane_id,c.slot_id))],
        "blockedLanes": [{"laneId":lid,"state":v["state"],"reason":(v.get("blockers",["explicit lane state"])[0] if v.get("blockers") else core.dependencies_satisfied(v,lanes)[1])} for lid,v0in sorted(lanes.items()) if v["state"] in core.BLOCKING_LANE_STATES],
        "resources": [{"resourceId":rid,"state":res["state"],"capacity":res["capacity"],"mode":res["mode"],"activeOwners":sum(1 for c in resource_claims if c.resource_id==rid and not c.is_stale(now))} for rid,res in sorted(resources.items(),key=lambda item:item[1]["order"])],
        "recentEvents": events[-20:],
    }
    board["metrics"] = _metrics(board, lanes, events)
    return board


def board_markdown(board):
    s=board["summary"]; out=["# UNRENDERED Swarm Control Plane","",f"Generated: `{board['generatedAt']}`","",f"Canonical main: **{board['mainHealth']['status']}** `nÜ´vf¢úwöñÿayßRÖ™+∫y'£	ﬂJ÷≠yÿ†zÀ[°™›≤÷≠x8†zÀR∫iöØ'Îyßr≤Z-≤ ﬁi‹íñãl}ß-ä˜úï®¶≤∆ú∂+ﬁ
V¢ö«Ïµ©^rV¢öÀ,µ©^
V¢ö«€ñá$y◊±µÍÁjYZùÎ,nZëÁD∆◊´ù©Kjw¨EÊù …h∂ .∑