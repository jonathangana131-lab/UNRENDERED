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
	representations: { [string]: Instance },
}

local current: Session? = nil

local function assertOwnedRoot(instance: Instance): ()
	assert(
		instance:GetAttribute(PhysicsLabRealizer.OwnershipAttribute) == true,
		`refusing to destroy unrelated Workspace content named {PhysicsLabRealizer.ModelName}`
	)
end

local function syncInstanceDiagnostics(target: Instance, record: WorldEntityRecord): ()
	target:SetAttribute("Fidelity", record.fidelity)
	target:SetAttribute("StateRevision", record.stateRevision)
	target:SetAttribute("RepresentationRevision", record.representationRevision)
	target:SetAttribute("FidelityAuthority", "PhysicsLabRuntime")

	if target:IsA("BasePart") then
		local billboard = target:FindFirstChild("UNRENDERED_Diagnostic")
		if billboard ~= nil then
			local label = billboard:FindFirstChild("Label")
			if label ~= nil and label:IsA("TextLabel") then
				label.Text = `{record.origin.recipeKey} | {record.fidelity}\n{record.id}`
			end
		end
	end
end

local function syncRecordDiagnostics(session: Session, record: WorldEntityRecord): ()
	local representation = session.representations[record.id]
	assert(representation ~= nil, `Physics Lab representation missing WorldEntityId {record.id}`)
	assert(
		representation:GetAttribute("WorldEntityId") == record.id,
		`Physics Lab representation identity drifted for {record.id}`
	)

	syncInstanceDiagnostics(representation, record)
	for _, descendant in ipairs(representation:GetDescendants()) do
		if descendant:GetAttribute("WorldEntityId") == record.id then
			syncInstanceDiagnostics(descendant, record)
		end
	end
end

local function syncAllDiagnostics(session: Session): ()
	for _, element in ipairs(session.recipe.elements) do
		syncRecordDiagnostics(session, session.runtime:getRecord(element.entity.id))
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

	local recipe = PhysicsLabRecipe.build()
	local runtime = PhysicsLabRuntime.new(recipe)
	local realizedOk, realizedOrError, representationResult = pcall(function()
		return PhysicsLabRealizer.realize(recipe, parent)
	end)
	if not realizedOk then
		runtime:dispose()
		error(realizedOrError)
	end

	local root = realizedOrError :: Folder
	local representations = representationResult :: { [string]: Instance }
	assertOwnedRoot(root)
	local session: Session = {
		recipe = recipe,
		runtime = runtime,
		root = root,
		representations = representations,
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
	syncRecordDiagnostics(session, record)
	return result
end

function PhysicsLabController.snapshot(): Snapshot
	local session = current
	assert(session ~= nil, "Physics Lab is not running")
	return session.runtime:snapshot()
end

return table.freeze(PhysicsLabController)
