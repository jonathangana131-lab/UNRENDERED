from __future__ import annotations

import json
import shutil
import tempfile
from pathlib import Path

import swarm_burst_event_replay as _event_replay

# Legacy exact-byte takeover compatibility retained for the already-reviewed
# historical rows below. New recovery rows should prefer GIT_RULES so the
# compatibility is additionally bound to the exact first-parent transition.
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

# One later stale takeover is accepted only while replaying the exact reviewed
# first-parent Git transition. Snapshot validation and all future/live takeovers
# remain strict; no rule from this table is installed into the global byte-only
# takeover registry.
GIT_RULES = {
    "claims/HG-CAPACITY-MINING/mine-diagnostics.json": {
        "predecessorSha": "1a9cfdbbb82ca9a799e8579667a2fba0b6d1402c",
        "commitSha": "97e5c7d4643c0cee914983c3eeb2f523be90c484",
        "beforeGitBlobSha1": "487b795f6e33e40c78686eccca7e7737a03348a4",
        "afterGitBlobSha1": "76072a219b5a5989fd0dc0f3eade316befff6c83",
        "takeoverOf": "sol-20260812-am0s2f7s",
    },
    "claims/HG-BACKFILL-WORLDENTITY/primary.json": {
        "predecessorSha": "2e354e477e0ed7566b5832ed2a16a7dafa0c027f",
        "commitSha": "72c2530d3cfe8d8fdff08c06472e67b52266e217",
        "beforeGitBlobSha1": "b1deb0f37009dd90d7b2f120dd78f6ef43aaa8a4",
        "afterGitBlobSha1": "13edc7064471e5e8705b1f04a2f2a7ad8a75191f",
        "takeoverOf": "sol-20260812-q6n9v2m4",
    },
}


def install(hardening_module) -> None:
    registry = getattr(hardening_module, "_FINITE_CLAIM_TAKEOVER_COMPAT", None)
    if not isinstance(registry, dict):
        raise RuntimeError("finite takeover registry unavailable")
    for path, rule in RULES.items():
        registry[path] = dict(rule)
    _event_replay.install(hardening_module)


def _require_exact_changed_path(hardening_module, relative: str, changed_paths: tuple[str, ...]) -> None:
    expected = (f".swarm/{relative}",)
    actual = tuple(sorted(changed_paths))
    if actual != expected:
        raise hardening_module.core.ControlError(
            f"finite historical takeover changed-path mismatch: expected {expected}, got {actual}"
        )


def validate_git_transition(
    hardening_module,
    before_sha: str,
    after_sha: str,
    changed_paths: tuple[str, ...],
    before: Path,
    after: Path,
) -> dict | None:
    """Cross only an exact reviewed Git-bound missing-takeoverOf transition."""
    before = Path(before)
    after = Path(after)

    for relative, rule in GIT_RULES.items():
        if before_sha != rule["predecessorSha"] or after_sha != rule["commitSha"]:
            continue

        _require_exact_changed_path(hardening_module, relative, changed_paths)
        before_path = before / relative
        after_path = after / relative
        if not before_path.is_file() or not after_path.is_file():
            raise hardening_module.core.ControlError("finite historical takeover path shape mismatch")
        if hardening_module._git_blob_sha1(before_path) != rule["beforeGitBlobSha1"]:
            raise hardening_module.core.ControlError("finite historical takeover predecessor blob mismatch")
        if hardening_module._git_blob_sha1(after_path) != rule["afterGitBlobSha1"]:
            raise hardening_module.core.ControlError("finite historical takeover malformed blob mismatch")

        obj = hardening_module.core.load_json(after_path, max_bytes=32_000)
        if "takeoverOf" in obj:
            raise hardening_module.core.ControlError("finite historical takeover bytes unexpectedly contain takeoverOf")

        with tempfile.TemporaryDirectory(prefix="swarm-burst-takeover-git-") as temp_dir:
            compat_after = Path(temp_dir) / "after"
            shutil.copytree(after, compat_after)
            compat_path = compat_after / relative
            compat_obj = hardening_module.core.load_json(compat_path, max_bytes=32_000)
            compat_obj["takeoverOf"] = rule["takeoverOf"]
            compat_path.write_text(json.dumps(compat_obj, indent=2) + "\n", encoding="utf-8")
            result = hardening_module.transition_check(before, compat_after)

        result["finiteHistoricalTakeoverCompat"] = [relative]
        result["historicalGitTransition"] = {
            "predecessorSha": before_sha,
            "commitSha": after_sha,
        }
        return result

    return None
