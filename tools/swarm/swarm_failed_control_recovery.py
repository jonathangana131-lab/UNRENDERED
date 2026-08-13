#!/usr/bin/env python3
"""Finite post-bootstrap failed-control recovery identities.

A listed invalid commit is never authoritative. The trusted-history replayer may
cross a row only when predecessor, invalid commit, immediate repair commit, and
both changed-path sets match exactly. It then validates predecessor -> repair
under the ordinary strict control rules.
"""
from __future__ import annotations

FAILED_CONTROL_RECOVERY_PAIRS = (
    {
        "predecessorSha": "d7bc6b94419c26e11ba56f920635fc784b9dffa3",
        "invalidSha": "69836b4ac25576138c95cd0794204c639bd234f4",
        "repairSha": "6e38cee9ae4d4c2d71b36a944cd22aca232f3497",
        "invalidChangedPaths": (
            ".swarm/claims/SWARM-RECOVERY-HEALTH-VALIDATION-FENCE/primary.json",
            ".swarm/claims/SWARM-V16-MISSION-GRAPH/primary.json",
            ".swarm/lanes/SWARM-V16-MISSION-GRAPH.json",
            ".swarm/resource-claims/SWARM-PROTOCOL.json",
            ".swarm/workers/sol-20260812-v16graph.json",
            ".swarm/workers/sol-20260812-v16pkg1.json",
        ),
        "repairChangedPaths": (
            ".swarm/claims/SWARM-RECOVERY-HEALTH-VALIDATION-FENCE/primary.json",
            ".swarm/resource-claims/SWARM-PROTOCOL.json",
        ),
        "reason": (
            "The first V16 protocol-resource handoff removed a lane resource from a still-live "
            "primary claim and attempted takeover before the prior exclusive lease expired. "
            "The exact repair restores the prior owner and shortens only its same-owner lease "
            "to an already expired valid duration. No immutable event is touched."
        ),
    },
)
