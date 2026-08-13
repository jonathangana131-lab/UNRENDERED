from __future__ import annotations

import datetime as dt
import hashlib
import json
import math
import re
import uuid
from collections import Counter
from copy import deepcopy
from dataclasses import asdict, dataclass
from difflib import SequenceMatcher
from pathlib import Path, PurePosixPath
from typing import Any, Mapping, Sequence

SCHEMA_VERSION = 16
GRAPH_PATH = ".swarm/runtime/v16/mission-graph.json"
CLAIMS_PREFIX = ".swarm/runtime/v16/claims"
MISSION_STATES = {"ACTIVE", "MILESTONE_ATTACK", "SURGE", "BLOCKED_EXTERNAL", "DONE"}
OBJECTIVE_STATES = {"PROPOSED", "READY", "ACTIVE", "BLOCKED", "REVIEW", "INTEGRATING", "EXTERNAL_BLOCKED", "DONE"}
WORK_STATES = {"QUEUED", "CLAIMED", "ACTIVE", "BLOCKED", "REVIEW", "INTEGRATING", "DONE", "SUPERSEDED", "ARCHIVED"}
BLOCKER_STATES = {"OPEN", "OWNED", "RESOLVED", "EXTERNAL"}
SEVERITIES = {"P0", "P1", "P2", "P3"}
TRUTH_CLASSES = {"SOURCE_VERIFIED", "CI_VERIFIED", "SIMULATED", "STUDIO_OBSERVED", "MULTICLIENT_OBSERVED", "DEVICE_PROFILED", "AUTHORITY_VERIFIED"}
EXTERNAL_TRUTH_CLASSES = {"STUDIO_OBSERVED", "MULTICLIENT_OBSERVED", "DEVICE_PROFILED", "AUTHORITY_VERIFIED"}
INTEGRATION_WORLDS = {"MAIN", "NEXT", "FRONTIER", "EXPERIMENTAL"}
BRANCH_STATES = {"EXPERIMENTAL", "PROMISING", "SELECTED", "INTEGRATED", "SUPERSEDED", "ARCHIVED"}
ROLES = {"builder", "reviewer", "integrator", "captain", "debugger", "tester", "auditor", "miner"}
GENOME_DIMENSIONS = (
    "functionality", "determinism", "physics", "visualQuality", "audio", "accessibility",
    "multiplayerSecurity", "persistence", "performance", "testing", "integration", "runtimeTruth", "knownBlockers",
)
GENOME_STATES = {"NOT_STARTED", "ACTIVE", "BLOCKED", "ACCEPTED", "NOT_APPLICABLE"}
ID_RE = re.compile(r"^[a-z0-9][a-z0-9._-]{0,95}$")
WORKER_RE = re.compile(r"^sol-[0-9]{8}-[a-z0-9][a-z0-9._-]{0,63}$")
SHA40_RE = re.compile(r"^[0-9a-f]{40}$")
TOKEN_RE = re.compile(r"[a-z0-9][a-z0-9._/-]*")
STOP = {"the","a","an","and","or","to","of","for","on","in","with","from","current","exact","head","test","tests","qa","review","audit","repair","fix","build","validation","unrendered","hero","gate"}

class SwarmV16Error(RuntimeError): pass
class ValidationError(SwarmV16Error): pass
class ConflictError(SwarmV16Error): pass
class NotFoundError(SwarmV16Error): pass


def now_utc(value: dt.datetime | None = None) -> dt.datetime:
    value = value or dt.datetime.now(dt.timezone.utc)
    if value.tzinfo is None: value = value.replace(tzinfo=dt.timezone.utc)
    return value.astimezone(dt.timezone.utc)


def fmt(value: dt.datetime | None = None) -> str:
    return now_utc(value).isoformat(timespec="seconds").replace("+00:00", "Z")


def parse_time(value: str) -> dt.datetime:
    if not isinstance(value, str) or not value: raise ValidationError("timestamp must be non-empty text")
    try: parsed = dt.datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError as exc: raise ValidationError("invalid V16 timestamp") from exc
    if parsed.tzinfo is None: raise ValidationError("timestamp must include timezone")
    return now_utc(parsed)


def digest(value: Any) -> str:
    return hashlib.sha256(json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode()).hexdigest()


def safe_path(value: str) -> str:
    if not isinstance(value, str) or not value or len(value) > 300 or "\\" in value: raise ValidationError("invalid repository path")
    p = PurePosixPath(value)
    if p.is_absolute() or ".." in p.parts or value.startswith("~"): raise ValidationError("path must be repository-relative")
    return str(p)


def validate_data_only(value: Any, path: str = "$") -> None:
    if isinstance(value, dict):
        if len(value) > 512: raise ValidationError(f"{path} has too many keys")
        for key, item in value.items():
            if not isinstance(key, str) or len(key) > 160: raise ValidationError(f"{path} invalid key")
            if key.lower().replace("_", "").replace("-", "") in {"command","commands","shell","script","scripts","exec","execute","executable","localpath","filesystempath","workingdirectory"}:
                raise ValidationError(f"{path}.{key} executable control field forbidden")
            validate_data_only(item, f"{path}.{key}")
    elif isinstance(value, list):
        if len(value) > 1000: raise ValidationError(f"{path} too many items")
        for index, item in enumerate(value): validate_data_only(item, f"{path}[{index}]")
    elif isinstance(value, str):
        if len(value) > 12000 or "\x00" in value: raise ValidationError(f"{path} invalid text")
    elif value is None or isinstance(value, (bool, int, float)): return
    else: raise ValidationError(f"{path} unsupported type")


def _id(value: Any, field: str) -> str:
    if not isinstance(value, str) or not ID_RE.fullmatch(value): raise ValidationError(f"invalid {field}")
    return value


def _list_strings(value: Any, field: str, maximum: int = 256) -> list[str]:
    if not isinstance(value, list) or len(value) > maximum or any(not isinstance(x, str) for x in value): raise ValidationError(f"invalid {field}")
    return list(value)


def slug(value: str) -> str:
    out = re.sub(r"[^a-z0-9._-]+", "-", value.lower()).strip("-._")[:90]
    return out if out and ID_RE.fullmatch(out) else "objective-" + hashlib.sha256(value.encode()).hexdigest()[:12]


def default_genome(*, runtime_required: bool = False) -> dict[str, dict[str, Any]]:
    out = {}
    for dimension in GENOME_DIMENSIONS:
        state = "NOT_APPLICABLE" if dimension == "runtimeTruth" and not runtime_required else "NOT_STARTED"
        out[dimension] = {"state": state, "evidenceIds": [], "notes": ""}
    return out


def _validate_genome(value: Any) -> dict[str, dict[str, Any]]:
    if not isinstance(value, Mapping) or set(value) != set(GENOME_DIMENSIONS): raise ValidationError("featureGenome must expose every V16 dimension")
    result = {}
    for dim in GENOME_DIMENSIONS:
        item = value[dim]
        if not isinstance(item, Mapping) or item.get("state") not in GENOME_STATES: raise ValidationError(f"invalid featureGenome.{dim}")
        result[dim] = {"state": item["state"], "evidenceIds": _list_strings(item.get("evidenceIds", []), f"{dim}.evidenceIds"), "notes": str(item.get("notes", ""))[:4000]}
    return result


def make_objective(objective_id: str, mission_id: str, title: str, *, priority: int = 5, severity: str = "P2", dependencies: Sequence[str] = (), finish_conditions: Sequence[str] = (), canonical_branch: str = "", user_value: int = 5, external_truth_required: bool = False, release_blocking: bool = False, safety_critical: bool = False, primary_scope: Sequence[str] = (), forbidden_areas: Sequence[str] = (), now: dt.datetime | None = None) -> dict[str, Any]:
    stamp = fmt(now)
    finish = list(finish_conditions) or ["implementation accepted", "tests accepted", "independent review accepted", "integrated to main", "no unresolved P0/P1 blockers"]
    return {
        "objectiveId": _id(objective_id, "objectiveId"), "missionId": _id(mission_id, "missionId"), "title": str(title)[:500],
        "status": "READY", "priority": max(0, min(9, int(priority))), "dependencies": list(dependencies), "blockerIds": [],
        "captain": "", "activeWorkers": [], "evidenceIds": [], "integrationState": "FRONTIER", "severity": severity if severity in SEVERITIES else "P2",
        "userValue": max(0, min(10, int(user_value))), "externalTruthRequired": bool(external_truth_required), "lastMeaningfulProgress": stamp,
        "finishConditions": finish, "finishSatisfied": [False] * len(finish), "featureGenome": default_genome(runtime_required=external_truth_required),
        "canonicalBranch": canonical_branch, "primaryScope": [safe_path(x) for x in primary_scope if x and "*" not in x], "scopePatterns": list(primary_scope),
        "forbiddenAreas": list(forbidden_areas), "releaseBlocking": bool(release_blocking), "safetyCritical": bool(safety_critical), "createdAt": stamp,
    }


def validate_graph(graph: Any) -> dict[str, Any]:
    validate_data_only(graph)
    if not isinstance(graph, Mapping) or graph.get("schemaVersion") != 16 or graph.get("kind") != "mission-graph": raise ValidationError("unsupported V16 graph")
    required_maps = ("missions","objectives","blockers","workItems","solutions","evidence","branches","agents","metrics","modes","migration","authority")
    for key in required_maps:
        if not isinstance(graph.get(key), Mapping): raise ValidationError(f"invalid graph map {key}")
    if not isinstance(graph.get("memory"), list) or not isinstance(graph.get("failureKnowledge"), list) or not isinstance(graph.get("mergeTrain"), Mapping): raise ValidationError("invalid coordination records")
    if not isinstance(graph.get("revision"), int) or graph["revision"] < 0: raise ValidationError("invalid revision")
    for timestamp in ("createdAt", "updatedAt"): parse_time(graph[timestamp])
    if graph["authority"].get("automaticExternalTruthPromotion") is not False: raise ValidationError("external runtime truth must remain fail-closed")
    if graph["migration"].get("destructiveActionsAllowed") is not False: raise ValidationError("destructive migration actions are not authorized")
    objectives = graph["objectives"]
    for oid, obj in objectives.items():
        if oid != obj.get("objectiveId") or not ID_RE.fullmatch(oid) or obj.get("missionId") not in graph["missions"]: raise ValidationError("invalid objective identity")
        if obj.get("status") not in OBJECTIVE_STATES or obj.get("severity") not in SEVERITIES or obj.get("integrationState") not in INTEGRATION_WORLDS: raise ValidationError(f"invalid objective {oid}")
        deps = _list_strings(obj.get("dependencies", []), "dependencies")
        if any(dep not in objectives for dep in deps): raise ValidationError(f"missing dependency for {oid}")
        finish = _list_strings(obj.get("finishConditions", []), "finishConditions")
        if not isinstance(obj.get("finishSatisfied"), list) or len(finish) != len(obj["finishSatisfied"]) or any(type(x) is not bool for x in obj["finishSatisfied"]): raise ValidationError(f"finish condition mismatch for {oid}")
        _validate_genome(obj.get("featureGenome"))
    visiting, done = set(), set()
    def visit(oid: str) -> None:
        if oid in done: return
        if oid in visiting: raise ValidationError("objective dependency cycle")
        visiting.add(oid)
        for dep in objectives[oid].get("dependencies", []): visit(dep)
        visiting.remove(oid); done.add(oid)
    for oid in objectives: visit(oid)
    for bid, blocker in graph["blockers"].items():
        if bid != blocker.get("blockerId") or blocker.get("objectiveId") not in objectives or blocker.get("state") not in BLOCKER_STATES or blocker.get("severity") not in SEVERITIES: raise ValidationError(f"invalid blocker {bid}")
    for wid, item in graph["workItems"].items():
        if wid != item.get("workItemId") or item.get("objectiveId") not in objectives or item.get("status") not in WORK_STATES or item.get("role") not in ROLES: raise ValidationError(f"invalid work item {wid}")
        if item.get("integrationWorld") not in INTEGRATION_WORLDS or item.get("branchState") not in BRANCH_STATES: raise ValidationError(f"invalid work integration state {wid}")
    for eid, ev in graph["evidence"].items():
        if eid != ev.get("evidenceId") or ev.get("objectiveId") not in objectives or ev.get("truthClass") not in TRUTH_CLASSES or ev.get("status") not in {"PASS","FAIL","STALE","PENDING"}: raise ValidationError(f"invalid evidence {eid}")
        if ev["truthClass"] in EXTERNAL_TRUTH_CLASSES and not ev.get("details", {}).get("externalAuthorityExplicit"): raise ValidationError(f"external evidence {eid} lacks explicit authority")
    for oid, obj in objectives.items():
        if obj.get("featureGenome", {}).get("runtimeTruth", {}).get("state") == "ACCEPTED":
            elevated = [graph["evidence"].get(eid) for eid in obj.get("evidenceIds", [])]
            if not any(ev and ev.get("status") == "PASS" and ev.get("truthClass") in EXTERNAL_TRUTH_CLASSES for ev in elevated): raise ValidationError(f"runtime truth accepted without external evidence for {oid}")
    return deepcopy(dict(graph))


def seed_graph(now: dt.datetime | None = None) -> dict[str, Any]:
    stamp = fmt(now)
    hero = "hero-gate-reality-grade"; ops = "swarm-operations"
    missions = {
        hero: {"missionId": hero, "title": "Hero Gate Reality-Grade", "why": "Converge Foundation Lock and Physics Lab work into one retained Reality-Grade Hero Gate instead of maximizing PR count.", "status": "ACTIVE", "priority": 0, "objectiveIds": [], "captain": "", "startedAt": stamp, "lastMeaningfulProgress": stamp, "remainingFinishConditions": ["foundation contracts accepted", "Physics Lab accepted", "server authority accepted", "real Studio/two-client gates satisfied where required", "final Hero Gate audit accepted"]},
        ops: {"missionId": ops, "title": "Swarm Operations", "why": "Keep main and the control plane trustworthy while product work advances.", "status": "ACTIVE", "priority": 1, "objectiveIds": [], "captain": "", "startedAt": stamp, "lastMeaningfulProgress": stamp, "remainingFinishConditions": ["control state valid", "red main repaired", "merge/review backlogs converged"]},
    }
    objectives = {}
    seeds = [
        ("stable-identity", "Stable identity / deterministic contracts", [], False, ["src/shared/Reality"]),
        ("world-entity", "WorldEntity identity and lifecycle", ["stable-identity"], False, ["src/shared/Reality"]),
        ("material-dna", "MaterialDNA production contract", ["stable-identity"], False, ["src/shared/Materials"]),
        ("object-genome", "ObjectGenome production contract", ["stable-identity"], False, ["src/shared/Objects"]),
        ("fidelity-manager", "Fidelity manager", ["world-entity"], False, ["src/shared/Physics"]),
        ("physics-lab", "Production Physics Lab / Perfect 5 Minutes foundation", ["world-entity","material-dna","object-genome","fidelity-manager"], False, ["src/server/PhysicsLab","src/shared/Physics"]),
        ("server-authority", "Server-authoritative runtime boundary", ["physics-lab"], False, ["src/server","src/client"]),
        ("studio-runtime-evidence", "Real Roblox Studio runtime evidence", ["physics-lab"], True, ["src/server/PhysicsLab"]),
        ("two-client-authority", "Real two-client shared authority evidence", ["server-authority","studio-runtime-evidence"], True, ["src/server","src/client"]),
        ("hero-gate-final", "Final Hero Gate audit", ["physics-lab","server-authority","studio-runtime-evidence","two-client-authority"], False, ["src","tests","Docs"]),
    ]
    for oid, title, deps, external, scope in seeds:
        objectives[oid] = make_objective(oid, hero, title, priority=0 if external or oid == "hero-gate-final" else 2, severity="P0" if external else "P1", dependencies=deps, user_value=10 if oid in {"physics-lab","hero-gate-final"} else 8, external_truth_required=external, release_blocking=oid in {"hero-gate-final","studio-runtime-evidence","two-client-authority"}, safety_critical=oid in {"server-authority","two-client-authority"}, canonical_branch=f"mission/{oid}", primary_scope=scope, forbidden_areas=["invented Roblox Studio evidence", "self-minted two-client/device authority"] if external else [], now=now)
        missions[hero]["objectiveIds"].append(oid)
    control_obj = make_objective("swarm-v16-mission-graph", ops, "Swarm V16 Mission Graph control plane", priority=0, severity="P0", dependencies=[], user_value=10, release_blocking=True, canonical_branch="agent/swarm-v16-mission-graph", primary_scope=["tools/swarm", ".github/workflows", "Docs"], forbidden_areas=["rewrite or delete immutable legacy events", "mint Studio/two-client/device truth from CI"], now=now)
    objectives["swarm-v16-mission-graph"] = control_obj; missions[ops]["objectiveIds"].append("swarm-v16-mission-graph")
    graph = {
        "schemaVersion": 16, "kind": "mission-graph", "graphId": "unrendered-v16", "revision": 0, "createdAt": stamp, "updatedAt": stamp,
        "missions": missions, "objectives": objectives, "blockers": {}, "workItems": {}, "solutions": {}, "evidence": {}, "branches": {},
        "mergeTrain": {"queue": [], "history": [], "activeCandidate": None}, "agents": {}, "memory": [], "failureKnowledge": [],
        "metrics": {"startBlockers": 0, "closedBlockers": 0, "newLegitimateBlockers": 0, "duplicateTasksPrevented": 0, "supersededBranches": 0, "meaningfulProgressEvents": 0, "legacyLanesImported": 0},
        "modes": {"surgeMissionId": "", "convergenceFamilies": [], "milestoneAttackObjectives": [], "frozenBranchFamilies": []},
        "migration": {"phase": "SHADOW", "legacyImported": False, "legacyLaneIds": [], "legacyControlSHA": "", "activationMainSHA": "", "liveRefreshMainSHA": "", "destructiveActionsAllowed": False},
        "authority": {"legacyControlBranch": "swarm-control", "legacyClaimsRemainEnforced": True, "immutableEventsRemainAuthoritative": True, "automaticExternalTruthPromotion": False, "studioRunnerExternal": True, "notes": "Source/CI never imply Studio, multiplayer, device, graphics, or authority truth."},
    }
    return validate_graph(graph)

