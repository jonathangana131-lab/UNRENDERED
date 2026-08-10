#!/usr/bin/env python3
"""Reject Roblox value types from canonical plain-data contracts.

Canonical recipes/identity contracts must stay plain/versioned data so Roblox value objects
remain a representation or runtime-computation concern. This deliberately does NOT ban
Roblox math/value types from every shared-domain module: e.g. shared physics computation may
legitimately use Vector3/CFrame after the canonical-data boundary.
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

from check_domain_boundaries import DOMAIN_ROOTS, REPO_ROOT, _line_for_offset, _mask_luau

# Existing foundational plain-data contracts. Recipe/DNA contracts are also identified by
# filename below so the new ResolvedRegionRecipe/PhysicsLabRecipe families are protected
# without turning all of src/shared/Physics into a Roblox-value-free zone.
PLAIN_DATA_CONTRACT_FILENAMES = frozenset(
    {
        "StableId.luau",
        "Versions.luau",
        "RealityVersions.luau",
        "MaterialDNA.luau",
        "ObjectGenome.luau",
    }
)

# Keep this list to Roblox-global names sufficiently distinctive for a lexical guard.
# Generic names such as NumberRange/NumberSequence/ColorSequence/Axes/Faces can be valid
# project-defined plain records, so a bare occurrence is not proof of a Roblox dependency.
ROBLOX_VALUE_TYPE = re.compile(
    r"\b(?:BrickColor|CFrame|Color3|PhysicalProperties|Ray|Rect|Region3|Region3int16|"
    r"UDim|UDim2|Vector2|Vector3)\b"
)
ROBLOX_ENUM = re.compile(r"\bEnum\s*\.")


def _is_plain_data_contract(path: Path) -> bool:
    name = path.name
    return (
        name in PLAIN_DATA_CONTRACT_FILENAMES
        or name.endswith("Recipe.luau")
        or name.endswith("DNA.luau")
    )


def _find_violations(path: Path, source: str) -> list[tuple[int, str, str]]:
    if not _is_plain_data_contract(path):
        return []

    code_only = _mask_luau(source, mask_strings=True)
    violations: list[tuple[int, str, str]] = []

    for match in ROBLOX_VALUE_TYPE.finditer(code_only):
        line_number, snippet = _line_for_offset(source, match.start())
        violations.append((line_number, "Roblox value type in canonical plain-data contract", snippet))

    for match in ROBLOX_ENUM.finditer(code_only):
        line_number, snippet = _line_for_offset(source, match.start())
        violations.append((line_number, "Roblox Enum in canonical plain-data contract", snippet))

    return violations


def _self_test() -> None:
    recipe_path = REPO_ROOT / "src/shared/Physics/PhysicsLabRecipe.luau"
    violating = r'''
local position: Vector3 = Vector3.new(1, 2, 3)
local transform = CFrame.identity
local material = Enum.Material.Concrete
local nested = `value = {Color3.new(1, 1, 1)}`
'''.lstrip()
    actual = [(line, rule) for line, rule, _ in _find_violations(recipe_path, violating)]
    value_rule = "Roblox value type in canonical plain-data contract"
    enum_rule = "Roblox Enum in canonical plain-data contract"
    expected = [
        (1, value_rule),
        (1, value_rule),
        (2, value_rule),
        (4, value_rule),
        (3, enum_rule),
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
    clean_violations = _find_violations(
        REPO_ROOT / "src/shared/Objects/ObjectGenome.luau", clean
    )
    if clean_violations:
        raise AssertionError(f"plain-data value self-test produced false positives: {clean_violations!r}")

    # The architecture rule is intentionally narrower than DOMAIN_ROOTS: runtime physics
    # may use Roblox math/value types after the canonical recipe/data boundary.
    physics_computation = "local impulse = Vector3.new(0, 10, 0)\nlocal pose = CFrame.identity"
    computation_violations = _find_violations(
        REPO_ROOT / "src/shared/Physics/ContactSolver.luau", physics_computation
    )
    if computation_violations:
        raise AssertionError(
            "plain-data guard incorrectly constrained shared physics computation: "
            f"{computation_violations!r}"
        )

    if not _is_plain_data_contract(recipe_path):
        raise AssertionError("PhysicsLabRecipe must be recognized as a canonical plain-data contract")

    print("Canonical plain-data Roblox-value guard self-test passed")


def _iter_luau_files() -> list[Path]:
    files: list[Path] = []
    missing_roots: list[Path] = []

    for root in DOMAIN_ROOTS:
        if not root.is_dir():
            missing_roots.append(root)
            continue
        files.extend(path for path in root.rglob("*.luau") if path.is_file())

    if missing_roots:
        missing = ", ".join(str(path.relative_to(REPO_ROOT)) for path in missing_roots)
        raise RuntimeError(f"shared-domain audit roots are missing: {missing}")

    return sorted(files)


def _audit_repository() -> int:
    violations: list[tuple[Path, int, str, str]] = []
    files = _iter_luau_files()
    protected_files = 0

    for path in files:
        if _is_plain_data_contract(path):
            protected_files += 1
        source = path.read_text(encoding="utf-8")
        for line_number, rule, snippet in _find_violations(path, source):
            violations.append((path, line_number, rule, snippet))

    if violations:
        print("Canonical plain-data value boundary violations found:", file=sys.stderr)
        for path, line_number, rule, snippet in violations:
            relative = path.relative_to(REPO_ROOT)
            print(f"  {relative}:{line_number}: {rule}: {snippet}", file=sys.stderr)
        print(
            "Keep Roblox value objects/enums out of canonical recipe/data contracts; use plain records/scalars and convert in realization/runtime adapters.",
            file=sys.stderr,
        )
        return 1

    print(
        f"Canonical plain-data value audit passed ({protected_files} protected contracts; {len(files)} shared-domain Luau files scanned)"
    )
    return 0


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--self-test",
        action="store_true",
        help="verify canonical plain-data scope and Roblox value/type detection before auditing",
    )
    args = parser.parse_args()

    if args.self_test:
        _self_test()
        return 0

    return _audit_repository()


if __name__ == "__main__":
    raise SystemExit(main())
