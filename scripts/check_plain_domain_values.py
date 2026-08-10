#!/usr/bin/env python3
"""Reject Roblox value types from canonical shared-domain Luau.

The shared Reality/Physics/etc. contracts must stay plain/versioned data so Roblox value
objects remain a physical-representation concern. This complements check_domain_boundaries
by catching value/type dependencies that do not require Instance or service access.
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

from check_domain_boundaries import DOMAIN_ROOTS, REPO_ROOT, _line_for_offset, _mask_luau

ROBLOX_VALUE_TYPE = re.compile(
    r"\b(?:Axes|BrickColor|CFrame|Color3|ColorSequence|Faces|NumberRange|NumberSequence|"
    r"PhysicalProperties|Ray|Rect|Region3|Region3int16|UDim|UDim2|Vector2|Vector3)\b"
)
ROBLOX_ENUM = re.compile(r"\bEnum\s*\.")


def _find_violations(source: str) -> list[tuple[int, str, str]]:
    code_only = _mask_luau(source, mask_strings=True)
    violations: list[tuple[int, str, str]] = []

    for match in ROBLOX_VALUE_TYPE.finditer(code_only):
        line_number, snippet = _line_for_offset(source, match.start())
        violations.append((line_number, "Roblox value type in shared domain", snippet))

    for match in ROBLOX_ENUM.finditer(code_only):
        line_number, snippet = _line_for_offset(source, match.start())
        violations.append((line_number, "Roblox Enum in shared domain", snippet))

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
        (1, "Roblox value type in shared domain"),
        (1, "Roblox value type in shared domain"),
        (2, "Roblox value type in shared domain"),
        (4, "Roblox value type in shared domain"),
        (3, "Roblox Enum in shared domain"),
    ]
    if actual != expected:
        raise AssertionError(f"plain-domain value self-test expected {expected!r}, got {actual!r}")

    clean = r'''
-- Vector3.new(1, 2, 3) Enum.Material.Concrete
local quoted = "CFrame Color3 Enum.Material"
local longQuoted = [[UDim2.new(1, 0, 1, 0)]]
local position = { x = 1, y = 2, z = 3 }
local transform = { position = position, yawRadians = 0 }
'''.lstrip()
    clean_violations = _find_violations(clean)
    if clean_violations:
        raise AssertionError(f"plain-domain value self-test produced false positives: {clean_violations!r}")

    physics_path = REPO_ROOT / "src/shared/Physics/Test.luau"
    if not any(physics_path == root / "Test.luau" for root in DOMAIN_ROOTS):
        raise AssertionError("shared Physics root is not protected by the canonical domain audit roots")

    print("Plain shared-domain Roblox-value guard self-test passed")


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

    for path in files:
        source = path.read_text(encoding="utf-8")
        for line_number, rule, snippet in _find_violations(source):
            violations.append((path, line_number, rule, snippet))

    if violations:
        print("Plain shared-domain value boundary violations found:", file=sys.stderr)
        for path, line_number, rule, snippet in violations:
            relative = path.relative_to(REPO_ROOT)
            print(f"  {relative}:{line_number}: {rule}: {snippet}", file=sys.stderr)
        print(
            "Keep Roblox value objects/enums in realization adapters; canonical shared data uses plain records/scalars.",
            file=sys.stderr,
        )
        return 1

    print(f"Plain shared-domain value audit passed ({len(files)} Luau files checked)")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--self-test",
        action="store_true",
        help="verify Roblox value/type detection before auditing the repository",
    )
    args = parser.parse_args()

    if args.self_test:
        _self_test()
        return 0

    return _audit_repository()


if __name__ == "__main__":
    raise SystemExit(main())
