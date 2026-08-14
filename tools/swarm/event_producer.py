#!/usr/bin/env python3
from __future__ import annotations

"""Fail-closed producer boundary for immutable swarm events.

This does not widen the event schema and does not repair historical events. It
forces candidate bytes through the same strict validator *before* a publication
sink is invoked. Callers may then use the returned canonical bytes in their
normal conditional GitHub write.
"""

import argparse
import json
from pathlib import Path
import tempfile
from typing import Any, Callable, Mapping, TypeVar

import swarmctl

T = TypeVar("T")


class EventProductionError(swarmctl.ControlError):
    pass


def canonical_event_bytes(payload: Mapping[str, Any]) -> bytes:
    if not isinstance(payload, Mapping):
        raise EventProductionError("event payload must be an object")
    # Serialize once before validation so the exact bytes returned to the writer
    # are the bytes whose decoded shape passed strict swarmctl.validate_event.
    try:
        raw = (json.dumps(dict(payload), sort_keys=True, indent=2, ensure_ascii=False) + "\n").encode("utf-8")
    except (TypeError, ValueError) as exc:
        raise EventProductionError("event payload is not JSON-serializable") from exc
    if len(raw) > 48_000:
        raise EventProductionError("event payload exceeds strict event size limit")
    with tempfile.TemporaryDirectory(prefix="unrendered-event-producer-") as temp:
        candidate = Path(temp) / "event.json"
        candidate.write_bytes(raw)
        try:
            swarmctl.validate_event(candidate)
        except swarmctl.ControlError as exc:
            raise EventProductionError(f"event rejected before publication: {exc}") from exc
    return raw


def publish_validated_event(payload: Mapping[str, Any], sink: Callable[[bytes], T]) -> T:
    """Invoke *sink* only after exact candidate bytes pass strict validation."""
    raw = canonical_event_bytes(payload)
    return sink(raw)


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description="Validate immutable swarm event bytes before publication")
    parser.add_argument("--input", required=True, help="candidate JSON event")
    parser.add_argument("--output", required=True, help="write validated canonical JSON bytes here")
    args = parser.parse_args(argv)
    payload = json.loads(Path(args.input).read_text(encoding="utf-8"))
    raw = canonical_event_bytes(payload)
    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_bytes(raw)
    print(json.dumps({"status": "PASS", "bytes": len(raw), "eventId": payload.get("eventId")}, sort_keys=True))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (EventProductionError, json.JSONDecodeError) as exc:
        print(f"SWARM EVENT PRODUCER ERROR: {exc}", file=__import__("sys").stderr)
        raise SystemExit(2)
