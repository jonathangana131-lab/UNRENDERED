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
		"function PhysicsLabStudioHarness.start(parent: Instance?): RealizedLab"
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

	local startBody = sliceFunction(
		harnessSource,
		"function PhysicsLabStudioHarness.start(parent: Instance?): RealizedLab",
		"function PhysicsLabStudioHarness.get(): RealizedLab?"
	)
	expect("Studio harness start function remains discoverable", startBody ~= nil)
	if startBody ~= nil then
		expect(
			"start fails closed before creating a second canonical lab",
			containsInOrder(startBody, {
				"assertStudioServer()",
				'assert(current == nil, "Physics Lab Studio harness already owns a realized lab")',
				"PhysicsLabRealizer.realize(parent or workspace)",
				"current = realized",
				"return realized",
			})
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
