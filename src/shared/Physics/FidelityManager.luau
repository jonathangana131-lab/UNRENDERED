--!strict

local FidelityManager = {}

export type FidelityLevel = "F0" | "F1" | "F2" | "F3" | "F4"

export type PolicyInput = {
	distanceStuds: number,
	observed: boolean,
	secondsSinceInteraction: number,
	significance: number,
	networkRelevance: number,
	isMoving: boolean,
}

export type Config = {
	structuralSignificance: number,
	renderDistanceStuds: number,
	interactiveDistanceStuds: number,
	heroDistanceStuds: number,
	interactiveGraceSeconds: number,
	heroSignificance: number,
	heroNetworkRelevance: number,
	distanceHysteresisStuds: number,
	significanceHysteresis: number,
	networkHysteresis: number,
	interactionHysteresisSeconds: number,
	promotionCooldownSeconds: number,
	demotionCooldownSeconds: number,
}

export type EntityState = {
	level: FidelityLevel,
	lastTransitionAt: number,
	snapshot: unknown,
}

export type Metrics = {
	counts: { [FidelityLevel]: number },
	transitions: number,
	promotions: number,
	demotions: number,
	blockedByCooldown: number,
}

export type Registry = {
	entities: { [string]: EntityState },
	metrics: Metrics,
}

export type Adapter = {
	captureState: ((entityId: string, fromLevel: FidelityLevel, toLevel: FidelityLevel) -> unknown)?,
	applyTransition: ((entityId: string, fromLevel: FidelityLevel, toLevel: FidelityLevel, snapshot: unknown) -> ())?,
}

export type TransitionResult = {
	changed: boolean,
	level: FidelityLevel,
	target: FidelityLevel,
	reason: string,
	blockedReason: string?,
}

local ORDER: { [FidelityLevel]: number } = {
	F0 = 0,
	F1 = 1,
	F2 = 2,
	F3 = 3,
	F4 = 4,
}

local DEFAULT_CONFIG: Config = table.freeze({
	structuralSignificance = 0.05,
	renderDistanceStuds = 320,
	interactiveDistanceStuds = 80,
	heroDistanceStuds = 24,
	interactiveGraceSeconds = 8,
	heroSignificance = 0.8,
	heroNetworkRelevance = 0.8,
	distanceHysteresisStuds = 12,
	significanceHysteresis = 0.05,
	networkHysteresis = 0.05,
	interactionHysteresisSeconds = 1.5,
	promotionCooldownSeconds = 0.1,
	demotionCooldownSeconds = 1.0,
})

FidelityManager.Level = table.freeze({
	Potential = "F0" :: FidelityLevel,
	Structural = "F1" :: FidelityLevel,
	Render = "F2" :: FidelityLevel,
	Interactive = "F3" :: FidelityLevel,
	Hero = "F4" :: FidelityLevel,
})

FidelityManager.DEFAULT_CONFIG = DEFAULT_CONFIG

local function assertUnitInterval(name: string, value: number): ()
	assert(value >= 0 and value <= 1, `{name} must be in [0, 1]`)
end

local function assertNonNegative(name: string, value: number): ()
	assert(value >= 0, `{name} must be non-negative`)
end

function FidelityManager.validateConfig(config: Config): ()
	assertNonNegative("renderDistanceStuds", config.renderDistanceStuds)
	assertNonNegative("interactiveDistanceStuds", config.interactiveDistanceStuds)
	assertNonNegative("heroDistanceStuds", config.heroDistanceStuds)
	assert(config.heroDistanceStuds <= config.interactiveDistanceStuds, "hero distance must be <= interactive distance")
	assert(config.interactiveDistanceStuds <= config.renderDistanceStuds, "interactive distance must be <= render distance")
	assertUnitInterval("structuralSignificance", config.structuralSignificance)
	assertUnitInterval("heroSignificance", config.heroSignificance)
	assertUnitInterval("heroNetworkRelevance", config.heroNetworkRelevance)
	assertUnitInterval("significanceHysteresis", config.significanceHysteresis)
	assertUnitInterval("networkHysteresis", config.networkHysteresis)
	assertNonNegative("interactiveGraceSeconds", config.interactiveGraceSeconds)
	assertNonNegative("distanceHysteresisStuds", config.distanceHysteresisStuds)
	assertNonNegative("interactionHysteresisSeconds", config.interactionHysteresisSeconds)
	assertNonNegative("promotionCooldownSeconds", config.promotionCooldownSeconds)
	assertNonNegative("demotionCooldownSeconds", config.demotionCooldownSeconds)
end

function FidelityManager.validateInput(input: PolicyInput): ()
	assertNonNegative("distanceStuds", input.distanceStuds)
	assertNonNegative("secondsSinceInteraction", input.secondsSinceInteraction)
	assertUnitInterval("significance", input.significance)
	assertUnitInterval("networkRelevance", input.networkRelevance)
end

local function retains(current: FidelityLevel, candidate: FidelityLevel): boolean
	return ORDER[current] >= ORDER[candidate]
end

local function withinDistance(current: FidelityLevel, candidate: FidelityLevel, distance: number, threshold: number, hysteresis: number): boolean
	local releaseDistance = if retains(current, candidate) then threshold + hysteresis else threshold
	return distance <= releaseDistance
end

local function aboveThreshold(current: FidelityLevel, candidate: FidelityLevel, value: number, threshold: number, hysteresis: number): boolean
	local releaseThreshold = if retains(current, candidate) then math.max(0, threshold - hysteresis) else threshold
	return value >= releaseThreshold
end

function FidelityManager.evaluateTarget(current: FidelityLevel, input: PolicyInput, config: Config?): (FidelityLevel, string)
	local policy = config or DEFAULT_CONFIG
	FidelityManager.validateInput(input)

	local recentInteraction = input.secondsSinceInteraction
		<= policy.interactiveGraceSeconds
			+ if retains(current, "F3") then policy.interactionHysteresisSeconds else 0

	local heroRelevant = aboveThreshold(current, "F4", input.significance, policy.heroSignificance, policy.significanceHysteresis)
		or aboveThreshold(current, "F4", input.networkRelevance, policy.heroNetworkRelevance, policy.networkHysteresis)
		or recentInteraction

	if withinDistance(current, "F4", input.distanceStuds, policy.heroDistanceStuds, policy.distanceHysteresisStuds) and heroRelevant then
		return "F4", "hero-near-relevant"
	end

	if withinDistance(current, "F3", input.distanceStuds, policy.interactiveDistanceStuds, policy.distanceHysteresisStuds)
		or recentInteraction
		or aboveThreshold(current, "F3", input.networkRelevance, 0.6, policy.networkHysteresis)
	then
		return "F3", "interactive-relevance"
	end

	if withinDistance(current, "F2", input.distanceStuds, policy.renderDistanceStuds, policy.distanceHysteresisStuds)
		or aboveThreshold(current, "F2", input.significance, 0.4, policy.significanceHysteresis)
		or aboveThreshold(current, "F2", input.networkRelevance, 0.35, policy.networkHysteresis)
		or (input.isMoving and input.distanceStuds <= policy.renderDistanceStuds * 1.25)
	then
		return "F2", "render-relevance"
	end

	if input.observed
		or aboveThreshold(current, "F1", input.significance, policy.structuralSignificance, policy.significanceHysteresis)
		or input.networkRelevance > 0
	then
		return "F1", "structural-truth"
	end

	return "F0", "potential-only"
end

local function emptyCounts(): { [FidelityLevel]: number }
	return {
		F0 = 0,
		F1 = 0,
		F2 = 0,
		F3 = 0,
		F4 = 0,
	}
end

function FidelityManager.newRegistry(): Registry
	return {
		entities = {},
		metrics = {
			counts = emptyCounts(),
			transitions = 0,
			promotions = 0,
			demotions = 0,
			blockedByCooldown = 0,
		},
	}
end

function FidelityManager.register(registry: Registry, entityId: string, initialLevel: FidelityLevel?, now: number?): EntityState
	assert(entityId ~= "", "entityId required")
	assert(registry.entities[entityId] == nil, `duplicate fidelity registration: {entityId}`)
	local level = initialLevel or "F0"
	local state: EntityState = {
		level = level,
		lastTransitionAt = now or 0,
		snapshot = nil,
	}
	registry.entities[entityId] = state
	registry.metrics.counts[level] += 1
	return state
end

function FidelityManager.unregister(registry: Registry, entityId: string): EntityState?
	local state = registry.entities[entityId]
	if state == nil then
		return nil
	end
	registry.entities[entityId] = nil
	registry.metrics.counts[state.level] -= 1
	return state
end

function FidelityManager.getState(registry: Registry, entityId: string): EntityState?
	return registry.entities[entityId]
end

function FidelityManager.request(
	registry: Registry,
	entityId: string,
	target: FidelityLevel,
	now: number,
	reason: string,
	adapter: Adapter?,
	config: Config?
): TransitionResult
	assert(reason ~= "", "transition reason required")
	local policy = config or DEFAULT_CONFIG
	local state = registry.entities[entityId]
	assert(state ~= nil, `entity is not registered: {entityId}`)

	if state.level == target then
		return {
			changed = false,
			level = state.level,
			target = target,
			reason = reason,
			blockedReason = nil,
		}
	end

	local fromIndex = ORDER[state.level]
	local targetIndex = ORDER[target]
	local isPromotion = targetIndex > fromIndex
	local cooldown = if isPromotion then policy.promotionCooldownSeconds else policy.demotionCooldownSeconds
	if now - state.lastTransitionAt < cooldown then
		registry.metrics.blockedByCooldown += 1
		return {
			changed = false,
			level = state.level,
			target = target,
			reason = reason,
			blockedReason = "cooldown",
		}
	end

	local snapshot = state.snapshot
	if not isPromotion and adapter ~= nil and adapter.captureState ~= nil then
		snapshot = adapter.captureState(entityId, state.level, target)
	end

	if adapter ~= nil and adapter.applyTransition ~= nil then
		adapter.applyTransition(entityId, state.level, target, snapshot)
	end

	registry.metrics.counts[state.level] -= 1
	registry.metrics.counts[target] += 1
	registry.metrics.transitions += 1
	if isPromotion then
		registry.metrics.promotions += 1
	else
		registry.metrics.demotions += 1
	end

	state.level = target
	state.lastTransitionAt = now
	state.snapshot = snapshot

	return {
		changed = true,
		level = target,
		target = target,
		reason = reason,
		blockedReason = nil,
	}
end

function FidelityManager.update(
	registry: Registry,
	entityId: string,
	input: PolicyInput,
	now: number,
	adapter: Adapter?,
	config: Config?
): TransitionResult
	local state = registry.entities[entityId]
	assert(state ~= nil, `entity is not registered: {entityId}`)
	local target, reason = FidelityManager.evaluateTarget(state.level, input, config)
	return FidelityManager.request(registry, entityId, target, now, reason, adapter, config)
end

function FidelityManager.getMetrics(registry: Registry): Metrics
	return {
		counts = {
			F0 = registry.metrics.counts.F0,
			F1 = registry.metrics.counts.F1,
			F2 = registry.metrics.counts.F2,
			F3 = registry.metrics.counts.F3,
			F4 = registry.metrics.counts.F4,
		},
		transitions = registry.metrics.transitions,
		promotions = registry.metrics.promotions,
		demotions = registry.metrics.demotions,
		blockedByCooldown = registry.metrics.blockedByCooldown,
	}
end

return table.freeze(FidelityManager)
