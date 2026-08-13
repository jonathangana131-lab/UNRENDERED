from __future__ import annotations

import math
from collections import Counter
from copy import deepcopy
from dataclasses import dataclass
from typing import Any, Mapping, Sequence

from .model import *
from .model import _id
from .work import _remember, rabbit_hole
def objective_done(graph: Mapping[str, Any], objective_id: str) -> tuple[bool, list[str]]:
    obj = graph["objectives"][objective_id]; missing = [c for c, ok in zip(obj["finishConditions"], obj["finishSatisfied"]) if not ok]
    missing += [f"unresolved {graph['blockers'][bid]['severity']} blocker {bid}" for bid in obj["blockerIds"] if graph["blockers"][bid]["state"] != "RESOLVED" and graph["blockers"][bid]["severity"] in {"P0","P1"}]
    if obj["integrationState"] != "MAIN": missing.append("integration has not reached MAIN")
    for dim in ("functionality","testing","integration"):
        if obj["featureGenome"][dim]["state"] not in {"ACCEPTED","NOT_APPLICABLE"}: missing.append(f"{dim} not accepted")
    if obj["externalTruthRequired"] and obj["featureGenome"]["runtimeTruth"]["state"] != "ACCEPTED": missing.append("external runtime truth not accepted")
    return not missing, missing


def complete_objective(graph: dict[str, Any], objective_id: str, now: dt.datetime | None = None) -> None:
    done, missing = objective_done(graph, objective_id)
    if not done: raise ValidationError("objective not done: " + "; ".join(missing))
    graph["objectives"][objective_id].update({"status": "DONE", "lastMeaningfulProgress": fmt(now)}); _remember(graph, "OBJECTIVE_DONE", graph["objectives"][objective_id]["title"], objective_id, now)


def objective_score(graph: Mapping[str, Any], objective_id: str, now: dt.datetime | None = None) -> float:
    obj = graph["objectives"][objective_id]
    if obj["status"] in {"DONE","EXTERNAL_BLOCKED"} or any(graph["objectives"][dep]["status"] != "DONE" for dep in obj["dependencies"]): return -math.inf
    severity = {"P0":1200,"P1":700,"P2":250,"P3":60}[obj["severity"]]; fanout = sum(objective_id in other["dependencies"] for other in graph["objectives"].values()); remaining = sum(not x for x in obj["finishSatisfied"]); age = max(0, (now_utc(now) - parse_time(obj["lastMeaningfulProgress"])).total_seconds() / 86400)
    score = severity + (400 if obj["releaseBlocking"] else 0) + (180 if obj["safetyCritical"] else 0) + obj["userValue"] * 35 + fanout * 80 + max(0, 9 - obj["priority"]) * 20 + min(age * 25, 250)
    if remaining <= 2: score += 300
    elif remaining <= 4: score += 120
    if obj["status"] in {"REVIEW","INTEGRATING"}: score += 220
    if graph["modes"].get("surgeMissionId") == obj["missionId"]: score += 1000
    return score


def role_allocation(graph: Mapping[str, Any], workers: int = 30) -> dict[str, int]:
    if workers < 1: raise ValidationError("workers must be positive")
    active = [x for x in graph["workItems"].values() if x["status"] not in {"DONE","SUPERSEDED","ARCHIVED"}]
    reviews = sum(x["status"] == "REVIEW" for x in active); integrations = sum(x["status"] == "INTEGRATING" for x in active)
    b, r, i = .58, .22, .20
    if integrations >= max(3, workers // 8): b, r, i = .46, .20, .34
    if reviews >= max(4, workers // 6): b, r, i = .46, .36, .18
    if graph["modes"].get("surgeMissionId"): b, r, i = .50, .23, .27
    out = {"builder": round(workers * b), "reviewer": round(workers * r)}; out["integrator"] = workers - out["builder"] - out["reviewer"]; return out


@dataclass(frozen=True)
class MissionPacket:
    mission_id: str; objective_id: str; work_item_id: str; role: str; priority_score: float; packet: dict[str, Any]


def recommend(graph: Mapping[str, Any], worker_ids: Sequence[str] = (), limit: int = 30, now: dt.datetime | None = None) -> list[MissionPacket]:
    validate_graph(graph); candidates = []
    for item in graph["workItems"].values():
        if item["status"] not in {"QUEUED","REVIEW","INTEGRATING","BLOCKED"}: continue
        score = objective_score(graph, item["objectiveId"], now)
        if score == -math.inf: continue
        blocker = graph["blockers"].get(item.get("blockerId"))
        if blocker and blocker["state"] == "EXTERNAL": continue
        score += 140 if item["status"] == "INTEGRATING" else (120 if item["status"] == "REVIEW" else 0)
        candidates.append((score, item))
    candidates.sort(key=lambda pair: (-pair[0], pair[1]["createdAt"], pair[1]["workItemId"]))
    packets = []
    for index, (score, item) in enumerate(candidates[:limit]):
        obj = graph["objectives"][item["objectiveId"]]; mission = graph["missions"][item["missionId"]]; blocker = graph["blockers"].get(item.get("blockerId"))
        packets.append(MissionPacket(item["missionId"], item["objectiveId"], item["workItemId"], item["role"], score, {"MISSION": mission["title"], "WHY_IT_MATTERS": mission["why"], "CURRENT_STATE": obj["status"], "CANONICAL_BRANCH": obj.get("canonicalBranch", ""), "PRIMARY_SCOPE": item["primaryScope"], "FORBIDDEN_AREAS": item["forbiddenAreas"], "KNOWN_BLOCKERS": [graph["blockers"][bid]["symptom"] for bid in obj["blockerIds"] if graph["blockers"][bid]["state"] != "RESOLVED"], "RELEVANT_EVIDENCE": obj["evidenceIds"][-12:], "EXIT_CONDITION": blocker["exitCondition"] if blocker else item["outcome"], "ASSIGNED_WORKER": worker_ids[index] if index < len(worker_ids) else ""}))
    return packets


def authorize_tournament(graph: dict[str, Any], tournament_id: str, blocker_id: str, candidate_limit: int = 3, now: dt.datetime | None = None) -> None:
    if blocker_id not in graph["blockers"] or not 2 <= candidate_limit <= 3: raise ValidationError("invalid tournament")
    graph["solutions"][tournament_id] = {"tournamentId": tournament_id, "blockerId": blocker_id, "authorized": True, "candidateLimit": candidate_limit, "candidateWorkItemIds": [], "selectedWorkItemId": "", "state": "EXPERIMENTAL", "createdAt": fmt(now), "selectionEvidence": {}}


def select_tournament_winner(graph: dict[str, Any], tournament_id: str, winner: str, comparison: Mapping[str, Any], now: dt.datetime | None = None) -> None:
    tournament = graph["solutions"].get(tournament_id); candidates = [wid for wid, item in graph["workItems"].items() if item.get("tournamentId") == tournament_id]
    if not tournament or not tournament.get("authorized") or winner not in candidates: raise ValidationError("invalid tournament winner")
    tournament.update({"candidateWorkItemIds": candidates, "selectedWorkItemId": winner, "state": "SELECTED", "selectionEvidence": dict(comparison)})
    for wid in candidates:
        item = graph["workItems"][wid]
        if wid == winner: item["branchState"] = "SELECTED"
        else: item["status"] = "SUPERSEDED"; item["branchState"] = "SUPERSEDED"; graph["metrics"]["supersededBranches"] += 1
    _remember(graph, "SOLUTION_SELECTED", f"{tournament_id} selected {winner}", graph["workItems"][winner]["objectiveId"], now)


def enqueue_merge(graph: dict[str, Any], work_item_ids: Sequence[str], candidate_id: str, required_suites: Sequence[str], now: dt.datetime | None = None) -> None:
    if not work_item_ids: raise ValidationError("merge candidate requires work")
    for wid in work_item_ids:
        if graph["workItems"][wid]["status"] not in {"REVIEW","INTEGRATING","DONE"}: raise ValidationError("work not accepted enough for merge train")
    graph["mergeTrain"]["queue"].append({"candidateId": _id(candidate_id, "candidateId"), "workItemIds": list(work_item_ids), "state": "QUEUED", "requiredSuites": list(required_suites), "results": {}, "createdAt": fmt(now), "startedAt": "", "completedAt": ""})
    for wid in work_item_ids: graph["workItems"][wid]["status"] = "INTEGRATING"; graph["workItems"][wid]["integrationWorld"] = "NEXT"


def start_merge(graph: dict[str, Any], candidate_id: str, now: dt.datetime | None = None) -> None:
    if graph["mergeTrain"].get("activeCandidate"): raise ConflictError("merge train already active")
    entry = next((x for x in graph["mergeTrain"]["queue"] if x["candidateId"] == candidate_id), None)
    if not entry or entry["state"] != "QUEUED": raise ConflictError("candidate not queued")
    entry.update({"state": "ACTIVE", "startedAt": fmt(now)}); graph["mergeTrain"]["activeCandidate"] = candidate_id


def finish_merge(graph: dict[str, Any], candidate_id: str, results: Mapping[str, bool], integrated: bool, now: dt.datetime | None = None) -> None:
    entry = next((x for x in graph["mergeTrain"]["queue"] if x["candidateId"] == candidate_id), None)
    if not entry or graph["mergeTrain"].get("activeCandidate") != candidate_id: raise ConflictError("candidate not active")
    missing = [suite for suite in entry["requiredSuites"] if suite not in results]
    if missing: raise ValidationError("missing merge train results")
    passed = integrated and all(results[suite] for suite in entry["requiredSuites"]); entry.update({"state": "INTEGRATED" if passed else "FAILED", "results": dict(results), "completedAt": fmt(now)})
    for wid in entry["workItemIds"]:
        item = graph["workItems"][wid]
        if passed: item.update({"status": "DONE", "integrationWorld": "MAIN", "branchState": "INTEGRATED"}); graph["objectives"][item["objectiveId"]]["integrationState"] = "MAIN"
        else: item["status"] = "INTEGRATING"
    graph["mergeTrain"]["history"].append(deepcopy(entry)); graph["mergeTrain"]["queue"] = [x for x in graph["mergeTrain"]["queue"] if x["candidateId"] != candidate_id]; graph["mergeTrain"]["activeCandidate"] = None


def health_report(graph: Mapping[str, Any], workers: int = 30, now: dt.datetime | None = None) -> dict[str, Any]:
    active = [x for x in graph["workItems"].values() if x["status"] not in {"DONE","SUPERSEDED","ARCHIVED"}]; selected = Counter(x["objectiveId"] for x in graph["branches"].values() if x.get("state") == "SELECTED"); branches = [x for x in graph["branches"].values() if x.get("state") not in {"INTEGRATED","ARCHIVED"}]
    branch_explosion = sum(max(0, n - 1) for n in selected.values()) + max(0, len(branches) - max(8, len(graph["objectives"]) // 2)); merge_backlog = sum(x["status"] == "INTEGRATING" for x in active); stale = 0
    for blocker in graph["blockers"].values():
        if blocker["state"] in {"OPEN","OWNED"} and (now_utc(now) - parse_time(blocker["lastProgressAt"])).total_seconds() >= 43200: stale += 1
    rabbits = sum(rabbit_hole(graph, bid)[0] for bid in graph["blockers"]); pressure = branch_explosion * 3 + merge_backlog * 2 + stale * 2 + rabbits * 4
    health = "RED" if pressure >= 16 else "ORANGE" if pressure >= 9 else "YELLOW" if pressure >= 4 else "GREEN"
    start, closed, new = int(graph["metrics"]["startBlockers"]), int(graph["metrics"]["closedBlockers"]), int(graph["metrics"]["newLegitimateBlockers"]); remaining = sum(b["state"] != "RESOLVED" for b in graph["blockers"].values())
    return {"health": health, "workers": workers, "allocation": role_allocation(graph, workers), "signals": {"activeWorkItems": len(active), "duplicateWorkPrevented": graph["metrics"]["duplicateTasksPrevented"], "activeBranches": len(branches), "branchExplosion": branch_explosion, "mergeBacklog": merge_backlog, "staleBlockers": stale, "rabbitHoles": rabbits}, "scoreboard": {"started": start, "closed": closed, "newLegitimate": new, "remaining": remaining}}


def complexity_review(production_loc: int, test_loc: int, workflow_count: int, branch_count: int, validation_count: int, duplicate_checks: int, integration_overhead: int) -> dict[str, Any]:
    production = max(1, production_loc); ratio = test_loc / production; pressure = (test_loc + validation_count * 50 + workflow_count * 80) / production; flags = []
    if ratio >= 4: flags.append("test LOC exceeds 4x production LOC")
    if workflow_count >= 20: flags.append("workflow count pathological")
    if branch_count >= 20: flags.append("branch count pathological")
    if pressure >= 6: flags.append("validation infrastructure dominates production")
    if duplicate_checks >= 10: flags.append("duplicate validation primitives should consolidate")
    if integration_overhead >= 10: flags.append("integration overhead excessive")
    return {"reviewRequired": bool(flags), "flags": flags, "testToProductionRatio": round(ratio, 2), "validationPressure": round(pressure, 2)}


def momentum_score(*, meaningful_code: int, blockers_removed: int, dependencies_unlocked: int, acceptance_gained: int, integration_gained: int, user_visible_improvement: int, regressions: int, duplicate_work: int) -> int:
    return meaningful_code + blockers_removed * 100 + dependencies_unlocked * 70 + acceptance_gained * 40 + integration_gained * 70 + user_visible_improvement * 60 - regressions * 120 - duplicate_work * 80


def user_status(graph: Mapping[str, Any], workers: int = 30, now: dt.datetime | None = None) -> str:
    report = health_report(graph, workers, now); features = Counter(); roles = Counter()
    for item in graph["workItems"].values():
        if item["status"] in {"DONE","SUPERSEDED","ARCHIVED"}: continue
        features[graph["objectives"][item["objectiveId"]]["title"]] += 1; roles[item["role"]] += 1
    lines = [f"UNRENDERED SWARM V16 — {report['health']}", f"{workers} agents"]
    if features: lines.append("Building: " + ", ".join(f"{name} — {count}" for name, count in features.most_common(8)))
    if roles: lines.append("Roles: " + ", ".join(f"{role} {count}" for role, count in roles.items()))
    blockers = sorted([b for b in graph["blockers"].values() if b["state"] != "RESOLVED"], key=lambda b: ({"P0":0,"P1":1,"P2":2,"P3":3}[b["severity"]], b["firstObserved"]))
    if blockers: lines.append("Current blockers: " + " | ".join(f"{b['severity']} {b['symptom'][:120]}" for b in blockers[:6]))
    lines.append(f"Waste: duplicate tasks prevented {report['signals']['duplicateWorkPrevented']}; branch explosion {report['signals']['branchExplosion']}; merge backlog {report['signals']['mergeBacklog']}")
    score = report["scoreboard"]; lines.append(f"Blocker scoreboard: started {score['started']} - closed {score['closed']} + new {score['newLegitimate']} = remaining {score['remaining']}")
    return "\n".join(lines)

