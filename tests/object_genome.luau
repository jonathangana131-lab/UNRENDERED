local ObjectGenome = require("../src/shared/Objects/ObjectGenome")
local ObjectFixtures = require("../src/shared/Objects/ObjectFixtures")

local function shallowCloneGenome(source)
	local clone = table.clone(source)
	clone.provenance = table.clone(source.provenance)
	clone.dimensionsMeters = table.clone(source.dimensionsMeters)
	clone.plausibleDimensionsMeters = {
		min = table.clone(source.plausibleDimensionsMeters.min),
		max = table.clone(source.plausibleDimensionsMeters.max),
	}
	clone.plausibleMassKg = table.clone(source.plausibleMassKg)
	clone.centerOfMassMeters = table.clone(source.centerOfMassMeters)
	clone.components = table.clone(source.components)
	clone.mechanisms = table.clone(source.mechanisms)
	clone.gripRegions = table.clone(source.gripRegions)
	clone.affordances = table.clone(source.affordances)
	return clone
end

return function()
	local failures = 0

	local function expectEqual(name, actual, expected)
		if actual ~= expected then
			failures += 1
			print(`FAIL {name}: expected {expected}, got {actual}`)
		else
			print(`PASS {name}`)
		end
	end

	local function expectTruthy(name, value, detail)
		if not value then
			failures += 1
			print(`FAIL {name}: {detail or "expected truthy value"}`)
		else
			print(`PASS {name}`)
		end
	end

	local function expectRejects(name, callback)
		local ok = pcall(callback)
		if ok then
			failures += 1
			print(`FAIL {name}: expected validation failure`)
		else
			print(`PASS {name}`)
		end
	end

	local expectedChairId = ObjectGenome.deriveId(
		1,
		"office-chair",
		"norridge",
		"taskline-94",
		"t94-midback",
		"grey-blue"
	)
	expectEqual("object genome deterministic id", ObjectFixtures.officeChair.id, expectedChairId)
	expectEqual(
		"object genome deterministic id repeat",
		ObjectGenome.deriveId(1, "office-chair", "norridge", "taskline-94", "t94-midback", "grey-blue"),
		expectedChairId
	)

	for name, fixture in ObjectFixtures do
		local ok, err = pcall(ObjectGenome.validate, fixture)
		expectTruthy(`object fixture {name} validates`, ok, tostring(err))
	end

	local badId = shallowCloneGenome(ObjectFixtures.officeChair)
	badId.id = "object-genome:1:office-chair:norridge:taskline-94:t94-midback:wrong"
	expectRejects("object genome rejects non-deterministic id", function()
		ObjectGenome.validate(badId)
	end)

	local badDimensions = shallowCloneGenome(ObjectFixtures.officeTable)
	badDimensions.dimensionsMeters = { x = 5, y = 0.74, z = 0.76 }
	expectRejects("object genome rejects implausible dimensions", function()
		ObjectGenome.validate(badDimensions)
	end)

	local badSupport = shallowCloneGenome(ObjectFixtures.filingCabinet)
	badSupport.components[2] = table.clone(badSupport.components[2])
	badSupport.components[2].supportedBy = { "missing-support" }
	expectRejects("object genome rejects unknown structural support", function()
		ObjectGenome.validate(badSupport)
	end)

	local badMassGraph = shallowCloneGenome(ObjectFixtures.officeChair)
	badMassGraph.components[1] = table.clone(badMassGraph.components[1])
	badMassGraph.components[1].massFraction = 0.5
	expectRejects("object genome rejects invalid component mass fractions", function()
		ObjectGenome.validate(badMassGraph)
	end)

	local cyclicSupport = shallowCloneGenome(ObjectFixtures.officeChair)
	cyclicSupport.components[6] = table.clone(cyclicSupport.components[6])
	cyclicSupport.components[7] = table.clone(cyclicSupport.components[7])
	cyclicSupport.components[6].supportedBy = { "arms" }
	cyclicSupport.components[7].supportedBy = { "back" }
	expectRejects("object genome rejects support cycles", function()
		ObjectGenome.validate(cyclicSupport)
	end)

	local state = ObjectGenome.newState()
	state.mechanismPosition["seat-height"] = 0.05
	local stateOk, stateErr = pcall(ObjectGenome.validateState, ObjectFixtures.officeChair, state)
	expectTruthy("object state validates independently from immutable genome", stateOk, tostring(stateErr))

	state.mechanismPosition["seat-height"] = 2
	expectRejects("object state rejects mechanism state outside limits", function()
		ObjectGenome.validateState(ObjectFixtures.officeChair, state)
	end)

	return failures
end
