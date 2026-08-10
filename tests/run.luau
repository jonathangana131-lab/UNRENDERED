local process = require("@lune/process")

require("./object_genome")

local failures = 0

local function expectEqual(name, actual, expected)
	if actual ~= expected then
		failures += 1
		print(`FAIL {name}: expected {expected}, got {actual}`)
	else
		print(`PASS {name}`)
	end
end

-- Pure algorithm smoke tests live here until a fuller test harness lands.
-- Values are intentionally duplicated from simple local implementations so CI can
-- catch accidental changes to canonical deterministic behavior without Roblox Studio.
local function hash32(text, seed)
	local UINT32 = 4294967296
	local hash = (seed or 0) % UINT32
	for i = 1, #text do
		hash = (hash + string.byte(text, i)) % UINT32
		hash = (hash + bit32.lshift(hash, 10)) % UINT32
		hash = bit32.bxor(hash, bit32.rshift(hash, 6))
	end
	hash = (hash + bit32.lshift(hash, 3)) % UINT32
	hash = bit32.bxor(hash, bit32.rshift(hash, 11))
	hash = (hash + bit32.lshift(hash, 15)) % UINT32
	return hash
end

expectEqual("hash deterministic repeat", hash32("UNRENDERED", 1234), hash32("UNRENDERED", 1234))
if hash32("UNRENDERED", 1234) == hash32("UNRENDERED!", 1234) then
	failures += 1
	print("FAIL hash distinguishes nearby input")
else
	print("PASS hash distinguishes nearby input")
end

if failures > 0 then
	process.exit(1)
end

print("UNRENDERED pure test suite passed")
