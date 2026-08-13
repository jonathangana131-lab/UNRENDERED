from __future__ import annotations

RULES = {
    "evt-20260813-224330-r8m4q7v2-fidelity-manager-backing-state": {
        "date": "2026-08-13",
        "filename": "evt-20260813-224330-r8m4q7v2-fidelity-manager-backing-state.json",
        "quarantineOnlyGitBlobSha1": "cfe7cf3c383c8daeeb46e4bc24e8fa24d70fc30c",
    },
}


def install(hardening_module) -> None:
    registry = getattr(hardening_module, "_CANONICAL_IMMUTABLE_EVENTS", None)
    if not isinstance(registry, dict):
        raise RuntimeError("immutable event registry unavailable")
    for event_id, rule in RULES.items():
        registry[event_id] = dict(rule)
