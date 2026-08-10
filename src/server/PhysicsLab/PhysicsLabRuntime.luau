--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("UNRENDERED")
local FidelityManager = require(Shared.Physics.FidelityManager)
local PhysicsLabRecipe = require(Shared.PhysicsLab.PhysicsLabRecipe)
local WorldEntity = require(Shared.Reality.WorldEntity)
local PhysicsLabRealizer = require(script.Parent.PhysicsLabRealizer)

type Recipe = PhysicsLabRecipe.Recipe

type RuntimeHandle = {
	recipe: Recipe,
	model: Model,
	registry: WorldEntity.Registry,
	fidelityManager: FidelityManager.Manager,
}

local PhysicsLabRuntime = {}
local activeHandle: RuntimeHandle? = nil

local function attachFidelityDiagnostics(model: Model, manager: FidelityManager.Manager): ()
	local metrics = manager:getMetrics()
	model:SetAttribute("UNRENDERED_FidelityRegistered", metrics.registered)
	model:SetAttribute("UNRENDERED_FidelityF0", metrics.counts.F0)
	model:SetAttribute("UNRENDERED_FidelityF1", metrics.counts.F1)
	model:SetAttribute("UNRENDERED_FidelityF2", metrics.counts.F2)
	model:SetAttribute("UNRENDERED_FidelityF3", metrics.counts.F3)
	model:SetAttribute("UNRENDERED_FidelityF4", metrics.counts.F4)
end

function PhysicsLabRuntime.stop(): ()
	local handle = activeHandle
	if handle == nil then
		return
	end
	if handle.model.Parent ~= nil then
		handle.model:Destroy()
	end
	activeHandle = nil
end

function PhysicsLabRuntime.start(): RuntimeHandle
	assert(RunService:IsServer(), "PhysicsLabRuntime must run on the server")
	PhysicsLabRuntime.stop()

	local recipe = PhysicsLabRecipe.build()
	local registry = WorldEntity.createRegistry()
	local fidelityManager = FidelityManager.new()

	for _, item in ipairs(recipe.items) do
		local registered, duplicate = registry.register(item.entity)
		assert(
			registered,
			if duplicate ~= nil
				then `duplicate Physics Lab WorldEntityId {duplicate.entityId}`
				else `failed to register Physics Lab WorldEntityId {item.entity.id}`
		)
		fidelityManager:register(item.entity.id, item.entity.fidelity)
	end

	local model = PhysicsLabRealizer.realize(recipe)
	attachFidelityDiagnostics(model, fidelityManager)

	local handle: RuntimeHandle = {
		recipe = recipe,
		model = model,
		registry = registry,
		fidelityManager = fidelityManager,
	}
	activeHandle = handle

	local metrics = fidelityManager:getMetrics()
	print(
		string.format(
			"[UNRENDERED] Physics Lab online | world=%s region=%s entities=%d F2=%d F3=%d",
			recipe.worldId,
			recipe.regionId,
			metrics.registered,
			metrics.counts.F2,
			metrics.counts.F3
		)
	)
	return handle
end

function PhysicsLabRuntime.getActive(): RuntimeHandle?
	return activeHandle
end

return table.freeze(PhysicsLabRuntime)
