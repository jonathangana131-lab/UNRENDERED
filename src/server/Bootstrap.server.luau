--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("UNRENDERED")
local Versions = require(Shared.Core.Versions)
local SeedStream = require(Shared.WorldGen.SeedStream)
local PhysicsLabStudioHarness = require(script.Parent.PhysicsLab.PhysicsLabStudioHarness)

assert(RunService:IsServer(), "server bootstrap must run on server")

local probe =
	SeedStream.derive("unrendered-bootstrap", Versions.Reality, "system.bootstrap", { "server", "probe" })
local deterministicProbe = probe:nextU32()

print(
	string.format(
		"[UNRENDERED] server foundation online | game=%d reality=%d probe=%u",
		Versions.Game,
		Versions.Reality,
		deterministicProbe
	)
)

if RunService:IsStudio() then
	local lab = PhysicsLabStudioHarness.start(workspace)
	print(
		string.format(
			"[UNRENDERED] Physics Lab realized | entities=%d recipe=%s",
			lab.model:GetAttribute("UNRENDERED_EntityCount") :: number,
			lab.model:GetAttribute("UNRENDERED_LabRecipeKey") :: string
		)
	)
end
