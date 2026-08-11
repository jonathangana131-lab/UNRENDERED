--!strict

local RunService = game:GetService("RunService")

local PhysicsLabRealizer = require(script.Parent.PhysicsLabRealizer)

type RealizedLab = PhysicsLabRealizer.RealizedLab

local PhysicsLabStudioHarness = {}

local current: RealizedLab? = nil

local function assertStudioServer(): ()
	assert(RunService:IsStudio(), "PhysicsLabStudioHarness is Studio-only validation tooling")
	assert(RunService:IsServer(), "PhysicsLabStudioHarness must run on the server")
end

local function bindOwnedHandle(realized: RealizedLab): RealizedLab
	local owned: RealizedLab = table.clone(realized)
	owned.destroy = function(): ()
		assertStudioServer()
		if current ~= owned then
			return
		end
		realized.destroy()
		if current == owned then
			current = nil
		end
	end
	return table.freeze(owned)
end

function PhysicsLabStudioHarness.start(parent: Instance?): RealizedLab
	assertStudioServer()
	assert(current == nil, "Physics Lab Studio harness already owns a realized lab")
	local realized = PhysicsLabRealizer.realize(parent or workspace)
	local owned = bindOwnedHandle(realized)
	current = owned
	return owned
end

function PhysicsLabStudioHarness.get(): RealizedLab?
	assertStudioServer()
	return current
end

function PhysicsLabStudioHarness.stop(): ()
	assertStudioServer()
	local active = current
	if active == nil then
		return
	end
	active.destroy()
	current = nil
end

function PhysicsLabStudioHarness.restart(parent: Instance?): RealizedLab
	assertStudioServer()
	PhysicsLabStudioHarness.stop()
	return PhysicsLabStudioHarness.start(parent)
end

return table.freeze(PhysicsLabStudioHarness)
