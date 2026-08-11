#!/usr/bin/env python3
"""V2.1 compatibility facade over the proven Swarm V2 hardening engine.

The base module remains byte-for-byte preserved so this repair can narrowly change
the worker-facing zero-slot dashboard semantics without destabilizing ownership,
fencing, scheduling, or transition logic.
"""
from __future__ import annotations

import swarmctl_hardening_base as _base
from swarmctl_hardening_base import *  # re-export the proven engine API


def dashboard(board: dict) -> str:
    out = [
        "# UNRENDERED Swarm Control Plane",
        "",
        f"Generated: `{board['generatedAt']}`",
        "",
        f"Canonical main: **{board['mainHealth']['status']}** `{board['mainHealth']['headSha'] or 'unknown'}`",
        "",
        f"State digest: `{board['stateDigest']}`",
        "",
        "## Summary",
        "",
        f"- ready slots: **{board['summary']['readySlots']}**",
        f"- active claims: **{board['summary']['activeClaims']}**",
        f"- stale claims: **{board['summary']['staleClaims']}**",
        f"- blocked-external lanes: **{board['summary']['blockedExternalLanes']}**",
        "",
        "## Ready slots",
        "",
    ]
    out += [
        f"- `{x['laneId']}/{x['slotId']}` — **{x['role']}** — score {x['score']} — {x['reason']}"
        for x in board["readySlots"][:30]
    ] or [
        "_No ordinary ready slot is materialized. GREEN is not completion: re-read live state and exhaust review/integration → stale recovery → active-Epic backfill → tests/audit → capacity-mining before idling._"
    ]
    out += ["", "## Active claims", ""]
    out += [
        f"- `{x['laneId']}/{x['slotId']}` → `{x['workerId']}`; lease to `{x['expiresAt']}`"
        for x in board["activeClaims"]
    ] or ["_None._"]
    out += ["", "## Blocked lanes", ""]
    out += [
        f"- `{x['laneId']}` — **{x['state']}** — {x['reason']}"
        for x in board["blockedLanes"]
    ] or ["_None._"]
    out += ["", "> Generated state is disposable. Atomic claims/resource leases are ownership authority.", ""]
    return "\n".join(out)


# Functions imported from the base module resolve the base module's globals. Patch
# that one presentation hook so render()/main() both use V2.1 semantics.
_base.dashboard = dashboard


if __name__ == "__main__":
    _base.main()
