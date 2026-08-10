local DeterministicRng = require("../src/shared/Core/DeterministicRng")

local function run(): number
	local failures = 0

	local function expectEqual(name, actual, expected)
		if actual ~= expected then
			failures += 1
			print(`FAIL {name}: expected {tostring(expected)}, got {tostring(actual)}`)
		else
			print(`PASS {name}`)
		end
	end

	local function expectError(name, callback)
		local ok = pcall(callback)
		if ok then
			failures += 1
			print(`FAIL {name}: expected an error`)
		else
			print(`PASS {name}`)
		end
	end

	local die = DeterministicRng.new(1)
	local expectedDieRolls = { 4, 2, 4, 6, 6, 5, 5, 1 }
	for index, expected in expectedDieRolls do
		expectEqual(`bounded integer golden #{index}`, die:nextInteger(1, 6), expected)
	end

	local first = DeterministicRng.new(0x12345678)
	local second = DeterministicRng.new(0x12345678)
	for index = 1, 16 do
		expectEqual(
			`same seed bounded sequence #{index}`,
			first:nextInteger(-17, 29),
			second:nextInteger(-17, 29)
		)
	end

	local rejection = DeterministicRng.new(0x80000000)
	expectEqual(
		"rejection sampling skips out-of-band states",
		rejection:nextInteger(0, 2147483648),
		1756881985
	)
	expectEqual("rejection sampling leaves accepted state current", rejection.state, 1756881985)

	local fullWidth = DeterministicRng.new(1)
	expectEqual("full u32-width range is supported", fullWidth:nextInteger(0, 4294967295), 270369)

	expectError("bounded integer rejects fractional minimum", function()
		DeterministicRng.new(1):nextInteger(1.5, 10)
	end)
	expectError("bounded integer rejects fractional maximum", function()
		DeterministicRng.new(1):nextInteger(1, 10.5)
	end)
	expectError("bounded integer rejects reversed range", function()
		DeterministicRng.new(1):nextInteger(10, 1)
	end)
	expectError("bounded integer rejects width above u32", function()
		DeterministicRng.new(1):nextInteger(0, 4294967296)
	end)

	return failures
end

return run
