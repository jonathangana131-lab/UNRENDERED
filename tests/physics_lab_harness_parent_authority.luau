local fs = require("@lune/fs")

local HARNESS_SOURCE = "src/server/PhysicsLab/PhysicsLabStudioHarness.luau"
local VALIDATION_SOURCE = "src/server/PhysicsLab/PhysicsLabValidation.luau"

local function run(): number
	local failures = 0

	local function expect(name: string, condition: boolean)
		if not condition then
			failures += 1
			print(`FAIL physics-lab-parent-authority {name}`)
		else
			print(`PASS physics-lab-parent-authority {name}`)
		end
	end

	local harnessSource = fs.readFile(HARNESS_SOURCE)
	local validationSource = fs.readFile(VALIDATION_SOURCE)
	local function position(source: string, needle: string, init: number?): number?
		return string.find(source, needle, init or 1, true)
	end

	local policy = position(harnessSource, "parent == nil or parent == workspace")
	local workspaceReturn = position(harnessSource, "return workspace")
	local placementPolicy = position(harnessSource, "lab.model.Parent == workspace")
	local startFunction = position(harnessSource, "function PhysicsLabStudioHarness.start")
	local startPreflight = position(harnessSource, "local targetParent = resolveWorkspaceParent(parent)", startFunction)
	local startRealize = position(harnessSource, "local realized = PhysicsLabRealizer.realize(targetParent)", startFunction)
	local getFunction = position(harnessSource, "function PhysicsLabStudioHarness.get")
	local getPlacement = position(harnessSource, "assertCanonicalPlacement(active)", getFunction)
	local getReturn = position(harnessSource, "return active", getFunction)
	local restartFunction = position(harnessSource, "function PhysicsLabStudioHarness.restart")
	local restartPreflight = position(harnessSource, "local targetParent = resolveWorkspaceParent(parent)", restartFunction)
	local restartStop = position(harnessSource, "PhysicsLabStudioHarness.stop()", restartFunction)
	local restartStart = position(harnessSource, "return PhysicsLabStudioHarness.start(targetParent)", restartFunction)

	expect(
		"placement policy accepts only omitted parent or Workspace",
		policy ~= nil and workspaceReturn ~= nil and policy < workspaceReturn
	)
	expect(
		"start resolves the approved parent before physical realization",
		startFunction ~= nil
			and startPreflight ~= nil
			and startRealize ~= nil
			and startFunction < startPreflight
			and startPreflight < startRealize
	)
	expect(
		"start never forwards the caller parent directly to the realizer",
		position(harnessSource, "PhysicsLabRealizer.realize(parent", startFunction) == nil
			and position(harnessSource, "PhysicsLabRealizer.realize(parent or workspace", startFunction) == nil
	)
	expect("harness owns a live canonical Workspace placement assertion", placementPolicy ~= nil)
	expect(
		"get rejects a drifted owned lab before returning its handle",
		getFunction ~= nil
			and getPlacement ~= nil
			and getReturn ~= nil
			and getFunction < getPlacement
			and getPlacement < getReturn
	)
	expect(
		"restart rejects an invalid parent before tearing down the owned lab",
		restartFunction ~= nil
			and restartPreflight ~= nil
			and restartStop ~= nil
			and restartPreflight < restartStop
	)
	expect(
		"restart reuses the validated Workspace parent",
		restartPreflight ~= nil
			and restartStart ~= nil
			and restartStop ~= nil
			and restartPreflight < restartStop
			and restartStop < restartStart
	)
	expect("legacy arbitrary-parent fallback is absent", position(harnessSource, "parent or workspace") == nil)

	local workspaceRootFunction = position(validationSource, "local function assertCanonicalWorkspaceRoot")
	local validationParent = position(validationSource, "root.Parent == workspace", workspaceRootFunction)
	local workspaceScan = position(validationSource, "for _, child in ipairs(workspace:GetChildren()) do", workspaceRootFunction)
	local competingRoot = position(validationSource, "child == root", workspaceRootFunction)
	local exactlyOneRoot = position(validationSource, "matchingRootCount == 1", workspaceRootFunction)
	local captureFunction = position(validationSource, "local function captureInternal")
	local capturePlacement = position(validationSource, "assertCanonicalWorkspaceRoot(model)", captureFunction)
	local captureRecipe = position(validationSource, "local recipe = PhysicsLabRecipe.build()", captureFunction)

	expect(
		"validation requires the permanent root to remain a direct Workspace child",
		workspaceRootFunction ~= nil and validationParent ~= nil and workspaceRootFunction < validationParent
	)
	expect(
		"validation rejects competing canonical Workspace roots",
		workspaceScan ~= nil
			and competingRoot ~= nil
			and exactlyOneRoot ~= nil
			and workspaceScan < competingRoot
			and competingRoot < exactlyOneRoot
	)
	expect(
		"capture validates Workspace authority before canonical recipe evidence",
		captureFunction ~= nil
			and capturePlacement ~= nil
			and captureRecipe ~= nil
			and captureFunction < capturePlacement
			and capturePlacement < captureRecipe
	)

	return failures
end

return run
