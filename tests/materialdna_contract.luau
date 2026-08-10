--!strict

local MaterialDNA = require("../src/shared/Materials/MaterialDNA")

local function run(): number
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
		for _, message in result.errors do
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
			recipeVersion = 1,
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

	local malformedAccepted, malformedResult = pcall(function()
		return MaterialDNA.validateRecipe({ schemaVersion = MaterialDNA.SchemaVersion })
	end)
	expect("malformed plain recipe does not throw", malformedAccepted, tostring(malformedResult))
	if malformedAccepted then
		expect(
			"malformed plain recipe rejected",
			not malformedResult.ok and containsError(malformedResult, "substrate must be a table"),
			table.concat(malformedResult.errors, "; ")
		)
	end

	local frozenSource = makeRecipe()
	local frozen = MaterialDNA.freezeRecipe(frozenSource)
	frozenSource.physical.staticFriction = 3
	frozenSource.finish.color.r = 0
	frozenSource.historyEvents[1].severity01 = 1
	expect(
		"frozen recipe owns physical copy",
		frozen.physical.staticFriction == 0.6,
		tostring(frozen.physical.staticFriction)
	)
	expect(
		"frozen recipe owns nested color copy",
		frozen.finish.color.r == 0.7,
		tostring(frozen.finish.color.r)
	)
	expect(
		"frozen recipe owns history event copy",
		frozen.historyEvents[1].severity01 == 0.2,
		tostring(frozen.historyEvents[1].severity01)
	)

	local mutatePhysical = pcall(function()
		frozen.physical.staticFriction = 0.1
	end)
	local mutateColor = pcall(function()
		frozen.finish.color.r = 0.1
	end)
	local mutateEvent = pcall(function()
		frozen.historyEvents[1].severity01 = 0.1
	end)
	expect("nested physical recipe is immutable", not mutatePhysical, "physical table accepted mutation")
	expect("nested color recipe is immutable", not mutateColor, "color table accepted mutation")
	expect("nested history recipe is immutable", not mutateEvent, "history event accepted mutation")

	local sparseHistory = makeRecipe()
	local historyEvent = sparseHistory.historyEvents[1]
	local sparseEvents: any = {}
	sparseEvents[2] = historyEvent
	sparseHistory.historyEvents = sparseEvents
	local sparseHistoryResult = MaterialDNA.validateRecipe(sparseHistory)
	expect(
		"sparse history list rejected",
		not sparseHistoryResult.ok and containsError(sparseHistoryResult, "no sparse entries"),
		table.concat(sparseHistoryResult.errors, "; ")
	)

	local keyedModifiers = makeRecipe()
	local modifierList: any = {}
	modifierList.extra = "anomaly.example"
	keyedModifiers.anomalyModifiers = modifierList
	local keyedModifierResult = MaterialDNA.validateRecipe(keyedModifiers)
	expect(
		"keyed anomaly list rejected",
		not keyedModifierResult.ok and containsError(keyedModifierResult, "no keyed entries"),
		table.concat(keyedModifierResult.errors, "; ")
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

	local compatibilityMismatch = makeRecipe()
	compatibilityMismatch.substrate.classKey = "substrate.cold-rolled-steel"
	local compatibilityResult = MaterialDNA.validateRecipe(compatibilityMismatch)
	expect(
		"finish substrate mismatch rejected",
		not compatibilityResult.ok and containsError(compatibilityResult, "wall-compatible substrate"),
		table.concat(compatibilityResult.errors, "; ")
	)

	local installationMismatch = makeRecipe()
	installationMismatch.installation.methodKey = "installation.factory-coated-panel"
	local installationResult = MaterialDNA.validateRecipe(installationMismatch)
	expect(
		"finish installation mismatch rejected",
		not installationResult.ok and containsError(installationResult, "installation.pasted-wallpaper"),
		table.concat(installationResult.errors, "; ")
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

	local invalidSchema = makeRecipe()
	invalidSchema.schemaVersion = MaterialDNA.SchemaVersion + 1
	local schemaResult = MaterialDNA.validateRecipe(invalidSchema)
	expect(
		"unknown schema rejected",
		not schemaResult.ok and containsError(schemaResult, "schemaVersion must be"),
		table.concat(schemaResult.errors, "; ")
	)

	local invalidRecipeVersion = makeRecipe()
	invalidRecipeVersion.recipeVersion = 0
	local recipeVersionResult = MaterialDNA.validateRecipe(invalidRecipeVersion)
	expect(
		"non-positive recipe version rejected",
		not recipeVersionResult.ok and containsError(recipeVersionResult, "recipeVersion"),
		table.concat(recipeVersionResult.errors, "; ")
	)

	local revisionOne = makeRecipe()
	local revisionTwo = makeRecipe()
	revisionTwo.recipeVersion = 2
	revisionTwo.physical.staticFriction = 0.61
	local frozenRevisionOne = MaterialDNA.freezeRecipe(revisionOne)
	local frozenRevisionTwo = MaterialDNA.freezeRecipe(revisionTwo)
	local revisionOneState = MaterialDNA.defaultState(frozenRevisionOne)
	local revisionTwoState = MaterialDNA.defaultState(frozenRevisionTwo)
	expect(
		"state captures exact recipe revision",
		revisionOneState.recipeId == frozenRevisionOne.id and revisionOneState.recipeVersion == 1,
		`{revisionOneState.recipeId}@{revisionOneState.recipeVersion}`
	)
	expect(
		"same material id revisions stay distinct",
		frozenRevisionOne.id == frozenRevisionTwo.id
			and frozenRevisionOne.recipeVersion ~= frozenRevisionTwo.recipeVersion
			and MaterialDNA.stateMatchesRecipe(frozenRevisionOne, revisionOneState)
			and not MaterialDNA.stateMatchesRecipe(frozenRevisionTwo, revisionOneState)
			and MaterialDNA.stateMatchesRecipe(frozenRevisionTwo, revisionTwoState),
		"state did not preserve exact recipe revision identity"
	)

	local state = MaterialDNA.defaultState(makeRecipe())
	local stateMutation = pcall(function()
		state.wear01 = 0.5
	end)
	expect("material state remains mutable", stateMutation and state.wear01 == 0.5, "state mutation failed")
	local stateResult = MaterialDNA.validateState(state)
	expect("mutated state remains valid", stateResult.ok, table.concat(stateResult.errors, "; "))

	local invalidState: any = {
		recipeId = "material.v1.test.wallpaper",
		recipeVersion = 1,
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

	return failures
end

return run
