--!strict

export type MaterialDNA = {
	id: string,
	substrate: string,
	finishFamily: string,
	apparentEra: string,
	installationBatch: number,
	age: number,
	maintenance: number,
	humidityExposure: number,
	wear: number,
	damage: number,
	visualFamily: string,
	physicsClass: string,
	acousticClass: string,
}

local MaterialDNA = {}

local function assertUnitInterval(name: string, value: number): ()
	assert(value >= 0 and value <= 1, `{name} must be in [0, 1]`)
end

function MaterialDNA.validate(value: MaterialDNA): ()
	assert(value.id ~= "", "MaterialDNA.id required")
	assert(value.substrate ~= "", "substrate required")
	assert(value.finishFamily ~= "", "finishFamily required")
	assertUnitInterval("age", value.age)
	assertUnitInterval("maintenance", value.maintenance)
	assertUnitInterval("humidityExposure", value.humidityExposure)
	assertUnitInterval("wear", value.wear)
	assertUnitInterval("damage", value.damage)
end

return table.freeze(MaterialDNA)
