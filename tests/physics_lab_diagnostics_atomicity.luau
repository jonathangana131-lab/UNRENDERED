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
	local function position(needle: string, init: number?): number?
		return string.find(source, needle, init or 1, true)
	end

	local enableStart =
		position("function PhysicsLabStudioDiagnostics.enable(lab: PhysicsLabRealizer.RealizedLab): Snapshot")
	local enableEnd = enableStart and position("\nfunction PhysicsLabStudioDiagnostics.disable", enableStart)
		or nil
	local enableSource = if enableStart ~= nil and enableEnd ~= nil
		then string.sub(source, enableStart, enableEnd - 1)
		else ""
	local enablePreflight = string.find(enableSource, "local plans = preflightReadouts(lab, model)", 1, true)
	local enableTransaction =
		string.find(enableSource, "local ok, result = pcall(function(): Snapshot", 1, true)
	local enableCapture =
		string.find(enableSource, "return PhysicsLabStudioDiagnostics.capture(lab)", 1, true)
	local yieldAfterPreflight = if enablePreflight ~= nil
		then string.find(enableSource, ":Wait(", enablePreflight, true)
		else nil
	local taskYieldAfterPreflight = if enablePreflight ~= nil
		then string.find(enableSource, "task.wait(", enablePreflight, true)
		else nil

	local disableStart = position(
		"function PhysicsLabStudioDiagnostics.disable(lab: PhysicsLabRealizer.RealizedLab): Snapshot"
	)
	local disableEnd = disableStart
			and position("\nfunction PhysicsLabStudioDiagnostics.runToggleEvidence", disableStart)
		or nil
	local disableSource = if disableStart ~= nil and disableEnd ~= nil
		then string.sub(source, disableStart, disableEnd - 1)
		else ""
	local disableOptionalGuard = string.find(disableSource, "if folder ~= nil then", 1, true)
	local disableDestroy = string.find(disableSource, "folder:Destroy()", 1, true)
	local disableCapture =
		string.find(disableSource, "local snapshot = PhysicsLabStudioDiagnostics.capture(lab)", 1, true)
	local disablePostcondition =
		string.find(disableSource, "not snapshot.enabled and snapshot.diagnosticInstanceCount == 0", 1, true)

	local preflight = position("local plans = preflightReadouts(lab, model)")
	local transaction = position("local ok, result = pcall(function(): Snapshot")
	local rootName = position("folder.Name = DIAGNOSTICS_ROOT_NAME")
	local rootOwnership = position('folder:SetAttribute("UNRENDERED_PhysicsLabDiagnosticsOwned", true)')
	local parentMutation = position("folder.Parent = model")
	local billboardOwnership = position("billboard.Parent = folder")
	local billboardConfiguration = position("billboard.AlwaysOnTop = true")
	local labelOwnership = position("label.Parent = billboard")
	local labelConfiguration = position("label.BackgroundTransparency = 0.2")
	local capture = position("return PhysicsLabStudioDiagnostics.capture(lab)")
	local transactionEnd = position("\tend)\n\n\tif not ok then")
	local rollback = position("folder:Destroy()")
	local propagate = position("error(result, 0)")

	expect(
		"all readout dependencies are preflighted before the owned root is parented",
		preflight ~= nil and parentMutation ~= nil and preflight < parentMutation
	)
	expect(
		"Instance realization begins inside a protected transaction",
		transaction ~= nil and parentMutation ~= nil and transaction < parentMutation
	)
	expect(
		"authority preflight reaches protected capture without yielding",
		enablePreflight ~= nil
			and enableTransaction ~= nil
			and enableCapture ~= nil
			and enablePreflight < enableTransaction
			and enableTransaction < enableCapture
			and yieldAfterPreflight == nil
			and taskYieldAfterPreflight == nil
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
	expect(
		"force-off cleanup remains idempotent and verifies the disabled baseline",
		disableOptionalGuard ~= nil
			and disableDestroy ~= nil
			and disableCapture ~= nil
			and disablePostcondition ~= nil
			and disableOptionalGuard < disableDestroy
			and disableDestroy < disableCapture
			and disableCapture < disablePostcondition
	)

	return failures
end

return run
