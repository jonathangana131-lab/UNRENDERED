--!strict

local StableId = require(script.Parent.Parent.Core.StableId)

local ObjectGenomeRecipeIdentity = {}

ObjectGenomeRecipeIdentity.Namespace = "object-genome-recipe"
ObjectGenomeRecipeIdentity.Version = 1

local STRING_CHUNK_BYTES = 384

local function fold(digest: string, token: string): string
	assert(#token <= 512, "ObjectGenome recipe identity token exceeds StableId semantic-part limit")
	return StableId.fromParts(ObjectGenomeRecipeIdentity.Namespace, {
		`v{ObjectGenomeRecipeIdentity.Version}`,
		digest,
		token,
	})
end

local function numberText(value: number): string
	if value == 0 then
		return "0"
	end
	return string.format("%.17g", value)
end

local function foldString(digest: string, label: string, value: string): string
	digest = fold(digest, label)
	digest = fold(digest, `string-bytes:{#value}`)

	local chunkIndex = 0
	for offset = 1, #value, STRING_CHUNK_BYTES do
		chunkIndex += 1
		local chunk = string.sub(value, offset, offset + STRING_CHUNK_BYTES - 1)
		digest = fold(digest, `string-chunk:{chunkIndex}:{chunk}`)
	end

	return digest
end

local function foldNumber(digest: string, label: string, value: number): string
	digest = fold(digest, label)
	return fold(digest, `number:{numberText(value)}`)
end

local function foldVec3(digest: string, label: string, value: any): string
	digest = fold(digest, label)
	digest = foldNumber(digest, "x", value.x)
	digest = foldNumber(digest, "y", value.y)
	return foldNumber(digest, "z", value.z)
end

local function sortedRecordsByKey(values: { any }): { any }
	local sorted = table.create(#values)
	for index, value in ipairs(values) do
		sorted[index] = value
	end
	table.sort(sorted, function(left, right)
		return left.key < right.key
	end)
	return sorted
end

local function sortedStrings(values: { string }): { string }
	local sorted = table.create(#values)
	for index, value in ipairs(values) do
		sorted[index] = value
	end
	table.sort(sorted)
	return sorted
end

local function foldComponent(digest: string, component: any): string
	digest = fold(digest, "component")
	digest = foldString(digest, "key", component.key)
	digest = foldString(digest, "role", component.role)
	digest = foldString(digest, "materialKey", component.materialKey)
	digest = foldNumber(digest, "materialRecipeVersion", component.materialRecipeVersion)
	digest = foldNumber(digest, "massKg", component.massKg)
	digest = foldVec3(digest, "localPositionM", component.localPositionM)
	digest = foldVec3(digest, "localRotationDeg", component.localRotationDeg)
	digest = foldVec3(digest, "dimensionsM", component.dimensionsM)
	digest = foldString(digest, "externalSupport", component.externalSupport)

	local supportKeys = sortedStrings(component.supportKeys)
	digest = foldNumber(digest, "supportKeyCount", #supportKeys)
	for _, supportKey in ipairs(supportKeys) do
		digest = foldString(digest, "supportKey", supportKey)
	end

	return digest
end

local function foldMechanism(digest: string, mechanism: any): string
	digest = fold(digest, "mechanism")
	digest = foldString(digest, "key", mechanism.key)
	digest = foldString(digest, "kind", mechanism.kind)
	digest = foldString(digest, "movingComponentKey", mechanism.movingComponentKey)

	if mechanism.kind == "latch" then
		digest = foldString(digest, "catchComponentKey", mechanism.catchComponentKey)
		return foldNumber(digest, "engagementDistanceM", mechanism.engagementDistanceM)
	end

	digest = foldString(digest, "frameComponentKey", mechanism.frameComponentKey)
	if mechanism.kind == "hinge" or mechanism.kind == "tilt" then
		digest = foldVec3(digest, "axis", mechanism.axis)
		digest = foldNumber(digest, "minDegrees", mechanism.minDegrees)
		return foldNumber(digest, "maxDegrees", mechanism.maxDegrees)
	elseif mechanism.kind == "slide" then
		digest = foldVec3(digest, "axis", mechanism.axis)
		digest = foldNumber(digest, "minTravelM", mechanism.minTravelM)
		return foldNumber(digest, "maxTravelM", mechanism.maxTravelM)
	elseif mechanism.kind == "caster" then
		digest = foldNumber(digest, "wheelRadiusM", mechanism.wheelRadiusM)
		digest = foldVec3(digest, "swivelAxis", mechanism.swivelAxis)
		return foldVec3(digest, "rollAxis", mechanism.rollAxis)
	end

	error(`unsupported ObjectGenome mechanism kind {tostring(mechanism.kind)}`)
end

local function foldAffordance(digest: string, affordance: any): string
	digest = fold(digest, "affordance")
	digest = foldString(digest, "key", affordance.key)
	digest = foldString(digest, "kind", affordance.kind)
	digest = foldString(digest, "componentKey", affordance.componentKey)
	digest = foldVec3(digest, "localPointM", affordance.localPointM)
	return foldNumber(digest, "radiusM", affordance.radiusM)
end

function ObjectGenomeRecipeIdentity.key(value: any): string
	local digest = StableId.fromParts(ObjectGenomeRecipeIdentity.Namespace, {
		`v{ObjectGenomeRecipeIdentity.Version}`,
		"root",
	})

	digest = foldNumber(digest, "schemaVersion", value.schemaVersion)
	digest = foldString(digest, "familyId", value.familyId)
	digest = foldNumber(digest, "familyVersion", value.familyVersion)
	digest = foldString(digest, "variantKey", value.variantKey)

	digest = fold(digest, "provenance")
	digest = foldString(digest, "manufacturerFamily", value.provenance.manufacturerFamily)
	digest = foldString(digest, "productLine", value.provenance.productLine)
	digest = foldString(digest, "apparentEra", value.provenance.apparentEra)

	digest = foldVec3(digest, "dimensionsM", value.dimensionsM)
	digest = fold(digest, "dimensionLimits")
	digest = foldVec3(digest, "minM", value.dimensionLimits.minM)
	digest = foldVec3(digest, "maxM", value.dimensionLimits.maxM)
	digest = foldNumber(digest, "massKg", value.massKg)
	digest = fold(digest, "massLimitsKg")
	digest = foldNumber(digest, "min", value.massLimitsKg.min)
	digest = foldNumber(digest, "max", value.massLimitsKg.max)
	digest = foldVec3(digest, "centerOfMassM", value.centerOfMassM)

	local components = sortedRecordsByKey(value.components)
	digest = foldNumber(digest, "componentCount", #components)
	for _, component in ipairs(components) do
		digest = foldComponent(digest, component)
	end

	local mechanisms = sortedRecordsByKey(value.mechanisms)
	digest = foldNumber(digest, "mechanismCount", #mechanisms)
	for _, mechanism in ipairs(mechanisms) do
		digest = foldMechanism(digest, mechanism)
	end

	local affordances = sortedRecordsByKey(value.affordances)
	digest = foldNumber(digest, "affordanceCount", #affordances)
	for _, affordance in ipairs(affordances) do
		digest = foldAffordance(digest, affordance)
	end

	return digest
end

return table.freeze(ObjectGenomeRecipeIdentity)
