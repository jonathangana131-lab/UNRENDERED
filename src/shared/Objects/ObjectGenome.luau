--!strict

export type ComponentSpec = {
	key: string,
	role: string,
	materialId: string,
	massFraction: number,
	mechanism: string?,
}

export type ObjectGenome = {
	id: string,
	family: string,
	apparentEra: string,
	manufacturerFamily: string,
	dimensions: Vector3,
	massKg: number,
	components: { ComponentSpec },
	affordances: { string },
	wear: number,
	damage: number,
}

local ObjectGenome = {}

function ObjectGenome.validate(value: ObjectGenome): ()
	assert(value.id ~= "", "ObjectGenome.id required")
	assert(value.family ~= "", "family required")
	assert(value.massKg > 0, "massKg must be positive")
	assert(
		value.dimensions.X > 0 and value.dimensions.Y > 0 and value.dimensions.Z > 0,
		"dimensions must be positive"
	)
	assert(#value.components > 0, "components required")
	assert(value.wear >= 0 and value.wear <= 1, "wear must be in [0, 1]")
	assert(value.damage >= 0 and value.damage <= 1, "damage must be in [0, 1]")
end

return table.freeze(ObjectGenome)
