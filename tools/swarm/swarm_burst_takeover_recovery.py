from __future__ import annotations

import swarm_burst_event_replay as _event_replay

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
        raise RuntimeError("finite takeover registry unavailable")
    for path, rule in RULES.items():
        registry[path] = dict(rule)
    _event_replay.install(hardening_module)
