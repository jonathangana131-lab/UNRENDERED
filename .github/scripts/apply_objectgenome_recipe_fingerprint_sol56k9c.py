from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    p = Path(path)
    text = p.read_text()
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{path}: expected exactly one marker, found {count}")
    p.write_text(text.replace(old, new, 1))


# The scratch workflow first checks out the latest #109 three-file candidate. Keep
# exact MaterialDNA validation, but preserve the established ObjectGenome v1 ID.
replace_once(
    "src/shared/Objects/ObjectGenome.luau",
    'ObjectGenome.STABLE_ID_NAMESPACE = "object-genome"\n',
    'ObjectGenome.STABLE_ID_NAMESPACE = "object-genome"\n'
    'ObjectGenome.RECIPE_FINGERPRINT_NAMESPACE = "object-genome-recipe"\n'
    'ObjectGenome.RECIPE_FINGERPRINT_VERSION = 1\n',
)

old_identity = '''local function materialIdentitySignature(value: ObjectGenome): string
\t-- MaterialDNA recipe revisions are independent content versions. Fold the ordered
\t-- exact references into identity so a material retarget cannot preserve genomeId
\t-- even if an author forgets to advance the broader familyVersion.
\tlocal signature = StableId.fromParts("object-genome-materials", { "v1", "empty" })
\tfor index, component in ipairs(value.components) do
\t\tsignature = StableId.fromParts("object-genome-materials", {
\t\t\tsignature,
\t\t\ttostring(index),
\t\t\tcomponent.materialKey,
\t\t\ttostring(component.materialRecipeVersion),
\t\t})
\tend
\treturn signature
end

function ObjectGenome.identityParts(value: ObjectGenome): { string }
\treturn {
\t\ttostring(value.schemaVersion),
\t\tvalue.familyId,
\t\ttostring(value.familyVersion),
\t\tvalue.variantKey,
\t\tmaterialIdentitySignature(value),
\t}
end
'''

new_identity = '''local RECIPE_FINGERPRINT_CHUNK_BYTES = 384

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

function ObjectGenome.identityParts(value: ObjectGenome): { string }
\treturn {
\t\ttostring(value.schemaVersion),
\t\tvalue.familyId,
\t\ttostring(value.familyVersion),
\t\tvalue.variantKey,
\t}
end
'''
replace_once("src/shared/Objects/ObjectGenome.luau", old_identity, new_identity)

replace_once(
    "Docs/OBJECT_GENOME.md",
    "- `familyId + familyVersion + variantKey + schemaVersion` form the stable semantic family/version identity, and `ObjectGenome.identityParts()` also includes a deterministic signature of every component's ordered exact MaterialDNA reference. The locked project `StableId` contract performs hashing/canonical encoding. This makes a material recipe retarget mechanically change `genomeId` even if a producer forgets to advance `familyVersion`.\n",
    "- `familyId + familyVersion + variantKey + schemaVersion` remain the complete ObjectGenome v1 stable identity input. `ObjectGenome.identityParts()` supplies exactly those semantic parts to the locked project `StableId` contract; the Foundation repair does not rewrite established v1 IDs.\n"
    "- `ObjectGenome.recipeFingerprint()` is a separate versioned deterministic seal over the entire validated immutable v1 recipe table. It is not an entity/state/persistence identity. Fixture fingerprint goldens make same-version canonical recipe drift visible in tests, including nested provenance, geometry, mass, support, mechanism, affordance, and exact material-reference changes.\n",
)
replace_once(
    "Docs/OBJECT_GENOME.md",
    "- Each component pins an exact MaterialDNA recipe revision as `(materialKey, materialRecipeVersion)`. ObjectGenome keeps those values flat in its own schema, but validates the pair against production `MaterialDNA.validateReference()` semantics while preserving its stable field-specific diagnostics. ObjectGenome therefore accepts exactly the same MaterialDNA id/version domain instead of maintaining a drifting duplicate validator. Exact ordered material references also participate mechanically in ObjectGenome StableId. Advancing `familyVersion` remains the authored family-recipe evolution rule, but identity safety does not rely on that human discipline.\n",
    "- Each component pins an exact MaterialDNA recipe revision as `(materialKey, materialRecipeVersion)`. ObjectGenome keeps those values flat in its own schema and validates their value domains through production `MaterialDNA.validateReference()` semantics while preserving ObjectGenome's stable field-specific diagnostics. A published component material-revision change is canonical object recipe content and therefore requires the corresponding `familyVersion` to advance; the separate recipe fingerprint catches an accidental same-version retarget.\n",
)
replace_once(
    "Docs/OBJECT_GENOME.md",
    "Changing field meaning or deterministic identity inputs requires an object schema/version decision. Published authored recipe changes still advance `familyVersion`; independently versioned exact MaterialDNA revisions additionally participate directly in `genomeId`, so a material retarget can never preserve the prior state identity. Extend mechanism/affordance vocabularies through this contract rather than embedding furniture-specific runtime state into unrelated systems.\n",
    "Changing field meaning or deterministic identity inputs requires an object schema/version decision. Changing published canonical recipe content such as a component's exact material revision requires advancing `familyVersion`; the full immutable recipe fingerprint is the CI/golden guard against forgetting that revision. Extend mechanism/affordance vocabularies through this contract rather than embedding furniture-specific runtime state into unrelated systems.\n",
)

# Restore v1 identity goldens and add separate recipe-fingerprint goldens.
for old, new in [
    ("object-genome:v1:3eb84b8e4e34773f3b23b044f63b9166", "object-genome:v1:51c5fd2813c6dfc8b3e089570b0632af"),
    ("object-genome:v1:708d218fae658150bbaa0dfa4436be5d", "object-genome:v1:44d2ee4894de4c20184e7e2a91c876e4"),
    ("object-genome:v1:97e4e25c11f73d49300c4ad7bc0a30a2", "object-genome:v1:7bd8b9e0c82d36ae53374a390fe2f969"),
]:
    replace_once("tests/object_genome.luau", old, new)

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
    '''\texpect(
\t\t"material recipe revision mechanically changes canonical genome identity",
\t\tObjectGenome.identityKey(revisedMaterial) ~= ObjectGenome.identityKey(Fixtures.filingCabinet)
\t)
''',
    '''\texpect(
\t\t"same-version material drift preserves established v1 identity",
\t\tObjectGenome.identityKey(revisedMaterial) == ObjectGenome.identityKey(Fixtures.filingCabinet)
\t)
\texpect(
\t\t"same-version material drift changes full recipe fingerprint",
\t\tObjectGenome.recipeFingerprint(revisedMaterial) ~= ObjectGenome.recipeFingerprint(Fixtures.filingCabinet)
\t)
''',
)

boundary_tail = '''\tfor _, materialCase in ipairs(materialBoundaryCases) do
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

drift_tests = boundary_tail + '''\tlocal function expectSameVersionFingerprintDrift(name, mutate)
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

'''
replace_once("tests/object_genome.luau", boundary_tail, drift_tests)
