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
FORBIDDEN_REFERENCE = re.compile(
    r"\b(?:math\s*\.\s*random(?:seed)?|Random\s*\.\s*new)\b"
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
    """Replace comments and string contents with spaces while preserving newlines."""

    masked = list(source)
    length = len(source)
    cursor = 0

    def blank(index: int) -> None:
        if masked[index] != "\n":
            masked[index] = " "

    while cursor < length:
        char = source[cursor]

        if char in ('"', "'"):
            quote = char
            blank(cursor)
            cursor += 1
            while cursor < length:
                current = source[cursor]
                blank(cursor)
                if current == "\\" and cursor + 1 < length:
                    cursor += 1
                    blank(cursor)
                elif current == quote:
                    cursor += 1
                    break
                cursor += 1
            continue

        if char == "[":
            long_string = _long_bracket_level(source, cursor)
            if long_string is not None:
                level, content_start = long_string
                close = "]" + ("=" * level) + "]"
                for index in range(cursor, content_start):
                    blank(index)
                cursor = content_start
                while cursor < length:
                    if source.startswith(close, cursor):
                        for index in range(cursor, min(cursor + len(close), length)):
                            blank(index)
                        cursor += len(close)
                        break
                    blank(cursor)
                    cursor += 1
                continue

        if source.startswith("--", cursor):
            blank(cursor)
            blank(cursor + 1)
            cursor += 2

            long_comment = _long_bracket_level(source, cursor)
            if long_comment is not None:
                level, content_start = long_comment
                close = "]" + ("=" * level) + "]"
                for index in range(cursor, content_start):
                    blank(index)
                cursor = content_start
                while cursor < length:
                    if source.startswith(close, cursor):
                        for index in range(cursor, min(cursor + len(close), length)):
                            blank(index)
                        cursor += len(close)
                        break
                    blank(cursor)
                    cursor += 1
                continue

            while cursor < length and source[cursor] != "\n":
                blank(cursor)
                cursor += 1
            continue

        cursor += 1

    return "".join(masked)


def _find_violations(source: str) -> list[tuple[int, str]]:
    code = _mask_noncode(source)
    lines = source.splitlines()
    violations: list[tuple[int, str]] = []

    for match in FORBIDDEN_REFERENCE.finditer(code):
        line_number = source.count("\n", 0, match.start()) + 1
        snippet = lines[line_number - 1].strip() if line_number <= len(lines) else ""
        violations.append((line_number, snippet))

    return violations


def _self_test() -> None:
    sample = '''
-- math.random() in a comment is harmless
local text = "Random.new(4) inside a string"
local longText = [[math.randomseed(1) inside a long string]]
--[[ Random.new() inside a block comment ]]
local a = math.random()
local b = Random.new(123)
local c = math.randomseed(5)
local roll = math.random
local seed = math.randomseed
local constructor = Random.new
'''.lstrip()

    actual_lines = [line for line, _ in _find_violations(sample)]
    expected_lines = [5, 6, 7, 8, 9, 10]
    if actual_lines != expected_lines:
        raise AssertionError(
            f"guard self-test failed: expected forbidden references on {expected_lines}, got {actual_lines}"
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
    violations: list[tuple[Path, int, str]] = []

    for path in _iter_luau_files():
        source = path.read_text(encoding="utf-8")
        for line_number, snippet in _find_violations(source):
            violations.append((path, line_number, snippet))

    if violations:
        print("Forbidden direct RNG references found in canonical source:", file=sys.stderr)
        for path, line_number, snippet in violations:
            relative = path.relative_to(REPO_ROOT)
            print(f"  {relative}:{line_number}: {snippet}", file=sys.stderr)
        print(
            "Use the project-owned scoped deterministic RNG contract instead of direct RNG APIs.",
            file=sys.stderr,
        )
        return 1

    print(f"Canonical randomness audit passed ({len(_iter_luau_files())} Luau files checked)")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--self-test",
        action="store_true",
        help="verify the audit detects code references while ignoring comments and strings",
    )
    args = parser.parse_args()

    if args.self_test:
        _self_test()
        return 0

    return _audit_repository()


if __name__ == "__main__":
    raise SystemExit(main())
