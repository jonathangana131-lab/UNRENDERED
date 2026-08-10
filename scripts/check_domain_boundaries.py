#!/usr/bin/env python3
"""Fail when canonical shared-domain Luau crosses representation/storage boundaries.

The canonical world model is plain/versioned data. Roblox Instances, Workspace, service
access, persistence backends, and concrete asset IDs belong behind project adapters rather
than inside the shared domain contracts audited here.
"""

from __future__ import annotations

import argparse
import re
import sys
from dataclasses import dataclass
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
DOMAIN_ROOTS = (
    REPO_ROOT / "src/shared/Core",
    REPO_ROOT / "src/shared/Reality",
    REPO_ROOT / "src/shared/Spatial",
    REPO_ROOT / "src/shared/WorldGen",
    REPO_ROOT / "src/shared/Materials",
    REPO_ROOT / "src/shared/Objects",
)
ASSET_LITERAL_ROOTS = (
    REPO_ROOT / "src/shared/Materials",
    REPO_ROOT / "src/shared/Objects",
)


@dataclass(frozen=True)
class Rule:
    name: str
    pattern: re.Pattern[str]


CODE_RULES = (
    Rule("Roblox Instance construction in shared domain", re.compile(r"\bInstance\s*\.\s*new\s*\(")),
    Rule("Roblox service access in shared domain", re.compile(r"\bgame\s*:\s*GetService\s*\(")),
    Rule("Workspace access in shared domain", re.compile(r"\bworkspace\b")),
    Rule("DataStoreService access in shared domain", re.compile(r"\bDataStoreService\b")),
    Rule("MemoryStoreService access in shared domain", re.compile(r"\bMemoryStoreService\b")),
    Rule("MessagingService access in shared domain", re.compile(r"\bMessagingService\b")),
)
ASSET_LITERAL = re.compile(r"rbxassetid://", re.IGNORECASE)


def _long_bracket_level(source: str, start: int) -> tuple[int, int] | None:
    if start >= len(source) or source[start] != "[":
        return None
    cursor = start + 1
    while cursor < len(source) and source[cursor] == "=":
        cursor += 1
    if cursor < len(source) and source[cursor] == "[":
        return cursor - start - 1, cursor + 1
    return None


def _mask_luau(source: str, *, mask_strings: bool) -> str:
    """Mask comments and optionally literal string chunks, preserving interpolation code."""

    masked = list(source)
    length = len(source)

    def blank(index: int) -> None:
        if masked[index] != "\n":
            masked[index] = " "

    def mask_quoted(start: int) -> int:
        quote = source[start]
        if mask_strings:
            blank(start)
        cursor = start + 1
        while cursor < length:
            current = source[cursor]
            if mask_strings:
                blank(cursor)
            if current == "\\" and cursor + 1 < length:
                cursor += 1
                if mask_strings:
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
        if mask_strings:
            for index in range(start, content_start):
                blank(index)
        cursor = content_start
        while cursor < length:
            if source.startswith(close, cursor):
                if mask_strings:
                    for index in range(cursor, min(cursor + len(close), length)):
                        blank(index)
                return cursor + len(close)
            if mask_strings:
                blank(cursor)
            cursor += 1
        return cursor

    def mask_comment(start: int) -> int:
        blank(start)
        if start + 1 < length:
            blank(start + 1)
        cursor = start + 2
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
                    return cursor + len(close)
                blank(cursor)
                cursor += 1
            return cursor
        while cursor < length and source[cursor] != "\n":
            blank(cursor)
            cursor += 1
        return cursor

    def mask_interpolated(start: int) -> int:
        if mask_strings:
            blank(start)
        cursor = start + 1
        while cursor < length:
            current = source[cursor]
            if current == "\\":
                if mask_strings:
                    blank(cursor)
                cursor += 1
                if cursor < length:
                    if mask_strings:
                        blank(cursor)
                    cursor += 1
                continue
            if current == "`":
                if mask_strings:
                    blank(cursor)
                return cursor + 1
            if current == "{":
                if mask_strings:
                    blank(cursor)
                cursor = scan_interpolation(cursor + 1)
                continue
            if mask_strings:
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
                    if mask_strings:
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


def _is_asset_literal_domain(path: Path) -> bool:
    return any(path == root or root in path.parents for root in ASSET_LITERAL_ROOTS)


def _line_for_offset(source: str, offset: int) -> tuple[int, str]:
    line_number = source.count("\n", 0, offset) + 1
    lines = source.splitlines()
    snippet = lines[line_number - 1].strip() if line_number <= len(lines) else ""
    return line_number, snippet


def _find_violations(path: Path, source: str) -> list[tuple[int, str, str]]:
    violations: list[tuple[int, str, str]] = []
    code_only = _mask_luau(source, mask_strings=True)
    for rule in CODE_RULES:
        for match in rule.pattern.finditer(code_only):
            line_number, snippet = _line_for_offset(source, match.start())
            violations.append((line_number, rule.name, snippet))
    if _is_asset_literal_domain(path):
        comments_removed = _mask_luau(source, mask_strings=False)
        for match in ASSET_LITERAL.finditer(comments_removed):
            line_number, snippet = _line_for_offset(source, match.start())
            violations.append((line_number, "embedded Roblox asset id in material/object domain", snippet))
    return sorted(violations, key=lambda item: (item[0], item[1]))


def _self_test() -> None:
    root = REPO_ROOT
    cases = (
        (root / "src/shared/Objects/Test.luau", "local part = Instance.new('Part')", "Roblox Instance construction in shared domain"),
        (root / "src/shared/Reality/Test.luau", "local players = game:GetService('Players')", "Roblox service access in shared domain"),
        (root / "src/shared/Spatial/Test.luau", "local model = workspace.Model", "Workspace access in shared domain"),
        (root / "src/shared/Reality/Test.luau", "local service = DataStoreService", "DataStoreService access in shared domain"),
        (root / "src/shared/Reality/Test.luau", "local service = MemoryStoreService", "MemoryStoreService access in shared domain"),
        (root / "src/shared/Reality/Test.luau", "local service = MessagingService", "MessagingService access in shared domain"),
        (root / "src/shared/Materials/Test.luau", "local texture = 'rbxassetid://123'", "embedded Roblox asset id in material/object domain"),
    )
    for path, source, expected_rule in cases:
        actual_rules = {rule for _, rule, _ in _find_violations(path, source)}
        if expected_rule not in actual_rules:
            raise AssertionError(f"domain-boundary self-test expected {expected_rule!r}, got {sorted(actual_rules)!r}")

    interpolation_source = r'''
local literal = `Instance.new('Part') workspace game:GetService('Players')`
local escaped = `\{Instance.new('Part') stays literal}`
local instance = `value = {Instance.new('Part')}`
local service = `value = {game:GetService('Players')}`
local workspaceValue = `value = {({ root = workspace, nested = { ok = true } }).root}`
local nested = `value = {`inner = {MessagingService}`}`
local quotedInside = `value = {"DataStoreService"}`
local commentInside = `value = { -- MemoryStoreService
    42
}`
'''.lstrip()
    interpolation_violations = _find_violations(root / "src/shared/Reality/Test.luau", interpolation_source)
    interpolation_rules = [(line, rule) for line, rule, _ in interpolation_violations]
    expected_interpolation = [
        (3, "Roblox Instance construction in shared domain"),
        (4, "Roblox service access in shared domain"),
        (5, "Workspace access in shared domain"),
        (6, "MessagingService access in shared domain"),
    ]
    if interpolation_rules != expected_interpolation:
        raise AssertionError(f"interpolation self-test expected {expected_interpolation!r}, got {interpolation_rules!r}")

    clean_source = r'''
-- Instance.new("Part") game:GetService("Players") workspace DataStoreService
--[=[ MemoryStoreService MessagingService ]=]
local quoted = "workspace game:GetService('Players') MemoryStoreService"
local longQuoted = [=[Instance.new('Part') DataStoreService]=]
local interpolatedLiteral = `Instance.new('Part') MessagingService workspace`
local escapedInterpolation = `\{game:GetService('Players') is literal}`
local position = Vector3.new(1, 2, 3)
'''.lstrip()
    clean_violations = _find_violations(root / "src/shared/Core/Test.luau", clean_source)
    if clean_violations:
        raise AssertionError(f"domain-boundary self-test produced false positives: {clean_violations!r}")

    asset_source = r'''
-- rbxassetid://111 is documentation only
local direct = "rbxassetid://222"
local interpolatedLiteral = `rbxassetid://333`
local interpolationComment = `value = { -- rbxassetid://444 is comment only
    "clean.family"
}`
'''.lstrip()
    asset_violations = _find_violations(root / "src/shared/Materials/Test.luau", asset_source)
    asset_lines = [line for line, rule, _ in asset_violations if rule == "embedded Roblox asset id in material/object domain"]
    if asset_lines != [2, 3]:
        raise AssertionError(f"asset-literal self-test expected lines [2, 3], got {asset_lines!r}")

    outside_asset_domain = _find_violations(root / "src/shared/Core/Test.luau", "local diagnostic = 'rbxassetid://123'")
    if outside_asset_domain:
        raise AssertionError(f"domain-boundary self-test applied asset rule outside its scope: {outside_asset_domain!r}")

    print("Shared-domain boundary guard self-test passed")


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
        for line_number, rule, snippet in _find_violations(path, source):
            violations.append((path, line_number, rule, snippet))
    if violations:
        print("Shared-domain architecture boundary violations found:", file=sys.stderr)
        for path, line_number, rule, snippet in violations:
            relative = path.relative_to(REPO_ROOT)
            print(f"  {relative}:{line_number}: {rule}: {snippet}", file=sys.stderr)
        print("Keep Roblox representation, service, persistence, and concrete asset bindings behind project adapters.", file=sys.stderr)
        return 1
    print(f"Shared-domain boundary audit passed ({len(files)} Luau files checked)")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--self-test", action="store_true", help="verify code-only and asset-literal boundary checks before auditing the repository")
    args = parser.parse_args()
    if args.self_test:
        _self_test()
        return 0
    return _audit_repository()


if __name__ == "__main__":
    raise SystemExit(main())
