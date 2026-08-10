--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("UNRENDERED")
local Versions = require(Shared.Core.Versions)
local SeedStream = require(Shared.WorldGen.SeedStream)

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
	local PhysicsLabController = require(script.Parent.PhysicsLab.PhysicsLabController)
	local root = PhysicsLabController.start(Workspace)
	local snapshot = PhysicsLabController.snapshot()
	print(
		string.format(
			"[UNRENDERED] Physics Lab realized | recipe=%s elements=%d",
			tostring(root:GetAttribute("RecipeId")),
			snapshot.registered
		)
	)
end
