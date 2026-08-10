from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if text.count(old) != 1:
        raise SystemExit(f"{label}: expected exactly one marker, found {text.count(old)}")
    return text.replace(old, new, 1)


source_path = Path("src/shared/Objects/ObjectGenome.luau")
source = source_path.read_text()

source = replace_once(
    source,
    '''export type MechanismSpec = HingeMechanism | SlideMechanism | CasterMechanism | TiltMechanism | LatchMechanism

export type AffordanceKind = "grip" | "push" | "pull" | "sit" | "open" | "close"
''',
    '''export type MechanismSpec = HingeMechanism | SlideMechanism | CasterMechanism | TiltMechanism | LatchMechanism

export type DecodedMechanismPosition =
\t{ kind: "hinge", degrees: number }
\t| { kind: "tilt", degrees: number }
\t| { kind: "slide", travelM: number }
\t| { kind: "caster", swivelTurns: number, swivelDegrees: number }
\t| { kind: "latch", engaged: boolean }

export type AffordanceKind = "grip" | "push" | "pull" | "sit" | "open" | "close"
''',
    "decoded mechanism type",
)

source = replace_once(
    source,
    '''local function isUnitInterval(value: any): boolean
\treturn isFinite(value) and value >= 0 and value <= 1
end

local function isPositiveInteger(value: any): boolean
''',
    '''local function isUnitInterval(value: any): boolean
\treturn isFinite(value) and value >= 0 and value <= 1
end

local function mechanismPositionIsValid(mechanism: MechanismSpec, value: any): boolean
\tif mechanism.kind == "caster" then
\t\treturn isFinite(value) and value >= 0 and value < 1
\telseif mechanism.kind == "latch" then
\t\treturn value == 0 or value == 1
\telseif mechanism.kind == "hinge" or mechanism.kind == "tilt" or mechanism.kind == "slide" then
\t\treturn isUnitInterval(value)
\tend
\treturn false
end

local function defaultMechanismPosition(mechanism: MechanismSpec): number
\tif mechanism.kind == "hinge" or mechanism.kind == "tilt" then
\t\treturn -mechanism.minDegrees / (mechanism.maxDegrees - mechanism.minDegrees)
\telseif mechanism.kind == "slide" then
\t\treturn -mechanism.minTravelM / (mechanism.maxTravelM - mechanism.minTravelM)
\tend
\treturn 0
end

local function isPositiveInteger(value: any): boolean
''',
    "mechanism scalar helpers",
)

old_limits = '''\t\t\tif mechanism.kind == "hinge" or mechanism.kind == "tilt" then
\t\t\t\tvalidateAxis(issues, path .. ".axis", mechanism.axis)
\t\t\t\tif
\t\t\t\t\tnot isFinite(mechanism.minDegrees)
\t\t\t\t\tor not isFinite(mechanism.maxDegrees)
\t\t\t\t\tor mechanism.minDegrees >= mechanism.maxDegrees
\t\t\t\tthen
\t\t\t\t\taddIssue(
\t\t\t\t\t\tissues,
\t\t\t\t\t\t"mechanism.angular_limits",
\t\t\t\t\t\tpath,
\t\t\t\t\t\t"angular limits require finite minDegrees < maxDegrees"
\t\t\t\t\t)
\t\t\t\tend
\t\t\telseif mechanism.kind == "slide" then
\t\t\t\tvalidateAxis(issues, path .. ".axis", mechanism.axis)
\t\t\t\tif
\t\t\t\t\tnot isFinite(mechanism.minTravelM)
\t\t\t\t\tor not isFinite(mechanism.maxTravelM)
\t\t\t\t\tor mechanism.minTravelM >= mechanism.maxTravelM
\t\t\t\tthen
\t\t\t\t\taddIssue(
\t\t\t\t\t\tissues,
\t\t\t\t\t\t"mechanism.linear_limits",
\t\t\t\t\t\tpath,
\t\t\t\t\t\t"slide limits require finite minTravelM < maxTravelM"
\t\t\t\t\t)
\t\t\t\tend
\t\t\telseif mechanism.kind == "caster" then
'''
new_limits = '''\t\t\tif mechanism.kind == "hinge" or mechanism.kind == "tilt" then
\t\t\t\tvalidateAxis(issues, path .. ".axis", mechanism.axis)
\t\t\t\tlocal angularLimitsValid = isFinite(mechanism.minDegrees)
\t\t\t\t\tand isFinite(mechanism.maxDegrees)
\t\t\t\t\tand mechanism.minDegrees < mechanism.maxDegrees
\t\t\t\tif not angularLimitsValid then
\t\t\t\t\taddIssue(
\t\t\t\t\t\tissues,
\t\t\t\t\t\t"mechanism.angular_limits",
\t\t\t\t\t\tpath,
\t\t\t\t\t\t"angular limits require finite minDegrees < maxDegrees"
\t\t\t\t\t)
\t\t\t\telseif mechanism.minDegrees > 0 or mechanism.maxDegrees < 0 then
\t\t\t\t\taddIssue(
\t\t\t\t\t\tissues,
\t\t\t\t\t\t"mechanism.reference_pose",
\t\t\t\t\t\tpath,
\t\t\t\t\t\t"angular limits must include the authored zero/reference pose"
\t\t\t\t\t)
\t\t\t\tend
\t\t\telseif mechanism.kind == "slide" then
\t\t\t\tvalidateAxis(issues, path .. ".axis", mechanism.axis)
\t\t\t\tlocal linearLimitsValid = isFinite(mechanism.minTravelM)
\t\t\t\t\tand isFinite(mechanism.maxTravelM)
\t\t\t\t\tand mechanism.minTravelM < mechanism.maxTravelM
\t\t\t\tif not linearLimitsValid then
\t\t\t\t\taddIssue(
\t\t\t\t\t\tissues,
\t\t\t\t\t\t"mechanism.linear_limits",
\t\t\t\t\t\tpath,
\t\t\t\t\t\t"slide limits require finite minTravelM < maxTravelM"
\t\t\t\t\t)
\t\t\t\telseif mechanism.minTravelM > 0 or mechanism.maxTravelM < 0 then
\t\t\t\t\taddIssue(
\t\t\t\t\t\tissues,
\t\t\t\t\t\t"mechanism.reference_pose",
\t\t\t\t\t\tpath,
\t\t\t\t\t\t"slide limits must include the authored zero/reference pose"
\t\t\t\t\t)
\t\t\t\tend
\t\t\telseif mechanism.kind == "caster" then
'''
source = replace_once(source, old_limits, new_limits, "mechanism range validation")

source = replace_once(
    source,
    '''function ObjectGenome.defaultState(value: ObjectGenome): ObjectState
''',
    '''function ObjectGenome.decodeMechanismPosition(
\tmechanism: MechanismSpec,
\tposition: number
): DecodedMechanismPosition
\tassert(mechanismPositionIsValid(mechanism, position), "mechanism position must use canonical ObjectState v1 encoding")

\tif mechanism.kind == "hinge" or mechanism.kind == "tilt" then
\t\tassert(
\t\t\tisFinite(mechanism.minDegrees)
\t\t\t\tand isFinite(mechanism.maxDegrees)
\t\t\t\tand mechanism.minDegrees < mechanism.maxDegrees
\t\t\t\tand mechanism.minDegrees <= 0
\t\t\t\tand mechanism.maxDegrees >= 0,
\t\t\t"angular mechanism limits must include the authored zero/reference pose"
\t\t)
\t\treturn {
\t\t\tkind = mechanism.kind,
\t\t\tdegrees = mechanism.minDegrees + position * (mechanism.maxDegrees - mechanism.minDegrees),
\t\t}
\telseif mechanism.kind == "slide" then
\t\tassert(
\t\t\tisFinite(mechanism.minTravelM)
\t\t\t\tand isFinite(mechanism.maxTravelM)
\t\t\t\tand mechanism.minTravelM < mechanism.maxTravelM
\t\t\t\tand mechanism.minTravelM <= 0
\t\t\t\tand mechanism.maxTravelM >= 0,
\t\t\t"slide mechanism limits must include the authored zero/reference pose"
\t\t)
\t\treturn {
\t\t\tkind = "slide",
\t\t\ttravelM = mechanism.minTravelM + position * (mechanism.maxTravelM - mechanism.minTravelM),
\t\t}
\telseif mechanism.kind == "caster" then
\t\treturn {
\t\t\tkind = "caster",
\t\t\tswivelTurns = position,
\t\t\tswivelDegrees = position * 360,
\t\t}
\telseif mechanism.kind == "latch" then
\t\treturn {
\t\t\tkind = "latch",
\t\t\tengaged = position == 1,
\t\t}
\tend

\terror("unsupported ObjectGenome mechanism kind", 2)
end

function ObjectGenome.defaultState(value: ObjectGenome): ObjectState
''',
    "decoder insertion",
)

source = replace_once(
    source,
    '''\tlocal mechanismPosition: { [string]: number } = {}
\tfor _, mechanism in ipairs(value.mechanisms) do
\t\tmechanismPosition[mechanism.key] = 0
\tend
''',
    '''\tlocal mechanismPosition: { [string]: number } = {}
\tfor _, mechanism in ipairs(value.mechanisms) do
\t\tmechanismPosition[mechanism.key] = defaultMechanismPosition(mechanism)
\tend
''',
    "default mechanism state",
)

source = replace_once(
    source,
    '''\tlocal mechanismKeys: { [string]: boolean } = {}
\tfor _, mechanism in ipairs(genome.mechanisms) do
\t\tmechanismKeys[mechanism.key] = true
\tend
''',
    '''\tlocal mechanismKeys: { [string]: boolean } = {}
\tlocal mechanismsByKey: { [string]: MechanismSpec } = {}
\tfor _, mechanism in ipairs(genome.mechanisms) do
\t\tmechanismKeys[mechanism.key] = true
\t\tmechanismsByKey[mechanism.key] = mechanism
\tend
''',
    "mechanism state lookup",
)

old_state_calls = '''\tvalidateUnitMap("componentWear", state.componentWear, componentKeys)
\tvalidateUnitMap("componentDamage", state.componentDamage, componentKeys)
\tvalidateUnitMap("mechanismPosition", state.mechanismPosition, mechanismKeys)

\tif type(state.detachedComponents) ~= "table" then
'''
new_state_calls = '''\tlocal function validateMechanismPositionMap(mapValue: any): ()
\t\tlocal fieldName = "mechanismPosition"
\t\tif type(mapValue) ~= "table" then
\t\t\taddIssue(issues, "state.collection", fieldName, "mechanismPosition must be a table")
\t\t\treturn
\t\tend
\t\tif getmetatable(mapValue) ~= nil then
\t\t\taddIssue(issues, "state.metatable", fieldName, "mechanismPosition must not have a metatable")
\t\t\treturn
\t\tend
\t\tfor key in pairs(mechanismKeys) do
\t\t\tif mapValue[key] == nil then
\t\t\t\taddIssue(
\t\t\t\t\tissues,
\t\t\t\t\t"state.missing_key",
\t\t\t\t\t`mechanismPosition.{key}`,
\t\t\t\t\t"state is missing a required genome key"
\t\t\t\t)
\t\t\tend
\t\tend
\t\tfor key, position in pairs(mapValue) do
\t\t\tlocal mechanism = if type(key) == "string" then mechanismsByKey[key] else nil
\t\t\tif mechanism == nil then
\t\t\t\taddIssue(
\t\t\t\t\tissues,
\t\t\t\t\t"state.unknown_key",
\t\t\t\t\t`mechanismPosition.{safeKeyLabel(key)}`,
\t\t\t\t\t"state references an unknown genome key"
\t\t\t\t)
\t\t\telseif not mechanismPositionIsValid(mechanism, position) then
\t\t\t\taddIssue(
\t\t\t\t\tissues,
\t\t\t\t\t"state.mechanism_position",
\t\t\t\t\t`mechanismPosition.{key}`,
\t\t\t\t\t"mechanism position is not canonical for the referenced mechanism kind"
\t\t\t\t)
\t\t\tend
\t\tend
\tend

\tvalidateUnitMap("componentWear", state.componentWear, componentKeys)
\tvalidateUnitMap("componentDamage", state.componentDamage, componentKeys)
\tvalidateMechanismPositionMap(state.mechanismPosition)

\tif type(state.detachedComponents) ~= "table" then
'''
source = replace_once(source, old_state_calls, new_state_calls, "kind-aware state validation")
source_path.write_text(source)


test_path = Path("tests/object_genome.luau")
tests = test_path.read_text()
tests = replace_once(
    tests,
    '''local function findComponent(genome, key)
\tfor _, component in ipairs(genome.components) do
\t\tif component.key == key then
\t\t\treturn component
\t\tend
\tend
\treturn nil
end

local function run(): number
''',
    '''local function findComponent(genome, key)
\tfor _, component in ipairs(genome.components) do
\t\tif component.key == key then
\t\t\treturn component
\t\tend
\tend
\treturn nil
end

local function findMechanism(genome, key)
\tfor _, mechanism in ipairs(genome.mechanisms) do
\t\tif mechanism.key == key then
\t\t\treturn mechanism
\t\tend
\tend
\treturn nil
end

local function run(): number
''',
    "test findMechanism helper",
)

mechanism_test_marker = '''\tlocal nonUnitAxis = deepCopy(Fixtures.filingCabinet)
\tnonUnitAxis.mechanisms[1].axis = { x = 0, y = 0, z = -2 }
\texpect(
\t\t"rejects non-unit mechanism axis",
\t\thasCode(ObjectGenome.inspect(nonUnitAxis), "mechanism.axis_unit")
\t)
'''
mechanism_tests = mechanism_test_marker + '''

\tlocal positiveOnlyTilt = deepCopy(Fixtures.officeChair)
\tlocal positiveTiltMechanism = findMechanism(positiveOnlyTilt, "seat-tilt")
\tif positiveTiltMechanism ~= nil then
\t\tpositiveTiltMechanism.minDegrees = 2
\t\tpositiveTiltMechanism.maxDegrees = 14
\tend
\texpect(
\t\t"rejects angular mechanism range that excludes authored zero pose",
\t\tpositiveTiltMechanism ~= nil and hasCode(ObjectGenome.inspect(positiveOnlyTilt), "mechanism.reference_pose")
\t)

\tlocal positiveOnlySlide = deepCopy(Fixtures.filingCabinet)
\tlocal positiveSlideMechanism = findMechanism(positiveOnlySlide, "slide-top")
\tif positiveSlideMechanism ~= nil then
\t\tpositiveSlideMechanism.minTravelM = 0.05
\t\tpositiveSlideMechanism.maxTravelM = 0.44
\tend
\texpect(
\t\t"rejects slide range that excludes authored zero pose",
\t\tpositiveSlideMechanism ~= nil and hasCode(ObjectGenome.inspect(positiveOnlySlide), "mechanism.reference_pose")
\t)

\tlocal chairMechanismState = ObjectGenome.defaultState(Fixtures.officeChair)
\tlocal seatTiltMechanism = findMechanism(Fixtures.officeChair, "seat-tilt")
\tlocal seatTiltPosition = chairMechanismState.mechanismPosition["seat-tilt"]
\tlocal decodedTilt = if seatTiltMechanism ~= nil
\t\tthen ObjectGenome.decodeMechanismPosition(seatTiltMechanism, seatTiltPosition)
\t\telse nil
\texpect(
\t\t"chair tilt default scalar resolves to authored zero degrees",
\t\tseatTiltMechanism ~= nil
\t\t\tand math.abs(seatTiltPosition - (8 / 22)) < 1e-12
\t\t\tand decodedTilt ~= nil
\t\t\tand decodedTilt.kind == "tilt"
\t\t\tand math.abs(decodedTilt.degrees) < 1e-12
\t)

\tlocal casterMechanism = findMechanism(Fixtures.officeChair, "caster-front-left-swivel")
\tlocal casterState = ObjectGenome.defaultState(Fixtures.officeChair)
\tcasterState.mechanismPosition["caster-front-left-swivel"] = 0.999
\texpect(
\t\t"caster accepts canonical half-open swivel scalar",
\t\tcasterMechanism ~= nil and ObjectGenome.inspectState(Fixtures.officeChair, casterState).ok
\t)
\tlocal decodedCaster = if casterMechanism ~= nil
\t\tthen ObjectGenome.decodeMechanismPosition(casterMechanism, 0.25)
\t\telse nil
\texpect(
\t\t"caster decoder maps persisted swivel turn fraction and leaves wheel roll transient",
\t\tdecodedCaster ~= nil
\t\t\tand decodedCaster.kind == "caster"
\t\t\tand decodedCaster.swivelTurns == 0.25
\t\t\tand decodedCaster.swivelDegrees == 90
\t)
\tcasterState.mechanismPosition["caster-front-left-swivel"] = 1
\texpect(
\t\t"caster rejects duplicate full-turn endpoint",
\t\thasCode(ObjectGenome.inspectState(Fixtures.officeChair, casterState), "state.mechanism_position")
\t)

\tlocal slideMechanism = findMechanism(Fixtures.filingCabinet, "slide-top")
\tlocal decodedSlide = if slideMechanism ~= nil then ObjectGenome.decodeMechanismPosition(slideMechanism, 0.5) else nil
\texpect(
\t\t"slide decoder maps scalar to authored physical travel",
\t\tdecodedSlide ~= nil and decodedSlide.kind == "slide" and math.abs(decodedSlide.travelM - 0.22) < 1e-12
\t)

\tlocal latchMechanism = findMechanism(Fixtures.filingCabinet, "latch-top")
\tlocal latchState = ObjectGenome.defaultState(Fixtures.filingCabinet)
\tlocal decodedLatchDefault = if latchMechanism ~= nil
\t\tthen ObjectGenome.decodeMechanismPosition(latchMechanism, latchState.mechanismPosition["latch-top"])
\t\telse nil
\texpect(
\t\t"latch default is discrete disengaged authored reference pose",
\t\tdecodedLatchDefault ~= nil and decodedLatchDefault.kind == "latch" and not decodedLatchDefault.engaged
\t)
\tlatchState.mechanismPosition["latch-top"] = 1
\texpect(
\t\t"latch accepts engaged discrete state",
\t\tObjectGenome.inspectState(Fixtures.filingCabinet, latchState).ok
\t)
\tlocal decodedLatchEngaged = if latchMechanism ~= nil then ObjectGenome.decodeMechanismPosition(latchMechanism, 1) else nil
\texpect(
\t\t"latch decoder maps one to engaged",
\t\tdecodedLatchEngaged ~= nil and decodedLatchEngaged.kind == "latch" and decodedLatchEngaged.engaged
\t)
\tlatchState.mechanismPosition["latch-top"] = 0.5
\texpect(
\t\t"latch rejects fractional persisted state",
\t\thasCode(ObjectGenome.inspectState(Fixtures.filingCabinet, latchState), "state.mechanism_position")
\t)
'''
tests = replace_once(tests, mechanism_test_marker, mechanism_tests, "mechanism semantic regressions")
test_path.write_text(tests)


doc_path = Path("Docs/OBJECT_GENOME.md")
doc = doc_path.read_text()
doc = replace_once(
    doc,
    '''Mechanisms reference component keys and plain axes/limits. A later Roblox realization adapter may choose constraints, servo settings, collision groups, fidelity simplifications, or authored meshes without changing the domain recipe.
''',
    '''Mechanisms reference component keys and plain axes/limits. Their mutable `ObjectState.mechanismPosition` value is one canonical scalar whose meaning is kind-specific and project-owned rather than adapter-defined:

- `hinge` / `tilt`: `p` is in `[0, 1]` and decodes as `degrees = minDegrees + p * (maxDegrees - minDegrees)`;
- `slide`: `p` is in `[0, 1]` and decodes as `travelM = minTravelM + p * (maxTravelM - minTravelM)`;
- `caster`: `p` is a persisted swivel turn fraction in `[0, 1)`, decoding to `p * 360` degrees. The full-turn endpoint is rejected because it duplicates zero. Wheel roll phase is transient Physical-World realization state in v1 and is not persisted by this scalar;
- `latch`: only `0` and `1` are canonical. `0` is the authored/default disengaged reference pose and `1` is engaged.

For hinge, tilt, and slide mechanisms, authored component transforms are the physical zero/reference pose. Recipe limits must include zero, and `ObjectGenome.defaultState()` derives the scalar that maps back to exactly zero physical offset (`-min / (max - min)`) instead of blindly storing `0`. `ObjectGenome.decodeMechanismPosition()` is the shared decoder boundary so Physics Lab/fidelity adapters do not invent competing formulas.

A later Roblox realization adapter may choose constraints, servo settings, collision groups, fidelity simplifications, or authored meshes without changing the domain recipe or the persisted mechanism-state interpretation.
''',
    "mechanism docs",
)
doc = replace_once(
    doc,
    '''- `ObjectGenome.defaultState(genome)` creates separate zeroed mutable state bound to the exact canonical genome identity.
- `ObjectGenome.inspectState(genome, state)` validates the state identity plus mutable keys/ranges against the immutable recipe.
''',
    '''- `ObjectGenome.defaultState(genome)` creates separate mutable state bound to the exact canonical genome identity, with mechanism scalars at their authored zero/reference poses.
- `ObjectGenome.decodeMechanismPosition(mechanism, position)` converts the canonical persisted scalar into one kind-specific physical semantic value.
- `ObjectGenome.inspectState(genome, state)` validates the state identity plus mutable keys/ranges against the immutable recipe, including kind-specific mechanism encodings.
''',
    "validation API docs",
)
doc_path.write_text(doc)
