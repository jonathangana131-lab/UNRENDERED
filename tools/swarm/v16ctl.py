#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path

from v16cp.core import (
    GRAPH_PATH, ValidationError, fmt, health_report, migrate_legacy_root, recommend, run_adversarial_simulation,
    seed_graph, transition_check, user_status, validate_graph,
)
from v16cp.store import GitHubContentsStore, MissionGraphStore
from foundry_v17 import RepositoryPressure, admission_plan


def load(path: str) -> dict:
    value = json.loads(Path(path).read_text())
    return validate_graph(value)


def write(path: str, value: dict) -> None:
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    Path(path).write_text(json.dumps(value, sort_keys=True, indent=2, ensure_ascii=False) + "\n")


def parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(description="UNRENDERED Swarm V16 Mission Graph")
    sub = p.add_subparsers(dest="cmd", required=True)
    x = sub.add_parser("seed"); x.add_argument("--output", required=True)
    x = sub.add_parser("migrate"); x.add_argument("--legacy-root", required=True); x.add_argument("--output", required=True); x.add_argument("--main-sha", default=""); x.add_argument("--control-sha", default="")
    x = sub.add_parser("validate"); x.add_argument("--graph", required=True)
    x = sub.add_parser("status"); x.add_argument("--graph", required=True); x.add_argument("--workers", type=int, default=30)
    x = sub.add_parser("recommend"); x.add_argument("--graph", required=True); x.add_argument("--limit", type=int, default=10); x.add_argument("--workers", nargs="*", default=[])
    x = sub.add_parser("transition-check"); x.add_argument("--before-graph", required=True); x.add_argument("--after-graph", required=True)
    x = sub.add_parser("simulate"); x.add_argument("--workers", type=int, default=30)
    x = sub.add_parser("admission"); x.add_argument("--workers", type=int, default=20); x.add_argument("--ready-builders", type=int, required=True); x.add_argument("--active-builders", type=int, required=True); x.add_argument("--review-backlog", type=int, required=True); x.add_argument("--integration-backlog", type=int, required=True); x.add_argument("--retirement-candidates", type=int, required=True); x.add_argument("--open-prs", type=int, required=True); x.add_argument("--open-branches", type=int, required=True); x.add_argument("--red-main", action="store_true")
    x = sub.add_parser("activate"); x.add_argument("--legacy-root", required=True); x.add_argument("--repo", required=True); x.add_argument("--state-branch", default="swarm-control"); x.add_argument("--main-sha", required=True); x.add_argument("--control-sha", required=True); x.add_argument("--token", default="")
    x = sub.add_parser("refresh-main"); x.add_argument("--repo", required=True); x.add_argument("--state-branch", default="swarm-control"); x.add_argument("--main-sha", required=True); x.add_argument("--token", default="")
    return p


def main(argv=None) -> int:
    args = parser().parse_args(argv)
    if args.cmd == "seed":
        graph = seed_graph(); write(args.output, graph); print(json.dumps({"status":"PASS","graph":args.output,"revision":graph["revision"]}, indent=2)); return 0
    if args.cmd == "migrate":
        graph = migrate_legacy_root(Path(args.legacy_root), main_sha=args.main_sha, control_sha=args.control_sha); write(args.output, graph); print(json.dumps({"status":"PASS","legacyLanes":len(graph["migration"]["legacyLaneIds"]),"objectives":len(graph["objectives"]),"workItems":len(graph["workItems"])}, indent=2)); return 0
    if args.cmd == "validate":
        graph = load(args.graph); print(json.dumps({"status":"PASS","revision":graph["revision"],"missions":len(graph["missions"]),"objectives":len(graph["objectives"]),"workItems":len(graph["workItems"]),"evidence":len(graph["evidence"])}, indent=2)); return 0
    if args.cmd == "status":
        graph = load(args.graph); print(user_status(graph, args.workers)); print(json.dumps(health_report(graph, args.workers), indent=2)); return 0
    if args.cmd == "recommend":
        graph = load(args.graph); packets = [packet.__dict__ for packet in recommend(graph, args.workers, args.limit)]; print(json.dumps(packets, indent=2)); return 0
    if args.cmd == "transition-check":
        print(json.dumps(transition_check(load(args.before_graph), load(args.after_graph)), indent=2)); return 0
    if args.cmd == "simulate":
        result = run_adversarial_simulation(args.workers); print(json.dumps(result, indent=2)); return 0 if result["passed"] else 2
    if args.cmd == "admission":
        result = admission_plan(requested_workers=args.workers, ready_builders=args.ready_builders, active_builders=args.active_builders, review_backlog=args.review_backlog, integration_backlog=args.integration_backlog, retirement_candidates=args.retirement_candidates, pressure=RepositoryPressure(args.open_prs, args.open_branches), red_main=args.red_main)
        print(json.dumps(result, indent=2)); return 0
    token = args.token or os.getenv("GITHUB_TOKEN", "")
    if not token: raise SystemExit("GITHUB_TOKEN is required")
    store = GitHubContentsStore(args.repo, token, args.state_branch); service = MissionGraphStore(store)
    if args.cmd == "activate":
        candidate = migrate_legacy_root(Path(args.legacy_root), main_sha=args.main_sha, control_sha=args.control_sha)
        try:
            current, _ = service.load()
            if current["migration"].get("phase") == "ACTIVE":
                def refresh(graph):
                    graph["migration"]["liveRefreshMainSHA"] = args.main_sha
                    graph["migration"]["legacyControlSHA"] = args.control_sha
                    graph["migration"]["destructiveActionsAllowed"] = False
                    return {"idempotent": True}
                graph, result = service.mutate(refresh, message="swarm v16: refresh active Mission Graph")
            else:
                raise ValidationError("existing V16 graph is not ACTIVE; refusing implicit replacement")
        except Exception as exc:
            from v16cp.core import NotFoundError
            if isinstance(exc, NotFoundError):
                graph, _ = service.ensure(candidate); result = {"idempotent": False}
            else:
                raise
        print(json.dumps({"status":"ACTIVE","revision":graph["revision"],"legacyLanes":len(graph["migration"]["legacyLaneIds"]),"destructiveActionsAllowed":False,**result}, indent=2)); return 0
    if args.cmd == "refresh-main":
        def refresh(graph):
            graph["migration"]["liveRefreshMainSHA"] = args.main_sha; graph["migration"]["destructiveActionsAllowed"] = False
            graph["metrics"]["meaningfulProgressEvents"] = int(graph["metrics"].get("meaningfulProgressEvents", 0)) + 1
            return {"mainSHA": args.main_sha}
        graph, result = service.mutate(refresh, message=f"swarm v16: bind live main {args.main_sha[:12]}")
        print(json.dumps({"status":"PASS","revision":graph["revision"],**result}, indent=2)); return 0
    raise AssertionError(args.cmd)


if __name__ == "__main__":
    try: raise SystemExit(main())
    except ValidationError as exc:
        print(f"SWARM V16 ERROR: {exc}", file=__import__("sys").stderr); raise SystemExit(2)
