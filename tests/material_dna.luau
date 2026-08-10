local process = require("@lune/process")

local MaterialDNA = require("../src/shared/Materials/MaterialDNA")
local MaterialExamples = require("../src/shared/Materials/MaterialExamples")

local failures = 0

local function pass(name)
	print(`PASS {name}`)
end

local function fail(name, message)
	failures += 1
	print(`FAIL {name}: {message}`)
end

local function deepCopy(value)
	if type(value) ~= "table" then
		return value
	end

	local copy = {}
	for key, nested in pairs(value) do
		copy[deepCopy(key)] = deepCopy(nested)
	end
	return copy
end

local function expectValid(name, value)
	local issues = MaterialDNA.validateRecipe(value)
	if #issues == 0 then
		pass(name)
		return
	end

	fail(name, `{#issues} validation issue(s), first={issues[1].path}/{issues[1].code}`)
end

local function expectIssueCode(name, value, expectedCode)
	local issues = MaterialDNA.validateRecipe(value)
	for _, issue in ipairs(issues) do
		if issue.code == expectedCode then
			pass(name)
			return
		end
	end

	fail(name, `expected issue code {expectedCode}, got {#issues} issue(s)`)
end

local function expectSurfaceIssueCode(name, value, expectedCode)
	local issues = MaterialDNA.validateSurfaceState(value)
	for _, issue in ipairs(issues) do
		if issue.code == expectedCode then
			pass(name)
			return
		end
	end

	fail(name, `expected surface-state issue code {expectedCode}, got {#issues} issue(s)`)
end

for name, recipe in pairs(MaterialExamples) do
	expectValid(`fixture {name}`, recipe)
end

if MaterialDNA.SchemaVersion == 1 then
	pass("supported schema version is explicit")
else
	fail("supported schema version is explicit", `expected 1, got {tostring(MaterialDNA.SchemaVersion)}`)
end

local futureSchema = deepCopy(MaterialExamples.commercialWallpaper)
futureSchema.schemaVersion = MaterialDNA.SchemaVersion + 1
expectIssueCode("reject unsupported future schema", futureSchema, "unsupported_version")

local rawAssetId = deepCopy(MaterialExamples.commercialWallpaper)
rawAssetId.response.visualFamily = "rbxassetid://123456789"
expectIssueCode("reject raw Roblox asset IDs", rawAssetId, "raw_asset_id")

local incompatibleFinish = deepCopy(MaterialExamples.commercialWallpaper)
incompatibleFinish.finish.family = "low_pile_carpet"
expectIssueCode("reject incompatible finish/substrate", incompatibleFinish, "finish_substrate_mismatch")
expectIssueCode("reject incompatible finish/installation", incompatibleFinish, "finish_installation_mismatch")

local impossibleExposure = deepCopy(MaterialExamples.lowPileCarpet)
impossibleExposure.environment.humidityExposure = 1.25
expectIssueCode("reject exposure outside unit interval", impossibleExposure, "out_of_range")

local impossibleHistory = deepCopy(MaterialExamples.paintedMetal)
impossibleHistory.events[1].ageYearsAgo = impossibleHistory.apparentAgeYears + 1
expectIssueCode("reject event predating material", impossibleHistory, "event_before_material")

expectIssueCode("malformed recipe is reported", {}, "required")

local validState = {
	wetness = 0.2,
	wear = 0.45,
	damage = 0.1,
	dirt = 0.35,
	temperatureC = 21,
}
if #MaterialDNA.validateSurfaceState(validState) == 0 then
	pass("valid mutable surface state")
else
	fail("valid mutable surface state", "unexpected validation failure")
end

local invalidState = deepCopy(validState)
invalidState.damage = 1.1
expectSurfaceIssueCode("reject invalid mutable damage", invalidState, "out_of_range")

if
	MaterialExamples.commercialWallpaper.wetness == nil
	and MaterialExamples.commercialWallpaper.wear == nil
	and MaterialExamples.commercialWallpaper.damage == nil
then
	pass("mutable state is not embedded in immutable recipe")
else
	fail("mutable state is not embedded in immutable recipe", "recipe contains wetness/wear/damage state")
end

if failures > 0 then
	process.exit(1)
end

print("MaterialDNA contract tests passed")
