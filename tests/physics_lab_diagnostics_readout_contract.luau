local fs = require("@lune/fs")

local DIAGNOSTICS_SOURCE = "src/server/PhysicsLab/PhysicsLabStudioDiagnostics.luau"

local STRING_SENTINELS = {
	UNRENDERED_WorldEntityId = "__STR_WORLD_ENTITY_ID__",
	BillboardGui = "__STR_BILLBOARD_GUI__",
	Readout = "__STR_READOUT__",
	TextLabel = "__STR_TEXT_LABEL__",
	UNRENDERED_RepresentationClass = "__STR_REPRESENTATION_CLASS__",
}

local function longBracketEnd(source: string, openerStart: number): number?
	if string.sub(source, openerStart, openerStart) ~= "[" then
		return nil
	end

	local cursor = openerStart + 1
	while string.sub(source, cursor, cursor) == "=" do
		cursor += 1
	end
	if string.sub(source, cursor, cursor) ~= "[" then
		return nil
	end

	local equals = string.sub(source, openerStart + 1, cursor - 1)
	local closer = "]" .. equals .. "]"
	local _, closeEnd = string.find(source, closer, cursor + 1, true)
	return closeEnd or #source
end

local function quotedEnd(source: string, quoteStart: number, quote: string): number
	local cursor = quoteStart + 1
	while cursor <= #source do
		local character = string.sub(source, cursor, cursor)
		if character == "\\" then
			cursor += 2
		elseif character == quote then
			return cursor
		else
			cursor += 1
		end
	end
	return #source
end

local function appendMasked(output: { string }, region: string)
	table.insert(output, (string.gsub(region, "[^\n]", " ")))
end

local function appendStringToken(output: { string }, region: string, token: string)
	table.insert(output, token)
	local _, newlineCount = string.gsub(region, "\n", "\n")
	if newlineCount > 0 then
		table.insert(output, string.rep("\n", newlineCount))
	end
end

local function executableContractSource(source: string): string
	local output: { string } = {}
	local cursor = 1

	while cursor <= #source do
		local character = string.sub(source, cursor, cursor)
		if string.sub(source, cursor, cursor + 1) == "--" then
			local bracketEnd = longBracketEnd(source, cursor + 2)
			local regionEnd = bracketEnd
			if regionEnd == nil then
				local newline = string.find(source, "\n", cursor + 2, true)
				regionEnd = if newline ~= nil then newline - 1 else #source
			end
			appendMasked(output, string.sub(source, cursor, regionEnd))
			cursor = regionEnd + 1
		elseif character == '"' or character == "'" or character == "`" then
			local quoteEnd = quotedEnd(source, cursor, character)
			local region = string.sub(source, cursor, quoteEnd)
			local rawValue = string.sub(source, cursor + 1, math.max(cursor, quoteEnd - 1))
			local token = nil
			if string.find(rawValue, "\\", 1, true) == nil then
				token = STRING_SENTINELS[rawValue]
			end
			appendStringToken(output, region, token or "__STRING__")
			cursor = quoteEnd + 1
		else
			local bracketEnd = longBracketEnd(source, cursor)
			if bracketEnd ~= nil then
				appendStringToken(output, string.sub(source, cursor, bracketEnd), "__STRING__")
				cursor = bracketEnd + 1
			else
				table.insert(output, character)
				cursor += 1
			end
		end
	end

	return table.concat(output)
end

local function helperBodyFrom(sourceText: string): string?
	local executable = executableContractSource(sourceText)
	local helperStart = string.find(executable, "local function validateReadoutCompleteness(", 1, true)
	local helperEnd = helperStart
		and string.find(
			executable,
			"local function captureCanonicalWhileDiagnosticsEnabled(",
			helperStart,
			true
		)
	if helperStart == nil or helperEnd == nil or helperStart >= helperEnd then
		return nil
	end
	return string.sub(executable, helperStart, helperEnd - 1)
end

local function hasCoreReadoutProof(sourceText: string): boolean
	local helperBody = helperBodyFrom(sourceText)
	if helperBody == nil then
		return false
	end
	return string.find(helperBody, "assert%s*%(%s*child%.Enabled") ~= nil
		and string.find(helperBody, "assert%s*%(%s*label%.Visible") ~= nil
		and string.find(helperBody, "child.Adornee == expectedEntity.adornee", 1, true) ~= nil
		and string.find(helperBody, "label.Text == expectedEntity.text", 1, true) ~= nil
end

local function helperMutant(body: string): string
	return "local function validateReadoutCompleteness(folder, entities)\n"
		.. body
		.. "\nend\n\nlocal function captureCanonicalWhileDiagnosticsEnabled(lab)\nend\n"
end

local function run(): number
	local failures = 0

	local function expect(name: string, condition: boolean)
		if not condition then
			failures += 1
			print(`FAIL diagnostics-readout {name}`)
		else
			print(`PASS diagnostics-readout {name}`)
		end
	end

	local rawSource = fs.readFile(DIAGNOSTICS_SOURCE)
	-- Convert source into a contract-search form where comments and string bodies
	-- cannot masquerade as executable diagnostics checks. Exact simple literals
	-- needed by this contract become dedicated sentinels; arbitrary quoted,
	-- backtick, and long-bracket text collapses to a generic string token.
	local source = executableContractSource(rawSource)
	local function position(needle: string): number?
		return string.find(source, needle, 1, true)
	end

	local helper = position("local function validateReadoutCompleteness(")
	local helperEnd = helper
		and string.find(source, "local function captureCanonicalWhileDiagnosticsEnabled(", helper, true)
	local helperBody = if helper ~= nil
			and helperEnd ~= nil
			and helper < helperEnd
		then string.sub(source, helper, helperEnd - 1)
		else nil
	local function helperPosition(needle: string): number?
		if helperBody == nil then
			return nil
		end
		return string.find(helperBody, needle, 1, true)
	end

	local identityWrite = position("billboard:SetAttribute(__STR_WORLD_ENTITY_ID__, plan.worldEntityId)")
	local directChildren = helperPosition("folder:GetChildren()")
	local billboardClass = helperPosition("child:IsA(__STR_BILLBOARD_GUI__)")
	local readoutIdentity = helperPosition("requireStringAttribute(child, __STR_WORLD_ENTITY_ID__)")
	local expectedMembership = helperPosition("expectedEntity ~= nil")
	local duplicateGuard = helperPosition("seenEntityIds[entityId] == nil")
	local exactAdorneeProjection = helperPosition("child.Adornee == expectedEntity.adornee")
	local seenWrite = helperPosition("seenEntityIds[entityId] = true")
	local labelLookup = helperPosition("child:FindFirstChild(__STR_READOUT__)")
	local labelClass = helperPosition("label:IsA(__STR_TEXT_LABEL__)")
	local exactBillboardShape = helperPosition("#child:GetDescendants() == 1")
	local exactTextProjection = helperPosition("label.Text == expectedEntity.text")
	local readoutCountIncrement = helperPosition("readoutCount += 1")
	local exactEntityCount = helperPosition("readoutCount == #entities")
	local exactInstanceCount = helperPosition("return 1 + 2 * readoutCount")
	local billboardEnabledGuard = helperBody ~= nil
		and string.find(helperBody, "assert%s*%(%s*child%.Enabled") ~= nil
	local labelVisibleGuard = helperBody ~= nil
		and string.find(helperBody, "assert%s*%(%s*label%.Visible") ~= nil
	local preflightProjection = position("key = record.origin.recipeKey")
	local captureProjection = position(
		"text = readoutText(record.origin.recipeKey, record.id, record.fidelity, fingerprint, reproKey)"
	)
	local realizationProjection = position(
		"label.Text = readoutText(plan.key, plan.worldEntityId, plan.fidelity, fingerprint, reproKey)"
	)
	local mutableNameProjection = position("key = representation.Name")
	local mutableNameTextProjection = position("readoutText(representation.Name")
	local mutableClassProjection = position("representation:GetAttribute(__STR_REPRESENTATION_CLASS__)")
	local inertClassProjection = position("representationClass = nil")
	local entityIdSort = position("requireStringAttribute(a, __STR_WORLD_ENTITY_ID__)")
	local mutableNameSort = position("return a.Name < b.Name")
	local captureCall = position("diagnosticInstanceCount = validateReadoutCompleteness(folder, entities)")
	local descendantCountShortcut = position("diagnosticInstanceCount = 1 + #folder:GetDescendants()")

	expect("each diagnostics billboard carries the canonical WorldEntityId it projects", identityWrite ~= nil)
	expect(
		"capture validates the readout tree through an explicit completeness boundary",
		helper ~= nil and captureCall ~= nil and helper < captureCall
	)
	expect(
		"readout validation enumerates only direct diagnostics-root children",
		directChildren ~= nil and billboardClass ~= nil and directChildren < billboardClass
	)
	expect(
		"every readout identity is authoritative and unique",
		readoutIdentity ~= nil
			and expectedMembership ~= nil
			and duplicateGuard ~= nil
			and seenWrite ~= nil
			and readoutIdentity < expectedMembership
			and expectedMembership < duplicateGuard
			and duplicateGuard < seenWrite
	)
	expect(
		"capture compares each live Adornee to the authoritative represented BasePart",
		exactAdorneeProjection ~= nil
			and expectedMembership ~= nil
			and seenWrite ~= nil
			and expectedMembership < exactAdorneeProjection
			and exactAdorneeProjection < seenWrite
	)
	expect(
		"every entity readout has exactly one TextLabel named Readout",
		labelLookup ~= nil
			and labelClass ~= nil
			and exactBillboardShape ~= nil
			and billboardClass ~= nil
			and billboardClass < labelLookup
			and labelLookup < labelClass
			and labelClass < exactBillboardShape
	)
	expect(
		"capture compares displayed text to the exact authoritative readout projection before counting it",
		exactTextProjection ~= nil
			and labelClass ~= nil
			and exactBillboardShape ~= nil
			and readoutCountIncrement ~= nil
			and labelClass < exactBillboardShape
			and exactBillboardShape < exactTextProjection
			and exactTextProjection < readoutCountIncrement
	)
	expect(
		"capture rejects disabled BillboardGui readouts instead of counting invisible diagnostics as complete",
		billboardEnabledGuard
	)
	expect(
		"capture rejects hidden TextLabel readouts instead of counting invisible diagnostics as complete",
		labelVisibleGuard
	)
	expect(
		"realization and capture project the authoritative recipe key through the shared formatter",
		preflightProjection ~= nil
			and captureProjection ~= nil
			and realizationProjection ~= nil
			and mutableNameProjection == nil
			and mutableNameTextProjection == nil
	)
	expect(
		"diagnostics do not publish mutable representation-class attributes as authoritative evidence",
		mutableClassProjection == nil and inertClassProjection ~= nil
	)
	expect(
		"representation ordering is stable by WorldEntityId rather than mutable Instance name",
		entityIdSort ~= nil and mutableNameSort == nil
	)
	expect(
		"validated readouts form a one-to-one projection of authoritative entities",
		exactEntityCount ~= nil and exactInstanceCount ~= nil and exactEntityCount < exactInstanceCount
	)
	expect(
		"capture cannot bless an arbitrary descendant count as diagnostics completeness",
		descendantCountShortcut == nil
	)
	expect(
		"core visibility, Adornee, and text predicates are executable inside validateReadoutCompleteness",
		hasCoreReadoutProof(rawSource)
	)

	local inertLongCommentMutant = helperMutant(
		"\t--[=[\n"
			.. "\tassert(child.Enabled)\n"
			.. "\tassert(label.Visible)\n"
			.. "\tchild.Adornee == expectedEntity.adornee\n"
			.. "\tlabel.Text == expectedEntity.text\n"
			.. "\t]=]"
	)
	expect(
		"readout matcher rejects core predicates preserved only inside a long comment",
		not hasCoreReadoutProof(inertLongCommentMutant)
	)

	local inertLongStringMutant = helperMutant(
		"\tlocal inert = [=[\n"
			.. "\tassert(child.Enabled)\n"
			.. "\tassert(label.Visible)\n"
			.. "\tchild.Adornee == expectedEntity.adornee\n"
			.. "\tlabel.Text == expectedEntity.text\n"
			.. "\t]=]"
	)
	expect(
		"readout matcher rejects core predicates preserved only inside a long-bracket string",
		not hasCoreReadoutProof(inertLongStringMutant)
	)

	local inertQuotedStringMutant = helperMutant(
		'\tlocal inert = "assert(child.Enabled) assert(label.Visible) child.Adornee == expectedEntity.adornee label.Text == expectedEntity.text"'
	)
	expect(
		"readout matcher rejects core predicates preserved only inside a quoted string",
		not hasCoreReadoutProof(inertQuotedStringMutant)
	)

	local inertBacktickStringMutant = helperMutant(
		"\tlocal inert = `assert(child.Enabled) assert(label.Visible) child.Adornee == expectedEntity.adornee label.Text == expectedEntity.text`"
	)
	expect(
		"readout matcher rejects core predicates preserved only inside a backtick string",
		not hasCoreReadoutProof(inertBacktickStringMutant)
	)

	return failures
end

return run
