--!strict

local RunService = game:GetService("RunService")

local PhysicsLabRealizer = require(script.Parent.PhysicsLabRealizer)

type RealizedLab = PhysicsLabRealizer.RealizedLab

local PhysicsLabStudioHarness = {}

local current: RealizedLab? = nil
local currentReconcile: (() -> boolean)? = nil

local function assertStudioServer(): ()
	assert(RunService:IsStudio(), "PhysicsLabStudioHarness is Studio-only validation tooling")
	assert(RunService:IsServer(), "PhysicsLabStudioHarness must run on the server")
end

local function reconcileCurrent(): ()
	local reconcile = currentReconcile
	if reconcile == nil then
		return
	end
	if reconcile() and currentReconcile == reconcile then
		currentReconcile = nil
	end
end

local function bindOwnedHandle(realized: RealizedLab): (RealizedLab, () -> boolean)
	local owned: RealizedLab = table.clone(realized)
	local expectedParent = realized.model.Parent
	assert(expectedParent ~= nil, "Physics Lab realizer must publish an owned model before harness binding")

	local tearingDown = false
	local invalidated = false
	local cleanupComplete = false
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

	local function destroyRealized(): ()
		if cleanupComplete or tearingDown then
			return
		end
		tearingDown = true
		local ok, failure = pcall(realized.destroy)
		tearingDown = false
		if not ok then
			error(failure, 0)
		end
		cleanupComplete = true
	end

	local function invalidateExternalLifecycle(): ()
		if tearingDown or invalidated or current ~= owned then
			return
		end
		invalidated = true
		current = nil
		disconnectLifecycleSignals()
		task.defer(function(): ()
			if not cleanupComplete then
				destroyRealized()
			end
			if cleanupComplete and current == nil then
				currentReconcile = nil
			end
		end)
	end

	local function reconcileExternalLifecycle(): boolean
		if tearingDown then
			return false
		end
		if not invalidated then
			if current ~= owned then
				return true
			end
			if realized.model.Parent == expectedParent then
				return false
			end
			invalidated = true
			current = nil
			disconnectLifecycleSignals()
		end
		if not cleanupComplete then
			destroyRealized()
		end
		return cleanupComplete
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
		reconcileExternalLifecycle()
		if current ~= owned or invalidated then
			return
		end
		destroyRealized()
		disconnectLifecycleSignals()
		invalidated = true
		if current == owned then
			current = nil
		end
		if currentReconcile == reconcileExternalLifecycle then
			currentReconcile = nil
		end
	end
	return table.freeze(owned), reconcileExternalLifecycle
end

function PhysicsLabStudioHarness.start(parent: Instance?): RealizedLab
	assertStudioServer()
	reconcileCurrent()
	assert(current == nil, "Physics Lab Studio harness already owns a realized lab")
	local realized = PhysicsLabRealizer.realize(parent or workspace)
	local owned, reconcile = bindOwnedHandle(realized)
	current = owned
	currentReconcile = reconcile
	return owned
end

function PhysicsLabStudioHarness.get(): RealizedLab?
	assertStudioServer()
	reconcileCurrent()
	return current
end

function PhysicsLabStudioHarness.stop(): ()
	assertStudioServer()
	reconcileCurrent()
	local active = current
	if active == nil then
		return
	end
	active.destroy()
	current = nil
	currentReconcile = nil
end

function PhysicsLabStudioHarness.restart(parent: Instance?): RealizedLab
	assertStudioServer()
	reconcileCurrent()
	PhysicsLabStudioHarness.stop()
	return PhysicsLabStudioHarness.start(parent)
end

return table.freeze(PhysicsLabStudioHarness)
