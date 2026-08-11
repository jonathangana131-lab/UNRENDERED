local fs = require("@lune/fs")
local luau = require("@lune/luau")
local ProductionLoader = require("./support/ProductionLoader")

local PhysicsLabScale = ProductionLoader.requireShared("Physics/PhysicsLabScale")

local function nearlyEqual(left, right, tolerance)
	return math.abs(left - right) <= tolerance
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

	-- The production 0.28 m/stud factor cannot make a finite studs input overflow
	-- during studs->meters conversion, so amplify only a loaded test copy. This
	-- behaviorally exercises the otherwise unreachable reverse derived-output fence.
	local scaleSource = fs.readFile("src/shared/Physics/PhysicsLabScale.luau")
	local amplifiedSource, replacements =
		string.gsub(scaleSource, "METERS_PER_STUD = 0.28", "METERS_PER_STUD = 2")
	expect("Physics Lab reverse-overflow adversary rewrites exactly one scale constant", replacements == 1)

	local amplifiedChunk = luau.load(amplifiedSource, {
		debugName = "PhysicsLabScale reverse-overflow adversary",
		injectGlobals = true,
	})
	local amplifiedScale = amplifiedChunk()
	local reverseOverflowAccepted = pcall(function()
		amplifiedScale.studsToMeters(1e308)
	end)
	expect(
		"Physics Lab scale rejects finite stud inputs when their meter conversion overflows",
		not reverseOverflowAccepted
	)

	return failures
end

return run
