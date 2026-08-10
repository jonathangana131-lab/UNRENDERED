from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    p = Path(path)
    text = p.read_text()
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{path}: expected exactly one marker, found {count}")
    p.write_text(text.replace(old, new, 1))


replace_once(
    "src/shared/Physics/PhysicsLabRecipe.luau",
    '''local function worldEntity(key: string, kind: string, fidelity: FidelityLevel): WorldEntityRecord
\treturn WorldEntity.new({
\t\tid = worldEntityId(key),
\t\tkind = kind,
\t\torigin = {
\t\t\tworldId = PhysicsLabRecipe.WorldId,
\t\t\tregionId = PhysicsLabRecipe.RegionId,
\t\t\tgenerator = PhysicsLabRecipe.GeneratorKey,
\t\t\tgeneratorVersion = PhysicsLabRecipe.RecipeVersion,
\t\t\trecipeKey = key,
\t\t},
\t\tfidelity = fidelity,
\t\tpersistentState = {},
\t})
end
''',
    '''local function worldEntity(
\tkey: string,
\tkind: string,
\tfidelity: FidelityLevel,
\tpersistentState: any?
): WorldEntityRecord
\treturn WorldEntity.new({
\t\tid = worldEntityId(key),
\t\tkind = kind,
\t\torigin = {
\t\t\tworldId = PhysicsLabRecipe.WorldId,
\t\t\tregionId = PhysicsLabRecipe.RegionId,
\t\t\tgenerator = PhysicsLabRecipe.GeneratorKey,
\t\t\tgeneratorVersion = PhysicsLabRecipe.RecipeVersion,
\t\t\trecipeKey = key,
\t\t},
\t\tfidelity = fidelity,
\t\tpersistentState = persistentState or {},
\t})
end
''',
)

replace_once(
    "src/shared/Physics/PhysicsLabRecipe.luau",
    'entity = worldEntity(key, `physics-lab.{role}`, "F3"),',
    'entity = worldEntity(key, "object", "F3", ObjectGenome.defaultState(genome)),',
)

replace_once(
    "src/shared/Physics/PhysicsLabRecipe.luau",
    '''\t\tif element.objectGenomeId ~= nil then
\t\t\tassert(
\t\t\t\tStableId.is(element.objectGenomeId, ObjectGenome.STABLE_ID_NAMESPACE),
\t\t\t\t`{element.key} objectGenomeId must satisfy ObjectGenome identity contract`
\t\t\t)
\t\tend
''',
    '''\t\tif element.objectGenomeId ~= nil then
\t\t\tassert(
\t\t\t\tStableId.is(element.objectGenomeId, ObjectGenome.STABLE_ID_NAMESPACE),
\t\t\t\t`{element.key} objectGenomeId must satisfy ObjectGenome identity contract`
\t\t\t)
\t\t\tassert(element.entity.kind == "object", `{element.key} fixture-backed entity kind must be object`)
\t\t\tlocal objectState = element.entity.persistentState :: any
\t\t\tassert(
\t\t\t\tobjectState.genomeId == element.objectGenomeId,
\t\t\t\t`{element.key} persistent ObjectState must match objectGenomeId`
\t\t\t)
\t\tend
''',
)

replace_once(
    "tests/physics_lab_recipe.luau",
    '''\t\texpect(`element {index} state begins empty`, next(element.entity.persistentState) == nil)
''',
    '''\t\tif element.objectGenomeId ~= nil then
\t\t\texpect(
\t\t\t\t`element {index} fixture ObjectState binds genome identity`,
\t\t\t\telement.entity.persistentState.genomeId == element.objectGenomeId
\t\t\t)
\t\telse
\t\t\texpect(`element {index} proxy state begins empty`, next(element.entity.persistentState) == nil)
\t\tend
''',
)

replace_once(
    "tests/physics_lab_recipe.luau",
    '''\t\texpect(
\t\t\t`${role} uses landed ObjectGenome identity`,
\t\t\tmatched ~= nil
\t\t\t\tand matched.objectGenomeId == expectedGenomeId
\t\t\t\tand StableId.is(matched.objectGenomeId, ObjectGenome.STABLE_ID_NAMESPACE)
\t\t)
''',
    '''\t\texpect(
\t\t\t`${role} uses landed ObjectGenome identity and state`,
\t\t\tmatched ~= nil
\t\t\t\tand matched.objectGenomeId == expectedGenomeId
\t\t\t\tand StableId.is(matched.objectGenomeId, ObjectGenome.STABLE_ID_NAMESPACE)
\t\t\t\tand matched.entity.kind == "object"
\t\t\t\tand matched.entity.persistentState.genomeId == expectedGenomeId
\t\t)
''',
)

replace_once(
    "Docs/PHYSICS_LAB.md",
    "- chair and table proxies bound to the landed production ObjectGenome fixture identities;\n",
    "- chair and table proxies bound to the landed production ObjectGenome fixture identities and their default ObjectState snapshots;\n",
)
