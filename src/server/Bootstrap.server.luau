--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("UNRENDERED")
local Versions = require(Shared.Core.Versions)
local SeedStream = require(Shared.WorldGen.SeedStream)
local PhysicsLabRuntime = require(script.Parent.PhysicsLab.PhysicsLabRuntime)

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

local physicsLabEnabled = RunService:IsStudio() or Workspace:GetAttribute("UNRENDERED_EnablePhysicsLab") == true
if physicsLabEnabled then
	PhysicsLabRuntime.start()
end
