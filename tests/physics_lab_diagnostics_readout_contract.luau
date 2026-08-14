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

	local rawSource = fs.readFile(DIAGNOSTICS_SOURCE)
	-- Source-contract tests must not be satisfiable by inactive comments. Strip
	-- ordinary line comments before looking for the active diagnostics contract.
	local source = string.gsub(rawSource, "%-%-[^\n]*", "")
	local function position(needle: string): number?
		return string.find(source, needle, 1, true)
	end

	local helper = position("local function validateReadoutCompleteness(")
	local helperEnd = position("local function captureCanonicalWhileDiagnosticsEnabled(")
	local helperBody = nil
	if helper ~= nil and helperEnd ~= nil and helper < helperEnd then
		helperBody = string.sub(source, helper, helperEnd - 1)
	end
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
	local expectedMembership = helperPosition("expectedEntity ~= nil")
	local duplicateGuard = helperPosition("seenEntityIds[entityId] == nil")
	local exactAdorneeProjection = helperPosition("child.Adornee == expectedEntity.adornee")
	local seenWrite = helperPosition("seenEntityIds[entityId] = true")
	local labelLookup = helperPosition('child:FindFirstChild("Readout")')
	local labelClass = helperPosition('label:IsA("TextLabel")')
	local exactBillboardShape = helperPosition("#child:GetDescendants() == 1")
	local exactTextProjection = helperPosition("label.Text == expectedEntity.text")
	local readoutCountIncrement = helperPosition("readoutCount += 1")
	local exactEntityCount = helperPosition("readoutCount == #entities")
	local exactInstanceCount = helperPosition("return 1 + 2 * readoutCount")
	local billboardEnabledGuard = helperBody ~= nil
		and string.find(helperBody, "assert%s*%(%s*child%.Enabled") ~= nil
	local labelVisibleGuard = helperBody ~= nil
		and string.find(helperBody, "assert%s*%(%s*label%.Visible") ~= nil
	local preflightProjection = position("key = record.origin.recipeKey")
	local captureProjection = position(
		"text = readoutText(record.origin.recipeKey, record.id, record.fidelity, fingerprint, reproKey)"
	)
	local realizationProjection = position(
		"label.Text = readoutText(plan.key, plan.worldEntityId, plan.fidelity, fingerprint, reproKey)"
	)
	local mutableNameProjection = position("key = representation.Name")
	local mutableNameTextProjection = position("readoutText(representation.Name")
	local mutableClassProjection = position('representation:GetAttribute("UNRENDERED_RepresentationClass")')
	local inertClassProjection = position("representationClass = nil")
	local entityIdSort = position('requireStringAttribute(a, "UNRENDERED_WorldEntityId")')
	local mutableNameSort = position("return a.Name < b.Name")
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
		"capture compares each live Adornee to the authoritative represented BasePart",
		exactAdorneeProjection ~= nil
			and expectedMembership ~= nil
			and seenWrite ~= nil
			and expectedMembership < exactAdorneeProjection
			and exactAdorneeProjection < seenWrite
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
		"capture compares displayed text to the exact authoritative readout projection before counting it",
		exactTextProjection ~= nil
			and labelClass ~= nil
			and exactBillboardShape ~= nil
			and readoutCountIncrement ~= nil
			and labelClass < exactBillboardShape
			and exactBillboardShape < exactTextProjection
			and exactTextProjection < readoutCountIncrement
	)
	expect(
		"capture rejects disabled BillboardGui readouts instead of counting invisible diagnostics as complete",
		billboardEnabledGuard
	)
	expect(
		"capture rejects hidden TextLabel readouts instead of counting invisible diagnostics as complete",
		labelVisibleGuard
	)
	expect(
		"realization and capture project the authoritative recipe key through the shared formatter",
		preflightProjection ~= nil
			and captureProjection ~= nil
			and realizationProjection ~= nil
			and mutableNameProjection == nil
			and mutableNameTextProjection == nil
	)
	expect(
		"diagnostics do not publish mutable representation-class attributes as authoritative evidence",
		mutableClassProjection == nil and inertClassProjection ~= nil
	)
	expect(
		"representation ordering is stable by WorldEntityId rather than mutable Instance name",
		entityIdSort ~= nil and mutableNameSort == nil
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
