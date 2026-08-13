"""Finite replay-only compatibility for malformed burst takeovers.

The 2026-08-13 burst wrote stale generation-2 takeovers without the required
`takeoverOf` breadcrumb. Trusted first-parent replay encounters these historical
commits before the later states previously pinned by the recovery facade.

This module does not change live control bytes and does not relax the general
claim-transition contract. It installs only finite exact compatibility rows for
the trusted-history replayer, each binding the exact path, exact before-state
SHA-256, exact malformed after-state SHA-256, and exact missing previous worker.
"""
from __future__ import annotations

RULES = {
    "claims/SWARM-RECOVERY-EVENT-IDENTITY-COMPAT/repair.json": {
        "beforeSha256": "ed68427c1b4b4e75a079432ff7e27ffd9b03985c3e5f00842f9fc64a91d9fabb",
        "afterSha256": "eb8daf0a6c11dcee3527faacbb0ef264294af38fa95b09df8adcaadcf84607f2",
        "takeoverOf": "sol-20260811-m8q2v7",
    },
    "claims/SWARM-RECOVERY-WORKER-STATUS-CONTRACT/reviewer-1.json": {
        "beforeSha256": "e08ddfd623d5dbf07a06435d5b46775c91ff45fbc05eaec2211d23a25e52bc63",
        "afterSha256": "b50595eb9015ff36f00908ac983275b97e3f858a383914293d385bd8786b3ec0",
        "takeoverOf": "sol-20260812-rvw16g4a",
    },
}


def install(hardening_module) -> None:
    registry = getattr(hardening_module, "_FINITE_CLAIM_TAKEOVER_COMPAT", None)
    if not isinstance(registry, dict):
        raise RuntimeError("trusted hardening finite takeover registry is unavailable")
    for path, rule in RULES.items():
        registry[path] = dict(rule)
