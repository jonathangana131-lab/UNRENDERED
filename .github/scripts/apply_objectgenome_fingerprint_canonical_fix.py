#!/usr/bin/env python3
from __future__ import annotations

import argparse
import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parents[2]
OBJECT_GENOME = ROOT / "src/shared/Objects/ObjectGenome.luau"
TESTS = ROOT / "tests/object_genome.luau"
DOCS = ROOT / "Docs/OBJECT_GENOME.md"

OLD_NUMBER = '''local function canonicalFingerprintNumber(value: number): string
\tif value == 0 then
\t\treturn "0"
\tend
\treturn string.format("%.17g", value)
end'''

NEW_NUMBER = '''local function canonicalFingerprintNumber(value: number): string
\tassert(isFinite(value), "validated ObjectGenome fingerprint numbers must be finite")
\tif value == 0 then
\t\tvalue = 0
\tend
\treturn string.pack(">d", value)
end'''

OLD_MATERIAL = '''\t\tlocal materialKeyValidation = MaterialDNA.validateReference({
\t\t\tid = component.materialKey,
\t\t\trecipeVersion = 1,
\t\t})
\t\tif not materialKeyValidation.ok then
\t\t\taddIssue(
\t\t\t\tissues,
\t\t\t\t"component.material_key",
\t\t\t\tpath .. ".materialKey",
\t\t\t\t"materialKey must satisfy MaterialDNA v2 project id rules"
\t\t\t)
\t\tend
\t\tlocal materialRecipeVersionValidation = MaterialDNA.validateReference({
\t\t\tid = "material.v1.object-genome-validation-probe",
\t\t\trecipeVersion = component.materialRecipeVersion,
\t\t})
\t\tif not materialRecipeVersionValidation.ok then
\t\t\taddIssue(
\t\t\t\tissues,
\t\t\t\t"component.material_recipe_version",
\t\t\t\tpath .. ".materialRecipeVersion",
\t\t\t\t"materialRecipeVersion must satisfy MaterialDNA v2 recipe revision rules"
\t\t\t)
\t\tend'''

NEW_MATERIAL = '''\t\tlocal materialReferenceValidation = MaterialDNA.validateReference({
\t\t\tid = component.materialKey,
\t\t\trecipeVersion = component.materialRecipeVersion,
\t\t})
\t\tif not materialReferenceValidation.ok then
\t\t\tlocal diagnosedField = false
\t\t\tlocal materialKeyValidation = MaterialDNA.validateReference({
\t\t\t\tid = component.materialKey,
\t\t\t\trecipeVersion = 1,
\t\t\t})
\t\t\tif not materialKeyValidation.ok then
\t\t\t\tdiagnosedField = true
\t\t\t\taddIssue(
\t\t\t\t\tissues,
\t\t\t\t\t"component.material_key",
\t\t\t\t\tpath .. ".materialKey",
\t\t\t\t\t"materialKey must satisfy MaterialDNA v2 project id rules"
\t\t\t\t)
\t\t\tend

\t\t\tlocal materialRecipeVersionValidation = MaterialDNA.validateReference({
\t\t\t\tid = "material.v1.object-genome-validation-probe",
\t\t\t\trecipeVersion = component.materialRecipeVersion,
\t\t\t})
\t\t\tif not materialRecipeVersionValidation.ok then
\t\t\t\tdiagnosedField = true
\t\t\t\taddIssue(
\t\t\t\t\tissues,
\t\t\t\t\t"component.material_recipe_version",
\t\t\t\t\tpath .. ".materialRecipeVersion",
\t\t\t\t\t"materialRecipeVersion must satisfy MaterialDNA v2 recipe revision rules"
\t\t\t\t)
\t\t\tend

\t\t\tif not diagnosedField then
\t\t\t\taddIssue(
\t\t\t\t\tissues,
\t\t\t\t\t"component.material_reference",
\t\t\t\t\tpath,
\t\t\t\t\t"material reference must satisfy the complete MaterialDNA v2 reference contract"
\t\t\t\t)
\t\t\tend
\t\tend'''

TEST_MARKER = '''\tfor _, materialCase in ipairs(materialBoundaryCases) do
\t\tlocal reference = {
\t\t\tid = materialCase.id,
\t\t\trecipeVersion = materialCase.recipeVersion,
\t\t}
\t\tlocal expectedReferenceValidity = MaterialDNA.validateReference(reference).ok
\t\tlocal boundaryGenome = deepCopy(Fixtures.officeChair)
\t\tboundaryGenome.components[1].materialKey = reference.id
\t\tboundaryGenome.components[1].materialRecipeVersion = reference.recipeVersion
\t\texpect(
\t\t\t"ObjectGenome matches MaterialDNA reference boundary: " .. materialCase.name,
\t\t\tObjectGenome.inspect(boundaryGenome).ok == expectedReferenceValidity
\t\t)
\tend
'''

LONG_STRING_TEST = '''
\tlocal longContentGenome = deepCopy(Fixtures.officeChair)
\tlongContentGenome.provenance.productLine = string.rep("x", 513)
\texpect(
\t\t"accepts v1-valid free-form recipe strings above StableId part length",
\t\tObjectGenome.inspect(longContentGenome).ok
\t)
\tlocal longFingerprintOk, longFingerprint = pcall(function()
\t\treturn ObjectGenome.recipeFingerprint(longContentGenome)
\tend)
\texpect(
\t\t"fingerprint remains total for v1-valid long free-form strings",
\t\tlongFingerprintOk and type(longFingerprint) == "string"
\t)
\texpect(
\t\t"long free-form recipe fingerprint repeats deterministically",
\t\tlongFingerprintOk
\t\t\tand longFingerprint == ObjectGenome.recipeFingerprint(longContentGenome)
\t)
'''

OLD_DOC = '''- `ObjectGenome.recipeFingerprint()` is a separate versioned deterministic seal over the entire validated immutable v1 recipe table. It is not an entity/state/persistence identity. Fixture fingerprint goldens make same-version canonical recipe drift visible in tests, including nested provenance, geometry, mass, support, mechanism, affordance, and exact material-reference changes.'''

NEW_DOC = '''- `ObjectGenome.recipeFingerprint()` is a separate versioned deterministic seal over the entire validated immutable v1 recipe table. It is not an entity/state/persistence identity. Arbitrary accepted strings are length-framed and folded in bounded chunks; finite numbers use explicit big-endian 64-bit `string.pack(">d", value)` bytes with signed zero normalized before hashing, so the seal does not depend on host printf spelling. Fixture fingerprint goldens make same-version canonical recipe drift visible in tests, including nested provenance, geometry, mass, support, mechanism, affordance, and exact material-reference changes.'''

GOLDEN_PATTERN = re.compile(r"^(officeChair|officeTable|filingCabinet)=(object-genome-recipe:v1:[0-9a-f]{32})$", re.MULTILINE)
OLD_GOLDENS = {
    "officeChair": "object-genome-recipe:v1:1d5bb9a8ca475743a26663e492e22d56",
    "officeTable": "object-genome-recipe:v1:a7c8f49674cc01c57d91c0cb770c17fa",
    "filingCabinet": "object-genome-recipe:v1:e67dcf0b6b6563ef9bb5efa0f6086ddc",
}


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected one marker, found {count}")
    return text.replace(old, new, 1)


def apply_patch() -> None:
    source = OBJECT_GENOME.read_text()
    source = replace_once(source, OLD_NUMBER, NEW_NUMBER, "numeric encoder")
    source = replace_once(source, OLD_MATERIAL, NEW_MATERIAL, "MaterialDNA boundary")
    OBJECT_GENOME.write_text(source)

    tests = TESTS.read_text()
    if "fingerprint remains total for v1-valid long free-form strings" not in tests:
        tests = replace_once(tests, TEST_MARKER, TEST_MARKER + LONG_STRING_TEST, "long-string regression insertion")
    TESTS.write_text(tests)

    docs = DOCS.read_text()
    docs = replace_once(docs, OLD_DOC, NEW_DOC, "fingerprint docs")
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
