from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    p = Path(path)
    text = p.read_text()
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{path}: expected exactly one marker, found {count}")
    p.write_text(text.replace(old, new, 1))


replace_once(
    "src/shared/Objects/ObjectGenome.luau",
    'ObjectGenome.RECIPE_FINGERPRINT_VERSION = 1\n',
    'ObjectGenome.RECIPE_FINGERPRINT_VERSION = 2\n',
)

replace_once(
    "src/shared/Objects/ObjectGenome.luau",
    '''local function canonicalFingerprintNumber(value: number): string
\tif value == 0 then
\t\treturn "0"
\tend
\treturn string.format("%.17g", value)
end
''',
    '''local function canonicalFingerprintNumber(value: number): string
\t-- ObjectGenome validation rejects non-finite numbers before fingerprinting. Encode
\t-- finite values as endian-stable double bytes rather than host-CRT formatted text.
\t-- Normalize both signed zeros to the same canonical payload.
\tlocal canonicalValue = if value == 0 then 0 else value
\treturn string.pack(">d", canonicalValue)
end
''',
)

replace_once(
    "src/shared/Objects/ObjectGenome.luau",
    '''\t\tlocal materialKeyValidation = MaterialDNA.validateReference({
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
\t\tend
''',
    '''\t\tlocal materialReferenceValidation = MaterialDNA.validateReference({
\t\t\tid = component.materialKey,
\t\t\trecipeVersion = component.materialRecipeVersion,
\t\t})
\t\tif not materialReferenceValidation.ok then
\t\t\t-- The actual pair is the source of truth. Independent probes only preserve
\t\t\t-- ObjectGenome's landed field-specific diagnostics when one field is invalid.
\t\t\tlocal materialKeyValidation = MaterialDNA.validateReference({
\t\t\t\tid = component.materialKey,
\t\t\t\trecipeVersion = 1,
\t\t\t})
\t\t\tlocal materialRecipeVersionValidation = MaterialDNA.validateReference({
\t\t\t\tid = "material.v1.object-genome-validation-probe",
\t\t\t\trecipeVersion = component.materialRecipeVersion,
\t\t\t})
\t\t\tif not materialKeyValidation.ok then
\t\t\t\taddIssue(
\t\t\t\t\tissues,
\t\t\t\t\t"component.material_key",
\t\t\t\t\tpath .. ".materialKey",
\t\t\t\t\t"materialKey must satisfy MaterialDNA v2 project id rules"
\t\t\t\t)
\t\t\tend
\t\t\tif not materialRecipeVersionValidation.ok then
\t\t\t\taddIssue(
\t\t\t\t\tissues,
\t\t\t\t\t"component.material_recipe_version",
\t\t\t\t\tpath .. ".materialRecipeVersion",
\t\t\t\t\t"materialRecipeVersion must satisfy MaterialDNA v2 recipe revision rules"
\t\t\t\t)
\t\t\tend
\t\t\tif materialKeyValidation.ok and materialRecipeVersionValidation.ok then
\t\t\t\taddIssue(
\t\t\t\t\tissues,
\t\t\t\t\t"component.material_reference",
\t\t\t\t\tpath,
\t\t\t\t\t"materialKey and materialRecipeVersion must satisfy the exact MaterialDNA v2 reference contract"
\t\t\t\t)
\t\t\tend
\t\tend
''',
)

replace_once(
    "Docs/OBJECT_GENOME.md",
    "- `ObjectGenome.recipeFingerprint()` is a separate versioned deterministic seal over the entire validated immutable v1 recipe table. It is not an entity/state/persistence identity. Fixture fingerprint goldens make same-version canonical recipe drift visible in tests, including nested provenance, geometry, mass, support, mechanism, affordance, and exact material-reference changes.\n",
    "- `ObjectGenome.recipeFingerprint()` is a separate versioned deterministic seal over the entire validated immutable v1 recipe table. It is not an entity/state/persistence identity. Fingerprint contract v2 canonicalizes finite numbers as big-endian packed double bytes (with signed zero normalized) and chunks arbitrary accepted strings before StableId folding, avoiding host numeric-formatting and semantic-part-length dependencies. Fixture fingerprint goldens make same-version canonical recipe drift visible in tests, including nested provenance, geometry, mass, support, mechanism, affordance, and exact material-reference changes.\n",
)
replace_once(
    "Docs/OBJECT_GENOME.md",
    "- Each component pins an exact MaterialDNA recipe revision as `(materialKey, materialRecipeVersion)`. ObjectGenome keeps those values flat in its own schema and validates their value domains through production `MaterialDNA.validateReference()` semantics while preserving ObjectGenome's stable field-specific diagnostics. A published component material-revision change is canonical object recipe content and therefore requires the corresponding `familyVersion` to advance; the separate recipe fingerprint catches an accidental same-version retarget.\n",
    "- Each component pins an exact MaterialDNA recipe revision as `(materialKey, materialRecipeVersion)`. ObjectGenome reconstructs that exact plain `{ id, recipeVersion }` pair and validates it through production `MaterialDNA.validateReference()` first. Independent key/version probes are used only to preserve ObjectGenome's stable field-specific diagnostics when the actual pair is invalid. A published component material-revision change is canonical object recipe content and therefore requires the corresponding `familyVersion` to advance; the separate recipe fingerprint catches an accidental same-version retarget.\n",
)

# The fingerprint encoding changed after v1 briefly reached main, so v2 gets fresh goldens.
for old, marker in [
    ("object-genome-recipe:v1:1d5bb9a8ca475743a26663e492e22d56", "__CHAIR_FINGERPRINT_V2__"),
    ("object-genome-recipe:v1:a7c8f49674cc01c57d91c0cb770c17fa", "__TABLE_FINGERPRINT_V2__"),
    ("object-genome-recipe:v1:e67dcf0b6b6563ef9bb5efa0f6086ddc", "__CABINET_FINGERPRINT_V2__"),
]:
    replace_once("tests/object_genome.luau", old, marker)

replace_once(
    "tests/object_genome.luau",
    '''\tfor _, fixture in ipairs(fixtureCases) do
''',
    '''\texpect("recipe fingerprint contract version is explicit", ObjectGenome.RECIPE_FINGERPRINT_VERSION == 2)

\tfor _, fixture in ipairs(fixtureCases) do
''',
)

boundary_block = '''\tfor _, materialCase in ipairs(materialBoundaryCases) do
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

boundary_plus_totality = boundary_block + '''\tlocal longContentGenome = deepCopy(Fixtures.officeChair)
\tlongContentGenome.provenance.productLine = string.rep("x", 1025)
\tlocal longContentReport = ObjectGenome.inspect(longContentGenome)
\tlocal longFingerprintOk, longFingerprint = pcall(ObjectGenome.recipeFingerprint, longContentGenome)
\texpect("otherwise-valid >512-byte recipe content remains valid", longContentReport.ok)
\texpect(
\t\t">512-byte recipe content fingerprints without exceeding StableId semantic-part limits",
\t\tlongFingerprintOk
\t\t\tand type(longFingerprint) == "string"
\t\t\tand StableId.is(longFingerprint, ObjectGenome.RECIPE_FINGERPRINT_NAMESPACE)
\t)
\texpect(
\t\t">512-byte recipe content fingerprint is deterministic",
\t\tlongFingerprintOk and longFingerprint == ObjectGenome.recipeFingerprint(longContentGenome)
\t)

\tlocal positiveZeroGenome = deepCopy(Fixtures.officeChair)
\tlocal negativeZeroGenome = deepCopy(Fixtures.officeChair)
\tpositiveZeroGenome.centerOfMassM.x = 0
\tnegativeZeroGenome.centerOfMassM.x = -0.0
\texpect(
\t\t"recipe fingerprint normalizes signed zero",
\t\tObjectGenome.recipeFingerprint(positiveZeroGenome) == ObjectGenome.recipeFingerprint(negativeZeroGenome)
\t)

'''
replace_once("tests/object_genome.luau", boundary_block, boundary_plus_totality)
