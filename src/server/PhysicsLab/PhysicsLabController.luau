--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("UNRENDERED")
local PhysicsLabRecipe = require(Shared.Physics.PhysicsLabRecipe)
local PhysicsLabRuntime = require(Shared.Physics.PhysicsLabRuntime)
local PhysicsLabRealizer = require(script.Parent.PhysicsLabRealizer)

local PhysicsLabController = {}

type Runtime = PhysicsLabRuntime.Runtime
type Snapshot = PhysicsLabRuntime.Snapshot
type WorldEntityRecord = PhysicsLabRuntime.WorldEntityRecord
type RealizedLab = PhysicsLabRealizer.RealizedLab

type Session = {
	runtime: Runtime,
	realized: RealizedLab,
}

local current: Session? = nil

local function syncRecordDiagnostics(target: Instance, record: WorldEntityRecord): ()
	assert(
		target:GetAttribute("UNRENDERED_WorldEntityId") == record.id,
		`Physics Lab representation identity drifted for {record.id}`
	)
	target:SetAttribute("UNRENDERED_Fidelity", record.fidelity)
	target:SetAttribute("UNRENDERED_StateRevision", record.stateRevision)
	target:SetAttribute("UNRENDERED_RepresentationRevision", record.representationRevision)
	target:SetAttribute("UNRENDERED_FidelityAuthority", "PhysicsLabRuntime")

	for _, descendant in ipairs(target:GetDescendants()) do
		if descendant:GetAttribute("UNRENDERED_WorldEntityId") == record.id then
			descendant:SetAttribute("UNRENDERED_Fidelity", record.fidelity)
			descendant:SetAttribute("UNRENDERED_StateRevision", record.stateRevision)
			descendant:SetAttribute("UNRENDERED_RepresentationRevision", record.representationRevision)
			descendant:SetAttribute("UNRENDERED_FidelityAuthority", "PhysicsLabRuntime")
		end
	end
end

local function syncDiagnostics(session: Session): ()
	for entityId, representation in pairs(session.realized.representations) do
		syncRecordDiagnostics(representation, session.runtime:getRecord(entityId))
	end

	local snapshot = session.runtime:snapshot()
	local model = session.realized.model
	model:SetAttribute("UNRENDERED_EntityCount", snapshot.registered)
	model:SetAttribute("UNRENDERED_DuplicateIdentityCount", snapshot.duplicateIdentities)
	model:SetAttribute("UNRENDERED_FidelityF0", snapshot.fidelity.counts.F0)
	model:SetAttribute("UNRENDERED_FidelityF1", snapshot.fidelity.counts.F1)
	model:SetAttribute("UNRENDERED_FidelityF2", snapshot.fidelity.counts.F2)
	model:SetAttribute("UNRENDERED_FidelityF3", snapshot.fidelity.counts.F3)
	model:SetAttribute("UNRENDERED_FidelityF4", snapshot.fidelity.counts.F4)
	model:SetAttribute("UNRENDERED_FidelityAuthority", "PhysicsLabRuntime")
end

function PhysicsLabController.stop(): ()
	local session = current
	if session == nil then
		return
	end
	current = nil

	local destroyed, destroyError = pcall(session.realized.destroy)
	session.runtime:dispose()
	if not destroyed then
		error(destroyError)
	end
end

function PhysicsLabController.start(parent: Instance): Model
	PhysicsLabController.stop()

	local recipe = PhysicsLabRecipe.build()
	local runtime = PhysicsLabRuntime.new(recipe)
	local realizedOk, realizedOrError = pcall(function()
		return PhysicsLabRealizer.realize(parent, recipe)
	end)
	if not realizedOk then
		runtime:dispose()
		error(realizedOrError)
	end

	local realized = realizedOrError :: RealizedLab
	local session: Session = {
		runtime = runtime,
		realized = realized,
	}
	current = session
	syncDiagnostics(session)
	return realized.model
end

function PhysicsLabController.snapshot(): Snapshot
	local session = current
	assert(session ~= nil, "Physics Lab is not running")
	return session.runtime:snapshot()
end

return table.freeze(PhysicsLabController)
