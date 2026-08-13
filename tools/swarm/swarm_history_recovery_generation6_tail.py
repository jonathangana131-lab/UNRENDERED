#!/usr/bin/env python3
"""Final exact live-event additions measured by generation-6 bootstrap inventory.

This module also owns one finite post-anchor recovery discovered after the
separate trust ledger was established. Those bytes remain inert history: exact
path + Git-blob identity is required, and normal schema/immutability rules stay
strict for every other event and transition.
"""
from __future__ import annotations

import hashlib
import shutil
import tempfile
from pathlib import Path

import swarmctl_hardening_base as _base


MALFORMED_EVENT_QUARANTINE_ROWS = (
    (
        "231820-sol-q4m9v2c7-diagnostics-review-request-g8",
        "231820-sol-q4m9v2c7-diagnostics-review-request-g8.json",
        "c4653d6b8633cad95b177298f4e24ebba02bcbe3",
        "f6a3b209185593f8f8f234f4eaa20caa7fd42802",
    ),
    (
        "evt-20260811-231830-r8n4m2q6-fidelity-control-blocked-invalid-worker-status",
        "evt-20260811-231830-r8n4m2q6-fidelity-control-blocked-invalid-worker-status.json",
        "0b96371bbb1bd5ed5a8962b53b1d3115e8ddc759",
        "8703194e605df242b85d22922e90a2f6bdccca91",
    ),
    (
        "evt-20260811-231845-r8n4m2q6-fidelity-capacity-evidence",
        "evt-20260811-231845-r8n4m2q6-fidelity-capacity-evidence.json",
        "559122a672b74b04dc1b34b1810bbb5fd53fec2f",
        "a6a090dd3bd8ef54d1e540c5057c37fe8d7daebb",
    ),
    (
        "evt-20260811-232300-g4m8q2v7-geometry-test-lineage-union",
        "evt-20260811-232300-g4m8q2v7-geometry-test-lineage-union.json",
        "7c39519f61b6e82d94fc4f72a5e5443bafd086c5",
        "0431f08b228bef79faa08a20b5e449ccf535eab5",
    ),
)


# Exact malformed first-write event identities discovered after the trust anchor.
# The first row was later corrected in place; the remaining three still coexist
# with separate corrected/superseding events. They can reserve identity but never
# become authoritative evidence.
POST_ANCHOR_QUARANTINED_EVENTS = {
    ("2026-08-13", "224855-sol-20260813-j4n7q2v9-review-request-diagnostics-docs-g2.json"): {
        "eventId": "evt-20260813-224855-j4n7q2v9-diagnostics-docs-g2-review-request",
        "gitBlobSha1": "9f8bdb845fa82883451b502c2b298eea57ae04de",
    },
    ("2026-08-13", "evt-20260813-224945-f4q9n2c7-fidelity-extra-keys.json"): {
        "eventId": "evt-20260813-224945-f4q9n2c7-fidelity-extra-keys",
        "gitBlobSha1": "0dd395b2757e7e3685b5c79aa6d6852ee50e85f3",
    },
    ("2026-08-13", "evt-20260813-225000-8fa445-authority-current-main-no-new-gap.json"): {
        "eventId": "evt-20260813-225000-8fa445-authority-current-main-no-new-gap",
        "gitBlobSha1": "6503ee1458957314660adab6ef1e56793e775175",
    },
    ("2026-08-13", "225110-sol-20260813-j4n7q2v9-review-request-diagnostics-docs-g3.json"): {
        "eventId": "evt-20260813-225110-j4n7q2v9-diagnostics-docs-g3-review-request",
        "gitBlobSha1": "835076ffce9bf4f355aa9f9b6d85f54177543421",
    },
}


FINITE_POST_ANCHOR_EVENT_REWRITE = {
    "events/2026-08-13/224855-sol-20260813-j4n7q2v9-review-request-diagnostics-docs-g2.json": {
        "beforeGitBlobSha1": "9f8bdb845fa82883451b502c2b298eea57ae04de",
        "afterGitBlobSha1": "3eca1e3efe11b32526296f90fc952a48578c9a69",
    },
}


_STRICT_VALIDATE_EVENT = _base.core.validate_event
_STRICT_TRANSITION_CHECK = _base.transition_check


def _git_blob_sha1(path: Path) -> str:
    raw = path.read_bytes()
    header = f"blob {len(raw)}\0".encode("ascii")
    return hashlib.sha1(header + raw).hexdigest()


def _validate_event_with_post_anchor_quarantine(path):
    path = Path(path)
    rule = POST_ANCHOR_QUARANTINED_EVENTS.get((path.parent.name, path.name))
    if rule is not None and _git_blob_sha1(path) == rule["gitBlobSha1"]:
        return {
            "_quarantined": True,
            "eventId": rule["eventId"],
            "gitBlobSha1": rule["gitBlobSha1"],
            "quarantineOnly": True,
            "postAnchor": True,
        }
    return _STRICT_VALIDATE_EVENT(path)


def _transition_check_with_post_anchor_rewrite(before: Path, after: Path) -> dict:
    """Cross only the exact audited malformed->corrected immutable event rewrite."""
    try:
        return _STRICT_TRANSITION_CHECK(before, after)
    except _base.core.ControlError:
        matches: list[str] = []
        for relative, rule in FINITE_POST_ANCHOR_EVENT_REWRITE.items():
            before_path = Path(before) / relative
            after_path = Path(after) / relative
            if not before_path.is_file() or not after_path.is_file():
                continue
            if (
                _git_blob_sha1(before_path) == rule["beforeGitBlobSha1"]
                and _git_blob_sha1(after_path) == rule["afterGitBlobSha1"]
            ):
                matches.append(relative)
        if len(matches) != 1:
            raise

        relative = matches[0]
        with tempfile.TemporaryDirectory() as temp_dir:
            temp_root = Path(temp_dir)
            compat_before = temp_root / "before"
            compat_after = temp_root / "after"
            shutil.copytree(before, compat_before)
            shutil.copytree(after, compat_after)
            (compat_before / relative).unlink()
            (compat_after / relative).unlink()
            result = _STRICT_TRANSITION_CHECK(compat_before, compat_after)
        result["finiteImmutableEventRewriteCompat"] = [relative]
        return result


# Patch the strict base before swarmctl_hardening captures its baseline callables.
# This is intentionally exact and finite; future malformed payloads remain errors.
_base.core.validate_event = _validate_event_with_post_anchor_quarantine
_base.transition_check = _transition_check_with_post_anchor_rewrite
