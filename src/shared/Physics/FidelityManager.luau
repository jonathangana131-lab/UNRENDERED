--!strict

export type Fidelity = "F0" | "F1" | "F2" | "F3" | "F4"

export type PolicyInputs = {
	distanceStuds: number,
	observation: number,
	interaction: number,
	significance: number,
	networkRelevance: number,
}

export type Config = {
	promotionCooldownSeconds: number,
	demotionCooldownSeconds: number,
	demotionGraceSeconds: number,
	distanceF3: number,
	distanceF2: number,
	distanceF1: number,
	observationF3: number,
	observationF2: number,
	observationF1: number,
	interactionF4: number,
	interactionF3: number,
	interactionF2: number,
	interactionF1: number,
	significanceF4: number,
	significanceF3: number,
	significanceF2: number,
	significanceF1: number,
	networkF3: number,
	networkF2: number,
	networkF1: number,
}

export type PersistentState = { [string]: unknown }

export type Adapter = {
	captureState: (entityId: string, from: Fidelity, to: Fidelity, reason: string) -> PersistentState,
	transition: (
		entityId: string,
		from: Fidelity,
		target: Fidelity,
		capturedState: PersistentState?,
		reason: string
	) -> (),
}

export type FidelityCounts = {
	F0: number,
	F1: number,
	F2: number,
	F3: number,
	F4: number,
}

export type ReasonCounts = {
	distance: number,
	observation: number,
	interaction: number,
	significance: number,
	network: number,
	idle: number,
	other: number,
}

export type Metrics = {
	trackedEntities: number,
	fidelityCounts: FidelityCounts,
	transitions: number,
	promotions: number,
	demotions: number,
	stateCaptures: number,
	cooldownBlocks: number,
	hysteresisBlocks: number,
	externalResyncs: number,
	reasonCounts: ReasonCounts,
}

export type TransitionStatus = "unchanged" | "transitioned" | "blocked_hysteresis" | "blocked_cooldown"

export type TransitionResult = {
	status: TransitionStatus,
	entityId: string,
	from: Fidelity,
	target: Fidelity,
	reason: string,
}

export type DebugState = {
	currentFidelity: Fidelity,
	lastTransitionAt: number?,
	lastEvaluationAt: number?,
	pendingDemotionTarget: Fidelity?,
	pendingDemotionSince: number?,
}

type Entry = {
	currentFidelity: Fidelity,
	lastTransitionAt: number?,
	lastEvaluationAt: number?,
	pendingDemotionTarget: Fidelity?,
	pendingDemotionSince: number?,
}

type InternalMetrics = {
	trackedEntities: number,
	fidelityCounts: FidelityCounts,
	transitions: number,
	promotions: number,
	demotions: number,
	stateCaptures: number,
	cooldownBlocks: number,
	hysteresisBlocks: number,
	externalResyncs: number,
	reasonCounts: ReasonCounts,
}

export type Manager = {
	adapter: Adapter,
	config: Config,
	entries: { [string]: Entry },
	metrics: InternalMetrics,
}

local FidelityManager = {}

local FIDELITY_RANK: { [string]: number } = table.freeze({
	F0 = 0,
	F1 = 1,
	F2 = 2,
	F3 = 3,
	F4 = 4,
})

local DEFAULT_CONFIG: Config = table.freeze({
	promotionCooldownSeconds = 0.25,
	demotionCooldownSeconds = 2,
	demotionGraceSeconds = 2,
	distanceF3 = 32,
	distanceF2 = 96,
	distanceF1 = 256,
	observationF3 = 0.8,
	observationF2 = 0.35,
	observationF1 = 0.05,
	interactionF4 = 0.8,
	interactionF3 = 0.5,
	interactionF2 = 0.2,
	interactionF1 = 0.05,
	significanceF4 = 0.95,
	significanceF3 = 0.9,
	significanceF2 = 0.6,
	significanceF1 = 0.2,
	networkF3 = 0.85,
	networkF2 = 0.5,
	networkF1 = 0.1,
})

local function isFiniteNumber(value: number): boolean
	return value == value and value > -math.huge and value < math.huge
end

local function rank(fidelity: Fidelity): number
	local value = FIDELITY_RANK[fidelity]
	assert(value ~= nil, `invalid fidelity {fidelity}`)
	return value
end

local function assertUnitInterval(name: string, value: number)
	assert(isFiniteNumber(value), `{name} must be finite`)
	assert(value >= 0 and value <= 1, `{name} must be in [0, 1]`)
end

local function assertDescending(name: string, highest: number, middle: number, lowest: number)
	assert(highest >= middle and middle >= lowest, `{name} thresholds must descend by fidelity`)
end

local function validateInputs(inputs: PolicyInputs)
	assert(isFiniteNumber(inputs.distanceStuds), "distanceStuds must be finite")
	assert(inputs.distanceStuds >= 0, "distanceStuds must be non-negative")
	assertUnitInterval("observation", inputs.observation)
	assertUnitInterval("interaction", inputs.interaction)
	assertUnitInterval("significance", inputs.significance)
	assertUnitInterval("networkRelevance", inputs.networkRelevance)
end

local function validateConfig(config: Config)
	assert(
		isFiniteNumber(config.promotionCooldownSeconds) and config.promotionCooldownSeconds >= 0,
		"invalid promotion cooldown"
	)
	assert(
		isFiniteNumber(config.demotionCooldownSeconds) and config.demotionCooldownSeconds >= 0,
		"invalid demotion cooldown"
	)
	assert(
		isFiniteNumber(config.demotionGraceSeconds) and config.demotionGraceSeconds >= 0,
		"invalid demotion grace"
	)
	assert(isFiniteNumber(config.distanceF3) and config.distanceF3 >= 0, "invalid distanceF3")
	assert(isFiniteNumber(config.distanceF2) and config.distanceF2 >= config.distanceF3, "invalid distanceF2")
	assert(isFiniteNumber(config.distanceF1) and config.distanceF1 >= config.distanceF2, "invalid distanceF1")

	assertUnitInterval("observationF3", config.observationF3)
	assertUnitInterval("observationF2", config.observationF2)
	assertUnitInterval("observationF1", config.observationF1)
	assertDescending("observation", config.observationF3, config.observationF2, config.observationF1)

	assertUnitInterval("interactionF4", config.interactionF4)
	assertUnitInterval("interactionF3", config.interactionF3)
	assertUnitInterval("interactionF2", config.interactionF2)
	assertUnitInterval("interactionF1", config.interactionF1)
	assert(config.interactionF4 >= config.interactionF3, "interaction F4 threshold must be highest")
	assertDescending("interaction", config.interactionF3, config.interactionF2, config.interactionF1)

	assertUnitInterval("significanceF4", config.significanceF4)
	assertUnitInterval("significanceF3", config.significanceF3)
	assertUnitInterval("significanceF2", config.significanceF2)
	assertUnitInterval("significanceF1", config.significanceF1)
	assert(config.significanceF4 >= config.significanceF3, "significance F4 threshold must be highest")
	assertDescending("significance", config.significanceF3, config.significanceF2, config.significanceF1)

	assertUnitInterval("networkF3", config.networkF3)
	assertUnitInterval("networkF2", config.networkF2)
	assertUnitInterval("networkF1", config.networkF1)
	assertDescending("network", config.networkF3, config.networkF2, config.networkF1)
end

local function cloneConfig(config: Config): Config
	return {
		promotionCooldownSeconds = config.promotionCooldownSeconds,
		demotionCooldownSeconds = config.demotionCooldownSeconds,
		demotionGraceSeconds = config.demotionGraceSeconds,
		distanceF3 = config.distanceF3,
		distanceF2 = config.distanceF2,
		distanceF1 = config.distanceF1,
		observationF3 = config.observationF3,
		observationF2 = config.observationF2,
		observationF1 = config.observationF1,
		interactionF4 = config.interactionF4,
		interactionF3 = config.interactionF3,
		interactionF2 = config.interactionF2,
		interactionF1 = config.interactionF1,
		significanceF4 = config.significanceF4,
		significanceF3 = config.significanceF3,
		significanceF2 = config.significanceF2,
		significanceF1 = config.significanceF1,
		networkF3 = config.networkF3,
		networkF2 = config.networkF2,
		networkF1 = config.networkF1,
	}
end

local function newFidelityCounts(): FidelityCounts
	return { F0 = 0, F1 = 0, F2 = 0, F3 = 0, F4 = 0 }
end

local function newReasonCounts(): ReasonCounts
	return {
		distance = 0,
		observation = 0,
		interaction = 0,
		significance = 0,
		network = 0,
		idle = 0,
		other = 0,
	}
end

local function adjustFidelityCount(counts: FidelityCounts, fidelity: Fidelity, delta: number)
	if fidelity == "F0" then
		counts.F0 += delta
	elseif fidelity == "F1" then
		counts.F1 += delta
	elseif fidelity == "F2" then
		counts.F2 += delta
	elseif fidelity == "F3" then
		counts.F3 += delta
	else
		counts.F4 += delta
	end
end

local function countReason(counts: ReasonCounts, reason: string)
	if reason == "distance" then
		counts.distance += 1
	elseif reason == "observation" then
		counts.observation += 1
	elseif reason == "interaction" then
		counts.interaction += 1
	elseif reason == "significance" then
		counts.significance += 1
	elseif reason == "network" then
		counts.network += 1
	elseif reason == "idle" then
		counts.idle += 1
	else
		counts.other += 1
	end
end

local function clearPendingDemotion(entry: Entry)
	entry.pendingDemotionTarget = nil
	entry.pendingDemotionSince = nil
end

local function makeResult(
	status: TransitionStatus,
	entityId: string,
	from: Fidelity,
	target: Fidelity,
	reason: string
): TransitionResult
	return table.freeze({
		status = status,
		entityId = entityId,
		from = from,
		target = target,
		reason = reason,
	})
end

local function isCooldownActive(lastTransitionAt: number?, nowSeconds: number, duration: number): boolean
	return lastTransitionAt ~= nil and nowSeconds - lastTransitionAt < duration
end

local function getTrackedEntry(manager: Manager, entityId: string): Entry
	local entry = manager.entries[entityId]
	assert(entry ~= nil, `entity is not tracked: {entityId}`)
	return entry
end

local function performTransition(
	manager: Manager,
	entityId: string,
	entry: Entry,
	from: Fidelity,
	target: Fidelity,
	reason: string,
	nowSeconds: number,
	capturedState: PersistentState?
): TransitionResult
	manager.adapter.transition(entityId, from, target, capturedState, reason)

	adjustFidelityCount(manager.metrics.fidelityCounts, from, -1)
	adjustFidelityCount(manager.metrics.fidelityCounts, target, 1)
	entry.currentFidelity = target
	entry.lastTransitionAt = nowSeconds
	clearPendingDemotion(entry)

	manager.metrics.transitions += 1
	if rank(target) > rank(from) then
		manager.metrics.promotions += 1
	else
		manager.metrics.demotions += 1
	end
	countReason(manager.metrics.reasonCounts, reason)
	return makeResult("transitioned", entityId, from, target, reason)
end

function FidelityManager.defaultConfig(): Config
	return cloneConfig(DEFAULT_CONFIG)
end

function FidelityManager.evaluatePolicy(inputs: PolicyInputs, configOverride: Config?): (Fidelity, string)
	validateInputs(inputs)
	local config = configOverride or DEFAULT_CONFIG
	validateConfig(config)

	local best: Fidelity = "F0"
	local bestRank = 0
	local bestReason = "idle"
	local bestReasonPriority = 0

	local function consider(target: Fidelity, reason: string, reasonPriority: number)
		local targetRank = rank(target)
		if targetRank > bestRank or (targetRank == bestRank and reasonPriority > bestReasonPriority) then
			best = target
			bestRank = targetRank
			bestReason = reason
			bestReasonPriority = reasonPriority
		end
	end

	if inputs.distanceStuds <= config.distanceF3 then
		consider("F3", "distance", 1)
	elseif inputs.distanceStuds <= config.distanceF2 then
		consider("F2", "distance", 1)
	elseif inputs.distanceStuds <= config.distanceF1 then
		consider("F1", "distance", 1)
	end

	if inputs.observation >= config.observationF3 then
		consider("F3", "observation", 4)
	elseif inputs.observation >= config.observationF2 then
		consider("F2", "observation", 4)
	elseif inputs.observation >= config.observationF1 then
		consider("F1", "observation", 4)
	end

	if inputs.interaction >= config.interactionF4 then
		consider("F4", "interaction", 5)
	elseif inputs.interaction >= config.interactionF3 then
		consider("F3", "interaction", 5)
	elseif inputs.interaction >= config.interactionF2 then
		consider("F2", "interaction", 5)
	elseif inputs.interaction >= config.interactionF1 then
		consider("F1", "interaction", 5)
	end

	if inputs.significance >= config.significanceF4 and inputs.observation >= config.observationF3 then
		consider("F4", "significance", 3)
	elseif inputs.significance >= config.significanceF3 then
		consider("F3", "significance", 3)
	elseif inputs.significance >= config.significanceF2 then
		consider("F2", "significance", 3)
	elseif inputs.significance >= config.significanceF1 then
		consider("F1", "significance", 3)
	end

	if inputs.networkRelevance >= config.networkF3 then
		consider("F3", "network", 2)
	elseif inputs.networkRelevance >= config.networkF2 then
		consider("F2", "network", 2)
	elseif inputs.networkRelevance >= config.networkF1 then
		consider("F1", "network", 2)
	end

	return best, bestReason
end

function FidelityManager.new(adapter: Adapter, configOverride: Config?): Manager
	assert(type(adapter.captureState) == "function", "adapter.captureState required")
	assert(type(adapter.transition) == "function", "adapter.transition required")

	local config = cloneConfig(configOverride or DEFAULT_CONFIG)
	validateConfig(config)
	return {
		adapter = adapter,
		config = table.freeze(config),
		entries = {},
		metrics = {
			trackedEntities = 0,
			fidelityCounts = newFidelityCounts(),
			transitions = 0,
			promotions = 0,
			demotions = 0,
			stateCaptures = 0,
			cooldownBlocks = 0,
			hysteresisBlocks = 0,
			externalResyncs = 0,
			reasonCounts = newReasonCounts(),
		},
	}
end

function FidelityManager.track(manager: Manager, entityId: string, initialFidelity: Fidelity)
	assert(entityId ~= "", "entityId required")
	assert(manager.entries[entityId] == nil, `entity already tracked: {entityId}`)
	rank(initialFidelity)
	manager.entries[entityId] = {
		currentFidelity = initialFidelity,
		lastTransitionAt = nil,
		lastEvaluationAt = nil,
		pendingDemotionTarget = nil,
		pendingDemotionSince = nil,
	}
	manager.metrics.trackedEntities += 1
	adjustFidelityCount(manager.metrics.fidelityCounts, initialFidelity, 1)
end

function FidelityManager.resync(
	manager: Manager,
	entityId: string,
	authoritativeFidelity: Fidelity,
	nowSeconds: number
): boolean
	rank(authoritativeFidelity)
	assert(isFiniteNumber(nowSeconds) and nowSeconds >= 0, "nowSeconds must be a finite non-negative number")
	local entry = getTrackedEntry(manager, entityId)
	if entry.lastEvaluationAt ~= nil then
		assert(nowSeconds >= entry.lastEvaluationAt, `time moved backwards for {entityId}`)
	end
	entry.lastEvaluationAt = nowSeconds
	if authoritativeFidelity == entry.currentFidelity then
		return false
	end

	adjustFidelityCount(manager.metrics.fidelityCounts, entry.currentFidelity, -1)
	adjustFidelityCount(manager.metrics.fidelityCounts, authoritativeFidelity, 1)
	entry.currentFidelity = authoritativeFidelity
	entry.lastTransitionAt = nowSeconds
	clearPendingDemotion(entry)
	manager.metrics.externalResyncs += 1
	return true
end

function FidelityManager.untrack(manager: Manager, entityId: string): boolean
	local entry = manager.entries[entityId]
	if entry == nil then
		return false
	end
	adjustFidelityCount(manager.metrics.fidelityCounts, entry.currentFidelity, -1)
	manager.entries[entityId] = nil
	manager.metrics.trackedEntities -= 1
	return true
end

function FidelityManager.request(
	manager: Manager,
	entityId: string,
	target: Fidelity,
	reason: string,
	nowSeconds: number
): TransitionResult
	rank(target)
	assert(reason ~= "", "transition reason required")
	assert(isFiniteNumber(nowSeconds) and nowSeconds >= 0, "nowSeconds must be a finite non-negative number")

	local entry = getTrackedEntry(manager, entityId)
	local current = entry.currentFidelity
	if entry.lastEvaluationAt ~= nil then
		assert(nowSeconds >= entry.lastEvaluationAt, `time moved backwards for {entityId}`)
	end
	entry.lastEvaluationAt = nowSeconds

	if target == current then
		clearPendingDemotion(entry)
		return makeResult("unchanged", entityId, current, target, reason)
	end

	if rank(target) > rank(current) then
		clearPendingDemotion(entry)
		if isCooldownActive(entry.lastTransitionAt, nowSeconds, manager.config.promotionCooldownSeconds) then
			manager.metrics.cooldownBlocks += 1
			return makeResult("blocked_cooldown", entityId, current, target, reason)
		end
		return performTransition(manager, entityId, entry, current, target, reason, nowSeconds, nil)
	end

	if entry.pendingDemotionTarget ~= target then
		entry.pendingDemotionTarget = target
		entry.pendingDemotionSince = nowSeconds
	end
	local pendingSince = entry.pendingDemotionSince
	assert(pendingSince ~= nil, "pending demotion timestamp missing")

	if nowSeconds - pendingSince < manager.config.demotionGraceSeconds then
		manager.metrics.hysteresisBlocks += 1
		return makeResult("blocked_hysteresis", entityId, current, target, reason)
	end
	if isCooldownActive(entry.lastTransitionAt, nowSeconds, manager.config.demotionCooldownSeconds) then
		manager.metrics.cooldownBlocks += 1
		return makeResult("blocked_cooldown", entityId, current, target, reason)
	end

	local capturedState = manager.adapter.captureState(entityId, current, target, reason)
	assert(capturedState ~= nil, `demotion capture returned nil for {entityId}`)
	manager.metrics.stateCaptures += 1
	return performTransition(manager, entityId, entry, current, target, reason, nowSeconds, capturedState)
end

function FidelityManager.update(
	manager: Manager,
	entityId: string,
	inputs: PolicyInputs,
	nowSeconds: number
): TransitionResult
	local target, reason = FidelityManager.evaluatePolicy(inputs, manager.config)
	return FidelityManager.request(manager, entityId, target, reason, nowSeconds)
end

function FidelityManager.getMetrics(manager: Manager): Metrics
	return table.freeze({
		trackedEntities = manager.metrics.trackedEntities,
		fidelityCounts = table.freeze({
			F0 = manager.metrics.fidelityCounts.F0,
			F1 = manager.metrics.fidelityCounts.F1,
			F2 = manager.metrics.fidelityCounts.F2,
			F3 = manager.metrics.fidelityCounts.F3,
			F4 = manager.metrics.fidelityCounts.F4,
		}),
		transitions = manager.metrics.transitions,
		promotions = manager.metrics.promotions,
		demotions = manager.metrics.demotions,
		stateCaptures = manager.metrics.stateCaptures,
		cooldownBlocks = manager.metrics.cooldownBlocks,
		hysteresisBlocks = manager.metrics.hysteresisBlocks,
		externalResyncs = manager.metrics.externalResyncs,
		reasonCounts = table.freeze({
			distance = manager.metrics.reasonCounts.distance,
			observation = manager.metrics.reasonCounts.observation,
			interaction = manager.metrics.reasonCounts.interaction,
			significance = manager.metrics.reasonCounts.significance,
			network = manager.metrics.reasonCounts.network,
			idle = manager.metrics.reasonCounts.idle,
			other = manager.metrics.reasonCounts.other,
		}),
	})
end

function FidelityManager.getDebugState(manager: Manager, entityId: string): DebugState?
	local entry = manager.entries[entityId]
	if entry == nil then
		return nil
	end
	return table.freeze({
		currentFidelity = entry.currentFidelity,
		lastTransitionAt = entry.lastTransitionAt,
		lastEvaluationAt = entry.lastEvaluationAt,
		pendingDemotionTarget = entry.pendingDemotionTarget,
		pendingDemotionSince = entry.pendingDemotionSince,
	})
end

return table.freeze(FidelityManager)
