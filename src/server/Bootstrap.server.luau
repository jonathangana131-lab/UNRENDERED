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
	local PhysicsLabRecipe = require(Shared.Physics.PhysicsLabRecipe)
	local PhysicsLabRealizer = require(script.Parent.PhysicsLab.PhysicsLabRealizer)
	local recipe = PhysicsLabRecipe.build()
	PhysicsLabRealizer.realize(recipe, Workspace)
	print(
		string.format(
			"[UNRENDERED] Physics Lab realized | recipe=%s elements=%d",
			recipe.recipeId,
			#recipe.elements
		)
	)
end
