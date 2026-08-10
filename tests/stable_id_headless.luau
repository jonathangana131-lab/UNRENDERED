local StableId = require("../src/shared/Core/StableId")

local function run(): number
	local failures = 0

	local function expectEqual(name, actual, expected)
		if actual ~= expected then
			failures += 1
			print(`FAIL stable_id_headless {name}: expected {tostring(expected)}, got {tostring(actual)}`)
		else
			print(`PASS stable_id_headless {name}`)
		end
	end

	local worldId = StableId.fromParts("world", { "alpha" })
	expectEqual("loads production StableId under Lune", worldId, "world:v1:9fa76d9d4d3f004052fffe125f6bfb2a")
	expectEqual("contract version remains canonical", StableId.ContractVersion, 1)
	expectEqual("recognizes canonical namespace", StableId.is(worldId, "world"), true)
	expectEqual("rejects wrong namespace", StableId.is(worldId, "entity"), false)

	return failures
end

return run
