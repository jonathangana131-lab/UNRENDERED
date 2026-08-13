"""Finite replay-only compatibility for the first malformed burst takeover.

The 2026-08-13 burst wrote one stale generation-2 takeover without the required
`takeoverOf` breadcrumb. Trusted first-parent replay encounters this commit before
the later malformed state previously pinned by the recovery facade.

This module does not change live control bytes and does not relax the general
claim-transition contract. It replaces one finite compatibility row only for the
trusted-history replayer, binding the exact path, exact before-state SHA-256,
exact malformed after-state SHA-256, and exact missing previous worker.
"""
from __future__ import annotations

PATH = "claims/SWARM-RECOVERY-EVENT-IDENTITY-COMPAT/repair.json"
RULE = {
    "beforeSha256": "ed68427c1b4b4e75a079432ff7e27ffd9b03985c3e5f00842f9fc64a91d9fabb",
    "afterSha256": "eb8daf0a6c11dcee3527faacbb0ef264294af38fa95b09df8adcaadcf84607f2",
    "takeoverOf": "sol-20260811-m8q2v7",
}


def install(hardening_module) -> None:
    registry = getattr(hardening_module, "_FINITE_CLAIM_TAKEOVER_COMPAT", None)
    if not isinstance(registry, dict):
        raise RuntimeError("trusted hardening finite takeover registry is unavailable")
    registry[PATH] = dict(RULE)
