#!/usr/bin/env python3
"""Inventory unregistered malformed event intervals across trusted Git history."""
from __future__ import annotations

import argparse
import json
import sys
import tempfile
from pathlib import Path

import audit_worker_schema_history as common
import swarm_burst_takeover_recovery as recovery
import swarmctl_hardening as hard


def changed_paths(before: str, after: str) -> tuple[str, ...]:
    raw = common.git("diff-tree", "--no-commit-id", "--name-only", "-z", "-r", before, after, text=False)
    assert isinstance(raw, bytes)
    return tuple(path.decode("utf-8") for path in raw.split(b"\0") if path)


def strict_description(raw: bytes, path: str, blob: str) -> dict:
    try:
        obj = json.loads(raw)
    except json.JSONDecodeError as exc:
        return {"blob": blob, "eventId": None, "eventType": None, "error": f"invalid JSON: {exc.msg}"}
    event_id = obj.get("eventId") if isinstance(obj, dict) else None
    event_type = obj.get("eventType") if isinstance(obj, dict) else None
    relative = Path(path).relative_to(".swarm")
    with tempfile.TemporaryDirectory() as temp:
        destination = Path(temp) / relative
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes(raw)
        try:
            hard._STRICT_VALIDATE_EVENT(destination)
            error = None
        except hard.core.ControlError as exc:
            error = str(exc).replace(str(destination), relative.as_posix())
    return {"blob": blob, "eventId": event_id, "eventType": event_type, "error": error}


def registered_identity(path: str, blob: str) -> tuple[str, str] | None:
    relative = path.removeprefix(".swarm/")
    for expected_id, rule in hard._CANONICAL_IMMUTABLE_EVENTS.items():
        expected_path = f"events/{rule['date']}/{rule['filename']}"
        if relative != expected_path:
            continue
        identities = {
            label: rule[label]
            for label in ("canonicalGitBlobSha1", "quarantinedGitBlobSha1", "quarantineOnlyGitBlobSha1")
            if label in rule
        }
        for label, expected_blob in identities.items():
            if blob == expected_blob:
                return expected_id, label
    return None


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--control-ref", required=True)
    parser.add_argument("--trust-ref", required=True)
    args = parser.parse_args()

    # Install every reviewed Git-bound event identity before measuring the gap.
    recovery.install(hard)
    trust_raw = common.git("show", f"{args.trust_ref}:.swarm/trust.json")
    assert isinstance(trust_raw, str)
    anchor = json.loads(trust_raw)["trustedControlSha"]
    tip_raw = common.git("rev-parse", args.control_ref)
    assert isinstance(tip_raw, str)
    tip = tip_raw.strip()
    commits_raw = common.git("rev-list", "--first-parent", "--reverse", f"{anchor}..{tip}")
    assert isinstance(commits_raw, str)
    commits = tuple(line for line in commits_raw.splitlines() if line)

    active: dict[str, dict] = {}
    intervals: list[dict] = []
    event_deltas = 0
    invalid_deltas = 0
    registered_invalid_deltas = 0
    before = anchor
    for index, after in enumerate(commits, start=1):
        transition_paths = changed_paths(before, after)
        event_paths = tuple(path for path in transition_paths if path.startswith(".swarm/events/") and path.endswith(".json"))
        for path in event_paths:
            event_deltas += 1
            current = common.object_at(after, path)
            description = None if current is None else strict_description(current[1], path, current[0])
            previous = active.pop(path, None)
            if previous is not None:
                previous.update(
                    {
                        "repairCommitSha": after,
                        "repairGitBlobSha1": None if description is None else description["blob"],
                        "repairEventId": None if description is None else description["eventId"],
                        "repairError": None if description is None else description["error"],
                        "repairChangedPaths": transition_paths,
                    }
                )
                intervals.append(previous)
            if description is None or description["error"] is None:
                continue
            invalid_deltas += 1
            registered = registered_identity(path, description["blob"])
            if registered is not None:
                registered_invalid_deltas += 1
                continue
            active[path] = {
                "path": path.removeprefix(".swarm/"),
                "introductionIndex": index,
                "introductionPredecessorSha": before,
                "introductionCommitSha": after,
                "introductionChangedPaths": transition_paths,
                "invalidGitBlobSha1": description["blob"],
                "eventId": description["eventId"],
                "eventType": description["eventType"],
                "error": description["error"],
            }
        before = after

    for unfinished in active.values():
        unfinished["unrepairedAtTip"] = tip
        intervals.append(unfinished)

    print(json.dumps(
        {
            "trustedControlSha": anchor,
            "controlSha": tip,
            "transitionCount": len(commits),
            "eventDeltaCount": event_deltas,
            "strictInvalidDeltaCount": invalid_deltas,
            "registeredInvalidDeltaCount": registered_invalid_deltas,
            "unregisteredInvalidIntervalCount": len(intervals),
            "unregisteredInvalidIntervals": intervals,
        },
        indent=2,
        sort_keys=True,
    ))
    return 0


if __name__ == "__main__":
    sys.exit(main())
