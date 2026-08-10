#!/usr/bin/env python3
"""Reject Roblox value types from canonical plain-data Luau contracts.

Conceptual/resolved data must stay plain and versionable, but shared runtime physics may
legitimately use Roblox math/value types after that boundary. This complements
check_domain_boundaries without turning every shared Physics module into a serialization
contract.
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

from check_domain_boundaries import DOMAIN_ROOTS, REPO_ROOT, _line_for_offset, _mask_luau

# The broad domain guard still protects all shared Physics from Instances, Workspace,
# services, persistence backends, and concrete representation ownership. This stricter
# Roblox-value rule applies only to roots that are themselves canonical data domains plus
# explicitly named Physics contracts whose public data must remain plain/versionable.
PHYSICS_ROOT = REPO_ROOT / "src/shared/Physics"
PLAIN_DATA_ROOTS = tuple(root for root in DOMAIN_ROOTS if root != PHYSICS_ROOT)
PLAIN_DATA_FILES = (
    PHYSICS_ROOT / "FidelityManager.luau",
    PHYSICS_ROOT / "PhysicsLabRecipe.luau",
    PHYSICS_ROOT / "PhysicsLabObjectGenomes.luau",
)

# Keep this list to Roblox-global names that are sufficiently distinctive for a lexical
# guard. Generic names such as NumberRange/NumberSequence/ColorSequence/Axes/Faces can be
# legitimate project-defined plain record types, so treating the bare symbol as proof of a
# Roblox dependency would create false positives. Enum.* remains separately unambiguous.
ROBLOX_VALUE_TYPE = re.compile(
    r"\b(?:BrickColor|CFrame|Color3|PhysicalProperties|Ray|Rect|Region3|Region3int16|"
    r"UDim|UDim2|Vector2|Vector3)\b"
)
ROBLOX_ENUM = re.compile(r"\bEnum\s*\.")


def _find_violations(source: str) -> list[tuple[int, str, str]]:
    code_only = _mask_luau(source, mask_strings=True)
    violations: list[tuple[int, str, str]] = []

    for match in ROBLOX_VALUE_TYPE.finditer(code_only):
        line_number, snippet = _line_for_offset(source, match.start())
        violations.append((line_number, "Roblox value type in canonical data", snippet))

    for match in ROBLOX_ENUM.finditer(code_only):
        line_number, snippet = _line_for_offset(source, match.start())
        violations.append((line_number, "Roblox Enum in canonical data", snippet))

    return violations


def _self_test() -> None:
    violating = r'''
local position: Vector3 = Vector3.new(1, 2, 3)
local transform = CFrame.identity
local material = Enum.Material.Concrete
local nested = `value = {Color3.new(1, 1, 1)}`
'''.lstrip()
    actual = [(line, rule) for line, rule, _ in _find_violations(violating)]
    expected = [
        (1, "Roblox value type in canonical data"),
        (1, "Roblox value type in canonical data"),
        (2, "Roblox value type in canonical data"),
        (4, "Roblox value type in canonical data"),
        (3, "Roblox Enum in canonical data"),
    ]
    if actual != expected:
        raise AssertionError(f"plain-data value self-test expected {expected!r}, got {actual!r}")

    clean = r'''
-- Vector3.new(1, 2, 3) Enum.Material.Concrete
local quoted = "CFrame Color3 Enum.Material"
local longQuoted = [[UDim2.new(1, 0, 1, 0)]]
type NumberRange = { min: number, max: number }
type NumberSequence = { NumberRange }
type ColorSequence = { keypoints: { number } }
local massLimitsKg: NumberRange = { min = 1, max = 2 }
local position = { x = 1, y = 2, z = 3 }
local transform = { position = position, yawRadians = 0 }
'''.lstrip()
    clean_violations = _find_violations(clean)
    if clean_violations:
        raise AssertionError(f"plain-data value self-test produced false positives: {clean_violations!r}")

    if PHYSICS_ROOT not in DOMAIN_ROOTS:
        raise AssertionError("shared Physics must remain protected by the broad domain audit")
    if PHYSICS_ROOT in PLAIN_DATA_ROOTS:
        raise AssertionError("shared Physics must not be globally classified as canonical plain data")
    fidelity_contract = PHYSICS_ROOT / "FidelityManager.luau"
    if fidelity_contract not in PLAIN_DATA_FILES:
        raise AssertionError("FidelityManager plain-data contract must remain explicitly protected")

    print("Canonical plain-data Roblox-value guard self-test passed")


def _iter_luau_files() -> list[Path]:
    files: set[Path] = set()
    missing_roots: list[Path] = []

    for root in PLAIN_DATA_ROOTS:
        if not root.is_dir():
            missing_roots.append(root)
            continue
        files.update(path for path in root.rglob("*.luau") if path.is_file())

    if missing_roots:
        missing = ", ".join(str(path.relative_to(REPO_ROOT)) for path in missing_roots)
        raise RuntimeError(f"canonical plain-data audit roots are missing: {missing}")

    files.update(path for path in PLAIN_DATA_FILES if path.is_file())
    return sorted(files)


def _audit_repository() -> int:
    violations: list[tuple[Path, int, str, str]] = []
    files = _iter_luau_files()

    for path in files:
        source = path.read_text(encoding="utf-8")
        for line_number, rule, snippet in _find_violations(source):
            violations.append((path, line_number, rule, snippet))

    if violations:
        print("Canonical plain-data Roblox value boundary violations found:", file=sys.stderr)
        for path, line_number, rule, snippet in violations:
            relative = path.relative_to(REPO_ROOT)
            print(f"  {relative}:{line_number}: {rule}: {snippet}", file=sys.stderr)
        print(
            "Keep canonical data scalar/record-based; Roblox value objects belong after that data boundary.",
            file=sys.stderr,
        )
        return 1

    print(f"Canonical plain-data value audit passed ({len(files)} Luau files checked)")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--self-test",
        action="store_true",
        help="verify Roblox value/type detection and audit scoping before auditing the repository",
    )
    args = parser.parse_args()

    if args.self_test:
        _self_test()
        return 0

    return _audit_repository()


if __name__ == "__main__":
    raise SystemExit(main())
