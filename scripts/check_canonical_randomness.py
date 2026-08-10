#!/usr/bin/env python3
"""Fail when canonical Luau source bypasses project-owned deterministic RNG.

Canonical generation must derive randomness from explicit, scoped project streams.
Do not grow an exception allowlist here for convenience. If a canonical subsystem needs
randomness, route it through the deterministic contract instead. Non-canonical code
should live outside the audited roots rather than weakening this policy.
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
CANONICAL_ROOTS = (
    REPO_ROOT / "src/shared/Core",
    REPO_ROOT / "src/shared/Reality",
    REPO_ROOT / "src/shared/Spatial",
    REPO_ROOT / "src/shared/WorldGen",
    REPO_ROOT / "src/shared/Materials",
    REPO_ROOT / "src/shared/Objects",
)
FORBIDDEN_CALL = re.compile(
    r"\b(?:math\s*\.\s*random(?:seed)?|Random\s*\.\s*new)\s*\("
)


def _long_bracket_level(source: str, start: int) -> tuple[int, int] | None:
    if start >= len(source) or source[start] != "[":
        return None

    cursor = start + 1
    while cursor < len(source) and source[cursor] == "=":
        cursor += 1

    if cursor < len(source) and source[cursor] == "[":
        return cursor - start - 1, cursor + 1

    return None


def _mask_noncode(source: str) -> str:
    """Mask Luau comments/string literal chunks while preserving interpolation code."""

    masked = list(source)
    length = len(source)

    def blank(index: int) -> None:
        if masked[index] != "\n":
            masked[index] = " "

    def mask_quoted(start: int) -> int:
        quote = source[start]
        blank(start)
        cursor = start + 1
        while cursor < length:
            current = source[cursor]
            blank(cursor)
            if current == "\\" and cursor + 1 < length:
                cursor += 1
                blank(cursor)
            elif current == quote:
                return cursor + 1
            cursor += 1
        return cursor

    def mask_long_bracket(start: int) -> int | None:
        long_string = _long_bracket_level(source, start)
        if long_string is None:
            return None

        level, content_start = long_string
        close = "]" + ("=" * level) + "]"
        for index in range(start, content_start):
            blank(index)

        cursor = content_start
        while cursor < length:
            if source.startswith(close, cursor):
                for index in range(cursor, min(cursor + len(close), length)):
                    blank(index)
                return cursor + len(close)
            blank(cursor)
            cursor += 1
        return cursor

    def mask_comment(start: int) -> int:
        blank(start)
        if start + 1 < length:
            blank(start + 1)
        cursor = start + 2

        long_end = mask_long_bracket(cursor)
        if long_end is not None:
            return long_end

        while cursor < length and source[cursor] != "\n":
            blank(cursor)
            cursor += 1
        return cursor

    def mask_interpolated(start: int) -> int:
        blank(start)
        cursor = start + 1
        while cursor < length:
            current = source[cursor]

            if current == "\\":
                blank(cursor)
                cursor += 1
                if cursor < length:
                    blank(cursor)
                    cursor += 1
                continue

            if current == "`":
                blank(cursor)
                return cursor + 1

            if current == "{":
                blank(cursor)
                cursor = scan_interpolation(cursor + 1)
                continue

            blank(cursor)
            cursor += 1

        return cursor

    def scan_interpolation(start: int) -> int:
        depth = 1
        cursor = start
        while cursor < length:
            current = source[cursor]

            if source.startswith("--", cursor):
                cursor = mask_comment(cursor)
                continue

            if current in ('"', "'"):
                cursor = mask_quoted(cursor)
                continue

            if current == "[":
                long_end = mask_long_bracket(cursor)
                if long_end is not None:
                    cursor = long_end
                    continue

            if current == "`":
                cursor = mask_interpolated(cursor)
                continue

            if current == "{":
                depth += 1
                cursor += 1
                continue

            if current == "}":
                depth -= 1
                if depth == 0:
                    blank(cursor)
                    return cursor + 1
                cursor += 1
                continue

            cursor += 1

        return cursor

    cursor = 0
    while cursor < length:
        current = source[cursor]

        if source.startswith("--", cursor):
            cursor = mask_comment(cursor)
            continue

        if current in ('"', "'"):
            cursor = mask_quoted(cursor)
            continue

        if current == "[":
            long_end = mask_long_bracket(cursor)
            if long_end is not None:
                cursor = long_end
                continue

        if current == "`":
            cursor = mask_interpolated(cursor)
            continue

        cursor += 1

    return "".join(masked)


def _find_violations(source: str) -> list[tuple[int, str]]:
    code = _mask_noncode(source)
    lines = source.splitlines()
    violations: list[tuple[int, str]] = []

    for match in FORBIDDEN_CALL.finditer(code):
        line_number = source.count("\n", 0, match.start()) + 1
        snippet = lines[line_number - 1].strip() if line_number <= len(lines) else ""
        violations.append((line_number, snippet))

    return violations


def _self_test() -> None:
    sample = r'''
-- math.random() in a comment is harmless
local text = "Random.new(4) inside a string"
local longText = [[math.randomseed(1) inside a long string]]
--[[ Random.new() inside a block comment ]]
local backtickText = `math.random() and Random.new(4) are literal text`
local escapedInterpolation = `\{math.random() is still literal text}`
local interpolated = `value = {math.random()}`
local nested = `value = {({ x = 1, y = math.randomseed(5) }).y}`
local nestedBacktick = `value = {`inner = {Random.new(9)}`}`
local a = math.random()
local b = Random.new(123)
local c = math.randomseed(5)
'''.lstrip()

    actual_lines = [line for line, _ in _find_violations(sample)]
    expected_lines = [7, 8, 9, 10, 11, 12]
    if actual_lines != expected_lines:
        raise AssertionError(
            f"guard self-test failed: expected forbidden calls on {expected_lines}, got {actual_lines}"
        )

    print("Canonical randomness guard self-test passed")


def _iter_luau_files() -> list[Path]:
    files: list[Path] = []
    missing_roots: list[Path] = []

    for root in CANONICAL_ROOTS:
        if not root.is_dir():
            missing_roots.append(root)
            continue
        files.extend(path for path in root.rglob("*.luau") if path.is_file())

    if missing_roots:
        missing = ", ".join(str(path.relative_to(REPO_ROOT)) for path in missing_roots)
        raise RuntimeError(f"canonical randomness audit roots are missing: {missing}")

    return sorted(files)


def _audit_repository() -> int:
    files = _iter_luau_files()
    violations: list[tuple[Path, int, str]] = []

    for path in files:
        source = path.read_text(encoding="utf-8")
        for line_number, snippet in _find_violations(source):
            violations.append((path, line_number, snippet))

    if violations:
        print("Forbidden direct RNG calls found in canonical source:", file=sys.stderr)
        for path, line_number, snippet in violations:
            relative = path.relative_to(REPO_ROOT)
            print(f"  {relative}:{line_number}: {snippet}", file=sys.stderr)
        print(
            "Use the project-owned scoped deterministic RNG contract instead of direct RNG APIs.",
            file=sys.stderr,
        )
        return 1

    print(f"Canonical randomness audit passed ({len(files)} Luau files checked)")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--self-test",
        action="store_true",
        help="verify the audit detects code calls while ignoring non-code source text",
    )
    args = parser.parse_args()

    if args.self_test:
        _self_test()
        return 0

    return _audit_repository()


if __name__ == "__main__":
    raise SystemExit(main())
