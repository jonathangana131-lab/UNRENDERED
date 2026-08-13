#!/usr/bin/env python3
"""Trusted evidence-bound completion of an already-merged non-external V16 objective."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import subprocess
import urllib.parse
from typing import Any, Sequence

from v16cp.core import ValidationError, add_evidence, complete_objective, fmt, now_utc, safe_path
from v16cp.store import GitHubContentsStore, MissionGraphStore

SHA40 = re.compile(r"^[0-9a-f]{40}$")
REF = re.compile(r"^[1-9][0-9]{0,19}$")


def _digest(value: Any) -> str:
    return hashlib.sha256(json.dumps(value, sort_keys=True, separators=(",", ":")).encode()).hexdigest()


def record_objective_integration(graph: dict[str, Any], *, objective_id: str, pr: int, source_head: str, merge_sha: str, acceptance_runs: Sequence[str], review_refs: Sequence[str], affected_paths: Sequence[str], now=None) -> dict[str, Any]:
    if not SHA40.fullmatch(source_head) or not SHA40.fullmatch(merge_sha): raise ValidationError("source/merge SHA must be exact lowercase 40-hex")
    if pr < 1 or not acceptance_runs or not review_refs or not affected_paths: raise ValidationError("integration requires PR, acceptance runs, reviews, and affected paths")
    if any(not REF.fullmatch(str(x)) for x in acceptance_runs) or any(not REF.fullmatch(str(x)) for x in review_refs): raise ValidationError("run/review refs must be numeric IDs")
    paths = [safe_path(x) for x in affected_paths]
    objective = graph["objectives"].get(objective_id)
    if not objective: raise ValidationError("unknown objective")
    if objective["externalTruthRequired"]: raise ValidationError("software integration operator cannot accept external-runtime objective")
    unfinished = [dep for dep in objective["dependencies"] if graph["objectives"][dep]["status"] != "DONE"]
    if unfinished: raise ValidationError("objective dependencies are not DONE: " + ", ".join(unfinished))
    unresolved = [bid for bid in objective["blockerIds"] if graph["blockers"][bid]["state"] != "RESOLVED" and graph["blockers"][bid]["severity"] in {"P0","P1"}]
    if unresolved: raise ValidationError("objective still has unresolved P0/P1 blockers: " + ", ".join(unresolved))
    evidence_ids = [f"{objective_id}-ci-{source_head[:12]}", f"{objective_id}-review-{source_head[:12]}", f"{objective_id}-main-{merge_sha[:12]}"]
    if objective["status"] == "DONE":
        existing = [graph["evidence"].get(eid) for eid in evidence_ids]
        if all(existing) and existing[-1]["details"].get("mergeSHA") == merge_sha and existing[-1]["details"].get("pr") == pr:
            return {"objective":objective_id,"status":"DONE","integrationState":"MAIN","evidenceIds":evidence_ids,"runtimeAuthorityPromoted":False,"idempotent":True}
        raise ValidationError("objective already DONE under different evidence")
    stamp = fmt(now); source_digest = _digest({"pr":pr,"sourceHead":source_head,"affectedPaths":paths}); dependency_digest = _digest({"objective":objective_id,"mergeSHA":merge_sha})
    specs = [
        (evidence_ids[0], "software-acceptance", "CI_VERIFIED", _digest({"runs":list(acceptance_runs)}), {"pr":pr,"sourceHead":source_head,"acceptanceRuns":list(acceptance_runs)}),
        (evidence_ids[1], "independent-review", "SOURCE_VERIFIED", _digest({"reviews":list(review_refs)}), {"pr":pr,"sourceHead":source_head,"reviewRefs":list(review_refs)}),
        (evidence_ids[2], "main-integration", "CI_VERIFIED", _digest({"mergeSHA":merge_sha}), {"pr":pr,"sourceHead":source_head,"mergeSHA":merge_sha}),
    ]
    for eid, etype, truth, env, details in specs:
        add_evidence(graph, evidence_id=eid, objective_id=objective_id, evidence_type=etype, status="PASS", truth_class=truth, source_digest=source_digest, dependency_digest=dependency_digest, environment_digest=env, affected_paths=paths, details=details, now=now)
    objective["finishSatisfied"] = [True] * len(objective["finishConditions"]); objective["integrationState"] = "MAIN"; objective["lastMeaningfulProgress"] = stamp
    for dim in ("functionality","testing","integration","knownBlockers"):
        objective["featureGenome"][dim] = {"state":"ACCEPTED","evidenceIds":list(evidence_ids),"notes":f"Accepted software integration PR #{pr} -> {merge_sha[:12]}"}
    complete_objective(graph, objective_id, now)
    branch_name = objective.get("canonicalBranch", "")
    if branch_name:
        branch = graph["branches"].setdefault(branch_name, {"branch":branch_name,"missionId":objective["missionId"],"objectiveId":objective_id,"state":"SELECTED","world":"MAIN","selectedAt":stamp,"integratedAt":stamp,"pr":pr,"source":{}})
        branch.update({"state":"SELECTED","world":"MAIN","integratedAt":stamp,"pr":pr,"source":{"pr":pr,"headSHA":source_head,"mergeSHA":merge_sha}})
    graph["missions"][objective["missionId"]]["lastMeaningfulProgress"] = stamp; graph["metrics"]["meaningfulProgressEvents"] += 1
    return {"objective":objective_id,"status":"DONE","integrationState":"MAIN","evidenceIds":evidence_ids,"runtimeAuthorityPromoted":False,"idempotent":False}


def _intersects(path: str, bound: str) -> bool:
    return path == bound or path.startswith(bound.rstrip("/") + "/") or bound.startswith(path.rstrip("/") + "/")


def verify_local_ancestry_and_paths(merge_sha: str, affected_paths: Sequence[str]) -> str:
    head = subprocess.check_output(["git","rev-parse","HEAD"], text=True).strip()
    subprocess.run(["git","merge-base","--is-ancestor",merge_sha,head], check=True)
    changed = subprocess.check_output(["git","diff","--name-only",f"{merge_sha}..{head}"], text=True).splitlines()
    violations = sorted(path for path in changed if any(_intersects(path, bound) for bound in affected_paths))
    if violations: raise ValidationError("evidence-bound paths changed after merge: " + ", ".join(violations[:30]))
    return head


def verify_live_github(store: GitHubContentsStore, *, pr: int, source_head: str, merge_sha: str, acceptance_runs: Sequence[str], review_refs: Sequence[str], default_branch: str) -> dict[str, Any]:
    pull = store._request("GET", f"/repos/{store.owner}/{store.repo}/pulls/{pr}")
    if not isinstance(pull, dict) or not pull.get("merged_at"): raise ValidationError("PR is not merged")
    if (pull.get("base") or {}).get("ref") != default_branch: raise ValidationError("PR did not target default branch")
    if (pull.get("head") or {}).get("sha") != source_head: raise ValidationError("PR source head mismatch")
    if pull.get("merge_commit_sha") != merge_sha: raise ValidationError("PR merge commit mismatch")
    run_records = []
    for run_id in acceptance_runs:
        run = store._request("GET", f"/repos/{store.owner}/{store.repo}/actions/runs/{run_id}")
        if not isinstance(run, dict) or run.get("status") != "completed" or run.get("conclusion") != "success": raise ValidationError(f"acceptance run {run_id} is not completed success")
        run_records.append(run)
    if not any(run.get("head_sha") == source_head for run in run_records): raise ValidationError("at least one acceptance run must bind exact source head")
    reviews = []; page = 1
    while page <= 5:
        chunk = store._request("GET", f"/repos/{store.owner}/{store.repo}/pulls/{pr}/reviews?" + urllib.parse.urlencode({"per_page":100,"page":page}))
        if not isinstance(chunk, list): raise ValidationError("invalid reviews response")
        reviews.extend(chunk)
        if len(chunk) < 100: break
        page += 1
    wanted = {int(x) for x in review_refs}; matched = [r for r in reviews if r.get("id") in wanted]
    if {r.get("id") for r in matched} != wanted: raise ValidationError("one or more cited reviews do not exist on PR")
    if any(r.get("commit_id") != source_head for r in matched): raise ValidationError("all cited reviews must bind exact source head")
    required_fragments = [source_head] + [str(x) for x in acceptance_runs]
    if not any(all(fragment in str(r.get("body") or "") for fragment in required_fragments) for r in matched): raise ValidationError("at least one cited review body must bind source head and every acceptance run")
    return {"pr":pr,"runs":[int(x) for x in acceptance_runs],"reviews":[int(x) for x in review_refs]}


def parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(); p.add_argument("--repo", required=True); p.add_argument("--state-branch", default="swarm-control"); p.add_argument("--default-branch", default="main"); p.add_argument("--token", default=""); p.add_argument("--objective", required=True); p.add_argument("--pr", type=int, required=True); p.add_argument("--source-head", required=True); p.add_argument("--merge-sha", required=True); p.add_argument("--acceptance-run", action="append", default=[]); p.add_argument("--review-ref", action="append", default=[]); p.add_argument("--affected-path", action="append", default=[]); return p


def main(argv=None) -> int:
    args = parser().parse_args(argv); token = args.token or os.getenv("GITHUB_TOKEN", "")
    if not token: raise SystemExit("GITHUB_TOKEN is required")
    paths = [safe_path(x) for x in args.affected_path]; current_main = verify_local_ancestry_and_paths(args.merge_sha, paths)
    store = GitHubContentsStore(args.repo, token, args.state_branch); verified = verify_live_github(store, pr=args.pr, source_head=args.source_head, merge_sha=args.merge_sha, acceptance_runs=args.acceptance_run, review_refs=args.review_ref, default_branch=args.default_branch)
    service = MissionGraphStore(store)
    def mutate(graph):
        result = record_objective_integration(graph, objective_id=args.objective, pr=args.pr, source_head=args.source_head, merge_sha=args.merge_sha, acceptance_runs=args.acceptance_run, review_refs=args.review_ref, affected_paths=paths, now=now_utc())
        result["currentMain"] = current_main; result["liveGitHubVerified"] = verified; return result
    graph, result = service.mutate(mutate, message=f"swarm v16: integrate objective {args.objective}")
    print(json.dumps({"result":result,"revision":graph["revision"]}, indent=2, sort_keys=True)); return 0


if __name__ == "__main__":
    try: raise SystemExit(main())
    except (ValidationError, subprocess.CalledProcessError) as exc:
        print(f"SWARM V16 OBJECTIVE ERROR: {exc}", file=__import__("sys").stderr); raise SystemExit(2)
