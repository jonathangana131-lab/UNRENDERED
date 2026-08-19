--!strict

local FidelityManager = require("../src/shared/Physics/FidelityManager")

local function run(): number
	local failures = 0

	local function expect(name: string, condition: boolean, detail: string): ()
		if condition then
			print(`PASS fidelity-private-state {name}`)
		else
			failures += 1
			print(`FAIL fidelity-private-state {name}: {detail}`)
		end
	end

	local config = table.clone(FidelityManager.defaultConfig())
	config.maxRegisteredEntities = 1
	local manager = FidelityManager.new(config)
	local unsafeManager = manager :: any

	expect(
		"mutable states are not exposed on facade",
		unsafeManager._states == nil,
		"manager facade exposes live _states storage"
	)
	expect(
		"mutable metrics are not exposed on facade",
		unsafeManager._metrics == nil,
		"manager facade exposes live _metrics storage"
	)

	local metricsInjectionAccepted = pcall(function()
		unsafeManager._metrics = {
			registered = 0,
		}
	end)
	expect(
		"facade rejects metrics injection",
		not metricsInjectionAccepted,
		"caller assigned a replacement _metrics table"
	)

	local stateInjectionAccepted = pcall(function()
		unsafeManager._states = {}
	end)
	expect(
		"facade rejects state injection",
		not stateInjectionAccepted,
		"caller assigned a replacement _states table"
	)

	local replacementConfig = table.clone(FidelityManager.defaultConfig())
	replacementConfig.maxRegisteredEntities = 2
	local configRebindAccepted = pcall(function()
		unsafeManager.config = replacementConfig
	end)
	expect(
		"facade rejects config rebinding",
		not configRebindAccepted,
		"caller rebound manager config after construction"
	)
	expect(
		"accepted config remains authoritative",
		manager.config.maxRegisteredEntities == 1,
		`expected capacity 1, got {manager.config.maxRegisteredEntities}`
	)

	manager:register("entity:private-state-a", "F0")
	local overCapacityAccepted = pcall(function()
		manager:register("entity:private-state-b", "F0")
	end)
	expect(
		"private accounting keeps registration capacity enforced",
		not overCapacityAccepted,
		"second registration bypassed configured capacity"
	)

	local metrics = manager:getMetrics()
	expect(
		"private registration count remains coherent",
		metrics.registered == 1,
		`expected one registered entity, got {metrics.registered}`
	)
	expect(
		"capacity rejection remains observable",
		metrics.registrationCapacityRejections == 1,
		`expected one rejection, got {metrics.registrationCapacityRejections}`
	)
	expect(
		"private fidelity counts remain coherent",
		metrics.counts.F0 == 1,
		`expected one F0 entity, got {metrics.counts.F0}`
	)

	local managerMetatable = getmetatable(manager)
	assert(type(managerMetatable) == "table", "manager metatable must remain available for method dispatch")
	local forged: any = setmetatable({ config = manager.config }, managerMetatable :: any)
	local forgedAccessAccepted = pcall(function()
		forged:getMetrics()
	end)
	expect(
		"forged facade lacks private capability",
		not forgedAccessAccepted,
		"metatable-only forgery accessed another manager's state"
	)

	return failures
end

return run
