local fs = require("@lune/fs")

local function sliceFunction(source: string, signature: string, nextSignature: string): string?
	local startIndex = source:find(signature, 1, true)
	if startIndex == nil then
		return nil
	end
	local nextIndex = source:find(nextSignature, startIndex + #signature, true)
	if nextIndex == nil then
		return nil
	end
	return source:sub(startIndex, nextIndex - 1)
end

local function containsInOrder(source: string, tokens: { string }): boolean
	local cursor = 1
	for _, token in ipairs(tokens) do
		local startIndex, endIndex = source:find(token, cursor, true)
		if startIndex == nil or endIndex == nil then
			return false
		end
		cursor = endIndex + 1
	end
	return true
end

local function run(): number
	local failures = 0

	local function expect(name: string, condition: boolean)
		if condition then
			print(`PASS authority-teardown {name}`)
		else
			failures += 1
			print(`FAIL authority-teardown {name}`)
		end
	end

	local serverBootstrap = fs.readFile("src/server/Bootstrap.server.luau")
	local harnessSource = fs.readFile("src/server/PhysicsLab/PhysicsLabStudioHarness.luau")

	local authorityGuardBody = sliceFunction(
		harnessSource,
		"local function assertStudioServer(): ()",
		"local function bindOwnedHandle(realized: RealizedLab): RealizedLab"
	)
	expect("Studio/server authority helper remains discoverable", authorityGuardBody ~= nil)
	if authorityGuardBody ~= nil then
		expect(
			"Studio/server authority helper preserves both execution-context fences",
			containsInOrder(authorityGuardBody, {
				'assert(RunService:IsStudio(), "PhysicsLabStudioHarness is Studio-only validation tooling")',
				'assert(RunService:IsServer(), "PhysicsLabStudioHarness must run on the server")',
			})
		)
	end

	expect(
		"server context guard gates Studio lab startup",
		containsInOrder(serverBootstrap, {
			'assert(RunService:IsServer(), "server bootstrap must run on server")',
			"if RunService:IsStudio() then",
			"PhysicsLabStudioHarness.start(workspace)",
		})
	)

	local bindBody = sliceFunction(
		harnessSource,
		"local function bindOwnedHandle(realized: RealizedLab): RealizedLab",
		"function PhysicsLabStudioHarness.start(parent: Instance?): RealizedLab"
	)
	expect("Studio harness ownership wrapper remains discoverable", bindBody ~= nil)
	if bindBody ~= nil then
		expect(
			"owned handle binds lifecycle signals before publishing coordinated destroy authority",
			containsInOrder(bindBody, {
				"local owned: RealizedLab = table.clone(realized)",
				"local expectedParent = realized.model.Parent",
				"local tearingDown = false",
				"local invalidated = false",
				"local function invalidateExternalLifecycle(): ()",
				"if tearingDown or invalidated or current ~= owned then",
				"invalidated = true",
				"current = nil",
				"disconnectLifecycleSignals()",
				"task.defer(function(): ()",
				"realized.destroy()",
				"destroyingConnection = realized.model.Destroying:Connect(function(): ()",
				"invalidateExternalLifecycle()",
				"ancestryConnection = realized.model.AncestryChanged:Connect(function(): ()",
				"if realized.model.Parent ~= expectedParent then",
				"invalidateExternalLifecycle()",
			})
		)
		expect(
			"controlled destroy fences lifecycle callbacks and tears down before releasing ownership",
			containsInOrder(bindBody, {
				"owned.destroy = function(): ()",
				"assertStudioServer()",
				"if current ~= owned or invalidated then",
				"return",
				"tearingDown = true",
				"realized.destroy()",
				"tearingDown = false",
				"disconnectLifecycleSignals()",
				"if current == owned then",
				"current = nil",
				"return table.freeze(owned)",
			})
		)
	end

	local startBody = sliceFunction(
		harnessSource,
		"function PhysicsLabStudioHarness.start(parent: Instance?): RealizedLab",
		"function PhysicsLabStudioHarness.get(): RealizedLab?"
	)
	expect("Studio harness start function remains discoverable", startBody ~= nil)
	if startBody ~= nil then
		expect(
			"start fails closed before creating a second canonical lab and publishes only the owned handle",
			containsInOrder(startBody, {
				"assertStudioServer()",
				'assert(current == nil, "Physics Lab Studio harness already owns a realized lab")',
				"local realized = PhysicsLabRealizer.realize(parent or workspace)",
				"local owned = bindOwnedHandle(realized)",
				"current = owned",
				"return owned",
			})
		)
		expect("start does not return the raw RealizedLab", startBody:find("return realized", 1, true) == nil)
	end

	local getBody = sliceFunction(
		harnessSource,
		"function PhysicsLabStudioHarness.get(): RealizedLab?",
		"function PhysicsLabStudioHarness.stop(): ()"
	)
	expect("Studio harness get function remains discoverable", getBody ~= nil)
	if getBody ~= nil then
		expect(
			"get returns only the harness-owned coordinated handle",
			containsInOrder(getBody, { "assertStudioServer()", "return current" })
		)
	end

	local stopBody = sliceFunction(
		harnessSource,
		"function PhysicsLabStudioHarness.stop(): ()",
		"function PhysicsLabStudioHarness.restart(parent: Instance?): RealizedLab"
	)
	expect("Studio harness stop function remains discoverable", stopBody ~= nil)
	if stopBody ~= nil then
		expect(
			"stop is idempotent and destroys before releasing ownership",
			containsInOrder(stopBody, {
				"assertStudioServer()",
				"local active = current",
				"if active == nil then",
				"return",
				"active.destroy()",
				"current = nil",
			})
		)
	end

	local restartBody = sliceFunction(
		harnessSource,
		"function PhysicsLabStudioHarness.restart(parent: Instance?): RealizedLab",
		"return table.freeze(PhysicsLabStudioHarness)"
	)
	expect("Studio harness restart function remains discoverable", restartBody ~= nil)
	if restartBody ~= nil then
		expect(
			"restart tears down the owned lab before reacquiring one",
			containsInOrder(restartBody, {
				"assertStudioServer()",
				"PhysicsLabStudioHarness.stop()",
				"return PhysicsLabStudioHarness.start(parent)",
			})
		)
	end

	return failures
end

return run
