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
        "introductionPredecessorSha": "f55497a1a1a53c8a63fad2e4e2d2bb53b4b82662",
        "introductionCommitSha": "51fffefac32e3670794de06a55459d32ca4037c6",
        "repairPredecessorSha": "17829cc31434d92b252fafb1f406574f81281156",
        "repairCommitSha": "643de12b1fd3a008736d4815f6e3280c02ce5329",
    },
    "evt-20260813-224700-8fa445-physics-door-hinge-anchor-contract": {
        "date": "2026-08-13",
        "filename": "evt-20260813-224700-8fa445-physics-door-hinge-anchor-contract.json",
        "quarantinedGitBlobSha1": "817d7cafac3348ba914506fb86c9f933fbb92215",
        "canonicalGitBlobSha1": "2ba79e60a82df62b1f0d460012a61463ea1a973f",
        "introductionPredecessorSha": "dc3476753af55a76d44ab9135c7cfd6097fc70cc",
        "introductionCommitSha": "17fe117485c6d5a7b11ed0b80085e34071025390",
        "repairPredecessorSha": "c4c8330f65f03bac2233c798f87e8115c53c87f6",
        "repairCommitSha": "5a81fa430c545502ee0c429f8175015266c9f849",
    },
    "evt-20260813-224855-j4n7q2v9-diagnostics-docs-g2-review-request": {
        "date": "2026-08-13",
        "filename": "224855-sol-20260813-j4n7q2v9-review-request-diagnostics-docs-g2.json",
        "quarantinedGitBlobSha1": "9f8bdb845fa82883451b502c2b298eea57ae04de",
        "canonicalGitBlobSha1": "3eca1e3efe11b32526296f90fc952a48578c9a69",
        "introductionPredecessorSha": "85dc5823a786a5b0707e024d377806ba857bd205",
        "introductionCommitSha": "477176591ea73b4c8bebfba8d3c7f7b9181d96be",
        "repairPredecessorSha": "791a08bc09417be1453e614101bae115ce1409bb",
        "repairCommitSha": "9c00a778654499cd10f177b52f5840d530feee5e",
    },
    "evt-20260814-072200-x4m9p2c7-runtime-schema-closure": {
        "date": "2026-08-14",
        "filename": "evt-20260814-072200-x4m9p2c7-runtime-schema-closure.json",
        "quarantinedGitBlobSha1": "d91e2997f73bda1adcf0e6c7f255e84f17b4e135",
        "canonicalGitBlobSha1": "336ab9a01a87e43e3a04ca735f9113025eb93c97",
        "introductionPredecessorSha": "5647d4a704f984f51ac93db940861db5358bb096",
        "introductionCommitSha": "0c77f717f7331324c2834df98326b20254e83ce0",
        "repairPredecessorSha": "d817944a152104882a1717cb58046082d39ee2cb",
        "repairCommitSha": "1955d0207630d2d2062ea39a027f03636e8b8175",
    },
    "evt-20260814-072500-x4m9p2c7-runtime-schema-review-request": {
        "date": "2026-08-14",
        "filename": "evt-20260814-072500-x4m9p2c7-runtime-schema-review-request.json",
        "quarantinedGitBlobSha1": "9ef24b34d1965a18d3d9efff97a083e9c671b396",
        "canonicalGitBlobSha1": "4406f0a30a5ec4b3026fc28ea7cd6d3e39f8c30c",
        "introductionPredecessorSha": "577074756bee83842842bd14481bc1fe059ab55b",
        "introductionCommitSha": "03471b25b2bcfe3068b7a15767cb3e782f28d6e2",
        "repairPredecessorSha": "1955d0207630d2d2062ea39a027f03636e8b8175",
        "repairCommitSha": "0d8d4cfcc4519c4bebb96f914a1e70615cce41ea",
    },
}

QUARANTINE_ONLY_INTRODUCTIONS = {
    "evt-20260813-225000-8fa445-authority-current-main-no-new-gap": {
        "date": "2026-08-13",
        "filename": "evt-20260813-225000-8fa445-authority-current-main-no-new-gap.json",
        "quarantineOnlyGitBlobSha1": "6503ee1458957314660adab6ef1e56793e775175",
        "introductionPredecessorSha": "a3ec4ac5ca87ab5fd7058c22a33af44d69fd51bd",
        "introductionCommitSha": "47e9d65cb46852f396cfe109836623f4063d0d03",
    },
}


def _relative(rule: dict[str, str]) -> str:
    return f"events/{rule['date']}/{rule['filename']}"


def _git_relative(rule: dict[str, str]) -> str:
    return f".swarm/{_relative(rule)}"


def install(hardening_module) -> None:
    """Register exact historical bytes without changing transition semantics.

    Snapshot-only validation must remain strict. Finite compatibility transitions
    are authorized only by validate_git_transition(), where reviewed predecessor/
    commit identities and the exact Git path set are available.
    """
    registry = getattr(hardening_module, "_CANONICAL_IMMUTABLE_EVENTS", None)
    if not isinstance(registry, dict):
        raise RuntimeError("immutable event registry unavailable")
    for event_id, rule in RULES.items():
        registry[event_id] = {
            "date": rule["date"],
            "filename": rule["filename"],
            "quarantinedGitBlobSha1": rule["quarantinedGitBlobSha1"],
            "canonicalGitBlobSha1": rule["canonicalGitBlobSha1"],
        }


def _require_exact_changed_path(hardening_module, rule: dict[str, str], changed_paths: tuple[str, ...]) -> None:
    expected = (_git_relative(rule),)
    if tuple(sorted(changed_paths)) != expected:
        raise hardening_module.core.ControlError(
            f"finite historical event transition changed-path mismatch: expected {expected}, got {tuple(sorted(changed_paths))}"
        )


def _require_registered_quarantine_identity(hardening_module, event_id: str, rule: dict[str, str]) -> None:
    registry = getattr(hardening_module, "_CANONICAL_IMMUTABLE_EVENTS", None)
    registered = registry.get(event_id) if isinstance(registry, dict) else None
    expected = {
        "date": rule["date"],
        "filename": rule["filename"],
        "quarantineOnlyGitBlobSha1": rule["quarantineOnlyGitBlobSha1"],
    }
    if not isinstance(registered, dict) or any(registered.get(key) != value for key, value in expected.items()):
        raise hardening_module.core.ControlError("finite quarantine introduction registry identity mismatch")
    if "canonicalGitBlobSha1" in registered or "quarantinedGitBlobSha1" in registered:
        raise hardening_module.core.ControlError("finite quarantine introduction must remain quarantine-only")


def _real_after_metadata(hardening_module, result: dict, after: Path) -> dict:
    # Compatibility validates a disposable tree. Audit metadata must describe the
    # immutable real after-snapshot that actually participates in trusted history.
    result["quarantinedHistoricalEvents"] = len(hardening_module.quarantined_history(Path(after)))
    return result


def validate_git_transition(
    hardening_module,
    before_sha: str,
    after_sha: str,
    changed_paths: tuple[str, ...],
    before: Path,
    after: Path,
) -> dict | None:
    """Cross only reviewed malformed-event transitions in Git history.

    A matching commit identity with different paths/bytes fails closed. Any other
    commit pair receives no compatibility and must use the ordinary strict
    transition checker.
    """
    before = Path(before)
    after = Path(after)

    for event_id, rule in QUARANTINE_ONLY_INTRODUCTIONS.items():
        if before_sha != rule["introductionPredecessorSha"] or after_sha != rule["introductionCommitSha"]:
            continue
        _require_exact_changed_path(hardening_module, rule, changed_paths)
        _require_registered_quarantine_identity(hardening_module, event_id, rule)
        relative = _relative(rule)
        before_path = before / relative
        after_path = after / relative
        if before_path.exists() or not after_path.is_file():
            raise hardening_module.core.ControlError("finite quarantine introduction path shape mismatch")
        if hardening_module._git_blob_sha1(after_path) != rule["quarantineOnlyGitBlobSha1"]:
            raise hardening_module.core.ControlError("finite quarantine introduction blob mismatch")

        with tempfile.TemporaryDirectory(prefix="swarm-burst-quarantine-intro-") as temp:
            compat_after = Path(temp) / "after"
            shutil.copytree(after, compat_after)
            (compat_after / relative).unlink()
            result = hardening_module.transition_check(before, compat_after)

        event = hardening_module._validate_event_with_immutable_compat(after_path)
        if event.get("_quarantined") is not True or event.get("quarantineOnly") is not True or event.get("eventId") != event_id:
            raise hardening_module.core.ControlError("finite quarantine introduction did not remain quarantine-only")
        _real_after_metadata(hardening_module, result, after)
        result["finiteHistoricalQuarantineIntroductionCompat"] = [relative]
        result["historicalGitTransition"] = {
            "predecessorSha": before_sha,
            "commitSha": after_sha,
        }
        return result

    for event_id, rule in RULES.items():
        relative = _relative(rule)
        before_path = before / relative
        after_path = after / relative

        if before_sha == rule["introductionPredecessorSha"] and after_sha == rule["introductionCommitSha"]:
            _require_exact_changed_path(hardening_module, rule, changed_paths)
            if before_path.exists() or not after_path.is_file():
                raise hardening_module.core.ControlError("finite event introduction path shape mismatch")
            if hardening_module._git_blob_sha1(after_path) != rule["quarantinedGitBlobSha1"]:
                raise hardening_module.core.ControlError("finite event introduction blob mismatch")

            with tempfile.TemporaryDirectory(prefix="swarm-burst-event-intro-") as temp:
                compat_after = Path(temp) / "after"
                shutil.copytree(after, compat_after)
                (compat_after / relative).unlink()
                result = hardening_module.transition_check(before, compat_after)

            event = hardening_module._validate_event_with_immutable_compat(after_path)
            if event.get("_quarantined") is not True or event.get("eventId") != event_id:
                raise hardening_module.core.ControlError("finite event introduction did not remain quarantine-only")
            _real_after_metadata(hardening_module, result, after)
            result["finiteHistoricalEventIntroductionCompat"] = [relative]
            result["historicalGitTransition"] = {
                "predecessorSha": before_sha,
                "commitSha": after_sha,
            }
            return result

        if before_sha == rule["repairPredecessorSha"] and after_sha == rule["repairCommitSha"]:
            _require_exact_changed_path(hardening_module, rule, changed_paths)
            if not before_path.is_file() or not after_path.is_file():
                raise hardening_module.core.ControlError("finite event repair path shape mismatch")
            if hardening_module._git_blob_sha1(before_path) != rule["quarantinedGitBlobSha1"]:
                raise hardening_module.core.ControlError("finite event repair predecessor blob mismatch")
            if hardening_module._git_blob_sha1(after_path) != rule["canonicalGitBlobSha1"]:
                raise hardening_module.core.ControlError("finite event repair canonical blob mismatch")

            with tempfile.TemporaryDirectory(prefix="swarm-burst-event-repair-") as temp:
                compat_after = Path(temp) / "after"
                shutil.copytree(after, compat_after)
                shutil.copy2(before_path, compat_after / relative)
                result = hardening_module.transition_check(before, compat_after)

            repaired = hardening_module._validate_event_with_immutable_compat(after_path)
            if repaired.get("_quarantined") is True or repaired.get("eventId") != event_id:
                raise hardening_module.core.ControlError("finite event repair did not resolve to reviewed canonical bytes")
            _real_after_metadata(hardening_module, result, after)
            result["finiteHistoricalEventRepairCompat"] = [relative]
            result["historicalGitTransition"] = {
                "predecessorSha": before_sha,
                "commitSha": after_sha,
            }
            return result

    return None
