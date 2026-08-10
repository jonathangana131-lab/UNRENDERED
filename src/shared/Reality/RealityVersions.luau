--!strict

local Versions = require(script.Parent.Parent.Core.Versions)

export type RealityVersions = {
	reality: number,
	topology: number,
	material: number,
	object: number,
	entity: number,
}

local RealityVersions = {}

function RealityVersions.current(): RealityVersions
	return table.freeze({
		reality = Versions.Reality,
		topology = Versions.Topology,
		material = Versions.Material,
		object = Versions.Object,
		entity = Versions.Entity,
	})
end

return table.freeze(RealityVersions)
