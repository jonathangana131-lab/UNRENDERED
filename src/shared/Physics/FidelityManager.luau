--!strict

export type FidelityLevel = "F0" | "F1" | "F2" | "F3" | "F4"

export type PolicyInputs = {
	distanceStuds: number,
	visible: boolean,
	directlyObserved: boolean,
	secondsSinceInteraction: number,
	significance: number,
	networkRelevance: number,
	entityRelevance: number,
}

export type PolicyConfig = {
	structuralDistanceStuds: number,
	renderDistanceStuds: number,
	interactiveDistanceStuds: number,
	heroDistanceStuds: number,
	distanceHysteresisStuds: number,
	interactionGraceSeconds: number,
	significanceKeepaliveThreshold: number,
	activeRelevanceThreshold: number,
	heroRelevanceThreshold: number,
	promotionHoldSeconds: number,
	demotionHoldSeconds: number,
	transitionCooldownSeconds: number,
}

export type StepResult = {
	changed: boolean,
	currentLevel: FidelityLevel,
	desiredLevel: FidelityLevel,
	blockedReason: ("hold" | "cooldown" | "capture-required")?,
}

export type Metrics = {
	registered: number,
	counts: { [FidelityLevel]: number },
	transitions: number,
	promotions: number,
	demotions: number,
	captureCalls: number,
	blockedByHold: number,
	blockedByCooldown: number,
	blockedByCapture: number,
}

export type CaptureHook = (entityId: string, fromLevel: FidelityLevel, toLevel: FidelityLevel) -> ()

type EntityState = {
	level: FidelityLevel,
	pendingLevel: FidelityLevel?,
	pendingSince: number?,
	lastTransitionAt: number,
	lastEvaluatedAt: number,
}

type MutableMetrics = {
	registered: number,
	counts: { [FidelityLevel]: number },
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
	significanceKeepaliveThreshold = 0.75,
	activeRelevanceThreshold = 0.8,
	heroRelevanceThreshold = 0.95,
	promotionHoldSeconds = 0.1,
	demotionHoldSeconds = 1.5,
	transitionCooldownSeconds = 0.25,
})

local function isLevel(value: string): boolean
	return LEVEL_INDEX[value :: FidelityLevel] ~= nil
end

local function validateUnit(name: string, value: number)
	assert(value >= 0 and value <= 1, `{name} must be in [0, 1]`)
end

local function validateConfig(config: PolicyConfig)
	assert(config.heroDistanceStuds >= 0, "heroDistanceStuds must be non-negative")
	assert(config.heroDistanceStuds <= config.interactiveDistanceStuds, "hero distance must not exceed interactive")
	assert(config.interactiveDistanceStuds <= config.renderDistanceStuds, "interactive distance must not exceed render")
	assert(config.renderDistanceStuds <= config.structuralDistanceStuds, "render distance must not exceed structural")
	assert(config.distanceHysteresisStuds >= 0, "distanceHysteresisStuds must be non-negative")
	assert(config.interactionGraceSeconds >= 0, "interactionGraceSeconds must be non-negative")
	assert(config.promotionHoldSeconds >= 0, "promotionHoldSeconds must be non-negative")
	assert(config.demotionHoldSeconds >= 0, "demotionHoldSeconds must be non-negative")
	assert(config.transitionCooldownSeconds >= 0, "transitionCooldownSeconds must be non-negative")
	validateUnit("significanceKeepaliveThreshold", config.significanceKeepaliveThreshold)
	validateUnit("activeRelevanceThreshold", config.activeRelevanceThreshold)
	validateUnit("heroRelevanceThreshold", config.heroRelevanceThreshold)
	assert(config.activeRelevanceThreshold <= config.heroRelevanceThreshold, "active relevance must not exceed hero relevance")
end

local function validateInputs(inputs: PolicyInputs)
	assert(inputs.distanceStuds >= 0, "distanceStuds must be non-negative")
	assert(inputs.secondsSinceInteraction >= 0, "secondsSinceInteraction must be non-negative")
	validateUnit("significance", inputs.significance)
	validateUnit("networkRelevance", inputs.networkRelevance)
	validateUnit("entityRelevance", inputs.entityRelevance)
end

local function copyConfig(config: PolicyConfig): PolicyConfig
	return {
		structuralDistanceStuds = config.structuralDistanceStuds,
		renderDistanceStuds = config.renderDistanceStuds,
		interactiveDistanceStuds = config.interactiveDistanceStuds,
		heroDistanceStuds = config.heroDistanceStuds,
		distanceHysteresisStuds = config.distanceHysteresisStuds,
		interactionGraceSeconds = config.interactionGraceSeconds,
		significanceKeepaliveThreshold = config.significanceKeepaliveThreshold,
		activeRelevanceThreshold = config.activeRelevanceThreshold,
		heroRelevanceThreshold = config.heroRelevanceThreshold,
		promotionHoldSeconds = config.promotionHoldSeconds,
		demotionHoldSeconds = config.demotionHoldSeconds,
		transitionCooldownSeconds = config.transitionCooldownSeconds,
	}
end

local function atLeast(current: FidelityLevel, minimum: FidelityLevel): FidelityLevel
	if LEVEL_INDEX[current] >= LEVEL_INDEX[minimum] then
		return current
	end
	return minimum
end

local function distanceLimit(base: number, currentIndex: number, retainedIndex: number, hysteresis: number): number
	if currentIndex >= retainedIndex then
		return base + hysteresis
	end
	return base
end

function FidelityManager.defaultConfig(): PolicyConfig
	return table.freeze(copyConfig(DEFAULT_CONFIG))
end

function FidelityManager.selectDesiredLevel(
	inputs: PolicyInputs,
	config: PolicyConfig?,
	currentLevel: FidelityLevel?
): FidelityLevel
	local resolvedConfig = config or DEFAULT_CONFIG
	local resolvedCurrent = currentLevel or "F0"
	validateConfig(resolvedConfig)
	validateInputs(inputs)
	assert(isLevel(resolvedCurrent), "currentLevel must be F0-F4")

	local currentIndex = LEVEL_INDEX[resolvedCurrent]
	local hysteresis = resolvedConfig.distanceHysteresisStuds
	local structuralLimit = distanceLimit(resolvedConfig.structuralDistanceStuds, currentIndex, 1, hysteresis)
	local renderLimit = distanceLimit(resolvedConfig.renderDistanceStuds, currentIndex, 2, hysteresis)
	local interactiveLimit = distanceLimit(resolvedConfig.interactiveDistanceStuds, currentIndex, 3, hysteresis)
	local heroLimit = distanceLimit(resolvedConfig.heroDistanceStuds, currentIndex, 4, hysteresis)

	local desired: FidelityLevel = "F0"
	if inputs.distanceStuds <= structuralLimit then
		desired = "F1"
	end
	if inputs.distanceStuds <= renderLimit then
		desired = "F2"
	end
	if inputs.distanceStuds <= interactiveLimit then
		desired = "F3"
	end

	if inputs.significance >= resolvedConfig.significanceKeepaliveThreshold then
		desired = atLeast(desired, "F1")
	end
	if inputs.visible then
		desired = atLeast(desired, "F2")
	end

	local recentlyInteracted = inputs.secondsSinceInteraction <= resolvedConfig.interactionGraceSeconds
	if inputs.directlyObserved or recentlyInteracted then
		desired = atLeast(desired, "F3")
	end

	local activeRelevance = math.max(inputs.networkRelevance, inputs.entityRelevance)
	if activeRelevance >= resolvedConfig.activeRelevanceThreshold then
		desired = atLeast(desired, "F3")
	end

	local heroRelevance = math.max(inputs.significance, inputs.networkRelevance, inputs.entityRelevance)
	local locallyPresent = inputs.visible or inputs.directlyObserved or inputs.distanceStuds <= renderLimit
	local closeHeroDemand = inputs.distanceStuds <= heroLimit and (inputs.directlyObserved or recentlyInteracted)
	if closeHeroDemand or (heroRelevance >= resolvedConfig.heroRelevanceThreshold and locallyPresent) then
		desired = "F4"
	end

	return desired
end

function FidelityManager.new(config: PolicyConfig?): Manager
	local resolvedConfig = copyConfig(config or DEFAULT_CONFIG)
	validateConfig(resolvedConfig)

	local self: ManagerImpl = {
		config = table.freeze(resolvedConfig),
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

function FidelityManager.register(self: Manager, entityId: string, initialLevel: FidelityLevel?)
	assert(entityId ~= "", "entityId required")
	assert(self._states[entityId] == nil, `entity already registered: {entityId}`)
	local level = initialLevel or "F0"
	assert(isLevel(level), "initialLevel must be F0-F4")

	self._states[entityId] = {
		level = level,
		pendingLevel = nil,
		pendingSince = nil,
		lastTransitionAt = -math.huge,
		lastEvaluatedAt = -math.huge,
	}
	self._metrics.registered += 1
	self._metrics.counts[level] += 1
end

function FidelityManager.unregister(self: Manager, entityId: string)
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
	captureBeforeDemotion: CaptureHook?
): StepResult
	local state = self._states[entityId]
	assert(state ~= nil, `entity not registered: {entityId}`)
	assert(nowSeconds >= state.lastEvaluatedAt, "nowSeconds must be monotonic per entity")
	state.lastEvaluatedAt = nowSeconds

	local desired = FidelityManager.selectDesiredLevel(inputs, self.config, state.level)
	if desired == state.level then
		state.pendingLevel = nil
		state.pendingSince = nil
		return {
			changed = false,
			currentLevel = state.level,
			desiredLevel = desired,
			blockedReason = nil,
		}
	end

	if state.pendingLevel ~= desired then
		state.pendingLevel = desired
		state.pendingSince = nowSeconds
	end

	local pendingSince = state.pendingSince :: number
	local isPromotion = LEVEL_INDEX[desired] > LEVEL_INDEX[state.level]
	local holdSeconds = if isPromotion then self.config.promotionHoldSeconds else self.config.demotionHoldSeconds
	if nowSeconds - pendingSince < holdSeconds then
		self._metrics.blockedByHold += 1
		return {
			changed = false,
			currentLevel = state.level,
			desiredLevel = desired,
			blockedReason = "hold",
		}
	end

	if nowSeconds - state.lastTransitionAt < self.config.transitionCooldownSeconds then
		self._metrics.blockedByCooldown += 1
		return {
			changed = false,
			currentLevel = state.level,
			desiredLevel = desired,
			blockedReason = "cooldown",
		}
	end

	local previousLevel = state.level
	if not isPromotion then
		if captureBeforeDemotion == nil then
			self._metrics.blockedByCapture += 1
			return {
				changed = false,
				currentLevel = state.level,
				desiredLevel = desired,
				blockedReason = "capture-required",
			}
		end
		captureBeforeDemotion(entityId, previousLevel, desired)
		self._metrics.captureCalls += 1
	end

	self._metrics.counts[previousLevel] -= 1
	self._metrics.counts[desired] += 1
	state.level = desired
	state.pendingLevel = nil
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
		blockedReason = nil,
	}
end

function FidelityManager.getMetrics(self: Manager): Metrics
	local counts = table.freeze({
		F0 = self._metrics.counts.F0,
		F1 = self._metrics.counts.F1,
		F2 = self._metrics.counts.F2,
		F3 = self._metrics.counts.F3,
		F4 = self._metrics.counts.F4,
	})
	return table.freeze({
		registered = self._metrics.registered,
		counts = counts,
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
