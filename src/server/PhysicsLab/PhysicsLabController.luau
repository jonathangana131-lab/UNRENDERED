--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("UNRENDERED")
local PhysicsLabRecipe = require(Shared.Physics.PhysicsLabRecipe)
local PhysicsLabRuntime = require(Shared.Physics.PhysicsLabRuntime)
local PhysicsLabRealizer = require(script.Parent.PhysicsLabRealizer)

local PhysicsLabController = {}

type PolicyInputs = PhysicsLabRuntime.PolicyInputs
type PlainData = PhysicsLabRuntime.PlainData
type Runtime = PhysicsLabRuntime.Runtime
type Snapshot = PhysicsLabRuntime.Snapshot
type WorldEntityRecord = PhysicsLabRuntime.WorldEntityRecord

type Session = {
	recipe: PhysicsLabRecipe.Recipe,
	runtime: Runtime,
	root: Folder,
}

local current: Session? = nil

local function assertOwnedRoot(instance: Instance): ()
	assert(
		instance:GetAttribute("UNRENDEREDPhysicsLabOwned") == true,
		`refusing to destroy unrelated Workspace content named {PhysicsLabRealizer.ModelName}`
	)
end

local function syncRecordDiagnostics(root: Folder, record: WorldEntityRecord): ()
	local matched = false
	for _, child in ipairs(root:GetChildren()) do
		if child:GetAttribute("WorldEntityId") == record.id then
			matched = true
			child:SetAttribute("Fidelity", record.fidelity)
			child:SetAttribute("StateRevision", record.stateRevision)
			child:SetAttribute("RepresentationRevision", record.representationRevision)
			child:SetAttribute("FidelityAuthority", "PhysicsLabRuntime")
			for _, descendant in ipairs(child:GetDescendants()) do
				if descendant:GetAttribute("WorldEntityId") == record.id then
					descendant:SetAttribute("Fidelity", record.fidelity)
					descendant:SetAttribute("StateRevision", record.stateRevision)
					descendant:SetAttribute("RepresentationRevision", record.representationRevision)
					descendant:SetAttribute("FidelityAuthority", "PhysicsLabRuntime")
				end
			end
		end
	end
	assert(matched, `Physics Lab representation missing WorldEntityId {record.id}`)
end

local function syncAllDiagnostics(session: Session): ()
	for _, element in ipairs(session.recipe.elements) do
		syncRecordDiagnostics(session.root, session.runtime:getRecord(element.entity.id))
	end
	local snapshot = session.runtime:snapshot()
	session.root:SetAttribute("AuthoritativeEntityCount", snapshot.registered)
	session.root:SetAttribute("FidelityRegisteredCount", snapshot.fidelity.registered)
	session.root:SetAttribute("DuplicateIdentityCount", snapshot.duplicateIdentities)
end

function PhysicsLabController.stop(): ()
	local session = current
	if session == nil then
		return
	end
	current = nil

	if session.root.Parent ~= nil then
		assertOwnedRoot(session.root)
		session.root:Destroy()
	end
	session.runtime:dispose()
end

function PhysicsLabController.start(parent: Instance): Folder
	PhysicsLabController.stop()

	local preexisting = parent:FindFirstChild(PhysicsLabRealizer.ModelName)
	if preexisting ~= nil then
		assertOwnedRoot(preexisting)
		preexisting:Destroy()
	end

	local recipe = PhysicsLabRecipe.build()
	local runtime = PhysicsLabRuntime.new(recipe)
	local realizedOk, realizedOrError = pcall(function()
		return PhysicsLabRealizer.realize(recipe, parent)
	end)
	if not realizedOk then
		runtime:dispose()
		error(realizedOrError)
	end

	local root = realizedOrError :: Folder
	root:SetAttribute("UNRENDEREDPhysicsLabOwned", true)
	local session: Session = {
		recipe = recipe,
		runtime = runtime,
		root = root,
	}
	current = session
	syncAllDiagnostics(session)
	return root
end

function PhysicsLabController.step(
	entityId: string,
	inputs: PolicyInputs,
	nowSeconds: number,
	captureState: ((WorldEntityRecord) -> PlainData)?
): PhysicsLabRuntime.StepResult
	local session = current
	assert(session ~= nil, "Physics Lab is not running")
	local result, record = session.runtime:step(entityId, inputs, nowSeconds, captureState)
	syncRecordDiagnostics(session.root, record)
	return result
end

function PhysicsLabController.snapshot(): Snapshot
	local session = current
	assert(session ~= nil, "Physics Lab is not running")
	return session.runtime:snapshot()
end

return table.freeze(PhysicsLabController)
