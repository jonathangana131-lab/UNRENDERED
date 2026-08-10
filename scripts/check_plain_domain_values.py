#!/usr/bin/env python3
"""Reject Roblox value types from canonical plain-data shared Luau.

Conceptual/resolved data and authored production recipes stay plain/versioned so they can
be reconstructed independently of Roblox representation. Shared physics computation is a
different boundary: it may legitimately use Roblox math/value types while remaining free
of Instances, Workspace, services, and persistence backends. This audit therefore protects
canonical data roots plus explicitly data-shaped recipe/genome modules under shared Physics.
"""

from __future__ import annotations

import argparse
import fnmatch
import re
import sys
from pathlib import Path

from check_domain_boundaries import DOMAIN_ROOTS, REPO_ROOT, _line_for_offset, _mask_luau

PHYSICS_ROOT = REPO_ROOT / "src/shared/Physics"
PLAIN_DATA_ROOTS = tuple(root for root in DOMAIN_ROOTS if root != PHYSICS_ROOT)
PHYSICS_PLAIN_DATA_PATTERNS = (
    "*Recipe.luau",
    "*Genome*.luau",
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


def _is_under(path: Path, root: Path) -> bool:
    try:
        path.relative_to(root)
    except ValueError:
        return False
    return True


def _is_protected_path(path: Path) -> bool:
    if any(_is_under(path, root) for root in PLAIN_DATA_ROOTS):
        return True
    if _is_under(path, PHYSICS_ROOT):
        return any(fnmatch.fnmatch(path.name, pattern) for pattern in PHYSICS_PLAIN_DATA_PATTERNS)
    return False


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

    reality_contract = REPO_ROOT / "src/shared/Reality/WorldEntity.luau"
    physics_recipe = PHYSICS_ROOT / "PhysicsLabRecipe.luau"
    physics_genome = PHYSICS_ROOT / "PhysicsLabObjectGenomes.luau"
    physics_solver = PHYSICS_ROOT / "ContactSolver.luau"

    if not _is_protected_path(reality_contract):
        raise AssertionError("canonical Reality data must remain protected")
    if not _is_protected_path(physics_recipe) or not _is_protected_path(physics_genome):
        raise AssertionError("shared Physics recipe/genome data must remain protected")
    if _is_protected_path(physics_solver):
        raise AssertionError("generic shared Physics computation must not inherit the plain-value ban")

    print("Canonical plain-data Roblox-value guard self-test passed")


def _iter_luau_files() -> list[Path]:
    files: list[Path] = []
    missing_roots: list[Path] = []

    for root in DOMAIN_ROOTS:
        if not root.is_dir():
            missing_roots.append(root)
            continue
        files.extend(path for path in root.rglob("*.luau") if path.is_file() and _is_protected_path(path))

    if missing_roots:
        missing = ", ".join(str(path.relative_to(REPO_ROOT)) for path in missing_roots)
        raise RuntimeError(f"shared-domain audit roots are missing: {missing}")

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
            "Keep Roblox value objects/enums out of canonical data/recipes; use realization or simulation boundaries.",
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
        help="verify Roblox value/type detection and protected-scope selection before auditing",
    )
    args = parser.parse_args()

    if args.self_test:
        _self_test()
        return 0

    return _audit_repository()


if __name__ == "__main__":
    raise SystemExit(main())
