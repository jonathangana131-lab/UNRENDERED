#!/usr/bin/env python3
from __future__ import annotations

import argparse
import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parents[2]
SOURCE = ROOT / "src/shared/Objects/ObjectGenome.luau"
TESTS = ROOT / "tests/object_genome.luau"
DOCS = ROOT / "Docs/OBJECT_GENOME.md"

OLD_VERSION = 'ObjectGenome.RECIPE_FINGERPRINT_VERSION = 1'
NEW_VERSION = 'ObjectGenome.RECIPE_FINGERPRINT_VERSION = 2'

TEST_MARKER = '\tfor _, fixture in ipairs(fixtureCases) do\n'
VERSION_TEST = '''\texpect(
\t\t"locks corrected recipe fingerprint encoding revision",
\t\tObjectGenome.RECIPE_FINGERPRINT_VERSION == 2
\t)

'''

DOC_OLD = '''- `ObjectGenome.recipeFingerprint()` is a separate versioned deterministic seal over the entire validated immutable v1 recipe table. It is not an entity/state/persistence identity. Arbitrary accepted strings are length-framed and folded in bounded chunks; finite numbers use explicit big-endian 64-bit `string.pack(">d", value)` bytes with signed zero normalized before hashing, so the seal does not depend on host printf spelling. Fixture fingerprint goldens make same-version canonical recipe drift visible in tests, including nested provenance, geometry, mass, support, mechanism, affordance, and exact material-reference changes.'''
DOC_NEW = '''- `ObjectGenome.recipeFingerprint()` is a separate versioned deterministic seal over the entire validated immutable v1 recipe table. It is not an entity/state/persistence identity. Fingerprint encoding revision **2** is the corrected binary canonicalization: arbitrary accepted strings are length-framed and folded in bounded chunks; finite numbers use explicit big-endian 64-bit `string.pack(">d", value)` bytes with signed zero normalized before hashing, so the seal does not depend on host printf spelling. Revision 1 remains historical and is never silently reinterpreted under the corrected encoder. Fixture fingerprint goldens make same-version canonical recipe drift visible in tests, including nested provenance, geometry, mass, support, mechanism, affordance, and exact material-reference changes.'''

OLD_GOLDENS = {
    "officeChair": "object-genome-recipe:v1:ffa0af4f10aec2dbbd9ad86e81afaf9d",
    "officeTable": "object-genome-recipe:v1:dd51fe1c7c46d148e2ae5b01f2e08c69",
    "filingCabinet": "object-genome-recipe:v1:de0c52ff58128135017337220a339f3c",
}
GOLDEN_PATTERN = re.compile(r"^(officeChair|officeTable|filingCabinet)=(object-genome-recipe:v1:[0-9a-f]{32})$", re.MULTILINE)


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected one marker, found {count}")
    return text.replace(old, new, 1)


def apply_patch() -> None:
    source = SOURCE.read_text()
    source = replace_once(source, OLD_VERSION, NEW_VERSION, "fingerprint version")
    SOURCE.write_text(source)

    tests = TESTS.read_text()
    if "locks corrected recipe fingerprint encoding revision" not in tests:
        tests = replace_once(tests, TEST_MARKER, VERSION_TEST + TEST_MARKER, "version regression insertion")
    TESTS.write_text(tests)

    docs = DOCS.read_text()
    docs = replace_once(docs, DOC_OLD, DOC_NEW, "fingerprint revision docs")
    DOCS.write_text(docs)


def apply_goldens(path: pathlib.Path) -> None:
    output = path.read_text()
    found = dict(GOLDEN_PATTERN.findall(output))
    missing = set(OLD_GOLDENS) - set(found)
    if missing:
        raise SystemExit(f"fingerprint probe missing: {sorted(missing)}\n{output}")

    tests = TESTS.read_text()
    for name, old in OLD_GOLDENS.items():
        new = found[name]
        count = tests.count(old)
        if count != 1:
            raise SystemExit(f"golden {name}: expected one old value, found {count}")
        tests = tests.replace(old, new, 1)
    TESTS.write_text(tests)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--goldens", type=pathlib.Path)
    args = parser.parse_args()
    if args.goldens is None:
        apply_patch()
    else:
        apply_goldens(args.goldens)


if __name__ == "__main__":
    main()
