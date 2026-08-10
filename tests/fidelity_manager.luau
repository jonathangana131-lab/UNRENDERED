local FidelityManager = require("../src/shared/Physics/FidelityManager")
local WorldEntity = require("../src/shared/Reality/WorldEntity")

local function run(): number
	local failures = 0

	local function expectEqual(name, actual, expected)
		if actual ~= expected then
			failures += 1
			print(`FAIL {name}: expected {tostring(expected)}, got {tostring(actual)}`)
		else
			print(`PASS {name}`)
		end
	end

	local function expectTrue(name, value)
		expectEqual(name, value, true)
	end

	local function expectError(name, callback)
		local ok = pcall(callback)
		expectEqual(name, ok, false)
	end

	local target, reason = FidelityManager.evaluatePolicy({
		distanceStuds = 1000,
		observation = 0,
		interaction = 0,
		significance = 0,
		networkRelevance = 0,
	})
	expectEqual("idle distant entity selects F0", target, "F0")
	expectEqual("idle distant entity reports idle reason", reason, "idle")

	target, reason = FidelityManager.evaluatePolicy({
		distanceStuds = 20,
		observation = 0,
		interaction = 0,
		significance = 0,
		networkRelevance = 0,
	})
	expectEqual("near entity selects F3", target, "F3")
	expectEqual("near entity reports distance reason", reason, "distance")

	target, reason = FidelityManager.evaluatePolicy({
		distanceStuds = 1000,
		observation = 0,
		interaction = 0.85,
		significance = 0,
		networkRelevance = 0,
	})
	expectEqual("active interaction selects F4", target, "F4")
	expectEqual("active interaction reports interaction reason", reason, "interaction")

	target, reason = FidelityManager.evaluatePolicy({
		distanceStuds = 1000,
		observation = 0.85,
		interaction = 0,
		significance = 0.98,
		networkRelevance = 0,
	})
	expectEqual("observed significant entity can select F4", target, "F4")
	expectEqual("observed significant entity reports significance", reason, "significance")

	expectError("policy rejects negative distance", function()
		FidelityManager.evaluatePolicy({
			distanceStuds = -1,
			observation = 0,
			interaction = 0,
			significance = 0,
			networkRelevance = 0,
		})
	end)

	expectError("policy rejects out of range signal", function()
		FidelityManager.evaluatePolicy({
			distanceStuds = 10,
			observation = 1.01,
			interaction = 0,
			significance = 0,
			networkRelevance = 0,
		})
	end)

	local records = {
		["entity:a"] = WorldEntity.new({
			id = "entity:a",
			kind = "office-chair",
			origin = {
				worldId = "world:test",
				generator = "tests.fidelity",
				generatorVersion = 1,
				recipeKey = "chair/a",
			},
			fidelity = "F1",
			persistentState = { wear = 0.25 },
		}),
		["entity:b"] = WorldEntity.new({
			id = "entity:b",
			kind = "filing-cabinet",
			origin = {
				worldId = "world:test",
				generator = "tests.fidelity",
				generatorVersion = 1,
				recipeKey = "cabinet/b",
			},
			fidelity = "F3",
			persistentState = { drawerOpen = false },
		}),
	}
	local captureCount = 0
	local transitionEvents = {}

	local adapter = {
		captureState = function(entityId, from, to, transitionReason)
			captureCount += 1
			table.insert(transitionEvents, `capture:{entityId}:{from}:{to}:{transitionReason}`)
			return {
				capturedFrom = from,
				capturedTo = to,
				reason = transitionReason,
			}
		end,
		transition = function(entityId, from, targetFidelity, capturedState, transitionReason)
			local record = records[entityId]
			assert(record ~= nil, `missing test WorldEntity {entityId}`)
			assert(record.fidelity == from, `manager mirror stale for {entityId}`)
			if capturedState == nil then
				table.insert(
					transitionEvents,
					`transition:{entityId}:{targetFidelity}:{transitionReason}:no-capture`
				)
			else
				table.insert(
					transitionEvents,
					`transition:{entityId}:{targetFidelity}:{transitionReason}:captured`
				)
			end
			records[entityId] = WorldEntity.transition(record, targetFidelity, capturedState)
		end,
	}

	local manager = FidelityManager.new(adapter)
	FidelityManager.track(manager, "entity:a", records["entity:a"].fidelity)
	FidelityManager.track(manager, "entity:b", records["entity:b"].fidelity)

	expectError("untracked requests are rejected", function()
		FidelityManager.request(manager, "entity:missing", "F1", "distance", 0)
	end)

	local metrics = FidelityManager.getMetrics(manager)
	expectEqual("tracking counts entities", metrics.trackedEntities, 2)
	expectEqual("tracking counts F1", metrics.fidelityCounts.F1, 1)
	expectEqual("tracking counts F3", metrics.fidelityCounts.F3, 1)

	local promoted = FidelityManager.request(manager, "entity:a", "F3", "interaction", 0)
	expectEqual("promotion happens immediately", promoted.status, "transitioned")
	expectEqual("promotion reaches WorldEntity target", records["entity:a"].fidelity, "F3")
	expectEqual(
		"promotion increments WorldEntity representation revision",
		records["entity:a"].representationRevision,
		1
	)
	expectEqual("promotion does not capture state", captureCount, 0)

	local promotionBlocked = FidelityManager.request(manager, "entity:a", "F4", "interaction", 0.1)
	expectEqual("promotion cooldown blocks rapid escalation", promotionBlocked.status, "blocked_cooldown")
	expectEqual("blocked promotion preserves fidelity", records["entity:a"].fidelity, "F3")

	local promotionAfterCooldown = FidelityManager.request(manager, "entity:a", "F4", "interaction", 0.25)
	expectEqual("promotion resumes after cooldown", promotionAfterCooldown.status, "transitioned")
	expectEqual("promotion cooldown target applied", records["entity:a"].fidelity, "F4")

	local firstDemotion = FidelityManager.request(manager, "entity:a", "F1", "idle", 1)
	expectEqual("demotion begins hysteresis", firstDemotion.status, "blocked_hysteresis")
	expectEqual("hysteresis does not capture yet", captureCount, 0)

	local changedDemand = FidelityManager.request(manager, "entity:a", "F2", "distance", 2)
	expectEqual("changed demotion demand resets hysteresis", changedDemand.status, "blocked_hysteresis")

	local stillWaiting = FidelityManager.request(manager, "entity:a", "F2", "distance", 3.9)
	expectEqual("demotion waits full grace window", stillWaiting.status, "blocked_hysteresis")

	local demoted = FidelityManager.request(manager, "entity:a", "F2", "distance", 4)
	expectEqual("demotion proceeds after stable demand", demoted.status, "transitioned")
	expectEqual("demotion captures exactly once", captureCount, 1)
	expectEqual("demotion reaches WorldEntity target", records["entity:a"].fidelity, "F2")
	expectEqual("demotion increments WorldEntity state revision", records["entity:a"].stateRevision, 1)
	expectEqual(
		"capture precedes demotion transition",
		transitionEvents[#transitionEvents - 1],
		"capture:entity:a:F4:F2:distance"
	)
	expectEqual(
		"demotion transition receives capture",
		transitionEvents[#transitionEvents],
		"transition:entity:a:F2:distance:captured"
	)

	metrics = FidelityManager.getMetrics(manager)
	expectEqual("metrics count successful transitions", metrics.transitions, 3)
	expectEqual("metrics count promotions", metrics.promotions, 2)
	expectEqual("metrics count demotions", metrics.demotions, 1)
	expectEqual("metrics count captures", metrics.stateCaptures, 1)
	expectTrue("metrics expose cooldown blocks", metrics.cooldownBlocks >= 1)
	expectTrue("metrics expose hysteresis blocks", metrics.hysteresisBlocks >= 3)
	expectEqual("reason metrics count interaction promotions", metrics.reasonCounts.interaction, 2)
	expectEqual("reason metrics count distance demotion", metrics.reasonCounts.distance, 1)
	expectEqual("metrics move entity a into F2", metrics.fidelityCounts.F2, 1)
	expectEqual("metrics leave entity b in F3", metrics.fidelityCounts.F3, 1)

	records["entity:b"] = WorldEntity.transition(records["entity:b"], "F1", { external = true })
	expectTrue(
		"explicit resync accepts authoritative external change",
		FidelityManager.resync(manager, "entity:b", records["entity:b"].fidelity, 5)
	)
	expectTrue(
		"same-fidelity resync is a no-op",
		not FidelityManager.resync(manager, "entity:b", records["entity:b"].fidelity, 5)
	)
	metrics = FidelityManager.getMetrics(manager)
	expectEqual("resync notices external fidelity changes", metrics.externalResyncs, 1)
	expectEqual("resync corrects F1 count", metrics.fidelityCounts.F1, 1)
	expectEqual("resync corrects F3 count", metrics.fidelityCounts.F3, 0)

	expectError("manager rejects time moving backwards", function()
		FidelityManager.request(manager, "entity:a", "F3", "observation", 3)
	end)

	local function runDeterministicSequence(): string
		local record = WorldEntity.new({
			id = "entity:deterministic",
			kind = "test-object",
			origin = {
				worldId = "world:test",
				generator = "tests.fidelity",
				generatorVersion = 1,
				recipeKey = "deterministic/1",
			},
		})
		local localAdapter = {
			captureState = function(_, from, to, transitionReason)
				return { from = from, to = to, reason = transitionReason }
			end,
			transition = function(_, from, targetFidelity, capturedState)
				assert(record.fidelity == from, "deterministic manager mirror stale")
				record = WorldEntity.transition(record, targetFidelity, capturedState)
			end,
		}
		local localManager = FidelityManager.new(localAdapter)
		FidelityManager.track(localManager, "entity:deterministic", record.fidelity)
		local sequence = {
			{
				0,
				{
					distanceStuds = 20,
					observation = 0,
					interaction = 0,
					significance = 0,
					networkRelevance = 0,
				},
			},
			{
				1,
				{
					distanceStuds = 1000,
					observation = 0,
					interaction = 0,
					significance = 0,
					networkRelevance = 0,
				},
			},
			{
				2,
				{
					distanceStuds = 1000,
					observation = 0,
					interaction = 0,
					significance = 0,
					networkRelevance = 0,
				},
			},
			{
				3,
				{
					distanceStuds = 1000,
					observation = 0,
					interaction = 0,
					significance = 0,
					networkRelevance = 0,
				},
			},
			{
				4,
				{
					distanceStuds = 1000,
					observation = 0,
					interaction = 0.9,
					significance = 0,
					networkRelevance = 0,
				},
			},
		}
		local output = {}
		for _, item in ipairs(sequence) do
			local result = FidelityManager.update(localManager, "entity:deterministic", item[2], item[1])
			table.insert(output, `{item[1]}:{result.status}:{result.from}:{result.target}:{result.reason}`)
		end
		local localMetrics = FidelityManager.getMetrics(localManager)
		table.insert(
			output,
			`metrics:{localMetrics.transitions}:{localMetrics.promotions}:{localMetrics.demotions}`
		)
		return table.concat(output, "|")
	end

	expectEqual(
		"identical inputs and timestamps produce identical transition sequence",
		runDeterministicSequence(),
		runDeterministicSequence()
	)

	expectTrue("untrack removes tracked entity", FidelityManager.untrack(manager, "entity:b"))
	expectTrue("untrack reports missing entity", not FidelityManager.untrack(manager, "entity:b"))

	return failures
end

return run
