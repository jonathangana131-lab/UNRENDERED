--!strict

export type FidelityLevel = "F0" | "F1" | "F2" | "F3" | "F4"
export type RequestMode = "at-least" | "at-most"

export type PolicyInput = {
	distanceStuds: number,
	observationStrength: number,
	secondsSinceInteraction: number,
	significance: number,
	networkRelevance: number,
}

export type PolicyConfig = {
	structuralDistanceStuds: number,
	renderDistanceStuds: number,
	interactiveDistanceStuds: number,
	heroDistanceStuds: number,
	renderObservationStrength: number,
	interactiveObservationStrength: number,
	renderSignificance: number,
	interactiveSignificance: number,
	interactiveNetworkRelevance: number,
	heroInteractionSeconds: number,
	interactiveInteractionSeconds: number,
	promotionHoldSeconds: number,
	demotionHoldSeconds: number,
	transitionCooldownSeconds: number,
}

export type FidelityRequest = {
	level: FidelityLevel,
	mode: RequestMode,
	reason: string,
}

export type FidelityAdapter = {
	captureBeforeDemotion: ((entityId: string, fromLevel: FidelityLevel, toLevel: FidelityLevel) -> unknown)?,
	applyTransition: ((entityId: string, fromLevel: FidelityLevel, toLevel: FidelityLevel, capturedState: unknown?) -> ())?,
}

export type LevelCounts = {
	F0: number,
	F1: number,
	F2: number,
	F3: number,
	F4: number,
}

export type Metrics = {
	registeredEntities: number,
	levelCounts: LevelCounts,
	transitions: number,
	promotions: number,
	demotions: number,
	hysteresisBlocks: number,
	cooldownBlocks: number,
}

export type EntitySnapshot = {
	level: FidelityLevel,
	pendingLevel: FidelityLevel?,
	pendingReason: string?,
	pendingSince: number?,
	lastTransitionAt: number,
	capturedState: unknown?,
}

export type TransitionResult = {
	level: FidelityLevel,
	desiredLevel: FidelityLevel,
	reason: string,
	transitioned: boolean,
	blockedByHysteresis: boolean,
	blockedByCooldown: boolean,
}

type EntityState = EntitySnapshot

export type Manager = {
	_config: PolicyConfig,
	_adapter: FidelityAdapter?,
	_entities: { [string]: EntityState },
	_metrics: Metrics,
}

local FidelityManager = {}

local LEVEL_RANK: { [FidelityLevel]: number } = table.freeze({
	F0 = 0,
	F1 = 1,
	F2 = 2,
	F3 = 3,
	F4 = 4,
})

local DEFAULT_CONFIG: PolicyConfig = table.freeze({
	structuralDistanceStuds = 768,
	renderDistanceStuds = 320,
	interactiveDistanceStuds = 96,
	heroDistanceStuds = 24,
	renderObservationStrength = 0.2,
	interactiveObservationStrength = 0.65,
	renderSignificance = 0.35,
	interactiveSignificance = 0.8,
	interactiveNetworkRelevance = 0.65,
	heroInteractionSeconds = 1.5,
	interactiveInteractionSeconds = 8,
	promotionHoldSeconds = 0.05,
	demotionHoldSeconds = 0.75,
	transitionCooldownSeconds = 0.25,
})

local function levelCounts(): LevelCounts
	return {
		F0 = 0,
		F1 = 0,
		F2 = 0,
		F3 = 0,
		F4 = 0,
	}
end

local function isFinite(value: number): boolean
	return value == value and value > -math.huge and value < math.huge
end

local function assertNonNegative(name: string, value: number): ()
	assert(isFinite(value) and value >= 0, `{name} must be a finite non-negative number`)
end

local function assertUnitInterval(name: string, value: number): ()
	assert(isFinite(value) and value >= 0 and value <= 1, `{name} must be in [0, 1]`)
end

local function validateLevel(level: FidelityLevel): ()
	assert(LEVEL_RANK[level] ~= nil, `unknown fidelity level: {tostring(level)}`)
end

local function validateConfig(config: PolicyConfig): ()
	assertNonNegative("heroDistanceStuds", config.heroDistanceStuds)
	assertNonNegative("interactiveDistanceStuds", config.interactiveDistanceStuds)
	assertNonNegative("renderDistanceStuds", config.renderDistanceStuds)
	assertNonNegative("structuralDistanceStuds", config.structuralDistanceStuds)
	assert(
		config.heroDistanceStuds <= config.interactiveDistanceStuds
			and config.interactiveDistanceStuds <= config.renderDistanceStuds
			and config.renderDistanceStuds <= config.structuralDistanceStuds,
		"distance thresholds must be ordered hero <= interactive <= render <= structural"
	)
	assertUnitInterval("renderObservationStrength", config.renderObservationStrength)
	assertUnitInterval("interactiveObservationStrength", config.interactiveObservationStrength)
	assert(
		config.renderObservationStrength <= config.interactiveObservationStrength,
		"observation thresholds must be ordered render <= interactive"
	)
	assertUnitInterval("renderSignificance", config.renderSignificance)
	assertUnitInterval("interactiveSignificance", config.interactiveSignificance)
	assert(
		config.renderSignificance <= config.interactiveSignificance,
		"significance thresholds must be ordered render <= interactive"
	)
	assertUnitInterval("interactiveNetworkRelevance", config.interactiveNetworkRelevance)
	assertNonNegative("heroInteractionSeconds", config.heroInteractionSeconds)
	assertNonNegative("interactiveInteractionSeconds", config.interactiveInteractionSeconds)
	assert(
		config.heroInteractionSeconds <= config.interactiveInteractionSeconds,
		"interaction windows must be ordered hero <= interactive"
	)
	assertNonNegative("promotionHoldSeconds", config.promotionHoldSeconds)
	assertNonNegative("demotionHoldSeconds", config.demotionHoldSeconds)
	assertNonNegative("transitionCooldownSeconds", config.transitionCooldownSeconds)
end

local function validateInput(input: PolicyInput): ()
	assertNonNegative("distanceStuds", input.distanceStuds)
	assertUnitInterval("observationStrength", input.observationStrength)
	assertNonNegative("secondsSinceInteraction", input.secondsSinceInteraction)
	assertUnitInterval("significance", input.significance)
	assertUnitInterval("networkRelevance", input.networkRelevance)
end

local function evaluateUnchecked(input: PolicyInput, config: PolicyConfig): (FidelityLevel, string)
	if input.secondsSinceInteraction <= config.heroInteractionSeconds and input.distanceStuds <= config.heroDistanceStuds then
		return "F4", "recent-interaction"
	end

	if input.secondsSinceInteraction <= config.interactiveInteractionSeconds then
		return "F3", "recent-interaction"
	end

	if input.networkRelevance >= config.interactiveNetworkRelevance then
		return "F3", "network-relevance"
	end

	if input.significance >= config.interactiveSignificance then
		return "F3", "significance"
	end

	if input.observationStrength >= config.interactiveObservationStrength
		and input.distanceStuds <= config.interactiveDistanceStuds
	then
		return "F3", "observation"
	end

	if input.distanceStuds <= config.renderDistanceStuds then
		return "F2", "distance"
	end

	if input.observationStrength >= config.renderObservationStrength then
		return "F2", "observation"
	end

	if input.significance >= config.renderSignificance then
		return "F2", "significance"
	end

	if input.distanceStuds <= config.structuralDistanceStuds then
		return "F1", "distance"
	end

	if input.networkRelevance > 0 then
		return "F1", "network-relevance"
	end

	if input.significance > 0 then
		return "F1", "significance"
	end

	return "F0", "potential"
end

local function applyRequest(level: FidelityLevel, reason: string, request: FidelityRequest?): (FidelityLevel, string)
	if request == nil then
		return level, reason
	end

	validateLevel(request.level)
	assert(request.reason ~= "", "FidelityRequest.reason required")
	assert(request.mode == "at-least" or request.mode == "at-most", "invalid FidelityRequest.mode")

	local desiredRank = LEVEL_RANK[level]
	local requestRank = LEVEL_RANK[request.level]
	if request.mode == "at-least" and desiredRank < requestRank then
		return request.level, request.reason
	end
	if request.mode == "at-most" and desiredRank > requestRank then
		return request.level, request.reason
	end
	return level, reason
end

function FidelityManager.defaultConfig(): PolicyConfig
	return DEFAULT_CONFIG
end

function FidelityManager.evaluate(input: PolicyInput, config: PolicyConfig?, request: FidelityRequest?): (FidelityLevel, string)
	local resolvedConfig = config or DEFAULT_CONFIG
	validateConfig(resolvedConfig)
	validateInput(input)
	local level, reason = evaluateUnchecked(input, resolvedConfig)
	return applyRequest(level, reason, request)
end

function FidelityManager.new(config: PolicyConfig?, adapter: FidelityAdapter?): Manager
	local resolvedConfig = config or DEFAULT_CONFIG
	validateConfig(resolvedConfig)
	return {
		_config = resolvedConfig,
		_adapter = adapter,
		_entities = {},
		_metrics = {
			registeredEntities = 0,
			levelCounts = levelCounts(),
			transitions = 0,
			promotions = 0,
			demotions = 0,
			hysteresisBlocks = 0,
			cooldownBlocks = 0,
		},
	}
end

function FidelityManager.register(manager: Manager, entityId: string, initialLevel: FidelityLevel?, nowSeconds: number?): ()
	assert(entityId ~= "", "entityId required")
	assert(manager._entities[entityId] == nil, `entity already registered: {entityId}`)
	local level = initialLevel or "F0"
	validateLevel(level)
	local now = nowSeconds or 0
	assertNonNegative("nowSeconds", now)
	manager._entities[entityId] = {
		level = level,
		pendingLevel = nil,
		pendingReason = nil,
		pendingSince = nil,
		lastTransitionAt = now - manager._config.transitionCooldownSeconds,
		capturedState = nil,
	}
	manager._metrics.registeredEntities += 1
	manager._metrics.levelCounts[level] += 1
end

function FidelityManager.unregister(manager: Manager, entityId: string): EntitySnapshot?
	local state = manager._entities[entityId]
	if state == nil then
		return nil
	end
	manager._entities[entityId] = nil
	manager._metrics.registeredEntities -= 1
	manager._metrics.levelCounts[state.level] -= 1
	return {
		level = state.level,
		pendingLevel = state.pendingLevel,
		pendingReason = state.pendingReason,
		pendingSince = state.pendingSince,
		lastTransitionAt = state.lastTransitionAt,
		capturedState = state.capturedState,
	}
end

function FidelityManager.getLevel(manager: Manager, entityId: string): FidelityLevel?
	local state = manager._entities[entityId]
	return if state == nil then nil else state.level
end

function FidelityManager.getSnapshot(manager: Manager, entityId: string): EntitySnapshot?
	local state = manager._entities[entityId]
	if state == nil then
		return nil
	end
	return {
		level = state.level,
		pendingLevel = state.pendingLevel,
		pendingReason = state.pendingReason,
		pendingSince = state.pendingSince,
		lastTransitionAt = state.lastTransitionAt,
		capturedState = state.capturedState,
	}
end

local function result(
	state: EntityState,
	desiredLevel: FidelityLevel,
	reason: string,
	transitioned: boolean,
	blockedByHysteresis: boolean,
	blockedByCooldown: boolean
): TransitionResult
	return {
		level = state.level,
		desiredLevel = desiredLevel,
		reason = reason,
		transitioned = transitioned,
		blockedByHysteresis = blockedByHysteresis,
		blockedByCooldown = blockedByCooldown,
	}
end

function FidelityManager.update(
	manager: Manager,
	entityId: string,
	input: PolicyInput,
	nowSeconds: number,
	request: FidelityRequest?
): TransitionResult
	local state = manager._entities[entityId]
	assert(state ~= nil, `entity not registered: {entityId}`)
	assertNonNegative("nowSeconds", nowSeconds)
	assert(nowSeconds >= state.lastTransitionAt, "nowSeconds cannot move backwards")
	validateInput(input)

	local desiredLevel, reason = evaluateUnchecked(input, manager._config)
	desiredLevel, reason = applyRequest(desiredLevel, reason, request)

	if desiredLevel == state.level then
		state.pendingLevel = nil
		state.pendingReason = nil
		state.pendingSince = nil
		return result(state, desiredLevel, reason, false, false, false)
	end

	if state.pendingLevel ~= desiredLevel or state.pendingReason ~= reason then
		state.pendingLevel = desiredLevel
		state.pendingReason = reason
		state.pendingSince = nowSeconds
	end

	local currentRank = LEVEL_RANK[state.level]
	local desiredRank = LEVEL_RANK[desiredLevel]
	local isPromotion = desiredRank > currentRank
	local holdSeconds = if isPromotion then manager._config.promotionHoldSeconds else manager._config.demotionHoldSeconds
	local pendingSince = state.pendingSince or nowSeconds
	if nowSeconds - pendingSince < holdSeconds then
		manager._metrics.hysteresisBlocks += 1
		return result(state, desiredLevel, reason, false, true, false)
	end

	if nowSeconds - state.lastTransitionAt < manager._config.transitionCooldownSeconds then
		manager._metrics.cooldownBlocks += 1
		return result(state, desiredLevel, reason, false, false, true)
	end

	local fromLevel = state.level
	if not isPromotion and manager._adapter ~= nil and manager._adapter.captureBeforeDemotion ~= nil then
		state.capturedState = manager._adapter.captureBeforeDemotion(entityId, fromLevel, desiredLevel)
	end

	if manager._adapter ~= nil and manager._adapter.applyTransition ~= nil then
		manager._adapter.applyTransition(entityId, fromLevel, desiredLevel, state.capturedState)
	end

	manager._metrics.levelCounts[fromLevel] -= 1
	manager._metrics.levelCounts[desiredLevel] += 1
	manager._metrics.transitions += 1
	if isPromotion then
		manager._metrics.promotions += 1
	else
		manager._metrics.demotions += 1
	end

	state.level = desiredLevel
	state.pendingLevel = nil
	state.pendingReason = nil
	state.pendingSince = nil
	state.lastTransitionAt = nowSeconds

	return result(state, desiredLevel, reason, true, false, false)
end

function FidelityManager.getMetrics(manager: Manager): Metrics
	return {
		registeredEntities = manager._metrics.registeredEntities,
		levelCounts = {
			F0 = manager._metrics.levelCounts.F0,
			F1 = manager._metrics.levelCounts.F1,
			F2 = manager._metrics.levelCounts.F2,
			F3 = manager._metrics.levelCounts.F3,
			F4 = manager._metrics.levelCounts.F4,
		},
		transitions = manager._metrics.transitions,
		promotions = manager._metrics.promotions,
		demotions = manager._metrics.demotions,
		hysteresisBlocks = manager._metrics.hysteresisBlocks,
		cooldownBlocks = manager._metrics.cooldownBlocks,
	}
end

return table.freeze(FidelityManager)
