--!strict

local ObjectGenome = require("./ObjectGenome")

type ObjectGenomeRecipe = ObjectGenome.ObjectGenome

local ObjectGenomeOwnership = {}

local function copyAndFreeze(
	value: any,
	path: string,
	active: { [any]: boolean },
	copies: { [any]: any }
): any
	local valueType = type(value)
	if valueType ~= "table" then
		assert(
			valueType == "string" or valueType == "number" or valueType == "boolean",
			`{path} must contain only plain ObjectGenome data, got {valueType}`
		)
		return value
	end

	assert(getmetatable(value) == nil, `{path} must not carry a metatable`)
	assert(not active[value], `{path} must not contain cyclic tables`)

	local existing = copies[value]
	if existing ~= nil then
		return existing
	end

	local result = {}
	copies[value] = result
	active[value] = true

	for key, child in pairs(value) do
		local keyType = type(key)
		assert(
			keyType == "string" or keyType == "number",
			`{path} contains unsupported {keyType} table key`
		)
		result[key] = copyAndFreeze(child, `{path}.{tostring(key)}`, active, copies)
	end

	active[value] = nil
	return table.freeze(result)
end

function ObjectGenomeOwnership.seal(value: ObjectGenomeRecipe): ObjectGenomeRecipe
	ObjectGenome.validate(value)
	return copyAndFreeze(value, "$", {}, {}) :: ObjectGenomeRecipe
end

return table.freeze(ObjectGenomeOwnership)
