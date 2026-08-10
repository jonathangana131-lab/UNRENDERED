--!strict

local MaterialDNA = require("../src/shared/Materials/MaterialDNA")

local function containsError(result: MaterialDNA.ValidationResult, needle: string): boolean
	for _, message in result.errors do
		if string.find(message, needle, 1, true) ~= nil then
			return true
		end
	end
	return false
end

local function run(): number
	local failures = 0

	local function expect(name: string, condition: boolean): ()
		if condition then
			print(`PASS materialdna_metatable_noexecute {name}`)
		else
			failures += 1
			print(`FAIL materialdna_metatable_noexecute {name}`)
		end
	end

	local recipeReads = 0
	local forgedRecipe = setmetatable({}, {
		__index = function()
			recipeReads += 1
			return nil
		end,
	})
	local recipeResult = MaterialDNA.validateRecipe(forgedRecipe)
	expect(
		"recipe metatable is rejected",
		not recipeResult.ok and containsError(recipeResult, "without a metatable")
	)
	expect("recipe __index is never executed", recipeReads == 0)

	local stateReads = 0
	local forgedState = setmetatable({}, {
		__index = function()
			stateReads += 1
			return nil
		end,
	})
	local stateResult = MaterialDNA.validateState(forgedState)
	expect(
		"state metatable is rejected",
		not stateResult.ok and containsError(stateResult, "without a metatable")
	)
	expect("state __index is never executed", stateReads == 0)

	return failures
end

return run
