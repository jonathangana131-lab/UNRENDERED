local FidelityManager = require("../src/shared/Physics/FidelityManager")

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

	local fidelity = "F3"
	local captures = 0
	local adapter = {
		getFidelity = function(_)
			return fidelity
		end,
		captureState = function(_, from, to, reason)
			captures += 1
			return { from = from, to = to, reason = reason }
		end,
		transition = function(_, target, _capturedState, _reason)
			fidelity = target
		end,
	}

	local config = FidelityManager.defaultConfig()
	config.promotionCooldownSeconds = 0
	config.demotionCooldownSeconds = 0
	config.demotionGraceSeconds = 2
	local manager = FidelityManager.new(adapter, config)

	local first = FidelityManager.request(manager, "entity:audit", "F2", "distance", 0)
	expectEqual("target-stable demotion starts hysteresis", first.status, "blocked_hysteresis")
	local changedReason = FidelityManager.request(manager, "entity:audit", "F2", "network", 1)
	expectEqual("reason change does not reset target hysteresis", changedReason.status, "blocked_hysteresis")
	local accepted = FidelityManager.request(manager, "entity:audit", "F2", "observation", 2)
	expectEqual("stable target demotes despite changing reasons", accepted.status, "transitioned")
	expectEqual("stable-target demotion captures once", captures, 1)

	FidelityManager.request(manager, "entity:audit", "F3", "custom:a", 3)
	FidelityManager.request(manager, "entity:audit", "F2", "custom:b", 3)
	FidelityManager.request(manager, "entity:audit", "F2", "custom:c", 5)
	FidelityManager.request(manager, "entity:audit", "F3", "custom:d", 6)
	FidelityManager.request(manager, "entity:audit", "F2", "custom:e", 6)
	FidelityManager.request(manager, "entity:audit", "F2", "custom:f", 8)

	local metrics = FidelityManager.getMetrics(manager)
	expectEqual("custom reasons aggregate into bounded other bucket", metrics.reasonCounts.other, 4)
	expectEqual("built-in reason remains independently counted", metrics.reasonCounts.observation, 1)
	expectEqual("arbitrary reason is not retained as a metric key", metrics.reasonCounts["custom:a"], nil)

	local reasonBucketCount = 0
	for _ in pairs(metrics.reasonCounts) do
		reasonBucketCount += 1
	end
	expectEqual("reason diagnostics have fixed bucket count", reasonBucketCount, 7)
	expectEqual("audit demotions capture state", captures, 3)

	return failures
end

return run
