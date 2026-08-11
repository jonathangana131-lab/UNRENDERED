local fs = require("@lune/fs")

local DIAGNOSTICS_SOURCE = "src/server/PhysicsLab/PhysicsLabStudioDiagnostics.luau"

local function run(): number
	local failures = 0

	local function expect(name: string, condition: boolean)
		if not condition then
			failures += 1
			print(`FAIL diagnostics-readout {name}`)
		else
			print(`PASS diagnostics-readout {name}`)
		end
	end

	local source = fs.readFile(DIAGNOSTICS_SOURCE)
	local function position(needle: string): number?
		return string.find(source, needle, 1, true)
	end

	local helper = position("local function validateReadoutCompleteness(")
	local function helperPosition(needle: string): number?
		if helper == nil then
			return nil
		end
		return string.find(source, needle, helper, true)
	end

	local identityWrite = position('billboard:SetAttribute("UNRENDERED_WorldEntityId", plan.worldEntityId)')
	local directChildren = helperPosition("folder:GetChildren()")
	local billboardClass = helperPosition('child:IsA("BillboardGui")')
	local readoutIdentity = helperPosition('requireStringAttribute(child, "UNRENDERED_WorldEntityId")')
	local expectedMembership = helperPosition("expectedEntityIds[entityId] == true")
	local duplicateGuard = helperPosition("seenEntityIds[entityId] == nil")
	local seenWrite = helperPosition("seenEntityIds[entityId] = true")
	local labelLookup = helperPosition('child:FindFirstChild("Readout")')
	local labelClass = helperPosition('label:IsA("TextLabel")')
	local exactBillboardShape = helperPosition("#child:GetDescendants() == 1")
	local exactEntityCount = helperPosition("readoutCount == #entities")
	local exactInstanceCount = helperPosition("return 1 + 2 * readoutCount")
	local captureCall = position("diagnosticInstanceCount = validateReadoutCompleteness(folder, entities)")
	local descendantCountShortcut = position("diagnosticInstanceCount = 1 + #folder:GetDescendants()")

	expect("each diagnostics billboard carries the canonical WorldEntityId it projects", identityWrite ~= nil)
	expect(
		"capture validates the readout tree through an explicit completeness boundary",
		helper ~= nil and captureCall ~= nil and helper < captureCall
	)
	expect(
		"readout validation enumerates only direct diagnostics-root children",
		directChildren ~= nil
			and billboardClass ~= nil
			and helper < directChildren
			and directChildren < billboardClass
	)
	expect(
		"every readout identity is authoritative and unique",
		readoutIdentity ~= nil
			and expectedMembership ~= nil
			and duplicateGuard ~= nil
			and seenWrite ~= nil
			and readoutIdentity < expectedMembership
			and expectedMembership < duplicateGuard
			and duplicateGuard < seenWrite
	)
	expect(
		"every entity readout has exactly one TextLabel named Readout",
		labelLookup ~= nil
			and labelClass ~= nil
			and exactBillboardShape ~= nil
			and billboardClass < labelLookup
			and labelLookup < labelClass
			and labelClass < exactBillboardShape
	)
	expect(
		"validated readouts form a one-to-one projection of authoritative entities",
		exactEntityCount ~= nil and exactInstanceCount ~= nil and exactEntityCount < exactInstanceCount
	)
	expect(
		"capture cannot bless an arbitrary descendant count as diagnostics completeness",
		descendantCountShortcut == nil
	)

	return failures
end

return run
