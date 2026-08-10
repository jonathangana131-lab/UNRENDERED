local Versions = require("../src/shared/Core/Versions")
local RealityVersions = require("../src/shared/Reality/RealityVersions")

local function run(): number
	local failures = 0

	local function expect(name, condition)
		if not condition then
			failures += 1
			print(`FAIL {name}`)
		else
			print(`PASS {name}`)
		end
	end

	local snapshot = RealityVersions.current()
	local expected = {
		reality = Versions.Reality,
		topology = Versions.Topology,
		material = Versions.Material,
		object = Versions.Object,
		entity = Versions.Entity,
	}

	local fieldCount = 0
	local exactShape = true
	for key, value in pairs(snapshot) do
		fieldCount += 1
		if expected[key] == nil or expected[key] ~= value then
			exactShape = false
		end
	end

	expect("snapshot has exact generator-version shape", exactShape and fieldCount == 5)
	expect("snapshot pins current reality version", snapshot.reality == Versions.Reality)
	expect("snapshot pins current topology version", snapshot.topology == Versions.Topology)
	expect("snapshot pins current material version", snapshot.material == Versions.Material)
	expect("snapshot pins current object version", snapshot.object == Versions.Object)
	expect("snapshot pins current entity version", snapshot.entity == Versions.Entity)

	local positiveIntegerVersions = true
	for _, value in pairs(snapshot) do
		if type(value) ~= "number" or value < 1 or value % 1 ~= 0 or value ~= value or value == math.huge then
			positiveIntegerVersions = false
			break
		end
	end
	expect("snapshot versions are finite positive integers", positiveIntegerVersions)

	local mutationAccepted = pcall(function()
		(snapshot :: any).reality = snapshot.reality + 1
	end)
	expect("snapshot rejects caller mutation", not mutationAccepted)

	local repeated = RealityVersions.current()
	expect(
		"repeated snapshot is value-stable",
		repeated.reality == snapshot.reality
			and repeated.topology == snapshot.topology
			and repeated.material == snapshot.material
			and repeated.object == snapshot.object
			and repeated.entity == snapshot.entity
	)

	return failures
end

return run
