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
	local expectedParent = realized.model.Parent
	assert(expectedParent ~= nil, "Physics Lab realizer must publish an owned model before harness binding")

	local tearingDown = false
	local invalidated = false
	local ancestryConnection: RBXScriptConnection? = nil
	local destroyingConnection: RBXScriptConnection? = nil

	local function disconnectLifecycleSignals(): ()
		local ancestry = ancestryConnection
		ancestryConnection = nil
		if ancestry ~= nil then
			ancestry:Disconnect()
		end

		local destroying = destroyingConnection
		destroyingConnection = nil
		if destroying ~= nil then
			destroying:Disconnect()
		end
	end

	local function invalidateExternalLifecycle(): ()
		if tearingDown or invalidated or current ~= owned then
			return
		end
		invalidated = true
		current = nil
		disconnectLifecycleSignals()
		task.defer(function(): ()
			realized.destroy()
		end)
	end

	destroyingConnection = realized.model.Destroying:Connect(function(): ()
		invalidateExternalLifecycle()
	end)
	ancestryConnection = realized.model.AncestryChanged:Connect(function(): ()
		if realized.model.Parent ~= expectedParent then
			invalidateExternalLifecycle()
		end
	end)

	owned.destroy = function(): ()
		assertStudioServer()
		if current ~= owned or invalidated then
			return
		end
		tearingDown = true
		realized.destroy()
		tearingDown = false
		disconnectLifecycleSignals()
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
