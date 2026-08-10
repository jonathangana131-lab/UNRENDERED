from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    p = Path(path)
    text = p.read_text()
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{path}: expected exactly one marker, found {count}")
    p.write_text(text.replace(old, new, 1))


# Exact MaterialDNA boundary, preserving ObjectGenome's stable field diagnostics.
replace_once(
    "src/shared/Objects/ObjectGenome.luau",
    'local StableId = require(script.Parent.Parent.Core.StableId)\n',
    'local StableId = require(script.Parent.Parent.Core.StableId)\nlocal MaterialDNA = require(script.Parent.Parent.Materials.MaterialDNA)\n',
)
replace_once(
    "src/shared/Objects/ObjectGenome.luau",
    'ObjectGenome.STABLE_ID_NAMESPACE = "object-genome"\n',
    'ObjectGenome.STABLE_ID_NAMESPACE = "object-genome"\nObjectGenome.RECIPE_FINGERPRINT_NAMESPACE = "object-genome-recipe"\nObjectGenome.RECIPE_FINGERPRINT_VERSION = 1\n',
)
replace_once(
    "src/shared/Objects/ObjectGenome.luau",
    '''\t\tif not isSemanticKey(component.materialKey) then
\t\t\taddIssue(
\t\t\t\tissues,
\t\t\t\t"component.material_key",
\t\t\t\tpath .. ".materialKey",
\t\t\t\t"materialKey must be the stable lowercase MaterialDNA recipe id"
\t\t\t)
\t\tend
\t\tif not isPositiveInteger(component.materialRecipeVersion) then
\t\t\taddIssue(
\t\t\t\tissues,
\t\t\t\t"component.material_recipe_version",
\t\t\t\tpath .. ".materialRecipeVersion",
\t\t\t\t"materialRecipeVersion must be a positive integer"
\t\t\t)
\t\tend
''',
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
)

fingerprint_helpers = '''local RECIPE_FINGERPRINT_CHUNK_BYTES = 384

local function canonicalFingerprintNumber(value: number): string
\tif value == 0 then
\t\treturn "0"
\tend
\treturn string.format("%.17g", value)
end

local function foldFingerprintToken(signature: string, kind: string, payload: string): string
\tlocal nextSignature = StableId.fromParts(ObjectGenome.RECIPE_FINGERPRINT_NAMESPACE, {
\t\tsignature,
\t\tkind,
\t\ttostring(#payload),
\t})
\tlocal offset = 1
\twhile offset <= #payload do
\t\tlocal chunk = string.sub(payload, offset, offset + RECIPE_FINGERPRINT_CHUNK_BYTES - 1)
\t\tnextSignature = StableId.fromParts(ObjectGenome.RECIPE_FINGERPRINT_NAMESPACE, {
\t\t\tnextSignature,
\t\t\t"chunk",
\t\t\tchunk,
\t\t})
\t\toffset += RECIPE_FINGERPRINT_CHUNK_BYTES
\tend
\treturn nextSignature
end

local function sortedFingerprintKeys(value: { [any]: any }): { any }
\tlocal keys: { any } = {}
\tfor key in pairs(value) do
\t\ttable.insert(keys, key)
\tend
\ttable.sort(keys, function(left: any, right: any): boolean
\t\tlocal leftType = type(left)
\t\tlocal rightType = type(right)
\t\tif leftType ~= rightType then
\t\t\treturn leftType < rightType
\t\tend
\t\tif leftType == "number" then
\t\t\treturn (left :: number) < (right :: number)
\t\tend
\t\tassert(leftType == "string", "validated ObjectGenome keys must be strings or array indices")
\t\treturn (left :: string) < (right :: string)
\tend)
\treturn keys
end

local function fingerprintValue(signature: string, value: any): string
\tlocal valueType = type(value)
\tif valueType == "string" then
\t\treturn foldFingerprintToken(signature, "string", value)
\telseif valueType == "number" then
\t\treturn foldFingerprintToken(signature, "number", canonicalFingerprintNumber(value))
\telseif valueType == "boolean" then
\t\treturn foldFingerprintToken(signature, "boolean", if value then "true" else "false")
\telseif valueType == "table" then
\t\tlocal keys = sortedFingerprintKeys(value)
\t\tlocal nextSignature = foldFingerprintToken(signature, "table", tostring(#keys))
\t\tfor _, key in ipairs(keys) do
\t\t\tnextSignature = fingerprintValue(nextSignature, key)
\t\t\tnextSignature = fingerprintValue(nextSignature, value[key])
\t\tend
\t\treturn foldFingerprintToken(nextSignature, "end-table", tostring(#keys))
\tend
\terror(`unsupported validated ObjectGenome fingerprint value type: {valueType}`)
end

function ObjectGenome.recipeFingerprint(value: ObjectGenome): string
\tObjectGenome.validate(value)
\tlocal signature = StableId.fromParts(ObjectGenome.RECIPE_FINGERPRINT_NAMESPACE, {
\t\ttostring(ObjectGenome.RECIPE_FINGERPRINT_VERSION),
\t\t"root",
\t})
\treturn fingerprintValue(signature, value)
end

'''
replace_once(
    "src/shared/Objects/ObjectGenome.luau",
    'function ObjectGenome.identityParts(value: ObjectGenome): { string }\n',
    fingerprint_helpers + 'function ObjectGenome.identityParts(value: ObjectGenome): { string }\n',
)

# Document identity stability and separate full-content drift seal without disturbing
# the landed mechanism-state semantics added by #117.
replace_once(
    "Docs/OBJECT_GENOME.md",
    '- `familyId + familyVersion + variantKey + schemaVersion` form the stable genome identity input. `ObjectGenome.identityParts()` supplies those semantic parts to the locked project `StableId` contract; ObjectGenome does not duplicate hashing/canonical encoding.\n',
    '- `familyId + familyVersion + variantKey + schemaVersion` remain the complete ObjectGenome v1 stable identity input. `ObjectGenome.identityParts()` supplies exactly those semantic parts to the locked project `StableId` contract; this Foundation repair does not rewrite established v1 IDs.\n- `ObjectGenome.recipeFingerprint()` is a separate versioned deterministic seal over the entire validated immutable v1 recipe table. It is not an entity/state/persistence identity. Fixture fingerprint goldens make same-version canonical recipe drift visible in tests, including nested provenance, geometry, mass, support, mechanism, affordance, and exact material-reference changes.\n',
)
replace_once(
    "Docs/OBJECT_GENOME.md",
    '- Each component pins an exact MaterialDNA recipe revision as `(materialKey, materialRecipeVersion)`: `materialKey` is the stable lowercase MaterialDNA recipe id and `materialRecipeVersion` is its positive content revision. ObjectGenome validates and owns those plain values but does not import MaterialDNA implementation details or Roblox asset IDs. A published component material-revision change is a canonical object recipe change and therefore requires the corresponding `familyVersion` to advance rather than silently retargeting an established genome identity.\n',
    '- Each component pins an exact MaterialDNA recipe revision as `(materialKey, materialRecipeVersion)`. ObjectGenome keeps those values flat in its own schema and validates their value domains through production `MaterialDNA.validateReference()` semantics while preserving ObjectGenome\'s stable field-specific diagnostics. A published component material-revision change is canonical object recipe content and therefore requires the corresponding `familyVersion` to advance; the separate recipe fingerprint catches an accidental same-version retarget.\n',
)
replace_once(
    "Docs/OBJECT_GENOME.md",
    "Changing field meaning or deterministic identity inputs requires an object schema/version decision. Changing published canonical recipe content such as a component's exact material revision requires advancing `familyVersion`. Extend mechanism/affordance vocabularies through this contract rather than embedding furniture-specific runtime state into unrelated systems.\n",
    "Changing field meaning or deterministic identity inputs requires an object schema/version decision. Changing published canonical recipe content such as a component's exact material revision requires advancing `familyVersion`; the full immutable recipe fingerprint is the CI/golden guard against forgetting that revision. Extend mechanism/affordance vocabularies through this contract rather than embedding furniture-specific runtime state into unrelated systems.\n",
)

# Cross-contract and full-content regression coverage.
replace_once(
    "tests/object_genome.luau",
    'local StableId = ProductionLoader.requireShared("Core/StableId")\nlocal ObjectGenome = ProductionLoader.requireShared("Objects/ObjectGenome")\n',
    'local StableId = ProductionLoader.requireShared("Core/StableId")\nlocal MaterialDNA = ProductionLoader.requireShared("Materials/MaterialDNA")\nlocal ObjectGenome = ProductionLoader.requireShared("Objects/ObjectGenome")\n',
)
for identity, marker in [
    ("object-genome:v1:51c5fd2813c6dfc8b3e089570b0632af", "__CHAIR_FINGERPRINT__"),
    ("object-genome:v1:44d2ee4894de4c20184e7e2a91c876e4", "__TABLE_FINGERPRINT__"),
    ("object-genome:v1:7bd8b9e0c82d36ae53374a390fe2f969", "__CABINET_FINGERPRINT__"),
]:
    replace_once(
        "tests/object_genome.luau",
        f'\t\t\tidentity = "{identity}",\n',
        f'\t\t\tidentity = "{identity}",\n\t\t\tfingerprint = "{marker}",\n',
    )
replace_once(
    "tests/object_genome.luau",
    '\t\texpect(fixture.name .. " repeat identity", identity == ObjectGenome.identityKey(fixture.genome))\n\n',
    '''\t\texpect(fixture.name .. " repeat identity", identity == ObjectGenome.identityKey(fixture.genome))

\t\tlocal fingerprint = ObjectGenome.recipeFingerprint(fixture.genome)
\t\texpect(fixture.name .. " locked full recipe fingerprint", fingerprint == fixture.fingerprint)
\t\texpect(
\t\t\tfixture.name .. " uses separate recipe fingerprint namespace",
\t\t\tStableId.is(fingerprint, ObjectGenome.RECIPE_FINGERPRINT_NAMESPACE)
\t\t)
\t\texpect(
\t\t\tfixture.name .. " repeat recipe fingerprint",
\t\t\tfingerprint == ObjectGenome.recipeFingerprint(fixture.genome)
\t\t)

''',
)
replace_once(
    "tests/object_genome.luau",
    '''\t\t\texpect(
\t\t\t\tfixture.name .. " component pins a material recipe revision",
\t\t\t\tcomponent.materialRecipeVersion == 1
\t\t\t)
\t\tend
''',
    '''\t\t\texpect(
\t\t\t\tfixture.name .. " component pins a material recipe revision",
\t\t\t\tcomponent.materialRecipeVersion == 1
\t\t\t)
\t\t\texpect(
\t\t\t\tfixture.name .. " component reference satisfies production MaterialDNA",
\t\t\t\tMaterialDNA.validateReference({
\t\t\t\t\tid = component.materialKey,
\t\t\t\t\trecipeVersion = component.materialRecipeVersion,
\t\t\t\t}).ok
\t\t\t)
\t\tend
''',
)
replace_once(
    "tests/object_genome.luau",
    '''\texpect(
\t\t"material recipe revision is retained as canonical object recipe input",
\t\trevisedShell ~= nil
\t\t\tand canonicalShell ~= nil
\t\t\tand revisedShell.materialKey == canonicalShell.materialKey
\t\t\tand revisedShell.materialRecipeVersion ~= canonicalShell.materialRecipeVersion
\t\t\tand ObjectGenome.inspect(revisedMaterial).ok
\t)

''',
    '''\texpect(
\t\t"material recipe revision is retained as canonical object recipe input",
\t\trevisedShell ~= nil
\t\t\tand canonicalShell ~= nil
\t\t\tand revisedShell.materialKey == canonicalShell.materialKey
\t\t\tand revisedShell.materialRecipeVersion ~= canonicalShell.materialRecipeVersion
\t\t\tand ObjectGenome.inspect(revisedMaterial).ok
\t)
\texpect(
\t\t"same-version material drift preserves established v1 identity",
\t\tObjectGenome.identityKey(revisedMaterial) == ObjectGenome.identityKey(Fixtures.filingCabinet)
\t)
\texpect(
\t\t"same-version material drift changes full recipe fingerprint",
\t\tObjectGenome.recipeFingerprint(revisedMaterial) ~= ObjectGenome.recipeFingerprint(Fixtures.filingCabinet)
\t)

\tlocal publishedMaterialRevision = deepCopy(Fixtures.filingCabinet)
\tlocal publishedShell = findComponent(publishedMaterialRevision, "shell")
\tpublishedMaterialRevision.familyVersion += 1
\tif publishedShell ~= nil then
\t\tpublishedShell.materialRecipeVersion += 1
\tend
\texpect(
\t\t"published material revision with familyVersion advance is valid and changes identity",
\t\tpublishedShell ~= nil
\t\t\tand ObjectGenome.inspect(publishedMaterialRevision).ok
\t\t\tand ObjectGenome.identityKey(publishedMaterialRevision)
\t\t\t\t~= ObjectGenome.identityKey(Fixtures.filingCabinet)
\t)

\tlocal materialBoundaryCases = {
\t\t{ name = "slash id", id = "material.v1/reference-probe", recipeVersion = 1 },
\t\t{ name = "numeric-only id", id = "123", recipeVersion = 1 },
\t\t{ name = "overlong id", id = "material.v1." .. string.rep("a", 151), recipeVersion = 1 },
\t\t{ name = "max recipe version", id = "material.v1.reference-probe", recipeVersion = 2147483647 },
\t\t{ name = "above max recipe version", id = "material.v1.reference-probe", recipeVersion = 2147483648 },
\t}
\tfor _, materialCase in ipairs(materialBoundaryCases) do
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

\tlocal function expectSameVersionFingerprintDrift(name, mutate)
\t\tlocal genome = deepCopy(Fixtures.officeChair)
\t\tmutate(genome)
\t\texpect(name .. " remains a valid v1 recipe", ObjectGenome.inspect(genome).ok)
\t\texpect(
\t\t\tname .. " does not rewrite established v1 identity inputs",
\t\t\tObjectGenome.identityKey(genome) == ObjectGenome.identityKey(Fixtures.officeChair)
\t\t)
\t\texpect(
\t\t\tname .. " changes full immutable recipe fingerprint",
\t\t\tObjectGenome.recipeFingerprint(genome) ~= ObjectGenome.recipeFingerprint(Fixtures.officeChair)
\t\t)
\tend

\texpectSameVersionFingerprintDrift("provenance drift", function(genome)
\t\tgenome.provenance.productLine ..= " Revised"
\tend)
\texpectSameVersionFingerprintDrift("dimension drift", function(genome)
\t\tgenome.dimensionsM.x += 0.01
\tend)
\texpectSameVersionFingerprintDrift("mass drift", function(genome)
\t\tgenome.massKg += 0.01
\tend)
\texpectSameVersionFingerprintDrift("component drift", function(genome)
\t\tgenome.components[1].role ..= " revised"
\tend)
\texpectSameVersionFingerprintDrift("support-order drift", function(genome)
\t\tlocal base = findComponent(genome, "base")
\t\tif base ~= nil then
\t\t\tbase.supportKeys[1], base.supportKeys[2] = base.supportKeys[2], base.supportKeys[1]
\t\tend
\tend)
\texpectSameVersionFingerprintDrift("mechanism drift", function(genome)
\t\tgenome.mechanisms[#genome.mechanisms].maxDegrees -= 1
\tend)
\texpectSameVersionFingerprintDrift("affordance drift", function(genome)
\t\tgenome.affordances[1].radiusM -= 0.01
\tend)

''',
)
