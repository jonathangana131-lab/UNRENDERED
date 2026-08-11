local fs = require("@lune/fs")

local ProductionLoader = require("./support/ProductionLoader")

local PhysicsLabScale = ProductionLoader.requireShared("Physics/PhysicsLabScale")

local function nearlyEqual(left, right, tolerance)
	return math.abs(left - right) <= tolerance
end

local function orderedWithin(source, needles)
	local cursor = 1
	for _, needle in ipairs(needles) do
		local found = string.find(source, needle, cursor, true)
		if found == nil then
			return false
		end
		cursor = found + #needle
	end
	return true
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

	-- Runtime callers are not protected by static Luau annotations. Reject malformed
	-- scalars before equality/order/arithmetic operators can invoke caller metamethods.
	local hostileOperatorCalls = 0
	local hostileScalar = setmetatable({}, {
		__eq = function()
			hostileOperatorCalls += 1
			error("hostile scale equality executed")
		end,
		__lt = function()
			hostileOperatorCalls += 1
			error("hostile scale ordering executed")
		end,
		__mul = function()
			hostileOperatorCalls += 1
			error("hostile scale arithmetic executed")
		end,
	})
	local hostileMetersAccepted = pcall(function()
		PhysicsLabScale.metersToStuds(hostileScalar)
	end)
	local hostileStudsAccepted = pcall(function()
		PhysicsLabScale.studsToMeters(hostileScalar)
	end)
	expect(
		"Physics Lab scale rejects malformed scalars before caller metamethod execution",
		not hostileMetersAccepted and not hostileStudsAccepted and hostileOperatorCalls == 0
	)

	-- A finite SI value can still overflow when projected into studs because
	-- STUDS_PER_METER is greater than one. The representation boundary must
	-- fail closed rather than emit math.huge into downstream geometry/evidence.
	local finiteOverflowAccepted = pcall(function()
		PhysicsLabScale.metersToStuds(1e308)
	end)
	expect(
		"Physics Lab scale rejects finite meter inputs whose stud conversion overflows",
		not finiteOverflowAccepted
	)

	-- With the current 0.28 m/stud scale, a finite studs input cannot overflow the
	-- studs->meters multiplication. Lock the symmetric postcondition in source so
	-- a future scale revision cannot silently drop the reverse derived-output fence.
	local scaleSource = fs.readFile("src/shared/Physics/PhysicsLabScale.luau")
	local metersStart = string.find(scaleSource, "function PhysicsLabScale.metersToStuds", 1, true)
	local studsStart = string.find(scaleSource, "function PhysicsLabScale.studsToMeters", 1, true)
	local moduleReturn = string.find(scaleSource, "return table.freeze(PhysicsLabScale)", 1, true)
	local metersBody = ""
	if metersStart ~= nil and studsStart ~= nil and metersStart < studsStart then
		metersBody = string.sub(scaleSource, metersStart, studsStart - 1)
	end
	local studsBody = ""
	if studsStart ~= nil and moduleReturn ~= nil and studsStart < moduleReturn then
		studsBody = string.sub(scaleSource, studsStart, moduleReturn - 1)
	end

	expect(
		"Physics Lab meters-to-studs keeps input and derived-output finite fences ordered around arithmetic",
		orderedWithin(metersBody, {
			"assertFinite(\"meters\", meters)",
			"local studs = meters * PhysicsLabScale.STUDS_PER_METER",
			"assertFinite(\"converted studs\", studs)",
			"return studs",
		})
	)
	expect(
		"Physics Lab studs-to-meters keeps input and derived-output finite fences ordered around arithmetic",
		orderedWithin(studsBody, {
			"assertFinite(\"studs\", studs)",
			"local meters = studs * PhysicsLabScale.METERS_PER_STUD",
			"assertFinite(\"converted meters\", meters)",
			"return meters",
		})
	)

	return failures
end

return run
