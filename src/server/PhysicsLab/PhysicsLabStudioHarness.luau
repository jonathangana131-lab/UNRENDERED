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

local function resolveWorkspaceParent(parent: Instance?): Workspace
	assert(
		parent == nil or parent == workspace,
		"Physics Lab Studio harness may only realize the permanent lab under Workspace"
	)
	return workspace
end

local function assertCanonicalPlacement(lab: RealizedLab): ()
	assert(
		lab.model.Parent == workspace,
		"Physics Lab Studio harness owned lab left the canonical Workspace root"
	)
end

function PhysicsLabStudioHarness.start(parent: Instance?): RealizedLab
	assertStudioServer()
	local targetParent = resolveWorkspaceParent(parent)
	assert(current == nil, "Physics Lab Studio harness already owns a realized lab")
	local realized = PhysicsLabRealizer.realize(targetParent)
	current = realized
	return realized
end

function PhysicsLabStudioHarness.get(): RealizedLab?
	assertStudioServer()
	local active = current
	if active ~= nil then
		assertCanonicalPlacement(active)
	end
	return active
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
	local targetParent = resolveWorkspaceParent(parent)
	local active = current
	if active ~= nil then
		assertCanonicalPlacement(active)
	end
	PhysicsLabStudioHarness.stop()
	return PhysicsLabStudioHarness.start(targetParent)
end

return table.freeze(PhysicsLabStudioHarness)
