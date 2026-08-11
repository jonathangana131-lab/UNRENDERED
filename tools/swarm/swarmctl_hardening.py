#!/usr/bin/env python3
"""Reality-Grade hardening for UNRENDERED Swarm Control Plane V2.

This module wraps the small bootstrap `swarmctl.py` engine. It adds validated-state
fencing, transition/takeover checks, red-main scheduling, WIP enforcement, worker
identity/PR integrity, metrics, and canonical-CI health projection. Control files
remain data; this module never executes control-supplied code.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from datetime import timedelta
from pathlib import Path

import swarmctl as core


def hard_config(path: Path) -> dict:
    cfg = core.validate_config(path)
    threshold = cfg["wip"].get("integrationBacklogThrottle", 3)
    if not isinstance(threshold, int) or not 1 <= threshold <= 100:
        raise core.ControlError(f"{path}: invalid integrationBacklogThrottle")
    cfg["wip"]["integrationBacklogThrottle"] = threshold
    for key in ("redMainOverride", "idleAllowed", "requireValidatedState"):
        if key in cfg["scheduler"] and not isinstance(cfg["scheduler"][key], bool):
            raise core.ControlError(f"{path}: scheduler.{key} must be bool")
    return cfg


def read_tree(root: Path):
    cfg, lanes, resources, claims, rclaims, workers, events = core.read_tree(root)
    cfg = hard_config(root / "config.json")
    for lane_id, lane in lanes.items():
        tags = lane.get("tags", [])
        if not isinstance(tags, list) or any(not isinstance(x, str) or not re.fullmatch(r"[a-z0-9][a-z0-9._-]{0,47}", x) for x in tags):
            raise core.ControlError(f"{lane_id}: invalid tags")
    return cfg, lanes, resources, claims, rclaims, workers, events


def main_health(root: Path) -> dict:
    path = root / "health" / "main.json"
    if not path.exists():
        return {"schemaVersion": 1, "status": "UNKNOWN", "headSha": None, "workflowRunId": None, "updatedAt": None, "conclusion": None}
    obj = core.load_json(path, 16_000)
    core.require_schema(obj, path)
    required = {"schemaVersion", "status", "headSha", "workflowRunId", "updatedAt", "conclusion"}
    core.require_keys(obj, required, required, path)
    if obj["status"] not in {"GREEN", "RED", "UNKNOWN"}:
        raise core.ControlError(f"{path}: invalid status")
    if not isinstance(obj["headSha"], str) or not re.fullmatch(r"[a-f0-9]{40}", obj["headSha"]):
        raise core.ControlError(f"{path}: invalid headSha")
    if not isinstance(obj["workflowRunId"], int) or obj["workflowRunId"] <= 0:
        raise core.ControlError(f"{path}: invalid workflowRunId")
    core.parse_time(obj["updatedAt"])
    if not isinstance(obj["conclusion"], str) or not re.fullmatch(r"[a-z_]{2,32}", obj["conclusion"]):
        raise core.ControlError(f"{path}: invalid conclusion")
    return obj


def state_digest(root: Path) -> str:
    h = hashlib.sha256()
    for path in sorted(root.rglob("*.json")):
        rel = path.relative_to(root)
        if rel.parts and rel.parts[0] == "generated":
            continue
        h.update(str(rel).encode()); h.update(b"\0"); h.update(path.read_bytes()); h.update(b"\0")
    return h.hexdigest()


def validate_marker(root: Path) -> dict:
    path = root / "generated" / "validation.json"
    obj = core.load_json(path, 16_000)
    required = {"schemaVersion", "status", "stateDigest", "validatedAt"}
    core.require_schema(obj, path); core.require_keys(obj, required, required, path)
    if obj["status"] != "PASS" or not re.fullmatch(r"[a-f0-9]{64}", str(obj["stateDigest"])):
        raise core.ControlError("invalid control-state validation marker")
    core.parse_time(obj["validatedAt"])
    if obj["stateDigest"] != state_digest(root):
        raise core.ControlError("live control state changed after its validation marker")
    return obj


def relation_errors(lanes, resources, claims, rclaims, now) -> list[str]:
    # A lane claim may exist briefly while its declared resource leases are acquired.
    # PR acceptance, not claim representation, requires all matching leases.
    errors = [e for e in core.validate_relations(lanes, resources, claims, rclaims, now)
              if "missing matching active resource lease" not in e]
    for claim in claims:
        if claim.is_stale(now) or claim.lane_id not in lanes:
            continue
        lane = lanes[claim.lane_id]
        extra = sorted(set(claim.resources) - set(lane["resources"]))
        if extra:
            errors.append(f"{claim.path}: resources outside lane declaration: {extra}")
        if claim.slot_id == "primary":
            missing = sorted(set(lane["resources"]) - set(claim.resources))
            if missing:
                errors.append(f"{claim.path}: primary claim omits lane resources: {missing}")
    return errors


def wip_errors(cfg, lanes, claims, now) -> list[str]:
    errors = []
    active_epics = {lane["epicId"] for lane in lanes.values()
                    if lane["state"] not in core.TERMINAL_LANE_STATES | core.BLOCKING_LANE_STATES}
    if len(active_epics) > cfg["wip"]["maxMajorEpics"]:
        errors.append(f"active major epics {len(active_epics)} exceed maxMajorEpics {cfg['wip']['maxMajorEpics']}")
    primaries = [c for c in claims if c.slot_id == "primary" and not c.is_stale(now)]
    if len(primaries) > cfg["wip"]["maxPrimaryImplementationLanes"]:
        errors.append(f"active primaries {len(primaries)} exceed maxPrimaryImplementationLanes {cfg['wip']['maxPrimaryImplementationLanes']}")
    return errors


def ready_slots(cfg, lanes, resources, claims, rclaims, now, health=None):
    ready = core.derive_ready_slots(cfg, lanes, resources, claims, rclaims, now)
    integration_backlog = sum(1 for lane in lanes.values() if lane["state"] == "INTEGRATION_READY")
    if integration_backlog >= cfg["wip"]["integrationBacklogThrottle"]:
        ready = [slot for slot in ready if slot.slot_id != "primary"]
    if cfg["scheduler"].get("redMainOverride", True) and health and health.get("status") == "RED":
        allowed = {lid for lid, lane in lanes.items() if set(lane.get("tags", [])) & {"red-main", "control-repair"}}
        ready = [slot for slot in ready if slot.lane_id in allowed]
    return ready


def validate_all(root: Path, now) -> dict:
    cfg, lanes, resources, claims, rclaims, workers, events = read_tree(root)
    errors = relation_errors(lanes, resources, claims, rclaims, now) + wip_errors(cfg, lanes, claims, now)
    if errors: raise core.ControlError("\n".join(errors))
    health = main_health(root)
    return {"lanes": len(lanes), "resources": len(resources), "claims": len(claims),
            "resourceClaims": len(rclaims), "workers": len(workers), "events": len(events),
            "mainHealth": health["status"], "readySlots": len(ready_slots(cfg, lanes, resources, claims, rclaims, now, health)),
            "stateDigest": state_digest(root)}


def render_board(root: Path, now) -> dict:
    cfg, lanes, resources, claims, rclaims, workers, events = read_tree(root)
    errors = relation_errors(lanes, resources, claims, rclaims, now) + wip_errors(cfg, lanes, claims, now)
    if errors: raise core.ControlError("\n".join(errors))
    health = main_health(root); active, stale = core.active_and_stale_claims(claims, now)
    ready = ready_slots(cfg, lanes, resources, claims, rclaims, now, health)
    board = {
        "schemaVersion": 1, "generatedAt": now.isoformat(), "controlBranch": cfg["controlBranch"],
        "stateDigest": state_digest(root), "mainHealth": health,
        "summary": {"lanes": len(lanes), "readySlots": len(ready), "activeClaims": len(active), "staleClaims": len(stale),
                    "activeResourceClaims": sum(1 for c in rclaims if not c.is_stale(now)), "workers": len(workers),
                    "blockedExternalLanes": sum(1 for lane in lanes.values() if lane["state"] == "BLOCKED_EXTERNAL")},
        "readySlots": [{"laneId": s.lane_id, "slotId": s.slot_id, "role": s.role, "score": s.score, "reason": s.reason,
                        "resources": list(s.resources), "writeScopes": list(s.write_scopes)} for s in ready],
        "activeClaims": [{"laneId": c.lane_id, "slotId": c.slot_id, "workerId": c.worker_id, "branch": c.branch, "pr": c.pr,
                          "generation": c.generation, "expiresAt": c.expires_at().isoformat()} for c in sorted(active, key=lambda c:(c.lane_id,c.slot_id))],
        "staleClaims": [{"laneId": c.lane_id, "slotId": c.slot_id, "workerId": c.worker_id, "generation": c.generation,
                         "expiredAt": c.expires_at().isoformat(), "branch": c.branch, "pr": c.pr} for c in sorted(stale,key=lambda c:(c.lane_id,c.slot_id))],
        "blockedLanes": [{"laneId": lid, "state": lane["state"], "reason": (lane.get("blockers", ["explicit lane state"])[0]
                          if lane.get("blockers") else core.dependencies_satisfied(lane, lanes)[1])}
                         for lid, lane in sorted(lanes.items()) if lane["state"] in core.BLOCKING_LANE_STATES],
        "resources": [{"resourceId": rid, "state": res["state"], "capacity": res["capacity"], "mode": res["mode"],
                       "activeOwners": sum(1 for c in rclaims if c.resource_id == rid and not c.is_stale(now))}
                      for rid, res in sorted(resources.items(), key=lambda item:item[1]["order"])],
        "recentEvents": events[-20:],
    }
    lane_states = {}; event_counts = {}
    for lane in lanes.values(): lane_states[lane["state"]] = lane_states.get(lane["state"], 0) + 1
    for event in events: event_counts[event["eventType"]] = event_counts.get(event["eventType"], 0) + 1
    board["metrics"] = {"schemaVersion": 1, "generatedAt": board["generatedAt"], "laneStates": lane_states,
                        "eventCounts": event_counts, "activeClaims": len(active), "staleClaims": len(stale),
                        "readySlots": len(ready), "reviewBacklog": sum(1 for x in lanes.values() if x["state"] in {"REVIEW","NEEDS_CHANGES"}),
                        "integrationBacklog": sum(1 for x in lanes.values() if x["state"] == "INTEGRATION_READY"),
                        "activeEpics": sorted({x["epicId"] for x in lanes.values() if x["state"] not in core.TERMINAL_LANE_STATES | core.BLOCKING_LANE_STATES}),
                        "note": "Gross lines written are diagnostic, not a success metric."}
    return board


def dashboard(board: dict) -> str:
    out = ["# UNRENDERED Swarm Control Plane", "", f"Generated: `{board['generatedAt']}`", "",
           f"Canonical main: **{board['mainHealth']['status']}** `{board['mainHealth']['headSha'] or 'unknown'}`", "",
           f"State digest: `{board['stateDigest']}`", "", "## Summary", "",
           f"- ready slots: **{board['summary']['readySlots']}**", f"- active claims: **{board['summary']['activeClaims']}**",
           f"- stale claims: **{board['summary']['staleClaims']}**", f"- blocked-external lanes: **{board['summary']['blockedExternalLanes']}**", "", "## Ready slots", ""]
    out += [f"- `{x['laneId']}/{x['slotId']}` — **{x['role']}** — score {x['score']} — {x['reason']}" for x in board["readySlots"][:30]] or ["_No runnable slot. Idle/review is preferable to duplicate implementation._"]
    out += ["", "## Active claims", ""]
    out += [f"- `{x['laneId']}/{x['slotId']}` → `{x['workerId']}`; lease to `{x['expiresAt']}`" for x in board["activeClaims"]] or ["_None._"]
    out += ["", "## Blocked lanes", ""]
    out += [f"- `{x['laneId']}` — **{x['state']}** — {x['reason']}" for x in board["blockedLanes"]] or ["_None._"]
    out += ["", "> Generated state is disposable. Atomic claims/resource leases are ownership authority.", ""]
    return "\n".join(out)


def pr_check(root: Path, event_path: Path, changed_path: Path, now) -> dict:
    cfg, lanes, resources, claims, rclaims, workers, _ = read_tree(root)
    errors = relation_errors(lanes, resources, claims, rclaims, now) + wip_errors(cfg, lanes, claims, now)
    if errors: raise core.ControlError("\n".join(errors))
    if cfg["scheduler"].get("requireValidatedState", False): validate_marker(root)
    event = core.load_json(event_path, 4_000_000); pr = event.get("pull_request")
    if not isinstance(pr, dict): raise core.ControlError("pull_request event required")
    meta = core.metadata_from_pr_body(pr.get("body") or "")
    if meta["Control-Schema"] != "1": raise core.ControlError("unsupported Control-Schema")
    lid = core.ensure_identifier(meta["Swarm-Lane"], core.LANE_ID_RE, "Swarm-Lane", event_path)
    sid = core.ensure_identifier(meta["Swarm-Slot"], core.SLOT_ID_RE, "Swarm-Slot", event_path)
    wid = core.ensure_identifier(meta["Swarm-Worker"], core.WORKER_ID_RE, "Swarm-Worker", event_path)
    token = core.ensure_identifier(meta["Swarm-Claim-Token"], core.TOKEN_RE, "Swarm-Claim-Token", event_path)
    lane = lanes.get(lid)
    if lane is None or lane["state"] in core.BLOCKING_LANE_STATES | core.TERMINAL_LANE_STATES: raise core.ControlError("lane is not writable")
    worker = workers.get(wid)
    if workers and worker is None: raise core.ControlError("worker record missing")
    if worker:
        if worker["status"] == "STOPPED": raise core.ControlError("worker is STOPPED")
        if worker.get("laneId") and worker["laneId"] != lid: raise core.ControlError("worker lane mismatch")
        if worker.get("slotId") and worker["slotId"] != sid: raise core.ControlError("worker slot mismatch")
    claim = next((c for c in claims if c.lane_id==lid and c.slot_id==sid and c.worker_id==wid and c.claim_token==token), None)
    if claim is None or claim.is_stale(now): raise core.ControlError("matching live authoritative claim required")
    head = pr.get("head", {}).get("ref")
    if claim.branch and head != claim.branch: raise core.ControlError("PR head does not match claim")
    if worker and worker.get("branch") and head != worker["branch"]: raise core.ControlError("PR head does not match worker")
    if claim.pr is not None and claim.pr != pr.get("number"): raise core.ControlError("claim is attached to another PR")
    slot = next((s for s in lane["slots"] if s["slotId"] == sid), None)
    if slot is None: raise core.ControlError("claim slot absent from lane")
    if "writeScopes" in slot: allowed = list(slot["writeScopes"])
    elif sid == "primary" or "implement" in slot["role"].lower() or "integrat" in slot["role"].lower(): allowed = list(lane["writeScopes"])
    else: allowed = []
    allowed += ["tests/**", "Docs/**", ".github/pull_request_template.md"]
    changed = [x.strip() for x in changed_path.read_text().splitlines() if x.strip()]
    bad = [p for p in changed if not core.path_matches_scope(p, allowed)]
    if bad: raise core.ControlError("PR exceeds lane/slot write scope: " + ", ".join(sorted(bad)[:20]))
    active = {(c.resource_id,c.worker_id,c.lane_id,c.claim_token) for c in rclaims if not c.is_stale(now)}
    missing = sorted(r for r in claim.resources if (r,wid,lid,token) not in active)
    if missing: raise core.ControlError(f"claim lacks active resource leases: {missing}")
    protected = []; required = set()
    for path in changed:
        for item in cfg["protectedScopes"]:
            if core.path_matches_scope(path, [item["pattern"]]): protected.append(path); required.add(item["resource"])
    undeclared = sorted(required - set(claim.resources))
    if undeclared: raise core.ControlError(f"protected scope lacks declared resources: {undeclared}")
    return {"laneId": lid, "slotId": sid, "workerId": wid, "changedFiles": len(changed), "protectedTouched": protected, "stateDigest": state_digest(root)}


def raw_map(root: Path, pattern: str, max_bytes: int) -> dict:
    return {str(p.relative_to(root)): core.load_json(p, max_bytes) for p in sorted(root.glob(pattern))}


def lease_transition(old: dict, new: dict, label: str, start_key: str, require_takeover_of: bool) -> None:
    old_hb, new_hb = core.parse_time(old["heartbeatAt"]), core.parse_time(new["heartbeatAt"])
    if new_hb < old_hb: raise core.ControlError(f"{label}: heartbeat moved backwards")
    same = old["workerId"] == new["workerId"] and old["claimToken"] == new["claimToken"]
    if same:
        if new["generation"] != old["generation"]: raise core.ControlError(f"{label}: same owner changed generation")
        return
    expiry = old_hb + timedelta(seconds=int(old["leaseSeconds"]))
    if core.parse_time(new[start_key]) < expiry: raise core.ControlError(f"{label}: takeover before old lease expired")
    if new["generation"] != old["generation"] + 1: raise core.ControlError(f"{label}: takeover generation must increment once")
    if require_takeover_of and new.get("takeoverOf") != old["workerId"]: raise core.ControlError(f"{label}: takeoverOf must identify previous worker")


def transition_check(before: Path, after: Path) -> dict:
    bc, ac = raw_map(before,"claims/*/*.json",32_000), raw_map(after,"claims/*/*.json",32_000)
    br, ar = raw_map(before,"resource-claims/*.json",24_000), raw_map(after,"resource-claims/*.json",24_000)
    for key in sorted(bc.keys() & ac.keys()): lease_transition(bc[key], ac[key], f"claim {key}", "claimedAt", True)
    for key in sorted(br.keys() & ar.keys()): lease_transition(br[key], ar[key], f"resource claim {key}", "acquiredAt", False)
    be = {str(p.relative_to(before)):p.read_bytes() for p in before.glob("events/*/*.json")}; ae = {str(p.relative_to(after)):p.read_bytes() for p in after.glob("events/*/*.json")}
    deleted = sorted(be.keys()-ae.keys()); changed = sorted(k for k in be.keys()&ae.keys() if be[k] != ae[k])
    if deleted or changed: raise core.ControlError(f"immutable events changed/deleted: changed={changed}, deleted={deleted}")
    return {"status":"PASS","claimTransitions":len(bc.keys()&ac.keys()),"resourceClaimTransitions":len(br.keys()&ar.keys()),"immutableEventsChecked":len(be)}


def render(root: Path, now) -> dict:
    board = render_board(root, now); g = root / "generated"; g.mkdir(parents=True, exist_ok=True)
    (g/"board.json").write_text(json.dumps(board,indent=2,sort_keys=True)+"\n"); (g/"dashboard.md").write_text(dashboard(board))
    (g/"metrics.json").write_text(json.dumps(board["metrics"],indent=2,sort_keys=True)+"\n")
    marker = {"schemaVersion":1,"status":"PASS","stateDigest":board["stateDigest"],"validatedAt":now.isoformat()}
    (g/"validation.json").write_text(json.dumps(marker,indent=2,sort_keys=True)+"\n")
    return board


def sync_main_health(root: Path, sha: str, conclusion: str, run_id: int, updated_at: str) -> dict:
    if not re.fullmatch(r"[a-f0-9]{40}", sha): raise core.ControlError("invalid main SHA")
    if not re.fullmatch(r"[a-z_]{2,32}", conclusion): raise core.ControlError("invalid workflow conclusion")
    updated = core.parse_time(updated_at); status = "GREEN" if conclusion == "success" else "RED"
    path = root/"health"/"main.json"; path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps({"schemaVersion":1,"status":status,"headSha":sha,"workflowRunId":run_id,"updatedAt":updated.isoformat(),"conclusion":conclusion},indent=2,sort_keys=True)+"\n")
    lane_path = root/"lanes"/"OPS-MAIN-HEALTH.json"
    if not lane_path.exists(): raise core.ControlError("OPS-MAIN-HEALTH lane required")
    lane = core.load_json(lane_path); lane["state"] = "DONE" if status == "GREEN" else "READY"; lane["notes"] = f"Canonical CI run {run_id} for {sha} concluded {conclusion}."
    lane_path.write_text(json.dumps(lane,indent=2)+"\n")
    return {"status":status,"headSha":sha,"workflowRunId":run_id}


def main() -> int:
    p=argparse.ArgumentParser(); sub=p.add_subparsers(dest="cmd",required=True)
    for name in ("validate","render","recommend"):
        x=sub.add_parser(name); x.add_argument("--root",default=".swarm"); x.add_argument("--now")
        if name=="recommend": x.add_argument("--limit",type=int,default=5)
    s=sub.add_parser("simulate"); s.add_argument("--workers",type=int,default=30)
    pc=sub.add_parser("pr-check"); pc.add_argument("--root",required=True); pc.add_argument("--event",required=True); pc.add_argument("--changed-files",required=True); pc.add_argument("--now")
    tc=sub.add_parser("transition-check"); tc.add_argument("--before-root",required=True); tc.add_argument("--after-root",required=True)
    h=sub.add_parser("sync-main-health"); h.add_argument("--root",default=".swarm"); h.add_argument("--sha",required=True); h.add_argument("--conclusion",required=True); h.add_argument("--run-id",type=int,required=True); h.add_argument("--updated-at",required=True)
    a=p.parse_args()
    try:
        now = core.parse_time(a.now) if getattr(a,"now",None) else core.now_utc()
        if a.cmd=="validate": print(json.dumps({"status":"PASS",**validate_all(Path(a.root),now)},indent=2))
        elif a.cmd=="render": print(json.dumps(render(Path(a.root),now)["summary"],indent=2))
        elif a.cmd=="recommend":
            root=Path(a.root); cfg,lanes,res,claims,rc,_,_=read_tree(root); errs=relation_errors(lanes,res,claims,rc,now)+wip_errors(cfg,lanes,claims,now)
            if errs: raise core.ControlError("\n".join(errs))
            slots=ready_slots(cfg,lanes,res,claims,rc,now,main_health(root))[:max(1,min(a.limit,20))]
            print(json.dumps([{"laneId":s.lane_id,"slotId":s.slot_id,"role":s.role,"score":s.score,"reason":s.reason,"resources":list(s.resources),"writeScopes":list(s.write_scopes)} for s in slots],indent=2))
        elif a.cmd=="simulate": print(json.dumps(core.simulate(a.workers),indent=2))
        elif a.cmd=="pr-check": print(json.dumps({"status":"PASS",**pr_check(Path(a.root),Path(a.event),Path(a.changed_files),now)},indent=2))
        elif a.cmd=="transition-check": print(json.dumps(transition_check(Path(a.before_root),Path(a.after_root)),indent=2))
        elif a.cmd=="sync-main-health": print(json.dumps(sync_main_health(Path(a.root),a.sha,a.conclusion,a.run_id,a.updated_at),indent=2))
        return 0
    except core.ControlError as exc:
        print(f"SWARM CONTROL ERROR: {exc}",file=sys.stderr); return 2

if __name__ == "__main__": raise SystemExit(main())
