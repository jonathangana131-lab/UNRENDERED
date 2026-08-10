--!strict

local process = require("@lune/process")
local MaterialDNA = require("../src/shared/Materials/MaterialDNA")

local failures = 0

local function fail(name: string, detail: string): ()
	failures += 1
	print(`FAIL {name}: {detail}`)
end

local function pass(name: string): ()
	print(`PASS {name}`)
end

local function expect(name: string, condition: boolean, detail: string): ()
	if condition then
		pass(name)
	else
		fail(name, detail)
	end
end

local function containsError(result: MaterialDNA.ValidationResult, needle: string): boolean
	for _, message in ipairs(result.errors) do
		if string.find(message, needle, 1, true) ~= nil then
			return true
		end
	end
	return false
end

local function makeRecipe(): MaterialDNA.MaterialRecipe
	return {
		id = "material.v1.test.wallpaper",
		schemaVersion = MaterialDNA.SchemaVersion,
		coherenceClass = "interior.wallpapered-drywall",
		substrate = {
			classKey = "substrate.gypsum-board",
			thicknessMeters = 0.0127,
			porosity01 = 0.3,
		},
		finish = {
			classKey = "finish.vinyl-wallpaper",
			color = {
				r = 0.7,
				g = 0.65,
				b = 0.4,
			},
			roughness01 = 0.7,
			metallic01 = 0,
		},
		installation = {
			methodKey = "installation.pasted-wallpaper",
			batchKey = "batch.test.a",
			quality01 = 0.8,
			seamPeriodMeters = 0.53,
		},
		apparentAgeYears = 12,
		maintenance = {
			careClassKey = "maintenance.light-commercial-cleaning",
			frequency01 = 0.5,
			cleanliness01 = 0.6,
			repairCount = 1,
		},
		environment = {
			humidity01 = 0.3,
			water01 = 0.1,
			uv01 = 0.05,
			grime01 = 0.2,
		},
		historyEvents = {
			{
				kindKey = "history.cabinet-shadow",
				causeKey = "cause.long-term-furniture-placement",
				severity01 = 0.2,
				coverage01 = 0.1,
			},
		},
		visual = {
			familyKey = "fallback.commercial-wallpaper.yellow-vinyl",
			coherenceClass = "interior.wallpapered-drywall",
			metersPerRepeat = 0.53,
		},
		physical = {
			classKey = "physics.wallpapered-drywall",
			coherenceClass = "interior.wallpapered-drywall",
			densityKgPerM3 = 800,
			staticFriction = 0.6,
			dynamicFriction = 0.5,
			restitution01 = 0.05,
		},
		acoustic = {
			classKey = "acoustic.wallpapered-drywall",
			coherenceClass = "interior.wallpapered-drywall",
			absorptionLow01 = 0.05,
			absorptionMid01 = 0.1,
			absorptionHigh01 = 0.15,
			impactFamilyKey = "audio.impact.wallpapered-drywall",
			scrapeFamilyKey = "audio.scrape.vinyl-wallpaper",
		},
		response = {
			wetFrictionMultiplier = 0.85,
			wetDarkening01 = 0.2,
			damageResistance01 = 0.35,
			stainAffinity01 = 0.6,
		},
		anomalyModifiers = {},
	}
end

local valid = MaterialDNA.validateRecipe(makeRecipe())
expect("valid recipe accepted", valid.ok, table.concat(valid.errors, "; "))

local repeated = MaterialDNA.validateRecipe(makeRecipe())
expect(
	"validation deterministic repeat",
	repeated.ok == valid.ok and table.concat(repeated.errors, "\n") == table.concat(valid.errors, "\n"),
	"identical recipes produced different validation results"
)

local coherenceMismatch = makeRecipe()
coherenceMismatch.acoustic.coherenceClass = "interior.low-pile-carpet"
local coherenceResult = MaterialDNA.validateRecipe(coherenceMismatch)
expect(
	"cross-domain coherence mismatch rejected",
	not coherenceResult.ok and containsError(coherenceResult, "acoustic.coherenceClass must match"),
	table.concat(coherenceResult.errors, "; ")
)

local rawAssetReference = makeRecipe()
rawAssetReference.visual.familyKey = "rbxassetid://123456"
local rawAssetResult = MaterialDNA.validateRecipe(rawAssetReference)
expect(
	"raw asset reference rejected",
	not rawAssetResult.ok and containsError(rawAssetResult, "project-owned semantic key"),
	table.concat(rawAssetResult.errors, "; ")
)

local frictionMismatch = makeRecipe()
frictionMismatch.physical.dynamicFriction = 0.8
frictionMismatch.physical.staticFriction = 0.4
local frictionResult = MaterialDNA.validateRecipe(frictionMismatch)
expect(
	"dynamic friction above static rejected",
	not frictionResult.ok and containsError(frictionResult, "dynamicFriction cannot exceed"),
	table.concat(frictionResult.errors, "; ")
)

local invalidRange = makeRecipe()
invalidRange.environment.humidity01 = 1.2
local rangeResult = MaterialDNA.validateRecipe(invalidRange)
expect(
	"out-of-range environment rejected",
	not rangeResult.ok and containsError(rangeResult, "environment.humidity01"),
	table.concat(rangeResult.errors, "; ")
)

local defaultState = MaterialDNA.defaultState("material.v1.test.wallpaper")
local defaultStateResult = MaterialDNA.validateState(defaultState)
expect("default mutable state accepted", defaultStateResult.ok, table.concat(defaultStateResult.errors, "; "))

local invalidState: MaterialDNA.MaterialState = {
	recipeId = "material.v1.test.wallpaper",
	schemaVersion = MaterialDNA.SchemaVersion,
	wear01 = 0.2,
	damage01 = -0.1,
	wetness01 = 0,
	soil01 = 0,
}
local invalidStateResult = MaterialDNA.validateState(invalidState)
expect(
	"invalid mutable state rejected",
	not invalidStateResult.ok and containsError(invalidStateResult, "damage01"),
	table.concat(invalidStateResult.errors, "; ")
)

if failures > 0 then
	process.exit(1)
end

print("MaterialDNA contract tests passed")
