--!strict

export type FidelityLevel = "F0" | "F1" | "F2" | "F3" | "F4"

export type PolicyReason =
	"distance"
	| "visibility"
	| "observation"
	| "interaction"
	| "significance"
	| "network-relevance"
	| "entity-relevance"
	| "no-demand"

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
	maxRegisteredEntities: number,
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

export type BlockedReason = "hold" | "cooldown" | "transition-required"

export type StepResult = {
	transitioned: boolean,
	currentLevel: FidelityLevel,
	desiredLevel: FidelityLevel,
	reason: PolicyReason,
	blockedReason: BlockedReason?,
}

export type FidelityCounts = {
	F0: number,
	F1: number,
	F2: number,
	F3: number,
	F4: number,
}

export type Metrics = {
	registered: number,
	counts: FidelityCounts,
	transitions: number,
	promotions: number,
	demotions: number,
	transitionHookCalls: number,
	blockedByHold: number,
	blockedByCooldown: number,
	blockedByMissingTransition: number,
	externalSynchronizations: number,
	registrationCapacityRejections: number,
}

export type TransitionHook = (
	entityId: string,
	fromLevel: FidelityLevel,
	toLevel: FidelityLevel,
	reason: PolicyReason
) -> ()

type EntityState = {
	observedLevel: FidelityLevel,
	pendingLevel: FidelityLevel?,
	pendingSince: number?,
	lastTransitionAt: number,
	lastEvaluatedAt: number,
}

type MutableMetrics = {
	registered: number,
	counts: FidelityCounts,
	transitions: number,
	promotions: number,
	demotions: number,
	transitionHookCalls: number,
	blockedByHold: number,
	blockedByCooldown: number,
	blockedByMissingTransition: number,
	externalSynchronizations: number,
	registrationCapacityRejections: number,
}

local FidelityManager = {}
FidelityManager.__index = FidelityManager

type ManagerImpl = {
	config: PolicyConfig,
}

export type Manager = typeof(setmetatable({} :: ManagerImpl, FidelityManager))

type PrivateState = {
	states: { [string]: EntityState },
	metrics: MutableMetrics,
}

-- Mutable manager state is intentionally capability-private. The weak keys keep
-- the backing records bounded by manager lifetime without exposing a second
-- write path around registration, timing, transition, or metrics invariants.
local PRIVATE_STATE = setmetatable({}, { __mode = "k" }) :: any

local function privateState(self: Manager): PrivateState
	local state = PRIVATE_STATE[self] :: PrivateState?
	assert(state ~= nil, "invalid FidelityManager capability")
	return state
end

local LEVEL_INDEX: { [FidelityLevel]: number } = {
	F0 = 0,
	F1 = 1,
	F2 = 2,
	F3 = 3,
	F4 = 4,
}
table.freeze(LEVEL_INDEX)

local DEFAULT_CONFIG: PolicyConfig = {
	maxRegisteredEntities = 4096,
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
}
table.freeze(DEFAULT_CONFIG)

local function isLevel(value: unknown): boolean
	return value == "F0" or value == "F1" or value == "F2" or value == "F3" or value == "F4"
end

local function assertEntityId(value: unknown): string
	assert(type(value) == "string", "entityId must satisfy the WorldEntityId string contract")
	local entityId = value :: string
	assert(
		entityId ~= "" and #entityId <= 256 and string.find(entityId, "%c") == nil,
		"entityId must satisfy the WorldEntityId value contract"
	)
	return entityId
end

local function levelIndex(level: FidelityLevel): number
	return LEVEL_INDEX[level]
end

local function isFinite(value: number): boolean
	return value == value and value > -math.huge and value < math.huge
end

local function validateUnit(name: string, value: number): ()
	assert(value == value and value >= 0 and value <= 1, `{name} must be in [0, 1]`)
end

local function validateNonNegative(name: string, value: number): ()
	assert(value == value and value >= 0, `{name} must be non-negative`)
end

local function validateFiniteNonNegative(name: string, value: number): ()
	assert(isFinite(value) and value >= 0, `{name} must be finite and non-negative`)
end

local function validateConfig(config: PolicyConfig): ()
	assert(
		config.maxRegisteredEntities >= 1
			and config.maxRegisteredEntities < math.huge
			and config.maxRegisteredEntities == math.floor(config.maxRegisteredEntities),
		"maxRegisteredEntities must be a positive finite integer"
	)
	validateFiniteNonNegative("heroDistanceStuds", config.heroDistanceStuds)
	validateFiniteNonNegative("interactiveDistanceStuds", config.interactiveDistanceStuds)
	validateFiniteNonNegative("renderDistanceStuds", config.renderDistanceStuds)
	validateFiniteNonNegative("structuralDistanceStuds", config.structuralDistanceStuds)
	assert(
		config.heroDistanceStuds <= config.interactiveDistanceStuds,
		"hero distance must not exceed interactive"
	)
	assert(
		config.interactiveDistanceStuds <= config.renderDistanceStuds,
		"interactive distance must not exceed render"
	)
	assert(
		config.renderDistanceStuds <= config.structuralDistanceStuds,
		"render distance must not exceed structural"
	)
	validateFiniteNonNegative("distanceHysteresisStuds", config.distanceHysteresisStuds)
	validateFiniteNonNegative("interactionGraceSeconds", config.interactionGraceSeconds)
	validateFiniteNonNegative("promotionHoldSeconds", config.promotionHoldSeconds)
	validateFiniteNonNegative("demotionHoldSeconds", config.demotionHoldSeconds)
	validateFiniteNonNegative("transitionCooldownSeconds", config.transitionCooldownSeconds)
	assert(
		config.structuralDistanceStuds + config.distanceHysteresisStuds < math.huge,
		"structural distance plus hysteresis must remain finite"
	)
	validateUnit("significanceKeepaliveThreshold", config.significanceKeepaliveThreshold)
	validateUnit("activeRelevanceThreshold", config.activeRelevanceThreshold)
	validateUnit("heroRelevanceThreshold", config.heroRelevanceThreshold)
	assert(
		config.activeRelevanceThreshold <= config.heroRelevanceThreshold,
		"active relevance must not exceed hero relevance"
	)
end

local function validateInputs(inputs: PolicyInputs): ()
	validateFiniteNonNegative("distanceStuds", inputs.distanceStuds)
	-- `math.huge` intentionally means the entity has never been interacted with.
	validateNonNegative("secondsSinceInteraction", inputs.secondsSinceInteraction)
	validateUnit("significance", inputs.significance)
	validateUnit("networkRelevance", inputs.networkRelevance)
	validateUnit("entityRelevance", inputs.entityRelevance)
end

local function copyConfig(config: PolicyConfig): PolicyConfig
	return {
		maxRegisteredEntities = config.maxRegisteredEntities,
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
	if levelIndex(current) >= levelIndex(minimum) then
		return current
	end
	return minimum
end

local function distanceLimit(
	base: number,
	currentIndex: number,
	retainedIndex: number,
	hysteresis: number
): number
	if currentIndex >= retainedIndex then
		return base + hysteresis
	end
	return base
end

local function adjustCount(counts: FidelityCounts, level: FidelityLevel, delta: number): ()
	if level == "F0" then
		counts.F0 += delta
	elseif level == "F1" then
		counts.F1 += delta
	elseif level == "F2" then
		counts.F2 += delta
	elseif level == "F3" then
		counts.F3 += delta
	else
		counts.F4 += delta
	end
end

local function frozenCounts(metrics: MutableMetrics): FidelityCounts
	return table.freeze({
		F0 = metrics.counts.F0,
		F1 = metrics.counts.F1,
		F2 = metrics.counts.F2,
		F3 = metrics.counts.F3,
		F4 = metrics.counts.F4,
	})
end

function FidelityManager.defaultConfig(): PolicyConfig
	local config = copyConfig(DEFAULT_CONFIG)
	return table.freeze(config)
end

local function evaluatePolicy(
	inputs: PolicyInputs,
	config: PolicyConfig?,
	currentLevel: FidelityLevel?
): (FidelityLevel, PolicyReason)
	local resolvedConfig = config or DEFAULT_CONFIG
	local resolvedCurrent: FidelityLevel
	if currentLevel == nil then
		resolvedCurrent = "F0"
	else
		resolvedCurrent = currentLevel
	end
	assert(isLevel(resolvedCurrent), "currentLevel must be F0-F4")
	validateConfig(resolvedConfig)
	validateInputs(inputs)

	local currentIndex = levelIndex(resolvedCurrent)
	local hysteresis = resolvedConfig.distanceHysteresisStuds
	local structuralLimit = distanceLimit(resolvedConfig.structuralDistanceStuds, currentIndex, 1, hysteresis)
	local renderLimit = distanceLimit(resolvedConfig.renderDistanceStuds, currentIndex, 2, hysteresis)
	local interactiveLimit =
		distanceLimit(resolvedConfig.interactiveDistanceStuds, currentIndex, 3, hysteresis)
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
	local closeHeroDemand = inputs.distanceStuds <= heroLimit
		and (inputs.directlyObserved or recentlyInteracted)
	local visibleHeroDemand = inputs.visible and heroRelevance >= resolvedConfig.heroRelevanceThreshold
	if closeHeroDemand or visibleHeroDemand then
		desired = "F4"
	end

	local reason: PolicyReason
	if desired == "F4" then
		if closeHeroDemand then
			if inputs.directlyObserved then
				reason = "observation"
			else
				reason = "interaction"
			end
		elseif
			inputs.significance >= inputs.networkRelevance
			and inputs.significance >= inputs.entityRelevance
		then
			reason = "significance"
		elseif inputs.networkRelevance >= inputs.entityRelevance then
			reason = "network-relevance"
		else
			reason = "entity-relevance"
		end
	elseif desired == "F3" then
		if inputs.directlyObserved then
			reason = "observation"
		elseif recentlyInteracted then
			reason = "interaction"
		elseif
			inputs.networkRelevance >= resolvedConfig.activeRelevanceThreshold
			and inputs.networkRelevance >= inputs.entityRelevance
		then
			reason = "network-relevance"
		elseif inputs.entityRelevance >= resolvedConfig.activeRelevanceThreshold then
			reason = "entity-relevance"
		else
			reason = "distance"
		end
	elseif desired == "F2" then
		if inputs.visible then
			reason = "visibility"
		else
			reason = "distance"
		end
	elseif desired == "F1" then
		if inputs.significance >= resolvedConfig.significanceKeepaliveThreshold then
			reason = "significance"
		else
			reason = "distance"
		end
	else
		reason = "no-demand"
	end

	return desired, reason
end

FidelityManager.evaluatePolicy = evaluatePolicy

local function selectDesiredLevel(
	inputs: PolicyInputs,
	config: PolicyConfig?,
	currentLevel: FidelityLevel?
): FidelityLevel
	local desired: FidelityLevel = evaluatePolicy(inputs, config, currentLevel)
	return desired
end

FidelityManager.selectDesiredLevel = selectDesiredLevel

function FidelityManager.new(config: PolicyConfig?): Manager
	local sourceConfig: PolicyConfig
	if config == nil then
		sourceConfig = DEFAULT_CONFIG
	else
		sourceConfig = config
	end
	local resolvedConfig = copyConfig(sourceConfig)
	validateConfig(resolvedConfig)

	local manager = setmetatable({
		config = table.freeze(resolvedConfig),
	} :: ManagerImpl, FidelityManager) :: Manager
	PRIVATE_STATE[manager] = {
		states = {},
		metrics = {
			registered = 0,
			counts = { F0 = 0, F1 = 0, F2 = 0, F3 = 0, F4 = 0 },
			transitions = 0,
			promotions = 0,
			demotions = 0,
			transitionHookCalls = 0,
			blockedByHold = 0,
			blockedByCooldown = 0,
			blockedByMissingTransition = 0,
			externalSynchronizations = 0,
			registrationCapacityRejections = 0,
		},
	}
	table.freeze(manager)
	return manager
end

function FidelityManager.register(self: Manager, entityId: string, currentLevel: FidelityLevel?): ()
	entityId = assertEntityId(entityId)
	local private = privateState(self)
	assert(private.states[entityId] == nil, `entity already registered: {entityId}`)
	if private.metrics.registered >= self.config.maxRegisteredEntities then
		private.metrics.registrationCapacityRejections += 1
		error(`fidelity registration capacity reached: {self.config.maxRegisteredEntities}`)
	end

	local level: FidelityLevel
	if currentLevel == nil then
		level = "F0"
	else
		level = currentLevel
	end
	assert(isLevel(level), "currentLevel must be F0-F4")

	private.states[entityId] = {
		observedLevel = level,
		pendingLevel = nil,
		pendingSince = nil,
		lastTransitionAt = -math.huge,
		lastEvaluatedAt = -math.huge,
	}
	private.metrics.registered += 1
	adjustCount(private.metrics.counts, level, 1)
end

function FidelityManager.unregister(self: Manager, entityId: string): ()
	entityId = assertEntityId(entityId)
	local private = privateState(self)
	local state = private.states[entityId]
	assert(state ~= nil, `entity not registered: {entityId}`)
	private.metrics.registered -= 1
	adjustCount(private.metrics.counts, state.observedLevel, -1)
	private.states[entityId] = nil
end

function FidelityManager.getObservedLevel(self: Manager, entityId: string): FidelityLevel
	entityId = assertEntityId(entityId)
	local state = privateState(self).states[entityId]
	assert(state ~= nil, `entity not registered: {entityId}`)
	return state.observedLevel
end

local function synchronizeObservedLevel(
	private: PrivateState,
	state: EntityState,
	currentLevel: FidelityLevel,
	nowSeconds: number
): ()
	if currentLevel == state.observedLevel then
		return
	end

	adjustCount(private.metrics.counts, state.observedLevel, -1)
	adjustCount(private.metrics.counts, currentLevel, 1)
	private.metrics.externalSynchronizations += 1
	state.observedLevel = currentLevel
	state.pendingLevel = nil
	state.pendingSince = nil
	state.lastTransitionAt = nowSeconds
end

function FidelityManager.step(
	self: Manager,
	entityId: string,
	currentLevel: FidelityLevel,
	inputs: PolicyInputs,
	nowSeconds: number,
	applyTransition: TransitionHook?
): StepResult
	entityId = assertEntityId(entityId)
	local private = privateState(self)
	local state = private.states[entityId]
	assert(state ~= nil, `entity not registered: {entityId}`)
	assert(isLevel(currentLevel), "currentLevel must be F0-F4")
	assert(
		isFinite(nowSeconds) and nowSeconds >= state.lastEvaluatedAt,
		"nowSeconds must be finite and monotonic per entity"
	)

	-- Policy validation is part of the acceptance boundary. Compute it before
	-- mutating manager time, fidelity mirrors, pending targets, or metrics so a
	-- rejected step is observationally atomic.
	local desired: FidelityLevel, reason: PolicyReason = evaluatePolicy(inputs, self.config, currentLevel)

	state.lastEvaluatedAt = nowSeconds
	synchronizeObservedLevel(private, state, currentLevel, nowSeconds)

	if desired == currentLevel then
		state.pendingLevel = nil
		state.pendingSince = nil
		return {
			transitioned = false,
			currentLevel = currentLevel,
			desiredLevel = desired,
			reason = reason,
			blockedReason = nil,
		}
	end

	if state.pendingLevel ~= desired then
		state.pendingLevel = desired
		state.pendingSince = nowSeconds
	end

	local pendingSince = state.pendingSince :: number
	local isPromotion = levelIndex(desired) > levelIndex(currentLevel)
	local holdSeconds = if isPromotion
		then self.config.promotionHoldSeconds
		else self.config.demotionHoldSeconds
	if nowSeconds - pendingSince < holdSeconds then
		private.metrics.blockedByHold += 1
		return {
			transitioned = false,
			currentLevel = currentLevel,
			desiredLevel = desired,
			reason = reason,
			blockedReason = "hold",
		}
	end

	if nowSeconds - state.lastTransitionAt < self.config.transitionCooldownSeconds then
		private.metrics.blockedByCooldown += 1
		return {
			transitioned = false,
			currentLevel = currentLevel,
			desiredLevel = desired,
			reason = reason,
			blockedReason = "cooldown",
		}
	end

	if applyTransition == nil then
		private.metrics.blockedByMissingTransition += 1
		return {
			transitioned = false,
			currentLevel = currentLevel,
			desiredLevel = desired,
			reason = reason,
			blockedReason = "transition-required",
		}
	end

	applyTransition(entityId, currentLevel, desired, reason)
	private.metrics.transitionHookCalls += 1
	adjustCount(private.metrics.counts, currentLevel, -1)
	adjustCount(private.metrics.counts, desired, 1)
	state.observedLevel = desired
	state.pendingLevel = nil
	state.pendingSince = nil
	state.lastTransitionAt = nowSeconds
	private.metrics.transitions += 1
	if isPromotion then
		private.metrics.promotions += 1
	else
		private.metrics.demotions += 1
	end

	return {
		transitioned = true,
		currentLevel = desired,
		desiredLevel = desired,
		reason = reason,
		blockedReason = nil,
	}
end

function FidelityManager.getMetrics(self: Manager): Metrics
	local metrics = privateState(self).metrics
	return table.freeze({
		registered = metrics.registered,
		counts = frozenCounts(metrics),
		transitions = metrics.transitions,
		promotions = metrics.promotions,
		demotions = metrics.demotions,
		transitionHookCalls = metrics.transitionHookCalls,
		blockedByHold = metrics.blockedByHold,
		blockedByCooldown = metrics.blockedByCooldown,
		blockedByMissingTransition = metrics.blockedByMissingTransition,
		externalSynchronizations = metrics.externalSynchronizations,
		registrationCapacityRejections = metrics.registrationCapacityRejections,
	})
end

return table.freeze(FidelityManager)
