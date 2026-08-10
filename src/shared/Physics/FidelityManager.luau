--!strict

local FidelityManager = {}
FidelityManager.__index = FidelityManager

export type Fidelity = "F0" | "F1" | "F2" | "F3" | "F4"
export type WorldEntityId = string
export type PersistentState = { [string]: any }

export type PolicyInput = {
	distanceStuds: number,
	isVisible: boolean,
	observationStrength: number,
	secondsSinceInteraction: number?,
	significance: number,
	networkRelevance: number,
	isMoving: boolean?,
	entityRelevance: number?,
}

export type PolicyConfig = {
	structuralDistanceStuds: number,
	renderDistanceStuds: number,
	interactiveDistanceStuds: number,
	heroDistanceStuds: number,
	observedRenderThreshold: number,
	observedInteractiveThreshold: number,
	networkRenderThreshold: number,
	networkInteractiveThreshold: number,
	heroSignificanceThreshold: number,
	heroEntityRelevanceThreshold: number,
	interactiveInteractionSeconds: number,
	heroInteractionSeconds: number,
}

export type ManagerConfig = {
	policy: PolicyConfig?,
	promotionHoldSeconds: number?,
	demotionHoldSeconds: number?,
	transitionCooldownSeconds: number?,
}

export type TransitionAdapter = {
	captureBeforeDemotion: (WorldEntityId, Fidelity, Fidelity) -> PersistentState,
	applyTransition: (WorldEntityId, Fidelity, Fidelity, PersistentState?) -> (),
}

export type TransitionResult = {
	changed: boolean,
	from: Fidelity,
	to: Fidelity,
	reason: string,
	blockedBy: string?,
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
	hysteresisBlocks: number,
	cooldownBlocks: number,
	captureFailures: number,
	transitionFailures: number,
	lastTransitionReason: { [WorldEntityId]: string },
}

type Entry = {
	fidelity: Fidelity,
	pendingTarget: Fidelity?,
	pendingReason: string?,
	pendingSince: number?,
	lastTransitionAt: number?,
	lastEvaluationAt: number?,
}

type ManagerState = {
	config: {
		policy: PolicyConfig,
		promotionHoldSeconds: number,
		demotionHoldSeconds: number,
		transitionCooldownSeconds: number,
	},
	adapter: TransitionAdapter,
	entries: { [WorldEntityId]: Entry },
	metrics: Metrics,
}

type Manager = typeof(setmetatable({} :: ManagerState, FidelityManager))

local FIDELITY_RANK: { [Fidelity]: number } = {
	F0 = 0,
	F1 = 1,
	F2 = 2,
	F3 = 3,
	F4 = 4,
}

local DEFAULT_POLICY: PolicyConfig = table.freeze({
	structuralDistanceStuds = 512,
	renderDistanceStuds = 256,
	interactiveDistanceStuds = 96,
	heroDistanceStuds = 28,
	observedRenderThreshold = 0.2,
	observedInteractiveThreshold = 0.75,
	networkRenderThreshold = 0.35,
	networkInteractiveThreshold = 0.75,
	heroSignificanceThreshold = 0.9,
	heroEntityRelevanceThreshold = 0.9,
	interactiveInteractionSeconds = 6,
	heroInteractionSeconds = 1.25,
})

local function assertFinite(name: string, value: number)
	assert(value == value and value ~= math.huge and value ~= -math.huge, `{name} must be finite`)
end

local function assertUnitInterval(name: string, value: number)
	assertFinite(name, value)
	assert(value >= 0 and value <= 1, `{name} must be in [0, 1]`)
end

local function rank(fidelity: Fidelity): number
	local value = FIDELITY_RANK[fidelity]
	assert(value ~= nil, `invalid fidelity {fidelity}`)
	return value
end

local function validatePolicyConfig(config: PolicyConfig)
	assertFinite("structuralDistanceStuds", config.structuralDistanceStuds)
	assertFinite("renderDistanceStuds", config.renderDistanceStuds)
	assertFinite("interactiveDistanceStuds", config.interactiveDistanceStuds)
	assertFinite("heroDistanceStuds", config.heroDistanceStuds)
	assert(config.heroDistanceStuds >= 0, "heroDistanceStuds must be non-negative")
	assert(
		config.heroDistanceStuds <= config.interactiveDistanceStuds
			and config.interactiveDistanceStuds <= config.renderDistanceStuds
			and config.renderDistanceStuds <= config.structuralDistanceStuds,
		"distance thresholds must satisfy hero <= interactive <= render <= structural"
	)
	assertUnitInterval("observedRenderThreshold", config.observedRenderThreshold)
	assertUnitInterval("observedInteractiveThreshold", config.observedInteractiveThreshold)
	assertUnitInterval("networkRenderThreshold", config.networkRenderThreshold)
	assertUnitInterval("networkInteractiveThreshold", config.networkInteractiveThreshold)
	assertUnitInterval("heroSignificanceThreshold", config.heroSignificanceThreshold)
	assertUnitInterval("heroEntityRelevanceThreshold", config.heroEntityRelevanceThreshold)
	assertFinite("interactiveInteractionSeconds", config.interactiveInteractionSeconds)
	assertFinite("heroInteractionSeconds", config.heroInteractionSeconds)
	assert(config.interactiveInteractionSeconds >= 0, "interactiveInteractionSeconds must be non-negative")
	assert(config.heroInteractionSeconds >= 0, "heroInteractionSeconds must be non-negative")
	assert(
		config.heroInteractionSeconds <= config.interactiveInteractionSeconds,
		"heroInteractionSeconds must not exceed interactiveInteractionSeconds"
	)
end

local function clonePolicyConfig(override: PolicyConfig?): PolicyConfig
	if override == nil then
		return DEFAULT_POLICY
	end
	validatePolicyConfig(override)
	return table.freeze({
		structuralDistanceStuds = override.structuralDistanceStuds,
		renderDistanceStuds = override.renderDistanceStuds,
		interactiveDistanceStuds = override.interactiveDistanceStuds,
		heroDistanceStuds = override.heroDistanceStuds,
		observedRenderThreshold = override.observedRenderThreshold,
		observedInteractiveThreshold = override.observedInteractiveThreshold,
		networkRenderThreshold = override.networkRenderThreshold,
		networkInteractiveThreshold = override.networkInteractiveThreshold,
		heroSignificanceThreshold = override.heroSignificanceThreshold,
		heroEntityRelevanceThreshold = override.heroEntityRelevanceThreshold,
		interactiveInteractionSeconds = override.interactiveInteractionSeconds,
		heroInteractionSeconds = override.heroInteractionSeconds,
	})
end

local function validateInput(input: PolicyInput)
	assertFinite("distanceStuds", input.distanceStuds)
	assert(input.distanceStuds >= 0, "distanceStuds must be non-negative")
	assertUnitInterval("observationStrength", input.observationStrength)
	assertUnitInterval("significance", input.significance)
	assertUnitInterval("networkRelevance", input.networkRelevance)
	if input.entityRelevance ~= nil then
		assertUnitInterval("entityRelevance", input.entityRelevance)
	end
	if input.secondsSinceInteraction ~= nil then
		assertFinite("secondsSinceInteraction", input.secondsSinceInteraction)
		assert(input.secondsSinceInteraction >= 0, "secondsSinceInteraction must be non-negative")
	end
end

local function copyCounts(counts: FidelityCounts): FidelityCounts
	return {
		F0 = counts.F0,
		F1 = counts.F1,
		F2 = counts.F2,
		F3 = counts.F3,
		F4 = counts.F4,
	}
end

local function cloneReasons(reasons: { [WorldEntityId]: string }): { [WorldEntityId]: string }
	return table.clone(reasons)
end

function FidelityManager.evaluateTarget(input: PolicyInput, policyOverride: PolicyConfig?): Fidelity
	validateInput(input)
	local policy = policyOverride or DEFAULT_POLICY
	if policyOverride ~= nil then
		validatePolicyConfig(policyOverride)
	end

	local target: Fidelity = "F0"
	local recentlyInteracted = input.secondsSinceInteraction
	local entityRelevance = input.entityRelevance or 0
	local moving = input.isMoving == true

	if
		input.distanceStuds <= policy.structuralDistanceStuds
		or input.observationStrength > 0
		or input.significance > 0
		or input.networkRelevance > 0
		or entityRelevance > 0
	then
		target = "F1"
	end

	if
		(
			input.distanceStuds <= policy.renderDistanceStuds
			and (input.isVisible or input.observationStrength >= policy.observedRenderThreshold)
		) or input.networkRelevance >= policy.networkRenderThreshold
	then
		target = "F2"
	end

	if
		input.distanceStuds <= policy.interactiveDistanceStuds
		and (
			moving
			or input.observationStrength >= policy.observedInteractiveThreshold
			or input.networkRelevance >= policy.networkInteractiveThreshold
			or (recentlyInteracted ~= nil and recentlyInteracted <= policy.interactiveInteractionSeconds)
		)
	then
		target = "F3"
	end

	if
		input.distanceStuds <= policy.heroDistanceStuds
		and (
			input.significance >= policy.heroSignificanceThreshold
			or entityRelevance >= policy.heroEntityRelevanceThreshold
			or (recentlyInteracted ~= nil and recentlyInteracted <= policy.heroInteractionSeconds)
		)
	then
		target = "F4"
	end

	return target
end

function FidelityManager.new(config: ManagerConfig?, adapter: TransitionAdapter): Manager
	assert(adapter ~= nil, "TransitionAdapter is required")
	assert(type(adapter.captureBeforeDemotion) == "function", "captureBeforeDemotion adapter is required")
	assert(type(adapter.applyTransition) == "function", "applyTransition adapter is required")

	local resolved: ManagerConfig = config or {}
	local promotionHoldSeconds = resolved.promotionHoldSeconds or 0.1
	local demotionHoldSeconds = resolved.demotionHoldSeconds or 1.5
	local transitionCooldownSeconds = resolved.transitionCooldownSeconds or 0.25
	assertFinite("promotionHoldSeconds", promotionHoldSeconds)
	assertFinite("demotionHoldSeconds", demotionHoldSeconds)
	assertFinite("transitionCooldownSeconds", transitionCooldownSeconds)
	assert(promotionHoldSeconds >= 0, "promotionHoldSeconds must be non-negative")
	assert(demotionHoldSeconds >= 0, "demotionHoldSeconds must be non-negative")
	assert(transitionCooldownSeconds >= 0, "transitionCooldownSeconds must be non-negative")

	local state: ManagerState = {
		config = {
			policy = clonePolicyConfig(resolved.policy),
			promotionHoldSeconds = promotionHoldSeconds,
			demotionHoldSeconds = demotionHoldSeconds,
			transitionCooldownSeconds = transitionCooldownSeconds,
		},
		adapter = adapter,
		entries = {},
		metrics = {
			registered = 0,
			counts = {
				F0 = 0,
				F1 = 0,
				F2 = 0,
				F3 = 0,
				F4 = 0,
			},
			transitions = 0,
			promotions = 0,
			demotions = 0,
			hysteresisBlocks = 0,
			cooldownBlocks = 0,
			captureFailures = 0,
			transitionFailures = 0,
			lastTransitionReason = {},
		},
	}
	return setmetatable(state, FidelityManager)
end

function FidelityManager.register(self: Manager, entityId: WorldEntityId, initialFidelity: Fidelity?)
	assert(entityId ~= "", "WorldEntityId must not be empty")
	assert(self.entries[entityId] == nil, `duplicate fidelity registration: {entityId}`)
	local fidelity: Fidelity = initialFidelity or "F0"
	rank(fidelity)
	self.entries[entityId] = {
		fidelity = fidelity,
		pendingTarget = nil,
		pendingReason = nil,
		pendingSince = nil,
		lastTransitionAt = nil,
		lastEvaluationAt = nil,
	}
	self.metrics.registered += 1
	self.metrics.counts[fidelity] += 1
end

function FidelityManager.unregister(self: Manager, entityId: WorldEntityId): Fidelity?
	local entry = self.entries[entityId]
	if entry == nil then
		return nil
	end
	self.entries[entityId] = nil
	self.metrics.registered -= 1
	self.metrics.counts[entry.fidelity] -= 1
	self.metrics.lastTransitionReason[entityId] = nil
	return entry.fidelity
end

function FidelityManager.getFidelity(self: Manager, entityId: WorldEntityId): Fidelity?
	local entry = self.entries[entityId]
	return if entry == nil then nil else entry.fidelity
end

function FidelityManager.getPendingTarget(self: Manager, entityId: WorldEntityId): Fidelity?
	local entry = self.entries[entityId]
	return if entry == nil then nil else entry.pendingTarget
end

local function unchangedResult(fidelity: Fidelity, reason: string, blockedBy: string?): TransitionResult
	return {
		changed = false,
		from = fidelity,
		to = fidelity,
		reason = reason,
		blockedBy = blockedBy,
	}
end

function FidelityManager.request(
	self: Manager,
	entityId: WorldEntityId,
	target: Fidelity,
	reason: string,
	nowSeconds: number
): TransitionResult
	assert(reason ~= "", "transition reason must not be empty")
	assertFinite("nowSeconds", nowSeconds)
	rank(target)

	local entry = self.entries[entityId]
	assert(entry ~= nil, `unknown fidelity entity: {entityId}`)
	if entry.lastEvaluationAt ~= nil then
		assert(nowSeconds >= entry.lastEvaluationAt, "fidelity time must be monotonic per entity")
	end
	entry.lastEvaluationAt = nowSeconds

	local current: Fidelity = entry.fidelity
	if target == current then
		entry.pendingTarget = nil
		entry.pendingReason = nil
		entry.pendingSince = nil
		return unchangedResult(current, reason, nil)
	end

	if entry.pendingTarget ~= target or entry.pendingReason ~= reason then
		entry.pendingTarget = target
		entry.pendingReason = reason
		entry.pendingSince = nowSeconds
		self.metrics.hysteresisBlocks += 1
		return unchangedResult(current, reason, "hysteresis")
	end

	local promoting = rank(target) > rank(current)
	local holdSeconds = if promoting
		then self.config.promotionHoldSeconds
		else self.config.demotionHoldSeconds
	local pendingSince = entry.pendingSince :: number
	if nowSeconds - pendingSince < holdSeconds then
		self.metrics.hysteresisBlocks += 1
		return unchangedResult(current, reason, "hysteresis")
	end

	if
		entry.lastTransitionAt ~= nil
		and nowSeconds - entry.lastTransitionAt < self.config.transitionCooldownSeconds
	then
		self.metrics.cooldownBlocks += 1
		return unchangedResult(current, reason, "cooldown")
	end

	local capturedState: PersistentState? = nil
	if not promoting then
		local captureOk, captureResult = pcall(self.adapter.captureBeforeDemotion, entityId, current, target)
		if not captureOk then
			self.metrics.captureFailures += 1
			return unchangedResult(current, reason, "capture_failed")
		end
		if type(captureResult) ~= "table" then
			self.metrics.captureFailures += 1
			return unchangedResult(current, reason, "capture_failed")
		end
		capturedState = captureResult :: PersistentState
	end

	local transitionOk = pcall(self.adapter.applyTransition, entityId, current, target, capturedState)
	if not transitionOk then
		self.metrics.transitionFailures += 1
		return unchangedResult(current, reason, "transition_failed")
	end

	self.metrics.counts[current] -= 1
	self.metrics.counts[target] += 1
	self.metrics.transitions += 1
	if promoting then
		self.metrics.promotions += 1
	else
		self.metrics.demotions += 1
	end
	self.metrics.lastTransitionReason[entityId] = reason

	entry.fidelity = target
	entry.pendingTarget = nil
	entry.pendingReason = nil
	entry.pendingSince = nil
	entry.lastTransitionAt = nowSeconds

	return {
		changed = true,
		from = current,
		to = target,
		reason = reason,
		blockedBy = nil,
	}
end

function FidelityManager.update(
	self: Manager,
	entityId: WorldEntityId,
	input: PolicyInput,
	nowSeconds: number
): TransitionResult
	local target: Fidelity = FidelityManager.evaluateTarget(input, self.config.policy)
	return FidelityManager.request(self, entityId, target, "policy", nowSeconds)
end

function FidelityManager.getMetrics(self: Manager): Metrics
	return {
		registered = self.metrics.registered,
		counts = copyCounts(self.metrics.counts),
		transitions = self.metrics.transitions,
		promotions = self.metrics.promotions,
		demotions = self.metrics.demotions,
		hysteresisBlocks = self.metrics.hysteresisBlocks,
		cooldownBlocks = self.metrics.cooldownBlocks,
		captureFailures = self.metrics.captureFailures,
		transitionFailures = self.metrics.transitionFailures,
		lastTransitionReason = cloneReasons(self.metrics.lastTransitionReason),
	}
end

return table.freeze(FidelityManager)
