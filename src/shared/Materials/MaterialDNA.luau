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

function MaterialDNA.validate(value: MaterialDNA): ()
	assert(value.id ~= "", "MaterialDNA.id required")
	assert(value.substrate ~= "", "substrate required")
	assert(value.finishFamily ~= "", "finishFamily required")
	for name, numberValue in {
		age = value.age,
		maintenance = value.maintenance,
		humidityExposure = value.humidityExposure,
		wear = value.wear,
		damage = value.damage,
	} do
		assert(numberValue >= 0 and numberValue <= 1, `{name} must be in [0, 1]`)
	end
end

return table.freeze(MaterialDNA)
