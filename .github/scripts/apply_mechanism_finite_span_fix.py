from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected one marker, found {count}")
    return text.replace(old, new, 1)


source_path = Path("src/shared/Objects/ObjectGenome.luau")
source = source_path.read_text()
source = replace_once(
    source,
    '''local function isUnitInterval(value: any): boolean
\treturn isFinite(value) and value >= 0 and value <= 1
end

local function mechanismPositionIsValid(mechanism: MechanismSpec, value: any): boolean
''',
    '''local function isUnitInterval(value: any): boolean
\treturn isFinite(value) and value >= 0 and value <= 1
end

local function finiteInterpolationSpan(minimum: number, maximum: number): number?
\tif not isFinite(minimum) or not isFinite(maximum) or minimum >= maximum then
\t\treturn nil
\tend
\tlocal span = maximum - minimum
\tif not isPositiveFinite(span) then
\t\treturn nil
\tend
\treturn span
end

local function mechanismPositionIsValid(mechanism: MechanismSpec, value: any): boolean
''',
    "finite interpolation helper",
)
source = replace_once(
    source,
    '''local function defaultMechanismPosition(mechanism: MechanismSpec): number
\tif mechanism.kind == "hinge" or mechanism.kind == "tilt" then
\t\treturn -mechanism.minDegrees / (mechanism.maxDegrees - mechanism.minDegrees)
\telseif mechanism.kind == "slide" then
\t\treturn -mechanism.minTravelM / (mechanism.maxTravelM - mechanism.minTravelM)
\tend
\treturn 0
end
''',
    '''local function canonicalReferencePosition(minimum: number, maximum: number): number
\tlocal span = finiteInterpolationSpan(minimum, maximum)
\tassert(span ~= nil, "mechanism interpolation span must be positive and finite")
\tlocal position = -minimum / span
\tassert(isUnitInterval(position), "mechanism authored zero/reference pose must map to a finite canonical scalar")
\treturn position
end

local function decodeLinearPosition(minimum: number, maximum: number, position: number): number
\tlocal span = finiteInterpolationSpan(minimum, maximum)
\tassert(span ~= nil, "mechanism interpolation span must be positive and finite")
\tlocal physicalPosition = minimum + position * span
\tassert(isFinite(physicalPosition), "decoded mechanism physical position must be finite")
\treturn physicalPosition
end

local function defaultMechanismPosition(mechanism: MechanismSpec): number
\tif mechanism.kind == "hinge" or mechanism.kind == "tilt" then
\t\treturn canonicalReferencePosition(mechanism.minDegrees, mechanism.maxDegrees)
\telseif mechanism.kind == "slide" then
\t\treturn canonicalReferencePosition(mechanism.minTravelM, mechanism.maxTravelM)
\tend
\treturn 0
end
''',
    "finite default helper",
)
source = replace_once(
    source,
    '''\t\t\tif mechanism.kind == "hinge" or mechanism.kind == "tilt" then
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
''',
    '''\t\t\tif mechanism.kind == "hinge" or mechanism.kind == "tilt" then
\t\t\t\tvalidateAxis(issues, path .. ".axis", mechanism.axis)
\t\t\t\tlocal angularSpan = finiteInterpolationSpan(mechanism.minDegrees, mechanism.maxDegrees)
\t\t\t\tif angularSpan == nil then
\t\t\t\t\taddIssue(
\t\t\t\t\t\tissues,
\t\t\t\t\t\t"mechanism.angular_limits",
\t\t\t\t\t\tpath,
\t\t\t\t\t\t"angular limits require finite minDegrees < maxDegrees with a finite interpolation span"
\t\t\t\t\t)
\t\t\t\telseif mechanism.minDegrees > 0 or mechanism.maxDegrees < 0 then
''',
    "angular span validation",
)
source = replace_once(
    source,
    '''\t\t\telseif mechanism.kind == "slide" then
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
''',
    '''\t\t\telseif mechanism.kind == "slide" then
\t\t\t\tvalidateAxis(issues, path .. ".axis", mechanism.axis)
\t\t\t\tlocal linearSpan = finiteInterpolationSpan(mechanism.minTravelM, mechanism.maxTravelM)
\t\t\t\tif linearSpan == nil then
\t\t\t\t\taddIssue(
\t\t\t\t\t\tissues,
\t\t\t\t\t\t"mechanism.linear_limits",
\t\t\t\t\t\tpath,
\t\t\t\t\t\t"slide limits require finite minTravelM < maxTravelM with a finite interpolation span"
\t\t\t\t\t)
\t\t\t\telseif mechanism.minTravelM > 0 or mechanism.maxTravelM < 0 then
''',
    "linear span validation",
)
source = replace_once(
    source,
    '''\tif mechanism.kind == "hinge" then
\t\tassert(
\t\t\tisFinite(mechanism.minDegrees)
\t\t\t\tand isFinite(mechanism.maxDegrees)
\t\t\t\tand mechanism.minDegrees < mechanism.maxDegrees
\t\t\t\tand mechanism.minDegrees <= 0
\t\t\t\tand mechanism.maxDegrees >= 0,
\t\t\t"angular mechanism limits must include the authored zero/reference pose"
\t\t)
\t\treturn {
\t\t\tkind = "hinge",
\t\t\tdegrees = mechanism.minDegrees + position * (mechanism.maxDegrees - mechanism.minDegrees),
\t\t}
\telseif mechanism.kind == "tilt" then
\t\tassert(
\t\t\tisFinite(mechanism.minDegrees)
\t\t\t\tand isFinite(mechanism.maxDegrees)
\t\t\t\tand mechanism.minDegrees < mechanism.maxDegrees
\t\t\t\tand mechanism.minDegrees <= 0
\t\t\t\tand mechanism.maxDegrees >= 0,
\t\t\t"angular mechanism limits must include the authored zero/reference pose"
\t\t)
\t\treturn {
\t\t\tkind = "tilt",
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
''',
    '''\tif mechanism.kind == "hinge" then
\t\tassert(
\t\t\tmechanism.minDegrees <= 0 and mechanism.maxDegrees >= 0,
\t\t\t"angular mechanism limits must include the authored zero/reference pose"
\t\t)
\t\treturn {
\t\t\tkind = "hinge",
\t\t\tdegrees = decodeLinearPosition(mechanism.minDegrees, mechanism.maxDegrees, position),
\t\t}
\telseif mechanism.kind == "tilt" then
\t\tassert(
\t\t\tmechanism.minDegrees <= 0 and mechanism.maxDegrees >= 0,
\t\t\t"angular mechanism limits must include the authored zero/reference pose"
\t\t)
\t\treturn {
\t\t\tkind = "tilt",
\t\t\tdegrees = decodeLinearPosition(mechanism.minDegrees, mechanism.maxDegrees, position),
\t\t}
\telseif mechanism.kind == "slide" then
\t\tassert(
\t\t\tmechanism.minTravelM <= 0 and mechanism.maxTravelM >= 0,
\t\t\t"slide mechanism limits must include the authored zero/reference pose"
\t\t)
\t\treturn {
\t\t\tkind = "slide",
\t\t\ttravelM = decodeLinearPosition(mechanism.minTravelM, mechanism.maxTravelM, position),
\t\t}
''',
    "finite decoder",
)
source_path.write_text(source)


test_path = Path("tests/object_genome.luau")
tests = test_path.read_text()
marker = '''\texpect(
\t\t"rejects slide range that excludes authored zero pose",
\t\tpositiveSlideMechanism ~= nil and hasCode(ObjectGenome.inspect(positiveOnlySlide), "mechanism.reference_pose")
\t)

\tlocal chairMechanismState = ObjectGenome.defaultState(Fixtures.officeChair)
'''
addition = '''\texpect(
\t\t"rejects slide range that excludes authored zero pose",
\t\tpositiveSlideMechanism ~= nil and hasCode(ObjectGenome.inspect(positiveOnlySlide), "mechanism.reference_pose")
\t)

\tlocal overflowingTilt = deepCopy(Fixtures.officeChair)
\tlocal overflowingTiltMechanism = findMechanism(overflowingTilt, "seat-tilt")
\tif overflowingTiltMechanism ~= nil then
\t\toverflowingTiltMechanism.minDegrees = -1e308
\t\toverflowingTiltMechanism.maxDegrees = 1e308
\tend
\tlocal overflowingTiltDefaultOk = pcall(function()
\t\tObjectGenome.defaultState(overflowingTilt)
\tend)
\texpect(
\t\t"rejects individually finite angular endpoints whose interpolation span overflows",
\t\toverflowingTiltMechanism ~= nil
\t\t\tand hasCode(ObjectGenome.inspect(overflowingTilt), "mechanism.angular_limits")
\t\t\tand not overflowingTiltDefaultOk
\t)

\tlocal overflowingSlide = deepCopy(Fixtures.filingCabinet)
\tlocal overflowingSlideMechanism = findMechanism(overflowingSlide, "slide-top")
\tif overflowingSlideMechanism ~= nil then
\t\toverflowingSlideMechanism.minTravelM = -1e308
\t\toverflowingSlideMechanism.maxTravelM = 1e308
\tend
\tlocal overflowingSlideDefaultOk = pcall(function()
\t\tObjectGenome.defaultState(overflowingSlide)
\tend)
\texpect(
\t\t"rejects individually finite slide endpoints whose interpolation span overflows",
\t\toverflowingSlideMechanism ~= nil
\t\t\tand hasCode(ObjectGenome.inspect(overflowingSlide), "mechanism.linear_limits")
\t\t\tand not overflowingSlideDefaultOk
\t)

\tlocal chairMechanismState = ObjectGenome.defaultState(Fixtures.officeChair)
'''
tests = replace_once(tests, marker, addition, "overflow regressions")
test_path.write_text(tests)


doc_path = Path("Docs/OBJECT_GENOME.md")
doc = doc_path.read_text()
doc = replace_once(
    doc,
    '''For hinge, tilt, and slide mechanisms, authored component transforms are the physical zero/reference pose. Recipe limits must include zero, and `ObjectGenome.defaultState()` derives the scalar that maps back to exactly zero physical offset (`-min / (max - min)`) instead of blindly storing `0`. `ObjectGenome.decodeMechanismPosition()` is the shared decoder boundary so Physics Lab/fidelity adapters do not invent competing formulas.
''',
    '''For hinge, tilt, and slide mechanisms, authored component transforms are the physical zero/reference pose. Recipe limits must include zero **and their interpolation span (`max - min`) must itself remain finite**; individually finite endpoints are insufficient if subtraction overflows. `ObjectGenome.defaultState()` derives the scalar that maps back to exactly zero physical offset (`-min / (max - min)`) instead of blindly storing `0`, and both default derivation and decoding assert finite canonical results. `ObjectGenome.decodeMechanismPosition()` is the shared decoder boundary so Physics Lab/fidelity adapters do not invent competing formulas.
''',
    "numeric closure docs",
)
doc_path.write_text(doc)
