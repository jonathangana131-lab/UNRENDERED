#!/usr/bin/env python3
"""Reject Roblox value types from canonical plain-data Luau contracts.

Canonical conceptual/resolved records must remain plain/versioned data, while shared
runtime physics is still Roblox-first and may legitimately use Roblox math/value types.
This guard therefore protects explicit canonical-data roots/files and recipe modules
instead of inheriting the broader Instance/service boundary roots.
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

from check_domain_boundaries import REPO_ROOT, _line_for_offset, _mask_luau

# Domain roots whose production contracts are canonical/plain data by architecture.
PLAIN_DATA_ROOTS = (
    REPO_ROOT / "src/shared/Reality",
    REPO_ROOT / "src/shared/Materials",
    REPO_ROOT / "src/shared/Objects",
)

# Stable identity/encoding/address contracts are also canonical plain data.
PLAIN_DATA_FILES = (
    REPO_ROOT / "src/shared/Core/StableId.luau",
    REPO_ROOT / "src/shared/Core/DeterminismContract.luau",
    REPO_ROOT / "src/shared/Spatial/RegionAddress.luau",
)

# Development/permanent lab recipes are canonical data; Physics runtime modules are not.
PLAIN_DATA_PATTERNS = (
    "src/shared/Physics/*Recipe.luau",
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
        violations.append((line_number, "Roblox value type in canonical plain data", snippet))

    for match in ROBLOX_ENUM.finditer(code_only):
        line_number, snippet = _line_for_offset(source, match.start())
        violations.append((line_number, "Roblox Enum in canonical plain data", snippet))

    return violations


def _is_protected_path(path: Path) -> bool:
    resolved = path.resolve()

    for root in PLAIN_DATA_ROOTS:
        try:
            resolved.relative_to(root.resolve())
            return True
        except ValueError:
            pass

    if any(resolved == file.resolve() for file in PLAIN_DATA_FILES):
        return True

    try:
        relative = resolved.relative_to(REPO_ROOT.resolve())
    except ValueError:
        return False
    return any(relative.match(pattern) for pattern in PLAIN_DATA_PATTERNS)


def _self_test() -> None:
    violating = r'''
local position: Vector3 = Vector3.new(1, 2, 3)
local transform = CFrame.identity
local material = Enum.Material.Concrete
local nested = `value = {Color3.new(1, 1, 1)}`
'''.lstrip()
    actual = [(line, rule) for line, rule, _ in _find_violations(violating)]
    expected = [
        (1, "Roblox value type in canonical plain data"),
        (1, "Roblox value type in canonical plain data"),
        (2, "Roblox value type in canonical plain data"),
        (4, "Roblox value type in canonical plain data"),
        (3, "Roblox Enum in canonical plain data"),
    ]
    if actual != expected:
        raise AssertionError(f"plain-domain value self-test expected {expected!r}, got {actual!r}")

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
        raise AssertionError(f"plain-domain value self-test produced false positives: {clean_violations!r}")

    canonical_recipe = REPO_ROOT / "src/shared/Physics/PhysicsLabRecipe.luau"
    runtime_physics = REPO_ROOT / "src/shared/Physics/FidelityManager.luau"
    if not _is_protected_path(canonical_recipe):
        raise AssertionError("Physics recipe modules must remain protected as canonical plain data")
    if _is_protected_path(runtime_physics):
        raise AssertionError("shared runtime Physics must not inherit the canonical value-type ban")

    print("Canonical plain-data Roblox-value guard self-test passed")


def _iter_luau_files() -> list[Path]:
    files: set[Path] = set()
    missing_roots: list[Path] = []
    missing_files: list[Path] = []

    for root in PLAIN_DATA_ROOTS:
        if not root.is_dir():
            missing_roots.append(root)
            continue
        files.update(path for path in root.rglob("*.luau") if path.is_file())

    for path in PLAIN_DATA_FILES:
        if not path.is_file():
            missing_files.append(path)
            continue
        files.add(path)

    if missing_roots or missing_files:
        missing = [*missing_roots, *missing_files]
        rendered = ", ".join(str(path.relative_to(REPO_ROOT)) for path in missing)
        raise RuntimeError(f"canonical plain-data audit paths are missing: {rendered}")

    for pattern in PLAIN_DATA_PATTERNS:
        files.update(path for path in REPO_ROOT.glob(pattern) if path.is_file())

    return sorted(files)


def _audit_repository() -> int:
    violations: list[tuple[Path, int, str, str]] = []
    files = _iter_luau_files()

    for path in files:
        source = path.read_text(encoding="utf-8")
        for line_number, rule, snippet in _find_violations(source):
            violations.append((path, line_number, rule, snippet))

    if violations:
        print("Canonical plain-data value boundary violations found:", file=sys.stderr)
        for path, line_number, rule, snippet in violations:
            relative = path.relative_to(REPO_ROOT)
            print(f"  {relative}:{line_number}: {rule}: {snippet}", file=sys.stderr)
        print(
            "Keep Roblox value objects/enums out of canonical plain-data records; runtime physics may use them outside this protected scope.",
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
        help="verify Roblox value/type detection and protected-path scope before auditing",
    )
    args = parser.parse_args()

    if args.self_test:
        _self_test()
        return 0

    return _audit_repository()


if __name__ == "__main__":
    raise SystemExit(main())
