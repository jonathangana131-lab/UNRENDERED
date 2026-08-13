from __future__ import annotations

import datetime as dt
import threading
import uuid
from typing import Any

from .model import *
from .coordination import *
def run_adversarial_simulation(workers: int = 30, now: dt.datetime | None = None) -> dict[str, Any]:
    from .store import MemoryStore, MissionGraphStore
    if workers < 30: raise ValidationError("V16 adversarial simulation requires at least 30 workers")
    stamp = now_utc(now or dt.datetime(2026, 8, 12, 18, 0, tzinfo=dt.timezone.utc)); graph = seed_graph(stamp); checks = {}
    for oid in ("stable-identity", "world-entity", "material-dna", "object-genome", "fidelity-manager"):
        obj = graph["objectives"][oid]; obj["status"] = "DONE"; obj["integrationState"] = "MAIN"; obj["finishSatisfied"] = [True] * len(obj["finishConditions"])
        for dim in ("functionality","testing","integration","knownBlockers"): obj["featureGenome"][dim]["state"] = "ACCEPTED"
    add_blocker(graph, blocker_id="sim-physics-blocker", mission_id="hero-gate-reality-grade", objective_id="physics-lab", symptom="source contract regression", severity="P0", exit_condition="exact-head acceptance", now=stamp)
    add_work_item(graph, work_item_id="sim-physics-repair", mission_id="hero-gate-reality-grade", objective_id="physics-lab", blocker_id="sim-physics-blocker", title="Repair Physics Lab source contract", outcome="restore exact-head accepted source behavior", role="builder", scope=["src/server/PhysicsLab"], branch="mission/physics-lab", now=stamp)
    duplicate = add_work_item(graph, work_item_id="sim-physics-duplicate", mission_id="hero-gate-reality-grade", objective_id="physics-lab", blocker_id="sim-physics-blocker", title="Fix Physics Lab source contract regression", outcome="restore accepted exact-head source", role="builder", now=stamp)
    checks["semantic_duplicate_suppressed"] = duplicate.duplicate and "sim-physics-duplicate" not in graph["workItems"]
    store = MemoryStore(); service = MissionGraphStore(store); service.ensure(graph)
    wins = 0; lock = threading.Lock()
    def contender(i: int) -> None:
        nonlocal wins
        try:
            store.create(f"{CLAIMS_PREFIX}/sim-physics-repair.json", {"workerId":f"sol-20260812-sim{i:02d}","generation":1,"leaseId":uuid.uuid4().hex,"status":"ACTIVE","lastHeartbeatAt":fmt(stamp),"leaseSeconds":1800}, "claim")
            with lock: wins += 1
        except ConflictError: pass
    threads = [threading.Thread(target=contender, args=(i,)) for i in range(workers)]
    for thread in threads: thread.start()
    for thread in threads: thread.join()
    checks["30_simultaneous_claims_one_winner"] = wins == 1
    authorize_tournament(graph, "sim-tournament", "sim-physics-blocker", now=stamp)
    for i in range(3): add_work_item(graph, work_item_id=f"sim-solution-{i}", mission_id="hero-gate-reality-grade", objective_id="physics-lab", blocker_id="sim-physics-blocker", title=f"Independent solution {i}", outcome=f"candidate architecture {i}", role="builder", branch=f"experimental/physics-{i}", tournament_id="sim-tournament", allow_duplicate=True, now=stamp)
    select_tournament_winner(graph, "sim-tournament", "sim-solution-1", {"correctness":"accepted","integrationCost":"lowest"}, stamp); checks["solution_tournament_converges"] = graph["workItems"]["sim-solution-0"]["status"] == "SUPERSEDED"
    try: resolve_blocker(graph, "sim-physics-blocker", [], "fake green", stamp); checks["bad_green_without_evidence_rejected"] = False
    except ValidationError: checks["bad_green_without_evidence_rejected"] = True
    for i in range(6): record_blocker_attempt(graph, "sim-physics-blocker", worker=f"sol-20260812-rh{i}", approach=f"successor {i}", result="same blocker", branch=f"validation/{i}", now=stamp)
    checks["anti_thrash_convergence"] = bool(graph["modes"]["convergenceFamilies"]); checks["rabbit_hole_detected"] = rabbit_hole(graph, "sim-physics-blocker")[0]
    add_evidence(graph, evidence_id="sim-source-evidence", objective_id="physics-lab", evidence_type="ci", status="PASS", truth_class="CI_VERIFIED", source_digest="a"*64, dependency_digest="b"*64, environment_digest="c"*64, affected_paths=["src/server/PhysicsLab/PhysicsLabRuntime.luau"], now=stamp)
    checks["moving_main_invalidates_evidence"] = invalidate_evidence(graph, ["src/server/PhysicsLab/PhysicsLabRuntime.luau"], "main moved", stamp) == ["sim-source-evidence"]
    try: add_evidence(graph, evidence_id="sim-fake-studio", objective_id="studio-runtime-evidence", evidence_type="studio", status="PASS", truth_class="STUDIO_OBSERVED", source_digest="a"*64, dependency_digest="b"*64, environment_digest="c"*64, affected_paths=["src"], details={}, now=stamp); checks["studio_truth_cannot_be_self_minted"] = False
    except ValidationError: checks["studio_truth_cannot_be_self_minted"] = True
    graph["workItems"]["sim-physics-repair"]["status"] = "REVIEW"; enqueue_merge(graph, ["sim-physics-repair"], "sim-merge", ["physics-lab"], stamp); start_merge(graph, "sim-merge", stamp)
    try: start_merge(graph, "sim-merge", stamp); checks["merge_train_serialized"] = False
    except ConflictError: checks["merge_train_serialized"] = True
    finish_merge(graph, "sim-merge", {"physics-lab":False}, False, stamp); checks["integration_failure_actionable"] = graph["workItems"]["sim-physics-repair"]["status"] == "INTEGRATING"
    graph["missions"]["hero-gate-reality-grade"]["captain"] = "sol-20260812-deadcaptain"; checks["captain_failure_no_deadlock"] = isinstance(recommend(graph, ["sol-20260812-fresh"], 1, stamp), list)
    checks["external_truth_stays_blocked"] = graph["objectives"]["studio-runtime-evidence"]["featureGenome"]["runtimeTruth"]["state"] != "ACCEPTED"
    checks["legacy_authority_preserved"] = graph["authority"]["legacyClaimsRemainEnforced"] and graph["authority"]["immutableEventsRemainAuthoritative"]
    return {"passed": all(checks.values()), "workers": workers, "checks": checks, "health": health_report(graph, workers, stamp)}
