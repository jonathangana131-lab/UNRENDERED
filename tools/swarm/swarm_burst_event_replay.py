from __future__ import annotations

import shutil
import tempfile
from pathlib import Path

RULES = {
    "evt-20260813-224330-r8m4q7v2-fidelity-manager-backing-state": {
        "date": "2026-08-13",
        "filename": "evt-20260813-224330-r8m4q7v2-fidelity-manager-backing-state.json",
        "quarantinedGitBlobSha1": "cfe7cf3c383c8daeeb46e4bc24e8fa24d70fc30c",
        "canonicalGitBlobSha1": "96971d517ca7ca980f24e0677f7432d514f5824b",
    },
}


def _relative(rule: dict[str, str]) -> str:
    return f"events/{rule['date']}/{rule['filename']}"


def install(hardening_module) -> None:
    registry = getattr(hardening_module, "_CANONICAL_IMMUTABLE_EVENTS", None)
    if not isinstance(registry, dict):
        raise RuntimeError("immutable event registry unavailable")
    for event_id, rule in RULES.items():
        registry[event_id] = dict(rule)

    if getattr(hardening_module, "_BURST_EVENT_REPLAY_TRANSITION_INSTALLED", False):
        return

    original_transition = hardening_module.transition_check

    def transition_check(before: Path, after: Path) -> dict:
        try:
            return original_transition(before, after)
        except hardening_module.core.ControlError:
            for event_id, rule in RULES.items():
                relative = _relative(rule)
                before_path = Path(before) / relative
                after_path = Path(after) / relative
                if not after_path.is_file():
                    continue
                after_blob = hardening_module._git_blob_sha1(after_path)

                # Exact historical first write: the malformed event is inert
                # quarantine. Validate every other byte/state transition with the
                # event removed from a disposable copy, then prove the real file is
                # exactly the reviewed quarantined blob.
                if not before_path.exists() and after_blob == rule["quarantinedGitBlobSha1"]:
                    with tempfile.TemporaryDirectory(prefix="swarm-burst-event-intro-") as temp:
                        compat_after = Path(temp) / "after"
                        shutil.copytree(after, compat_after)
                        (compat_after / relative).unlink()
                        result = original_transition(before, compat_after)
                    event = hardening_module._validate_event_with_immutable_compat(after_path)
                    if event.get("_quarantined") is not True or event.get("eventId") != event_id:
                        raise hardening_module.core.ControlError("finite event introduction did not remain quarantine-only")
                    result["finiteHistoricalEventIntroductionCompat"] = [relative]
                    return result

                # Exact later repair: validate every other state transition while a
                # disposable copy retains the old inert bytes, then separately prove
                # the real repaired file is the exact reviewed canonical blob.
                if before_path.is_file():
                    before_blob = hardening_module._git_blob_sha1(before_path)
                    if before_blob == rule["quarantinedGitBlobSha1"] and after_blob == rule["canonicalGitBlobSha1"]:
                        with tempfile.TemporaryDirectory(prefix="swarm-burst-event-repair-") as temp:
                            compat_after = Path(temp) / "after"
                            shutil.copytree(after, compat_after)
                            shutil.copy2(before_path, compat_after / relative)
                            result = original_transition(before, compat_after)
                        repaired = hardening_module._validate_event_with_immutable_compat(after_path)
                        if repaired.get("_quarantined") is True or repaired.get("eventId") != event_id:
                            raise hardening_module.core.ControlError("finite event repair did not resolve to reviewed canonical bytes")
                        result["finiteHistoricalEventRepairCompat"] = [relative]
                        return result
            raise

    hardening_module.transition_check = transition_check
    hardening_module._BURST_EVENT_REPLAY_TRANSITION_INSTALLED = True
