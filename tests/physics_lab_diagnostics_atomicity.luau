local fs = require("@lune/fs")

local DIAGNOSTICS_SOURCE = "src/server/PhysicsLab/PhysicsLabStudioDiagnostics.luau"

local function run(): number
	local failures = 0

	local function expect(name: string, condition: boolean)
		if not condition then
			failures += 1
			print(`FAIL diagnostics-atomicity {name}`)
		else
			print(`PASS diagnostics-atomicity {name}`)
		end
	end

	local source = fs.readFile(DIAGNOSTICS_SOURCE)
	local function position(needle: string): number?
		return string.find(source, needle, 1, true)
	end

	local preflight = position("local plans = preflightReadouts(lab, model)")
	local transaction = position("local ok, result = pcall(function(): Snapshot")
	local rootName = position("folder.Name = DIAGNOSTICS_ROOT_NAME")
	local rootOwnership = position('folder:SetAttribute("UNRENDERED_PhysicsLabDiagnosticsOwned", true)')
	local parentMutation = position("folder.Parent = model")
	local billboardOwnership = position("billboard.Parent = folder")
	local billboardConfiguration = position("billboard.AlwaysOnTop = true")
	local labelOwnership = position("label.Parent = billboard")
	local labelConfiguration = position("label.BackgroundTransparency = 0.2")
	local stateRevisionPlan = position("stateRevision = record.stateRevision")
	local representationRevisionPlan = position("representationRevision = record.representationRevision")
	local renderedRevisionLine = position("stateRevision=%d | representationRevision=%d")
	local renderedStateRevision = position("plan.stateRevision,")
	local renderedRepresentationRevision = position("plan.representationRevision,")
	local capture = position("return PhysicsLabStudioDiagnostics.capture(lab)")
	local transactionEnd = position("\tend)\n\n\tif not ok then")
	local rollback = position("folder:Destroy()")
	local propagate = position("error(result, 0)")

	expect(
		"all readout dependencies are preflighted before the owned root is parented",
		preflight ~= nil and parentMutation ~= nil and preflight < parentMutation
	)
	expect(
		"authoritative revisions are captured into readout plans before Instance mutation",
		stateRevisionPlan ~= nil
			and representationRevisionPlan ~= nil
			and parentMutation ~= nil
			and stateRevisionPlan < parentMutation
			and representationRevisionPlan < parentMutation
	)
	expect(
		"Instance realization begins inside a protected transaction",
		transaction ~= nil and parentMutation ~= nil and transaction < parentMutation
	)
	expect(
		"diagnostics root identity is established inside the transaction before parenting",
		transaction ~= nil
			and rootName ~= nil
			and rootOwnership ~= nil
			and parentMutation ~= nil
			and transaction < rootName
			and rootName < rootOwnership
			and rootOwnership < parentMutation
	)
	expect(
		"BillboardGui is owned before fallible configuration",
		billboardOwnership ~= nil
			and billboardConfiguration ~= nil
			and billboardOwnership < billboardConfiguration
	)
	expect(
		"TextLabel is owned before fallible configuration",
		labelOwnership ~= nil and labelConfiguration ~= nil and labelOwnership < labelConfiguration
	)
	expect(
		"visible diagnostics readouts render authoritative state and representation revisions",
		renderedRevisionLine ~= nil
			and renderedStateRevision ~= nil
			and renderedRepresentationRevision ~= nil
			and renderedRevisionLine < renderedStateRevision
			and renderedStateRevision < renderedRepresentationRevision
	)
	expect(
		"post-realization capture remains inside the protected transaction",
		capture ~= nil
			and transaction ~= nil
			and transactionEnd ~= nil
			and transaction < capture
			and capture < transactionEnd
	)
	expect(
		"failed realization destroys the owned diagnostics tree before propagating",
		rollback ~= nil
			and propagate ~= nil
			and transactionEnd ~= nil
			and transactionEnd < rollback
			and rollback < propagate
	)

	return failures
end

return run
