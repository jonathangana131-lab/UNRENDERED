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
    "claims/HG-CAPACITY-MINING/mine-authority.json": {
        "predecessorSha": "8c11228ad0295b4262df1dfd458dce730e8fa4b2",
        "commitSha": "55f5013b11d76ae056519a87027b63760b816c6f",
        "beforeGitBlobSha1": "0fd887f2f7ace8cae0d823126b508cee5ea593bd",
        "afterGitBlobSha1": "19cc4c10387b7d6d56026b560b327b1d884090fd",
        "takeoverOf": "sol-20260814-r6h3n9v2",
    },
    "claims/HG-BACKFILL-DIAGNOSTICS/primary.json": {
        "predecessorSha": "90a5e01349aa3aec0debeff621e3ee75cc6d19d9",
        "commitSha": "ce2324bd22af80993ceb92e9af61e39ab8ccfc6d",
        "beforeGitBlobSha1": "9cca8772895351c6f7b04c3717aadd1f0cfcd231",
        "afterGitBlobSha1": "263c0d08c7f8ea2417aadb0d811503b8ee254cee",
        "takeoverOf": "sol-20260814-t5n8q3v6",
    },
    "claims/SWARM-RECOVERY-EVENT-HISTORY-CONTINUITY/primary.json": {
        "predecessorSha": "b578b42b0f5fc34e46c6d8d0f07e3136badd4ed7",
        "commitSha": "8a2c4e26000fa3cefdd233a04ffdf2b8cf0b1add",
        "beforeGitBlobSha1": "4d0f1a35cf4d8d6384b209f103c6183b1504ad93",
        "afterGitBlobSha1": "1e9908edec975a41c2a5ddcf3ec867f516c3fbe5",
        "takeoverOf": "sol-20260814-q5n8v2c4",
    },
    "claims/HG-BACKFILL-DIAGNOSTICS/audit.json": {
        "predecessorSha": "1c886c3aa3d9a7ae9e502ad4c838ff32f2483eb7",
        "commitSha": "5f3c31707482a6b3992b9815545b3c0eb8061381",
        "beforeGitBlobSha1": "fdd42664e3bfa2d1b6f28cd6d6cd8902ac149f84",
        "afterGitBlobSha1": "ed12ece93e9749dab92b0da8e222dbbf700708c0",
        "takeoverOf": "sol-20260814-r6h3n9v2",
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
