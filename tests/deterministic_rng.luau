local Contract = require("../src/shared/Core/DeterminismContract")

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

	local dieState = 1
	local expectedDieRolls = { 3, 1, 3, 5, 5, 4, 4, 6 }
	for index, expected in expectedDieRolls do
		local value
		dieState, value = Contract.nextIntegerState(dieState, 1, 6)
		expectEqual(`bounded integer golden #{index}`, value, expected)
	end

	local firstState = 0x12345678
	local secondState = 0x12345678
	for index = 1, 16 do
		local firstValue
		local secondValue
		firstState, firstValue = Contract.nextIntegerState(firstState, -17, 29)
		secondState, secondValue = Contract.nextIntegerState(secondState, -17, 29)
		expectEqual(`same seed bounded sequence #{index}`, firstValue, secondValue)
	end

	local parityRejectionState, parityRejectionValue = Contract.nextIntegerState(0x5e6cfce7, 0, 1)
	expectEqual("two-way draw rejects unreachable-domain remainder", parityRejectionValue, 0)
	expectEqual("two-way rejection advances to accepted state", parityRejectionState, 0x0003e01f)

	local rejectionState, rejectionValue = Contract.nextIntegerState(0x80000000, 0, 2147483648)
	expectEqual("rejection sampling skips out-of-band states", rejectionValue, 1756881984)
	expectEqual("rejection sampling leaves accepted state current", rejectionState, 1756881985)

	local maxWidthState, maxWidthValue = Contract.nextIntegerState(1, 0, 4294967294)
	expectEqual("full xorshift-state-width range is supported", maxWidthValue, 270368)
	expectEqual("full xorshift-state-width range returns next state", maxWidthState, 270369)

	expectError("bounded integer rejects fractional minimum", function()
		Contract.nextIntegerState(1, 1.5, 10)
	end)
	expectError("bounded integer rejects fractional maximum", function()
		Contract.nextIntegerState(1, 1, 10.5)
	end)
	expectError("bounded integer rejects reversed range", function()
		Contract.nextIntegerState(1, 10, 1)
	end)
	expectError("bounded integer rejects width above xorshift state domain", function()
		Contract.nextIntegerState(1, 0, 4294967295)
	end)
	expectError("bounded integer rejects invalid RNG state", function()
		Contract.nextIntegerState(4294967296, 1, 6)
	end)

	return failures
end

return run
