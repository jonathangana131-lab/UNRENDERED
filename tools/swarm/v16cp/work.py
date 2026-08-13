from __future__ import annotations

import math
import re
import uuid
from collections import Counter
from copy import deepcopy
from dataclasses import dataclass
from difflib import SequenceMatcher
from typing import Any, Mapping, Sequence

from .model import *
from .model import _id
def _remember(graph: dict[str, Any], kind: str, message: str, objective_id: str = "", now: dt.datetime | None = None, data: Mapping[str, Any] | None = None) -> None:
    graph["memory"].append({"eventId": uuid.uuid4().hex[:16], "type": kind, "objectiveId": objective_id, "message": str(message)[:3000], "data": dict(data or {}), "at": fmt(now)})
    graph["memory"] = graph["memory"][-512:]


def semantic_tokens(text: str) -> list[str]:
    out = []
    for token in TOKEN_RE.findall(str(text).lower()):
        if token in STOP or len(token) <= 1: continue
        if token.endswith("ing") and len(token) > 6: token = token[:-3]
        elif token.endswith("ed") and len(token) > 5: token = token[:-2]
        out.append(token)
    return out


def similarity(left: str, right: str) -> float:
    a, b = semantic_tokens(left), semantic_tokens(right)
    if not a or not b: return 0.0
    aset, bset = set(a), set(b); inter = aset & bset; union = aset | bset
    return min(1.0, .45 * len(inter) / max(1, len(union)) + .25 * len(inter) / max(1, min(len(aset), len(bset))) + .30 * SequenceMatcher(a=" ".join(a), b=" ".join(b)).ratio())


@dataclass(frozen=True)
class DuplicateDecision:
    duplicate: bool; score: float; existing_work_item_id: str; action: str; reason: str


def detect_duplicate(graph: Mapping[str, Any], title: str, outcome: str, objective_id: str, blocker_id: str = "", threshold: float = .60) -> DuplicateDecision:
    proposed = " ".join((title, outcome, objective_id, blocker_id)); best = ("", 0.0, "")
    for wid, item in graph.get("workItems", {}).items():
        if item.get("status") in {"DONE","SUPERSEDED","ARCHIVED"}: continue
        score = 1.0 if blocker_id and item.get("blockerId") == blocker_id else similarity(proposed, " ".join((item.get("title",""), item.get("outcome",""), item.get("objectiveId",""), item.get("blockerId",""))))
        if item.get("objectiveId") == objective_id: score = min(1.0, score + .08)
        if score > best[1]: best = (wid, score, item.get("role", "builder"))
    if best[1] >= threshold: return DuplicateDecision(True, best[1], best[0], "JOIN" if best[2] not in {"reviewer","integrator"} else best[2].upper(), f"semantic duplicate of active {best[0]}")
    return DuplicateDecision(False, best[1], best[0], "CREATE", "no substantial active duplicate")


def add_work_item(graph: dict[str, Any], *, work_item_id: str, mission_id: str, objective_id: str, title: str, outcome: str, role: str = "builder", blocker_id: str = "", scope: Sequence[str] = (), forbidden_areas: Sequence[str] = (), branch: str = "", source: Mapping[str, Any] | None = None, tournament_id: str = "", now: dt.datetime | None = None, allow_duplicate: bool = False) -> DuplicateDecision:
    _id(work_item_id, "workItemId")
    if objective_id not in graph["objectives"] or role not in ROLES: raise ValidationError("invalid work item")
    decision = detect_duplicate(graph, title, outcome, objective_id, blocker_id)
    if decision.duplicate and not allow_duplicate:
        graph["metrics"]["duplicateTasksPrevented"] += 1; _remember(graph, "DUPLICATE_SUPPRESSED", f"Suppressed {work_item_id}: {decision.reason}", objective_id, now); return decision
    if tournament_id and not graph["solutions"].get(tournament_id, {}).get("authorized"): raise ValidationError("tournament not authorized")
    stamp = fmt(now); branch_state = "EXPERIMENTAL" if tournament_id else ("SELECTED" if branch else "PROMISING")
    graph["workItems"][work_item_id] = {"workItemId": work_item_id, "missionId": mission_id, "objectiveId": objective_id, "blockerId": blocker_id, "title": str(title)[:500], "outcome": str(outcome)[:3000], "role": role, "status": "QUEUED", "primaryScope": list(scope), "forbiddenAreas": list(forbidden_areas), "branch": branch, "branchState": branch_state, "owner": "", "reviewer": "", "integrationWorld": "FRONTIER", "createdAt": stamp, "updatedAt": stamp, "source": dict(source or {}), "similarityKey": " ".join(sorted(set(semantic_tokens(title + " " + outcome)))), "evidenceIds": [], "tournamentId": tournament_id}
    if branch: graph["branches"][branch] = {"branch": branch, "missionId": mission_id, "objectiveId": objective_id, "state": branch_state, "world": "FRONTIER", "selectedAt": stamp if branch_state == "SELECTED" else "", "integratedAt": "", "pr": (source or {}).get("pr"), "source": dict(source or {})}
    _remember(graph, "WORK_CREATED", f"{work_item_id}: {outcome}", objective_id, now)
    return DuplicateDecision(False, decision.score, decision.existing_work_item_id, "CREATE", "created")


def add_blocker(graph: dict[str, Any], *, blocker_id: str, mission_id: str, objective_id: str, symptom: str, severity: str = "P2", exit_condition: str = "accepted evidence resolves blocker", external: bool = False, owner: str = "", now: dt.datetime | None = None, legitimate_new: bool = False) -> None:
    _id(blocker_id, "blockerId")
    if blocker_id in graph["blockers"]: raise ConflictError(blocker_id)
    stamp = fmt(now)
    graph["blockers"][blocker_id] = {"blockerId": blocker_id, "missionId": mission_id, "objectiveId": objective_id, "symptom": str(symptom)[:4000], "evidenceIds": [], "owner": owner, "backup": "", "severity": severity if severity in SEVERITIES else "P2", "firstObserved": stamp, "attempts": [], "currentHypothesis": "", "relatedBranches": [], "knownDuplicateAttempts": [], "nextAction": "", "exitCondition": str(exit_condition)[:3000], "state": "EXTERNAL" if external else ("OWNED" if owner else "OPEN"), "lastProgressAt": stamp}
    obj = graph["objectives"][objective_id]
    if blocker_id not in obj["blockerIds"]: obj["blockerIds"].append(blocker_id)
    obj["status"] = "EXTERNAL_BLOCKED" if external else "BLOCKED"
    graph["metrics"]["newLegitimateBlockers"] += int(legitimate_new); graph["metrics"]["startBlockers"] += int(not legitimate_new)


def record_blocker_attempt(graph: dict[str, Any], blocker_id: str, *, worker: str, approach: str, result: str, meaningful_progress: bool = False, branch: str = "", evidence_ids: Sequence[str] = (), now: dt.datetime | None = None) -> None:
    blocker = graph["blockers"][blocker_id]
    blocker["attempts"].append({"worker": worker, "approach": str(approach)[:2000], "result": str(result)[:2000], "branch": branch, "evidenceIds": list(evidence_ids), "meaningfulProgress": bool(meaningful_progress), "at": fmt(now)})
    blocker["attempts"] = blocker["attempts"][-64:]
    if meaningful_progress: blocker["lastProgressAt"] = fmt(now); graph["metrics"]["meaningfulProgressEvents"] += 1
    recent = blocker["attempts"][-5:]
    if len(recent) >= 4 and sum(bool(x["meaningfulProgress"]) for x in recent) <= 1:
        family = "-".join(blocker_id.split("-")[:3])
        for key in ("convergenceFamilies", "frozenBranchFamilies"):
            if family not in graph["modes"][key]: graph["modes"][key].append(family)
        _remember(graph, "CONVERGENCE_MODE", f"Freeze competing branches and consolidate {blocker_id}", blocker["objectiveId"], now)


def rabbit_hole(graph: Mapping[str, Any], blocker_id: str) -> tuple[bool, str]:
    attempts = graph["blockers"][blocker_id]["attempts"]
    if len(attempts) < 5: return False, "insufficient attempts"
    workers = len({x.get("worker") for x in attempts if x.get("worker")}); branches = len({x.get("branch") for x in attempts if x.get("branch")}); progress = sum(bool(x.get("meaningfulProgress")) for x in attempts); activity = len(attempts) + workers + branches
    return activity >= 12 and progress <= 1, f"activity={activity}, progress={progress}"


def resolve_blocker(graph: dict[str, Any], blocker_id: str, evidence_ids: Sequence[str], resolution: str, now: dt.datetime | None = None) -> None:
    if not evidence_ids: raise ValidationError("blocker resolution requires evidence")
    blocker = graph["blockers"][blocker_id]
    if blocker["state"] == "RESOLVED": return
    blocker.update({"state": "RESOLVED", "evidenceIds": list(dict.fromkeys(blocker["evidenceIds"] + list(evidence_ids))), "currentHypothesis": str(resolution)[:3000], "lastProgressAt": fmt(now)})
    graph["metrics"]["closedBlockers"] += 1; _remember(graph, "BLOCKER_RESOLVED", f"{blocker_id}: {resolution}", blocker["objectiveId"], now)


def add_evidence(graph: dict[str, Any], *, evidence_id: str, objective_id: str, evidence_type: str, status: str, truth_class: str, source_digest: str, dependency_digest: str, environment_digest: str, affected_paths: Sequence[str], details: Mapping[str, Any] | None = None, now: dt.datetime | None = None) -> None:
    _id(evidence_id, "evidenceId")
    if status not in {"PASS","FAIL","STALE","PENDING"} or truth_class not in TRUTH_CLASSES: raise ValidationError("invalid evidence")
    details = dict(details or {})
    if truth_class in EXTERNAL_TRUTH_CLASSES and not details.get("externalAuthorityExplicit"): raise ValidationError("external runtime evidence requires explicit authority")
    graph["evidence"][evidence_id] = {"evidenceId": evidence_id, "objectiveId": objective_id, "type": str(evidence_type)[:200], "status": status, "truthClass": truth_class, "sourceDigest": source_digest, "dependencyDigest": dependency_digest, "environmentDigest": environment_digest, "affectedPaths": [safe_path(x) for x in affected_paths], "details": details, "createdAt": fmt(now), "invalidatedAt": "", "invalidationReason": ""}
    if evidence_id not in graph["objectives"][objective_id]["evidenceIds"]: graph["objectives"][objective_id]["evidenceIds"].append(evidence_id)


def invalidate_evidence(graph: dict[str, Any], changed_paths: Sequence[str], reason: str, now: dt.datetime | None = None) -> list[str]:
    def intersects(a: str, b: str) -> bool: return a == b or a.startswith(b.rstrip("/") + "/") or b.startswith(a.rstrip("/") + "/")
    invalid = []
    for eid, ev in graph["evidence"].items():
        if ev["status"] == "PASS" and any(intersects(a, b) for a in changed_paths for b in ev.get("affectedPaths", [])):
            ev.update({"status": "STALE", "invalidatedAt": fmt(now), "invalidationReason": str(reason)[:1000]}); invalid.append(eid)
    return invalid


TEST_IMPACT_RULES = (
    ("src/shared/Reality/", ("reality-contract", "determinism", "full-luau")),
    ("src/shared/Materials/", ("materialdna", "full-luau")),
    ("src/shared/Objects/", ("objectgenome", "physics-contract", "full-luau")),
    ("src/shared/Physics/", ("physics-contract", "fidelity", "full-luau")),
    ("src/server/PhysicsLab/", ("physics-lab", "authority-source", "full-luau")),
    ("src/server/Bootstrap.server.luau", ("authority-source", "full-luau")),
    ("src/client/Bootstrap.client.luau", ("authority-source", "full-luau")),
    ("tools/swarm/", ("swarm-v16", "swarm-legacy", "swarm-adversarial-30")),
    (".swarm/", ("swarm-v16", "swarm-legacy")),
)


def test_impact(changed_paths: Sequence[str], integration_boundary: bool = False, release_boundary: bool = False) -> list[str]:
    suites = set()
    for path in changed_paths:
        for prefix, affected in TEST_IMPACT_RULES:
            if path.startswith(prefix): suites.update(affected)
        if path.startswith(".github/workflows/"): suites.add("workflow-source-contract")
    if integration_boundary: suites.add("integration-suite")
    if release_boundary: suites.update({"integration-suite", "full-system-release", "studio-evidence-remains-external"})
    return sorted(suites)

