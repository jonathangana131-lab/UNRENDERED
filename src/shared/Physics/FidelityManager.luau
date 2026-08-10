--!strict

export type FidelityLevel = "F0" | "F1" | "F2" | "F3" | "F4"
export type RequestMode = "at-least" | "at-most"

export type PolicyInputs = {
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
	distanceHysteresisStuds: number,
	interactionGraceSeconds: number,
	renderObservationStrength: number,
	interactiveObservationStrength: number,
	significanceKeepaliveThreshold: number,
	activeNetworkRelevanceThreshold: number,
	heroRelevanceThreshold: number,
	promotionHoldSeconds: number,
	demotionHoldSeconds: number,
	transitionCooldownSeconds: number,
}

export type FidelityRequest = {
	level: FidelityLevel,
	mode: RequestMode,
	reason: string,
}

export type PolicyDecision = {
	level: FidelityLevel,
	reason: string,
}

export type BlockedReason = "hold" | "cooldown" | "capture-required"

export type StepResult = {
	changed: boolean,
	currentLevel: FidelityLevel,
	desiredLevel: FidelityLevel,
	reason: string,
	blockedReason: BlockedReason?,
}

export type LevelCounts = {
	F0: number,
	F1: number,
	F2: number,
	F3: number,
	F4: number,
}

export type Metrics = {
	registered: number,
	counts: LevelCounts,
	transitions: number,
	promotions: number,
	demotions: number,
	captureCalls: number,
	blockedByHold: number,
	blockedByCooldown: number,
	blockedByCapture: number,
}

export type CaptureHook = (entityId: string, fromLevel: FidelityLevel, toLevel: FidelityLevel) -> ()
export type ApplyHook = (
	entityId: string,
	fromLevel: FidelityLevel,
	toLevel: FidelityLevel,
	reason: string
) -> ()

export type TransitionAdapter = {
	captureBeforeDemotion: CaptureHook?,
	applyTransition: ApplyHook?,
}

type EntityState = {
	level: FidelityLevel,
	pendingLevel: FidelityLevel?,
	pendingReason: string?,
	pendingSince: number?,
	lastTransitionAt: number,
	lastEvaluatedAt: number,
}

type MutableMetrics = {
	registered: number,
	counts: LevelCounts,
	transitions: number,
	promotions: number,
	demotions: number,
	captureCalls: number,
	blockedByHold: number,
	blockedByCooldown: number,
	blockedByCapture: number,
}

local FidelityManager = {}
FidelityManager.__index = FidelityManager

type ManagerImpl = {
	config: PolicyConfig,
	adapter: TransitionAdapter?,
	_states: { [string]: EntityState },
	_metrics: MutableMetrics,
}

export type Manager = typeof(setmetatable({} :: ManagerImpl, FidelityManager))

local LEVEL_INDEX: { [FidelityLevel]: number } = table.freeze({
	F0 = 0,
	F1 = 1,
	F2 = 2,
	F3 = 3,
	F4 = 4,
})

local DEFAULT_CONFIG: PolicyConfig = table.freeze({
	structuralDistanceStuds = 512,
	renderDistanceStuds = 240,
	interactiveDistanceStuds = 48,
	heroDistanceStuds = 16,
	distanceHysteresisStuds = 8,
	interactionGraceSeconds = 3,
	renderObservationStrength = 0.1,
	interactiveObservationStrength = 0.75,
	significanceKeepaliveThreshold = 0.75,
	activeNetworkRelevanceThreshold = 0.8,
	heroRelevanceThreshold = 0.95,
	promotionHoldSeconds = 0.1,
	demotionHoldSeconds = 1.5,
	transitionCooldownSeconds = 0.25,
})

local function isFinite(value: number): boolean
	return value == value and value > -math.huge and value < math.huge
end

local function isLevel(value: string): boolean
	return LEVEL_INDEX[value :: FidelityLevel] ~= nil
end

local function assertFiniteNonNegative(name: string, value: number): ()
	assert(isFinite(value) and value >= 0, `{name} must be a finite non-negative number`)
end

local function assertNonNegative(name: string, value: number): ()
	assert(value == value and value >= 0, `{name} must be a non-negative number`)
end

local function assertUnit(name: string, value: number): ()
	assert(isFinite(value) and value >= 0 and value <= 1, `{name} must be in [0, 1]`)
end

local function validateConfig(config: PolicyConfig): ()
	assertFiniteNonNegative("heroDistanceStuds", config.heroDistanceStuds)
	assertFiniteNonNegative("interactiveDistanceStuds", config.interactiveDistanceStuds)
	assertFiniteNonNegative("renderDistanceStuds", config.renderDistanceStuds)
	assertFiniteNonNegative("structuralDistanceStuds", config.structuralDistanceStuds)
	assert(
		config.heroDistanceStuds <= config.interactiveDistanceStuds
			and config.interactiveDistanceStuds <= config.renderDistanceStuds
			and config.renderDistanceStuds <= config.structuralDistanceStuds,
		"distance thresholds must be ordered hero <= interactive <= render <= structural"
	)
	assertFiniteNonNegative("distanceHysteresisStuds", config.distanceHysteresisStuds)
	assertFiniteNonNegative("interactionGraceSeconds", config.interactionGraceSeconds)
	assertUnit("renderObservationStrength", config.renderObservationStrength)
	assertUnit("interactiveObservationStrength", config.interactiveObservationStrength)
	assert(
		config.renderObservationStrength <= config.interactiveObservationStrength,
		"observation thresholds must be ordered render <= interactive"
	)
	assertUnit("significanceKeepaliveThreshold", config.significanceKeepaliveThreshold)
	assertUnit("activeNetworkRelevanceThreshold", config.activeNetworkRelevanceThreshold)
	assertUnit("heroRelevanceThreshold", config.heroRelevanceThreshold)
	assert(
		config.activeNetworkRelevanceThreshold <= config.heroRelevanceThreshold,
		"active network relevance must not exceed hero relevance"
	)
	assertFiniteNonNegative("promotionHoldSeconds", config.promotionHoldSeconds)
	assertFiniteNonNegative("demotionHoldSeconds", config.demotionHoldSeconds)
	assertFiniteNonNegative("transitionCooldownSeconds", config.transitionCooldownSeconds)
end

local function validateInputs(inputs: PolicyInputs): ()
	assertNonNegative("distanceStuds", inputs.distanceStuds)
	assertUnit("observationStrength", inputs.observationStrength)
	assertNonNegative("secondsSinceInteraction", inputs.secondsSinceInteraction)
	assertUnit("significance", inputs.significance)
	assertUnit("networkRelevance", inputs.networkRelevance)
end

local function copyConfig(config: PolicyConfig): PolicyConfig
	return {
		structuralDistanceStuds = config.structuralDistanceStuds,
		renderDistanceStuds = config.renderDistanceStuds,
		interactiveDistanceStuds = config.interactiveDistanceStuds,
		heroDistanceStuds = config.heroDistanceStuds,
		distanceHysteresisStuds = config.distanceHysteresisStuds,
		interactionGraceSeconds = config.interactionGraceSeconds,
		renderObservationStrength = config.renderObservationStrength,
		interactiveObservationStrength = config.interactiveObservationStrength,
		significanceKeepaliveThreshold = config.significanceKeepaliveThreshold,
		activeNetworkRelevanceThreshold = config.activeNetworkRelevanceThreshold,
		heroRelevanceThreshold = config.heroRelevanceThreshold,
		promotionHoldSeconds = config.promotionHoldSeconds,
		demotionHoldSeconds = config.demotionHoldSeconds,
		transitionCooldownSeconds = config.transitionCooldownSeconds,
	}
end

local function promote(
	currentLevel: FidelityLevel,
	currentReason: string,
	candidateLevel: FidelityLevel,
	candidateReason: string
): (FidelityLevel, string)
	if LEVEL_INDEX[candidateLevel] > LEVEL_INDEX[currentLevel] then
		return candidateLevel, candidateReason
	end
	return currentLevel, currentReason
end

local function distanceLimit(
	base: number,
	currentLevel: FidelityLevel,
	retainedLevel: FidelityLevel,
	hysteresis: number
): number
	if LEVEL_INDEX[currentLevel] >= LEVEL_INDEX[retainedLevel] then
		return base + hysteresis
	end
	return base
end

local function applyRequest(decision: PolicyDecision, request: FidelityRequest?): PolicyDecision
	if request == nil then
		return decision
	end
	assert(isLevel(request.level), "FidelityRequest.level must be F0-F4")
	assert(request.mode == "at-least" or request.mode == "at-most", "invalid FidelityRequest.mode")
	assert(request.reason ~= "", "FidelityRequest.reason required")

	local desiredRank = LEVEL_INDEX[decision.level]
	local requestRank = LEVEL_INDEX[request.level]
	if request.mode == "at-least" and desiredRank < requestRank then
		return { level = request.level, reason = request.reason }
	end
	if request.mode == "at-most" and desiredRank > requestRank then
		return { level = request.level, reason = request.reason }
	end
	return decision
end

function FidelityManager.defaultConfig(): PolicyConfig
	return table.freeze(copyConfig(DEFAULT_CONFIG))
end

function FidelityManager.evaluate(
	inputs: PolicyInputs,
	config: PolicyConfig?,
	currentLevel: FidelityLevel?,
	request: FidelityRequest?
): PolicyDecision
	local resolvedConfig = config or DEFAULT_CONFIG
	local resolvedCurrent: FidelityLevel
	if currentLevel == nil then
		resolvedCurrent = "F0"
	else
		resolvedCurrent = currentLevel
	end
	validateConfig(resolvedConfig)
	validateInputs(inputs)
	assert(isLevel(resolvedCurrent), "currentLevel must be F0-F4")

	local structuralLimit = distanceLimit(
		resolvedConfig.structuralDistanceStuds,
		resolvedCurrent,
		"F1",
		resolvedConfig.distanceHysteresisStuds
	)
	local renderLimit = distanceLimit(
		resolvedConfig.renderDistanceStuds,
		resolvedCurrent,
		"F2",
		resolvedConfig.distanceHysteresisStuds
	)
	local interactiveLimit = distanceLimit(
		resolvedConfig.interactiveDistanceStuds,
		resolvedCurrent,
		"F3",
		resolvedConfig.distanceHysteresisStuds
	)
	local heroLimit = distanceLimit(
		resolvedConfig.heroDistanceStuds,
		resolvedCurrent,
		"F4",
		resolvedConfig.distanceHysteresisStuds
	)

	local level: FidelityLevel = "F0"
	local reason = "potential"
	if inputs.distanceStuds <= structuralLimit then
		level, reason = promote(level, reason, "F1", "distance-structural")
	end
	if inputs.distanceStuds <= renderLimit then
		level, reason = promote(level, reason, "F2", "distance-render")
	end
	if inputs.distanceStuds <= interactiveLimit then
		level, reason = promote(level, reason, "F3", "distance-interactive")
	end

	if inputs.significance >= resolvedConfig.significanceKeepaliveThreshold then
		level, reason = promote(level, reason, "F1", "significance")
	end
	if inputs.observationStrength >= resolvedConfig.renderObservationStrength then
		level, reason = promote(level, reason, "F2", "observation")
	end

	local recentlyInteracted = inputs.secondsSinceInteraction <= resolvedConfig.interactionGraceSeconds
	if recentlyInteracted then
		level, reason = promote(level, reason, "F3", "recent-interaction")
	end
	if inputs.observationStrength >= resolvedConfig.interactiveObservationStrength then
		level, reason = promote(level, reason, "F3", "observation")
	end
	if inputs.networkRelevance >= resolvedConfig.activeNetworkRelevanceThreshold then
		level, reason = promote(level, reason, "F3", "network-relevance")
	end

	local locallyPresented = inputs.distanceStuds <= renderLimit
		or inputs.observationStrength >= resolvedConfig.renderObservationStrength
	local highRelevance = math.max(inputs.significance, inputs.networkRelevance)
		>= resolvedConfig.heroRelevanceThreshold
	if
		inputs.distanceStuds <= heroLimit
		and (
			recentlyInteracted
			or inputs.observationStrength >= resolvedConfig.interactiveObservationStrength
		)
	then
		level = "F4"
		reason = if recentlyInteracted then "recent-interaction" else "observation"
	elseif highRelevance and locallyPresented then
		level = "F4"
		reason = if inputs.networkRelevance >= inputs.significance
			then "network-relevance"
			else "significance"
	end

	return applyRequest({ level = level, reason = reason }, request)
end

function FidelityManager.selectDesiredLevel(
	inputs: PolicyInputs,
	config: PolicyConfig?,
	currentLevel: FidelityLevel?,
	request: FidelityRequest?
): FidelityLevel
	return FidelityManager.evaluate(inputs, config, currentLevel, request).level
end

function FidelityManager.new(config: PolicyConfig?, adapter: TransitionAdapter?): Manager
	local resolvedConfig = copyConfig(config or DEFAULT_CONFIG)
	validateConfig(resolvedConfig)
	local self: ManagerImpl = {
		config = table.freeze(resolvedConfig),
		adapter = adapter,
		_states = {},
		_metrics = {
			registered = 0,
			counts = { F0 = 0, F1 = 0, F2 = 0, F3 = 0, F4 = 0 },
			transitions = 0,
			promotions = 0,
			demotions = 0,
			captureCalls = 0,
			blockedByHold = 0,
			blockedByCooldown = 0,
			blockedByCapture = 0,
		},
	}
	return setmetatable(self, FidelityManager)
end

function FidelityManager.register(self: Manager, entityId: string, initialLevel: FidelityLevel?): ()
	assert(entityId ~= "", "entityId required")
	assert(self._states[entityId] == nil, `entity already registered: {entityId}`)
	local level: FidelityLevel
	if initialLevel == nil then
		level = "F0"
	else
		level = initialLevel
	end
	assert(isLevel(level), "initialLevel must be F0-F4")
	self._states[entityId] = {
		level = level,
		pendingLevel = nil,
		pendingReason = nil,
		pendingSince = nil,
		lastTransitionAt = -math.huge,
		lastEvaluatedAt = -math.huge,
	}
	self._metrics.registered += 1
	self._metrics.counts[level] += 1
end

function FidelityManager.unregister(self: Manager, entityId: string): ()
	local state = self._states[entityId]
	assert(state ~= nil, `entity not registered: {entityId}`)
	self._metrics.registered -= 1
	self._metrics.counts[state.level] -= 1
	self._states[entityId] = nil
end

function FidelityManager.getLevel(self: Manager, entityId: string): FidelityLevel
	local state = self._states[entityId]
	assert(state ~= nil, `entity not registered: {entityId}`)
	return state.level
end

function FidelityManager.step(
	self: Manager,
	entityId: string,
	inputs: PolicyInputs,
	nowSeconds: number,
	request: FidelityRequest?
): StepResult
	local state = self._states[entityId]
	assert(state ~= nil, `entity not registered: {entityId}`)
	assertFiniteNonNegative("nowSeconds", nowSeconds)
	assert(nowSeconds >= state.lastEvaluatedAt, "nowSeconds must be monotonic per entity")
	state.lastEvaluatedAt = nowSeconds

	local decision = FidelityManager.evaluate(inputs, self.config, state.level, request)
	local desired: FidelityLevel = decision.level :: FidelityLevel
	if desired == state.level then
		state.pendingLevel = nil
		state.pendingReason = nil
		state.pendingSince = nil
		return {
			changed = false,
			currentLevel = state.level,
			desiredLevel = desired,
			reason = decision.reason,
			blockedReason = nil,
		}
	end

	if state.pendingLevel ~= desired then
		state.pendingLevel = desired
		state.pendingSince = nowSeconds
	end
	state.pendingReason = decision.reason

	local pendingSince = state.pendingSince :: number
	local isPromotion = LEVEL_INDEX[desired] > LEVEL_INDEX[state.level]
	local holdSeconds = if isPromotion
		then self.config.promotionHoldSeconds
		else self.config.demotionHoldSeconds
	if nowSeconds - pendingSince < holdSeconds then
		self._metrics.blockedByHold += 1
		return {
			changed = false,
			currentLevel = state.level,
			desiredLevel = desired,
			reason = decision.reason,
			blockedReason = "hold",
		}
	end

	if nowSeconds - state.lastTransitionAt < self.config.transitionCooldownSeconds then
		self._metrics.blockedByCooldown += 1
		return {
			changed = false,
			currentLevel = state.level,
			desiredLevel = desired,
			reason = decision.reason,
			blockedReason = "cooldown",
		}
	end

	local previousLevel: FidelityLevel = state.level
	if not isPromotion then
		if self.adapter == nil or self.adapter.captureBeforeDemotion == nil then
			self._metrics.blockedByCapture += 1
			return {
				changed = false,
				currentLevel = state.level,
				desiredLevel = desired,
				reason = decision.reason,
				blockedReason = "capture-required",
			}
		end
		self.adapter.captureBeforeDemotion(entityId, previousLevel, desired)
		self._metrics.captureCalls += 1
	end

	if self.adapter ~= nil and self.adapter.applyTransition ~= nil then
		self.adapter.applyTransition(entityId, previousLevel, desired, decision.reason)
	end

	self._metrics.counts[previousLevel] -= 1
	self._metrics.counts[desired] += 1
	state.level = desired
	state.pendingLevel = nil
	state.pendingReason = nil
	state.pendingSince = nil
	state.lastTransitionAt = nowSeconds
	self._metrics.transitions += 1
	if isPromotion then
		self._metrics.promotions += 1
	else
		self._metrics.demotions += 1
	end

	return {
		changed = true,
		currentLevel = desired,
		desiredLevel = desired,
		reason = decision.reason,
		blockedReason = nil,
	}
end

function FidelityManager.getMetrics(self: Manager): Metrics
	local counts: LevelCounts = {
		F0 = self._metrics.counts.F0,
		F1 = self._metrics.counts.F1,
		F2 = self._metrics.counts.F2,
		F3 = self._metrics.counts.F3,
		F4 = self._metrics.counts.F4,
	}
	return table.freeze({
		registered = self._metrics.registered,
		counts = table.freeze(counts),
		transitions = self._metrics.transitions,
		promotions = self._metrics.promotions,
		demotions = self._metrics.demotions,
		captureCalls = self._metrics.captureCalls,
		blockedByHold = self._metrics.blockedByHold,
		blockedByCooldown = self._metrics.blockedByCooldown,
		blockedByCapture = self._metrics.blockedByCapture,
	})
end

return table.freeze(FidelityManager)
