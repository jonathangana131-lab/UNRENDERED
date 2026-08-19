local fs = require("@lune/fs")

local HARNESS_SOURCE = "src/server/PhysicsLab/PhysicsLabStudioHarness.luau"

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

	local source = fs.readFile(HARNESS_SOURCE)
	local function position(needle: string, init: number?): number?
		return string.find(source, needle, init or 1, true)
	end

	local policy = position("parent == nil or parent == workspace")
	local workspaceReturn = position("return workspace")
	local startFunction = position("function PhysicsLabStudioHarness.start")
	local startPreflight = position("local targetParent = resolveWorkspaceParent(parent)", startFunction)
	local startRealize = position("local realized = PhysicsLabRealizer.realize(targetParent)", startFunction)
	local restartFunction = position("function PhysicsLabStudioHarness.restart")
	local restartPreflight = position("local targetParent = resolveWorkspaceParent(parent)", restartFunction)
	local restartStop = position("PhysicsLabStudioHarness.stop()", restartFunction)
	local restartStart = position("return PhysicsLabStudioHarness.start(targetParent)", restartFunction)

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
		position("PhysicsLabRealizer.realize(parent", startFunction) == nil
			and position("PhysicsLabRealizer.realize(parent or workspace", startFunction) == nil
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
	expect("legacy arbitrary-parent fallback is absent", position("parent or workspace") == nil)

	return failures
end

return run
