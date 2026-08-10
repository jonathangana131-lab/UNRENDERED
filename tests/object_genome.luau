local ProductionLoader = require("./support/ProductionLoader")

local StableId = ProductionLoader.requireShared("Core/StableId")
local MaterialDNA = ProductionLoader.requireShared("Materials/MaterialDNA")
local ObjectGenome = ProductionLoader.requireShared("Objects/ObjectGenome")
local Fixtures = ProductionLoader.requireShared("Objects/ObjectGenomeFixtures")

local function deepCopy(value)
	if type(value) ~= "table" then
		return value
	end
	local result = {}
	for key, child in pairs(value) do
		result[deepCopy(key)] = deepCopy(child)
	end
	return result
end

local function hasCode(report, code)
	for _, issue in ipairs(report.issues) do
		if issue.code == code then
			return true
		end
	end
	return false
end

local function hasCodeAtPath(report, code, path)
	for _, issue in ipairs(report.issues) do
		if issue.code == code and issue.path == path then
			return true
		end
	end
	return false
end

local function findComponent(genome, key)
	for _, component in ipairs(genome.components) do
		if component.key == key then
			return component
		end
	end
	return nil
end

local function findMechanism(genome, key)
	for _, mechanism in ipairs(genome.mechanisms) do
		if mechanism.key == key then
			return mechanism
		end
	end
	return nil
end

local function run(): number
	local failures = 0

	local function expect(name, condition)
		if not condition then
			failures += 1
			print(`FAIL object_genome {name}`)
		else
			print(`PASS object_genome {name}`)
		end
	end

	local fixtureCases = {
		{
			name = "office chair",
			genome = Fixtures.officeChair,
			identity = "object-genome:v1:51c5fd2813c6dfc8b3e089570b0632af",
			fingerprint = "object-genome-recipe:v1:a5612083f6e2c89bd042f0825d507f87",
		},
		{
			name = "office table",
			genome = Fixtures.officeTable,
			identity = "object-genome:v1:44d2ee4894de4c20184e7e2a91c876e4",
			fingerprint = "object-genome-recipe:v1:869dd383324b32d2bdd705df792560bc",
		},
		{
			name = "filing cabinet",
			genome = Fixtures.filingCabinet,
			identity = "object-genome:v1:7bd8b9e0c82d36ae53374a390fe2f969",
			fingerprint = "object-genome-recipe:v1:eaeab1cf27fe6e1866a395736bca4e71",
		},
	}

	expect("recipe fingerprint contract version is explicit", ObjectGenome.RECIPE_FINGERPRINT_VERSION == 2)

	for _, fixture in ipairs(fixtureCases) do
		local report = ObjectGenome.inspect(fixture.genome)
		expect(fixture.name .. " validates", report.ok)

		local identity = ObjectGenome.identityKey(fixture.genome)
		expect(fixture.name .. " locked stable identity", identity == fixture.identity)
		expect(
			fixture.name .. " uses project StableId",
			StableId.is(identity, ObjectGenome.STABLE_ID_NAMESPACE)
		)
		expect(fixture.name .. " repeat identity", identity == ObjectGenome.identityKey(fixture.genome))

		local fingerprint = ObjectGenome.recipeFingerprint(fixture.genome)
		expect(fixture.name .. " locked full recipe fingerprint", fingerprint == fixture.fingerprint)
		expect(
			fixture.name .. " uses separate recipe fingerprint namespace",
			StableId.is(fingerprint, ObjectGenome.RECIPE_FINGERPRINT_NAMESPACE)
		)
		expect(
			fixture.name .. " repeat recipe fingerprint",
			fingerprint == ObjectGenome.recipeFingerprint(fixture.genome)
		)

		for _, component in ipairs(fixture.genome.components) do
			expect(
				fixture.name .. " component uses MaterialDNA-style project key",
				string.match(component.materialKey, "^material%.v1%.") ~= nil
			)
			expect(
				fixture.name .. " component pins a material recipe revision",
				component.materialRecipeVersion == 1
			)
			expect(
				fixture.name .. " component reference satisfies production MaterialDNA",
				MaterialDNA.validateReference({
					id = component.materialKey,
					recipeVersion = component.materialRecipeVersion,
				}).ok
			)
		end

		local state = ObjectGenome.defaultState(fixture.genome)
		expect(
			fixture.name .. " default mutable state validates",
			ObjectGenome.inspectState(fixture.genome, state).ok
		)
	end

	local badDimensions = deepCopy(Fixtures.officeTable)
	badDimensions.dimensionsM.x = 9
	expect(
		"rejects dimensions outside family limits",
		hasCode(ObjectGenome.inspect(badDimensions), "dimensions.out_of_family_range")
	)

	local badMass = deepCopy(Fixtures.officeTable)
	badMass.components[1].massKg = 40
	expect(
		"rejects implausible component mass sum",
		hasCode(ObjectGenome.inspect(badMass), "mass.component_sum")
	)

	local badMaterial = deepCopy(Fixtures.officeChair)
	badMaterial.components[1].materialKey = ""
	expect(
		"rejects missing material assignment",
		hasCode(ObjectGenome.inspect(badMaterial), "component.material_key")
	)

	local badMaterialRevision = deepCopy(Fixtures.officeChair)
	badMaterialRevision.components[1].materialRecipeVersion = 0
	expect(
		"rejects missing material recipe revision",
		hasCode(ObjectGenome.inspect(badMaterialRevision), "component.material_recipe_version")
	)

	local legacyMaterial = deepCopy(Fixtures.officeChair)
	legacyMaterial.components[1].materialKey = "material:polymer-rubber.caster.v1"
	expect(
		"rejects legacy material reference syntax",
		hasCode(ObjectGenome.inspect(legacyMaterial), "component.material_key")
	)

	local revisedMaterial = deepCopy(Fixtures.filingCabinet)
	local revisedShell = findComponent(revisedMaterial, "shell")
	local canonicalShell = findComponent(Fixtures.filingCabinet, "shell")
	if revisedShell ~= nil then
		revisedShell.materialRecipeVersion += 1
	end
	expect(
		"material recipe revision is retained as canonical object recipe input",
		revisedShell ~= nil
			and canonicalShell ~= nil
			and revisedShell.materialKey == canonicalShell.materialKey
			and revisedShell.materialRecipeVersion ~= canonicalShell.materialRecipeVersion
			and ObjectGenome.inspect(revisedMaterial).ok
	)
	expect(
		"same-version material drift preserves established v1 identity",
		ObjectGenome.identityKey(revisedMaterial) == ObjectGenome.identityKey(Fixtures.filingCabinet)
	)
	expect(
		"same-version material drift changes full recipe fingerprint",
		ObjectGenome.recipeFingerprint(revisedMaterial)
			~= ObjectGenome.recipeFingerprint(Fixtures.filingCabinet)
	)

	local publishedMaterialRevision = deepCopy(Fixtures.filingCabinet)
	local publishedShell = findComponent(publishedMaterialRevision, "shell")
	publishedMaterialRevision.familyVersion += 1
	if publishedShell ~= nil then
		publishedShell.materialRecipeVersion += 1
	end
	expect(
		"published material revision with familyVersion advance is valid and changes identity",
		publishedShell ~= nil
			and ObjectGenome.inspect(publishedMaterialRevision).ok
			and ObjectGenome.identityKey(publishedMaterialRevision)
				~= ObjectGenome.identityKey(Fixtures.filingCabinet)
	)

	local materialBoundaryCases = {
		{ name = "slash id", id = "material.v1/reference-probe", recipeVersion = 1 },
		{ name = "numeric-only id", id = "123", recipeVersion = 1 },
		{ name = "overlong id", id = "material.v1." .. string.rep("a", 151), recipeVersion = 1 },
		{ name = "max recipe version", id = "material.v1.reference-probe", recipeVersion = 2147483647 },
		{ name = "above max recipe version", id = "material.v1.reference-probe", recipeVersion = 2147483648 },
	}
	for _, materialCase in ipairs(materialBoundaryCases) do
		local reference = {
			id = materialCase.id,
			recipeVersion = materialCase.recipeVersion,
		}
		local expectedReferenceValidity = MaterialDNA.validateReference(reference).ok
		local boundaryGenome = deepCopy(Fixtures.officeChair)
		boundaryGenome.components[1].materialKey = reference.id
		boundaryGenome.components[1].materialRecipeVersion = reference.recipeVersion
		expect(
			"ObjectGenome matches MaterialDNA reference boundary: " .. materialCase.name,
			ObjectGenome.inspect(boundaryGenome).ok == expectedReferenceValidity
		)
	end

	local longContentGenome = deepCopy(Fixtures.officeChair)
	longContentGenome.provenance.productLine = string.rep("x", 1025)
	local longContentReport = ObjectGenome.inspect(longContentGenome)
	local longFingerprintOk, longFingerprint = pcall(ObjectGenome.recipeFingerprint, longContentGenome)
	expect("otherwise-valid >512-byte recipe content remains valid", longContentReport.ok)
	expect(
		">512-byte recipe content fingerprints without exceeding StableId semantic-part limits",
		longFingerprintOk
			and type(longFingerprint) == "string"
			and StableId.is(longFingerprint, ObjectGenome.RECIPE_FINGERPRINT_NAMESPACE)
	)
	expect(
		">512-byte recipe content fingerprint is deterministic",
		longFingerprintOk and longFingerprint == ObjectGenome.recipeFingerprint(longContentGenome)
	)

	local positiveZeroGenome = deepCopy(Fixtures.officeChair)
	local negativeZeroGenome = deepCopy(Fixtures.officeChair)
	positiveZeroGenome.centerOfMassM.x = 0
	negativeZeroGenome.centerOfMassM.x = -0.0
	expect(
		"recipe fingerprint normalizes signed zero",
		ObjectGenome.recipeFingerprint(positiveZeroGenome)
			== ObjectGenome.recipeFingerprint(negativeZeroGenome)
	)

	local function expectSameVersionFingerprintDrift(name, mutate)
		local genome = deepCopy(Fixtures.officeChair)
		mutate(genome)
		expect(name .. " remains a valid v1 recipe", ObjectGenome.inspect(genome).ok)
		expect(
			name .. " does not rewrite established v1 identity inputs",
			ObjectGenome.identityKey(genome) == ObjectGenome.identityKey(Fixtures.officeChair)
		)
		expect(
			name .. " changes full immutable recipe fingerprint",
			ObjectGenome.recipeFingerprint(genome) ~= ObjectGenome.recipeFingerprint(Fixtures.officeChair)
		)
	end

	expectSameVersionFingerprintDrift("provenance drift", function(genome)
		genome.provenance.productLine ..= " Revised"
	end)
	expectSameVersionFingerprintDrift("dimension drift", function(genome)
		genome.dimensionsM.x += 0.01
	end)
	expectSameVersionFingerprintDrift("mass drift", function(genome)
		genome.massKg += 0.01
	end)
	expectSameVersionFingerprintDrift("component drift", function(genome)
		genome.components[1].role ..= " revised"
	end)
	expectSameVersionFingerprintDrift("support-order drift", function(genome)
		local base = findComponent(genome, "base")
		if base ~= nil then
			base.supportKeys[1], base.supportKeys[2] = base.supportKeys[2], base.supportKeys[1]
		end
	end)
	expectSameVersionFingerprintDrift("mechanism drift", function(genome)
		genome.mechanisms[#genome.mechanisms].maxDegrees -= 1
	end)
	expectSameVersionFingerprintDrift("affordance drift", function(genome)
		genome.affordances[1].radiusM -= 0.01
	end)

	local danglingSupport = deepCopy(Fixtures.filingCabinet)
	danglingSupport.components[2].supportKeys = { "missing-shell" }
	expect(
		"rejects dangling support graph edge",
		hasCode(ObjectGenome.inspect(danglingSupport), "component.support_missing")
	)

	local supportCycle = deepCopy(Fixtures.officeTable)
	supportCycle.components[1].externalSupport = "none"
	supportCycle.components[1].supportKeys = { "top" }
	expect("rejects cyclic load path", hasCode(ObjectGenome.inspect(supportCycle), "component.support_cycle"))

	local groundedCycle = deepCopy(Fixtures.officeTable)
	local groundedLeg = findComponent(groundedCycle, "leg-front-left")
	if groundedLeg ~= nil then
		groundedLeg.supportKeys = { "crossbar" }
	end
	expect(
		"rejects support cycle even when the cycle contains an externally supported component",
		groundedLeg ~= nil and hasCode(ObjectGenome.inspect(groundedCycle), "component.support_cycle")
	)

	local branchedCycle = deepCopy(Fixtures.officeTable)
	local branchedTop = findComponent(branchedCycle, "top")
	local branchedCrossbar = findComponent(branchedCycle, "crossbar")
	if branchedTop ~= nil and branchedCrossbar ~= nil then
		branchedTop.supportKeys = { "leg-front-left", "crossbar" }
		branchedCrossbar.supportKeys = { "top", "leg-front-right" }
	end
	expect(
		"rejects cyclic support branch even when another branch reaches ground",
		branchedTop ~= nil
			and branchedCrossbar ~= nil
			and hasCode(ObjectGenome.inspect(branchedCycle), "component.support_cycle")
	)

	local groundedReachableCycle = deepCopy(Fixtures.officeTable)
	local reachableTop = findComponent(groundedReachableCycle, "top")
	local reachableCrossbar = findComponent(groundedReachableCycle, "crossbar")
	local reachableGround = findComponent(groundedReachableCycle, "leg-front-left")
	if reachableTop ~= nil and reachableCrossbar ~= nil and reachableGround ~= nil then
		reachableTop.supportKeys = { "crossbar", "leg-front-left" }
		reachableCrossbar.supportKeys = { "top" }
		reachableGround.supportKeys = {}
		reachableGround.externalSupport = "ground"
	end
	local groundedReachableReport = ObjectGenome.inspect(groundedReachableCycle)
	expect(
		"ground-reachable cycle rejects cycle without false unsupported diagnostics",
		reachableTop ~= nil
			and reachableCrossbar ~= nil
			and reachableGround ~= nil
			and hasCode(groundedReachableReport, "component.support_cycle")
			and not hasCodeAtPath(groundedReachableReport, "component.unsupported", "components.top")
			and not hasCodeAtPath(groundedReachableReport, "component.unsupported", "components.crossbar")
	)

	local reorderedGroundedReachableCycle = deepCopy(groundedReachableCycle)
	local reversedComponents = {}
	for index = #reorderedGroundedReachableCycle.components, 1, -1 do
		table.insert(reversedComponents, reorderedGroundedReachableCycle.components[index])
	end
	reorderedGroundedReachableCycle.components = reversedComponents
	local reorderedGroundedReport = ObjectGenome.inspect(reorderedGroundedReachableCycle)
	expect(
		"ground reachability result is invariant to component traversal order",
		hasCode(reorderedGroundedReport, "component.support_cycle")
			and not hasCodeAtPath(reorderedGroundedReport, "component.unsupported", "components.top")
			and not hasCodeAtPath(reorderedGroundedReport, "component.unsupported", "components.crossbar")
	)

	local ungroundedReachableCycle = deepCopy(groundedReachableCycle)
	local ungroundedRoot = findComponent(ungroundedReachableCycle, "leg-front-left")
	if ungroundedRoot ~= nil then
		ungroundedRoot.externalSupport = "none"
	end
	local ungroundedReachableReport = ObjectGenome.inspect(ungroundedReachableCycle)
	expect(
		"genuinely ungrounded cycle reports both cycle and unsupported members",
		ungroundedRoot ~= nil
			and hasCode(ungroundedReachableReport, "component.support_cycle")
			and hasCodeAtPath(ungroundedReachableReport, "component.unsupported", "components.top")
			and hasCodeAtPath(ungroundedReachableReport, "component.unsupported", "components.crossbar")
	)

	local badMechanism = deepCopy(Fixtures.filingCabinet)
	badMechanism.mechanisms[1].frameComponentKey = "missing-frame"
	expect(
		"rejects mechanism with missing frame",
		hasCode(ObjectGenome.inspect(badMechanism), "mechanism.frame_component")
	)

	local nonUnitAxis = deepCopy(Fixtures.filingCabinet)
	nonUnitAxis.mechanisms[1].axis = { x = 0, y = 0, z = -2 }
	expect(
		"rejects non-unit mechanism axis",
		hasCode(ObjectGenome.inspect(nonUnitAxis), "mechanism.axis_unit")
	)

	local positiveOnlyTilt = deepCopy(Fixtures.officeChair)
	local positiveTiltMechanism = findMechanism(positiveOnlyTilt, "seat-tilt")
	if positiveTiltMechanism ~= nil then
		positiveTiltMechanism.minDegrees = 2
		positiveTiltMechanism.maxDegrees = 14
	end
	expect(
		"rejects angular mechanism range that excludes authored zero pose",
		positiveTiltMechanism ~= nil
			and hasCode(ObjectGenome.inspect(positiveOnlyTilt), "mechanism.reference_pose")
	)

	local positiveOnlySlide = deepCopy(Fixtures.filingCabinet)
	local positiveSlideMechanism = findMechanism(positiveOnlySlide, "slide-top")
	if positiveSlideMechanism ~= nil then
		positiveSlideMechanism.minTravelM = 0.05
		positiveSlideMechanism.maxTravelM = 0.44
	end
	expect(
		"rejects slide range that excludes authored zero pose",
		positiveSlideMechanism ~= nil
			and hasCode(ObjectGenome.inspect(positiveOnlySlide), "mechanism.reference_pose")
	)

	local overflowingTilt = deepCopy(Fixtures.officeChair)
	local overflowingTiltMechanism = findMechanism(overflowingTilt, "seat-tilt")
	if overflowingTiltMechanism ~= nil then
		overflowingTiltMechanism.minDegrees = -1e308
		overflowingTiltMechanism.maxDegrees = 1e308
	end
	local overflowingTiltDefaultOk = pcall(function()
		ObjectGenome.defaultState(overflowingTilt)
	end)
	expect(
		"rejects individually finite angular endpoints whose interpolation span overflows",
		overflowingTiltMechanism ~= nil
			and hasCode(ObjectGenome.inspect(overflowingTilt), "mechanism.angular_limits")
			and not overflowingTiltDefaultOk
	)

	local overflowingSlide = deepCopy(Fixtures.filingCabinet)
	local overflowingSlideMechanism = findMechanism(overflowingSlide, "slide-top")
	if overflowingSlideMechanism ~= nil then
		overflowingSlideMechanism.minTravelM = -1e308
		overflowingSlideMechanism.maxTravelM = 1e308
	end
	local overflowingSlideDefaultOk = pcall(function()
		ObjectGenome.defaultState(overflowingSlide)
	end)
	expect(
		"rejects individually finite slide endpoints whose interpolation span overflows",
		overflowingSlideMechanism ~= nil
			and hasCode(ObjectGenome.inspect(overflowingSlide), "mechanism.linear_limits")
			and not overflowingSlideDefaultOk
	)

	local chairMechanismState = ObjectGenome.defaultState(Fixtures.officeChair)
	local seatTiltMechanism = findMechanism(Fixtures.officeChair, "seat-tilt")
	local seatTiltPosition = chairMechanismState.mechanismPosition["seat-tilt"]
	local decodedTilt = if seatTiltMechanism ~= nil
		then ObjectGenome.decodeMechanismPosition(seatTiltMechanism, seatTiltPosition)
		else nil
	expect(
		"chair tilt default scalar resolves to authored zero degrees",
		seatTiltMechanism ~= nil
			and math.abs(seatTiltPosition - (8 / 22)) < 1e-12
			and decodedTilt ~= nil
			and decodedTilt.kind == "tilt"
			and math.abs(decodedTilt.degrees) < 1e-12
	)

	local casterMechanism = findMechanism(Fixtures.officeChair, "caster-front-left-swivel")
	local casterState = ObjectGenome.defaultState(Fixtures.officeChair)
	casterState.mechanismPosition["caster-front-left-swivel"] = 0.999
	expect(
		"caster accepts canonical half-open swivel scalar",
		casterMechanism ~= nil and ObjectGenome.inspectState(Fixtures.officeChair, casterState).ok
	)
	local decodedCaster = if casterMechanism ~= nil
		then ObjectGenome.decodeMechanismPosition(casterMechanism, 0.25)
		else nil
	expect(
		"caster decoder maps persisted swivel turn fraction and leaves wheel roll transient",
		decodedCaster ~= nil
			and decodedCaster.kind == "caster"
			and decodedCaster.swivelTurns == 0.25
			and decodedCaster.swivelDegrees == 90
	)
	casterState.mechanismPosition["caster-front-left-swivel"] = 1
	expect(
		"caster rejects duplicate full-turn endpoint",
		hasCode(ObjectGenome.inspectState(Fixtures.officeChair, casterState), "state.mechanism_position")
	)

	local slideMechanism = findMechanism(Fixtures.filingCabinet, "slide-top")
	local decodedSlide = if slideMechanism ~= nil
		then ObjectGenome.decodeMechanismPosition(slideMechanism, 0.5)
		else nil
	expect(
		"slide decoder maps scalar to authored physical travel",
		decodedSlide ~= nil and decodedSlide.kind == "slide" and math.abs(decodedSlide.travelM - 0.22) < 1e-12
	)

	local latchMechanism = findMechanism(Fixtures.filingCabinet, "latch-top")
	local latchState = ObjectGenome.defaultState(Fixtures.filingCabinet)
	local decodedLatchDefault = if latchMechanism ~= nil
		then ObjectGenome.decodeMechanismPosition(latchMechanism, latchState.mechanismPosition["latch-top"])
		else nil
	expect(
		"latch default is discrete disengaged authored reference pose",
		decodedLatchDefault ~= nil and decodedLatchDefault.kind == "latch" and not decodedLatchDefault.engaged
	)
	latchState.mechanismPosition["latch-top"] = 1
	expect(
		"latch accepts engaged discrete state",
		ObjectGenome.inspectState(Fixtures.filingCabinet, latchState).ok
	)
	local decodedLatchEngaged = if latchMechanism ~= nil
		then ObjectGenome.decodeMechanismPosition(latchMechanism, 1)
		else nil
	expect(
		"latch decoder maps one to engaged",
		decodedLatchEngaged ~= nil and decodedLatchEngaged.kind == "latch" and decodedLatchEngaged.engaged
	)
	latchState.mechanismPosition["latch-top"] = 0.5
	expect(
		"latch rejects fractional persisted state",
		hasCode(ObjectGenome.inspectState(Fixtures.filingCabinet, latchState), "state.mechanism_position")
	)

	local rotatedOutside = deepCopy(Fixtures.officeTable)
	local top = findComponent(rotatedOutside, "top")
	if top ~= nil then
		top.localRotationDeg = { x = 0, y = 90, z = 0 }
	end
	expect(
		"rotation-aware bounds reject a rotated non-cubic component that no longer fits",
		top ~= nil and hasCode(ObjectGenome.inspect(rotatedOutside), "component.outside_bounds")
	)

	local rotatedFits = deepCopy(Fixtures.officeTable)
	local crossbar = findComponent(rotatedFits, "crossbar")
	if crossbar ~= nil then
		crossbar.dimensionsM = { x = 0.70, y = 0.08, z = 1.30 }
		crossbar.localRotationDeg = { x = 0, y = 90, z = 0 }
	end
	expect(
		"rotation-aware bounds accept a rotated non-cubic component that fits after rotation",
		crossbar ~= nil and not hasCode(ObjectGenome.inspect(rotatedFits), "component.outside_bounds")
	)

	local mixedAxisOrder = deepCopy(Fixtures.officeTable)
	local mixedCrossbar = findComponent(mixedAxisOrder, "crossbar")
	if mixedCrossbar ~= nil then
		-- This geometry fits for fixed-axis XYZ (Rz * Ry * Rx), but not if matrix order
		-- is silently flipped to Rx * Ry * Rz. It therefore locks more than single-axis cases.
		mixedCrossbar.localRotationDeg = { x = 80, y = 25, z = 10 }
	end
	expect(
		"fixed-axis XYZ mixed rotation order is locked",
		mixedCrossbar ~= nil and not hasCode(ObjectGenome.inspect(mixedAxisOrder), "component.outside_bounds")
	)

	local outOfBoundsRotation = deepCopy(Fixtures.officeTable)
	local rotatedTop = findComponent(outOfBoundsRotation, "top")
	if rotatedTop ~= nil then
		rotatedTop.localRotationDeg = { x = 0, y = 270, z = 0 }
	end
	expect(
		"rejects rotation outside the v1 bounded representation",
		rotatedTop ~= nil and hasCode(ObjectGenome.inspect(outOfBoundsRotation), "component.rotation_range")
	)

	local badAffordance = deepCopy(Fixtures.officeChair)
	badAffordance.affordances[1].localPointM.x = 5
	expect(
		"rejects affordance outside component",
		hasCode(ObjectGenome.inspect(badAffordance), "affordance.outside_component")
	)

	local badState = ObjectGenome.defaultState(Fixtures.officeChair)
	badState.componentWear.seat = 1.25
	expect(
		"rejects mutable wear outside unit interval",
		hasCode(ObjectGenome.inspectState(Fixtures.officeChair, badState), "state.unit_interval")
	)

	local unknownStateKey = ObjectGenome.defaultState(Fixtures.filingCabinet)
	unknownStateKey.componentDamage["ghost-component"] = 0.2
	expect(
		"rejects mutable state for unknown component",
		hasCode(ObjectGenome.inspectState(Fixtures.filingCabinet, unknownStateKey), "state.unknown_key")
	)

	local invalidForAssert = deepCopy(Fixtures.officeTable)
	invalidForAssert.massKg = -1
	local ok = pcall(function()
		ObjectGenome.validate(invalidForAssert)
	end)
	expect("asserting validator rejects malformed recipe", not ok)

	return failures
end

return run
