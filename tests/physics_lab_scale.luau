local ProductionLoader = require("./support/ProductionLoader")

local PhysicsLabRecipe = ProductionLoader.requireShared("Physics/PhysicsLabRecipe")
local PhysicsLabScale = ProductionLoader.requireShared("Physics/PhysicsLabScale")

local EPSILON = 1e-9

local function nearlyEqual(left, right, tolerance)
	return math.abs(left - right) <= tolerance
end

local function isFinite(value)
	return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

local function run(): number
	local failures = 0

	local function expect(name, condition)
		if condition then
			print(`PASS {name}`)
		else
			failures += 1
			print(`FAIL {name}`)
		end
	end

	expect(
		"Physics Lab scale owns Roblox 0.28 meters-per-stud boundary",
		PhysicsLabScale.METERS_PER_STUD == 0.28
	)
	expect(
		"Physics Lab scale reciprocal is internally consistent",
		PhysicsLabScale.STUDS_PER_METER == 1 / PhysicsLabScale.METERS_PER_STUD
	)

	local exactCases = {
		{ meters = 0, studs = 0 },
		{ meters = 0.28, studs = 1 },
		{ meters = 2.8, studs = 10 },
		{ meters = -1.4, studs = -5 },
	}
	for index, case in ipairs(exactCases) do
		expect(
			`Physics Lab meters-to-studs exact vector {index}`,
			nearlyEqual(PhysicsLabScale.metersToStuds(case.meters), case.studs, 1e-12)
		)
		expect(
			`Physics Lab studs-to-meters exact vector {index}`,
			nearlyEqual(PhysicsLabScale.studsToMeters(case.studs), case.meters, 1e-12)
		)
	end

	local authoredMeters = { 0.045, 0.92, 2.02, 9.6, -4.35 }
	for index, meters in ipairs(authoredMeters) do
		local reconstructed = PhysicsLabScale.studsToMeters(PhysicsLabScale.metersToStuds(meters))
		expect(`Physics Lab SI realization round trip {index}`, nearlyEqual(reconstructed, meters, 1e-12))
	end

	local nanAccepted = pcall(function()
		PhysicsLabScale.metersToStuds(0 / 0)
	end)
	local infiniteAccepted = pcall(function()
		PhysicsLabScale.studsToMeters(math.huge)
	end)
	expect("Physics Lab scale rejects NaN inputs", not nanAccepted)
	expect("Physics Lab scale rejects infinite inputs", not infiniteAccepted)

	-- Geometry/property regressions live beside the SI realization boundary because
	-- the canonical recipe is authored in meters. These checks do not claim engine
	-- contact evidence; they fail source CI when the permanent lab becomes
	-- geometrically impossible, disconnected, or silently detached from the floor.
	local recipe = PhysicsLabRecipe.build()
	local byKey = {}
	local allPlacementFinite = true
	local allPrimitiveSizesPositive = true
	for _, entityRecipe in ipairs(recipe.entities) do
		byKey[entityRecipe.key] = entityRecipe
		for _, axis in ipairs({ "x", "y", "z" }) do
			if not isFinite(entityRecipe.positionM[axis]) or not isFinite(entityRecipe.rotationDeg[axis]) then
				allPlacementFinite = false
			end
		end
		if entityRecipe.kind == "primitive" then
			for _, axis in ipairs({ "x", "y", "z" }) do
				if not isFinite(entityRecipe.sizeM[axis]) or entityRecipe.sizeM[axis] <= 0 then
					allPrimitiveSizesPositive = false
				end
			end
		end
	end
	expect("Physics Lab authored placements stay finite", allPlacementFinite)
	expect("Physics Lab primitive dimensions stay finite and positive", allPrimitiveSizesPositive)

	local floor = byKey.floor
	local ceiling = byKey.ceiling
	local wallLeft = byKey["wall-left"]
	local wallRight = byKey["wall-right"]
	local wallBack = byKey["wall-back"]
	local wallFrontLeft = byKey["wall-front-left"]
	local wallFrontRight = byKey["wall-front-right"]
	local wallFrontHeader = byKey["wall-front-header"]
	local door = byKey["door-main"]
	local spawn = byKey["character-spawn-anchor"]
	local ramp = byKey.ramp
	local shellPresent = floor ~= nil
		and ceiling ~= nil
		and wallLeft ~= nil
		and wallRight ~= nil
		and wallBack ~= nil
		and wallFrontLeft ~= nil
		and wallFrontRight ~= nil
		and wallFrontHeader ~= nil
		and door ~= nil
		and spawn ~= nil
		and ramp ~= nil
	expect("Physics Lab geometry property fixtures are present", shellPresent)

	if shellPresent then
		local floorTop = floor.positionM.y + floor.sizeM.y / 2
		local floorLeft = floor.positionM.x - floor.sizeM.x / 2
		local floorRight = floor.positionM.x + floor.sizeM.x / 2
		local floorFront = floor.positionM.z - floor.sizeM.z / 2
		local floorBack = floor.positionM.z + floor.sizeM.z / 2
		local ceilingBottom = ceiling.positionM.y - ceiling.sizeM.y / 2
		local wallTop = wallLeft.positionM.y + wallLeft.sizeM.y / 2
		local leftInner = wallLeft.positionM.x + wallLeft.sizeM.x / 2
		local rightInner = wallRight.positionM.x - wallRight.sizeM.x / 2
		local backInner = wallBack.positionM.z - wallBack.sizeM.z / 2
		local frontLeftInner = wallFrontLeft.positionM.z + wallFrontLeft.sizeM.z / 2
		local frontRightInner = wallFrontRight.positionM.z + wallFrontRight.sizeM.z / 2

		expect(
			"Physics Lab floor walking plane stays at authored zero meters",
			nearlyEqual(floorTop, 0, EPSILON)
		)
		expect(
			"Physics Lab perimeter inner faces remain flush with the floor footprint",
			nearlyEqual(leftInner, floorLeft, EPSILON)
				and nearlyEqual(rightInner, floorRight, EPSILON)
				and nearlyEqual(backInner, floorBack, EPSILON)
				and nearlyEqual(frontLeftInner, floorFront, EPSILON)
				and nearlyEqual(frontRightInner, floorFront, EPSILON)
		)
		expect(
			"Physics Lab ceiling underside remains flush with perimeter wall tops",
			nearlyEqual(ceilingBottom, wallTop, EPSILON)
		)

		local openingLeft = wallFrontLeft.positionM.x + wallFrontLeft.sizeM.x / 2
		local openingRight = wallFrontRight.positionM.x - wallFrontRight.sizeM.x / 2
		local openingTop = wallFrontHeader.positionM.y - wallFrontHeader.sizeM.y / 2
		local headerLeft = wallFrontHeader.positionM.x - wallFrontHeader.sizeM.x / 2
		local headerRight = wallFrontHeader.positionM.x + wallFrontHeader.sizeM.x / 2
		local doorGenome = PhysicsLabRecipe.objectGenome(door.genomeKey)
		local doorLeft = door.positionM.x - doorGenome.dimensionsM.x / 2
		local doorRight = door.positionM.x + doorGenome.dimensionsM.x / 2
		local doorBottom = door.positionM.y - doorGenome.dimensionsM.y / 2
		local doorTop = door.positionM.y + doorGenome.dimensionsM.y / 2
		local leftClearance = doorLeft - openingLeft
		local rightClearance = openingRight - doorRight
		local topClearance = openingTop - doorTop
		expect(
			"Physics Lab front header exactly bridges the centered wall aperture",
			openingLeft < 0
				and openingRight > 0
				and nearlyEqual(math.abs(openingLeft), openingRight, EPSILON)
				and nearlyEqual(headerLeft, openingLeft, EPSILON)
				and nearlyEqual(headerRight, openingRight, EPSILON)
		)
		expect(
			"Physics Lab commercial door fits the wall aperture with small positive clearance",
			leftClearance > 0
				and leftClearance <= 0.10
				and rightClearance > 0
				and rightClearance <= 0.10
				and topClearance > 0
				and topClearance <= 0.15
				and nearlyEqual(doorBottom, floorTop, EPSILON)
		)

		local everyObjectGrounded = true
		for _, entityRecipe in ipairs(recipe.entities) do
			if entityRecipe.kind == "object" then
				local genome = PhysicsLabRecipe.objectGenome(entityRecipe.genomeKey)
				local objectBottom = entityRecipe.positionM.y - genome.dimensionsM.y / 2
				if not nearlyEqual(objectBottom, floorTop, EPSILON) then
					everyObjectGrounded = false
				end
			end
		end
		expect(
			"Physics Lab ObjectGenome outer envelopes remain grounded on the floor plane",
			everyObjectGrounded
		)

		local stairKeys = { "stair-1", "stair-2", "stair-3", "stair-4" }
		local stairsContiguous = true
		local stairsGrounded = true
		local stairsRiseMonotonic = true
		local priorStair = nil
		local priorTop = nil
		local canonicalRise = nil
		for _, key in ipairs(stairKeys) do
			local stair = byKey[key]
			if stair == nil then
				stairsContiguous = false
				stairsGrounded = false
				stairsRiseMonotonic = false
				break
			end
			local stairBottom = stair.positionM.y - stair.sizeM.y / 2
			local stairTop = stair.positionM.y + stair.sizeM.y / 2
			if not nearlyEqual(stairBottom, floorTop, EPSILON) then
				stairsGrounded = false
			end
			if priorStair ~= nil and priorTop ~= nil then
				local priorFarZ = priorStair.positionM.z + priorStair.sizeM.z / 2
				local currentNearZ = stair.positionM.z - stair.sizeM.z / 2
				if
					not nearlyEqual(priorFarZ, currentNearZ, EPSILON)
					or not nearlyEqual(priorStair.sizeM.x, stair.sizeM.x, EPSILON)
					or not nearlyEqual(priorStair.sizeM.z, stair.sizeM.z, EPSILON)
				then
					stairsContiguous = false
				end
				local rise = stairTop - priorTop
				if rise > 0 and (canonicalRise == nil or nearlyEqual(rise, canonicalRise, EPSILON)) then
					canonicalRise = rise
				else
					stairsRiseMonotonic = false
				end
			end
			priorStair = stair
			priorTop = stairTop
		end
		expect("Physics Lab stair blocks remain grounded on the floor plane", stairsGrounded)
		expect("Physics Lab stair run remains gap-free with consistent tread footprint", stairsContiguous)
		expect("Physics Lab stair top surfaces retain a constant positive rise", stairsRiseMonotonic)

		local firstStair = byKey["stair-1"]
		if firstStair ~= nil then
			local firstStairTop = firstStair.positionM.y + firstStair.sizeM.y / 2
			local rampAngle = math.rad(ramp.rotationDeg.z)
			local halfRun = ramp.sizeM.x / 2
			local halfThickness = ramp.sizeM.y / 2
			local verticalRun = math.abs(halfRun * math.sin(rampAngle))
			local surfaceThickness = halfThickness * math.cos(rampAngle)
			local lowSurfaceY = ramp.positionM.y - verticalRun + surfaceThickness
			local highSurfaceY = ramp.positionM.y + verticalRun + surfaceThickness
			expect(
				"Physics Lab ramp entry lip stays no higher than the first stair rise",
				lowSurfaceY >= floorTop - EPSILON and lowSurfaceY <= firstStairTop + EPSILON
			)
			expect(
				"Physics Lab ramp remains a single-axis climb with bounded incline",
				nearlyEqual(ramp.rotationDeg.x, 0, EPSILON)
					and nearlyEqual(ramp.rotationDeg.y, 0, EPSILON)
					and math.abs(ramp.rotationDeg.z) <= 15
					and highSurfaceY > lowSurfaceY
			)
		end

		local spawnBottom = spawn.positionM.y - spawn.sizeM.y / 2
		expect(
			"Physics Lab character spawn anchor stays grounded, non-collidable, and inside the shell",
			nearlyEqual(spawnBottom, floorTop, EPSILON)
				and spawn.collidable == false
				and spawn.positionM.x > floorLeft
				and spawn.positionM.x < floorRight
				and spawn.positionM.z > floorFront
				and spawn.positionM.z < floorBack
		)
	end

	return failures
end

return run
