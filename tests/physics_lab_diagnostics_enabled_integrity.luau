local fs = require("@lune/fs")

local DIAGNOSTICS_SOURCE = "src/server/PhysicsLab/PhysicsLabStudioDiagnostics.luau"
local DESCENDANT_BLOCK = [[
	for _, liveInstance in ipairs(lab.model:GetDescendants()) do
		local isDiagnosticsOverlay = liveInstance == liveRoot or liveInstance:IsDescendantOf(liveRoot)
		if not isDiagnosticsOverlay then
			assert(
				liveInstance.Archivable,
				`enabled canonical validation cannot clone non-Archivable live truth: {liveInstance:GetFullName()}`
			)
		end
	end]]

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

local function maskInertSource(source: string): string
	local output = {}
	local copyStart = 1
	local cursor = 1

	local function maskThrough(regionEnd: number)
		table.insert(output, string.sub(source, copyStart, cursor - 1))
		local region = string.sub(source, cursor, regionEnd)
		table.insert(output, (string.gsub(region, "[^\n]", " ")))
		cursor = regionEnd + 1
		copyStart = cursor
	end

	while cursor <= #source do
		local character = string.sub(source, cursor, cursor)
		if character == '"' or character == "'" or character == "`" then
			local quote = character
			cursor += 1
			while cursor <= #source do
				local quotedCharacter = string.sub(source, cursor, cursor)
				if quotedCharacter == "\\" then
					cursor += 2
				elseif quotedCharacter == quote then
					cursor += 1
					break
				else
					cursor += 1
				end
			end
		elseif string.sub(source, cursor, cursor + 1) == "--" then
			local commentStart = cursor
			local bracketEnd = longBracketEnd(source, cursor + 2)
			if bracketEnd ~= nil then
				maskThrough(bracketEnd)
			else
				local newline = string.find(source, "\n", cursor + 2, true)
				local commentEnd = if newline ~= nil then newline - 1 else #source
				cursor = commentStart
				maskThrough(commentEnd)
			end
		else
			local bracketEnd = longBracketEnd(source, cursor)
			if bracketEnd ~= nil then
				maskThrough(bracketEnd)
			else
				cursor += 1
			end
		end
	end

	table.insert(output, string.sub(source, copyStart))
	return table.concat(output)
end

local function hasCompleteCloneProof(helperSource: string): boolean
	local executableSource = maskInertSource(helperSource)
	local modelArchivable = string.find(
		executableSource,
		'\n\tassert(lab.model.Archivable, "enabled canonical validation requires an Archivable lab model")',
		1,
		true
	)
	local descendantBlock = string.find(executableSource, DESCENDANT_BLOCK, 1, true)
	local cloneLab = string.find(executableSource, "\n\tlocal cloneInstance = lab.model:Clone()", 1, true)
	return modelArchivable ~= nil
		and descendantBlock ~= nil
		and cloneLab ~= nil
		and modelArchivable < descendantBlock
		and descendantBlock < cloneLab
end

local function run(): number
	local failures = 0

	local function expect(name: string, condition: boolean)
		if not condition then
			failures += 1
			print(`FAIL diagnostics-enabled-integrity {name}`)
		else
			print(`PASS diagnostics-enabled-integrity {name}`)
		end
	end

	local rawSource = fs.readFile(DIAGNOSTICS_SOURCE)
	-- Mask comments and Luau long-bracket strings while preserving source positions and
	-- newlines. Source-contract checks must never certify executable behavior from inert text.
	local source = maskInertSource(rawSource)

	local helperStart =
		string.find(source, "local function captureCanonicalWhileDiagnosticsEnabled(", 1, true)
	local helperEnd = helperStart
		and string.find(source, "function PhysicsLabStudioDiagnostics.capture(", helperStart, true)
	local helperSource = if helperStart ~= nil and helperEnd ~= nil
		then string.sub(source, helperStart, helperEnd - 1)
		else nil
	local compactHelper = if helperSource ~= nil then string.gsub(helperSource, "%s+", " ") else nil

	local cloneLab = compactHelper
		and string.find(compactHelper, "local cloneInstance = lab.model:Clone()", 1, true)
	local proveCloneModel = compactHelper
		and string.find(compactHelper, 'assert(cloneInstance:IsA("Model")', 1, true)
	local locateOwnedOverlay = compactHelper
		and string.find(compactHelper, "local clonedRoot = diagnosticsRoot(clone)", 1, true)
	local removeOwnedOverlay = compactHelper and string.find(compactHelper, "clonedRoot:Destroy()", 1, true)
	local canonicalCapture = compactHelper
		and string.find(compactHelper, "return Validation.captureFull(clone)", 1, true)
	local destroyClone = compactHelper and string.find(compactHelper, "clone:Destroy()", 1, true)
	local propagate = compactHelper and string.find(compactHelper, "error(result, 0)", 1, true)

	expect(
		"enabled canonical integrity is checked on a disposable clone",
		helperStart ~= nil
			and helperEnd ~= nil
			and cloneLab ~= nil
			and proveCloneModel ~= nil
			and cloneLab < proveCloneModel
	)

	-- Instance:Clone() omits non-Archivable descendants. Pin the complete helper-local
	-- proof as a formatted block so token-preserving early exits or dead/inert wrappers cannot
	-- masquerade as an exhaustive scan. The block must remain at helper scope and finish
	-- before the disposable clone is created.
	expect(
		"enabled canonical clone proves every non-overlay live descendant is Archivable before cloning",
		helperSource ~= nil and hasCompleteCloneProof(helperSource)
	)

	local modelOnlyMutant = [[
	assert(lab.model.Archivable, "enabled canonical validation requires an Archivable lab model")
	local cloneInstance = lab.model:Clone()]]
	expect(
		"clone-completeness matcher rejects the prior model-only false-pass mutant",
		not hasCompleteCloneProof(modelOnlyMutant)
	)

	local broadOverlayMutant = [[
	assert(lab.model.Archivable, "enabled canonical validation requires an Archivable lab model")
	for _, liveInstance in ipairs(lab.model:GetDescendants()) do
		local isDiagnosticsOverlay = liveInstance.Name == liveRoot.Name
		if not isDiagnosticsOverlay then
			assert(
				liveInstance.Archivable,
				`enabled canonical validation cannot clone non-Archivable live truth: {liveInstance:GetFullName()}`
			)
		end
	end
	local cloneInstance = lab.model:Clone()]]
	expect(
		"clone-completeness matcher rejects a broadened overlay exemption mutant",
		not hasCompleteCloneProof(broadOverlayMutant)
	)

	local earlyExitMutant = [[
	assert(lab.model.Archivable, "enabled canonical validation requires an Archivable lab model")
	for _, liveInstance in ipairs(lab.model:GetDescendants()) do
		local isDiagnosticsOverlay = liveInstance == liveRoot or liveInstance:IsDescendantOf(liveRoot)
		if not isDiagnosticsOverlay then
			assert(
				liveInstance.Archivable,
				`enabled canonical validation cannot clone non-Archivable live truth: {liveInstance:GetFullName()}`
			)
		end
		break
	end
	local cloneInstance = lab.model:Clone()]]
	expect(
		"clone-completeness matcher rejects an early-exit descendant scan",
		not hasCompleteCloneProof(earlyExitMutant)
	)

	local deadWrapperMutant = [[
	if false then
		assert(lab.model.Archivable, "enabled canonical validation requires an Archivable lab model")
		for _, liveInstance in ipairs(lab.model:GetDescendants()) do
			local isDiagnosticsOverlay = liveInstance == liveRoot or liveInstance:IsDescendantOf(liveRoot)
			if not isDiagnosticsOverlay then
				assert(
					liveInstance.Archivable,
					`enabled canonical validation cannot clone non-Archivable live truth: {liveInstance:GetFullName()}`
				)
			end
		end
	end
	local cloneInstance = lab.model:Clone()]]
	expect(
		"clone-completeness matcher rejects a dead wrapped descendant scan",
		not hasCompleteCloneProof(deadWrapperMutant)
	)

	local inertCommentMutant = '\n\tassert(lab.model.Archivable, "enabled canonical validation requires an Archivable lab model")'
		.. "\n\t--[["
		.. DESCENDANT_BLOCK
		.. "\n\t]]"
		.. "\n\tlocal cloneInstance = lab.model:Clone()"
	expect(
		"clone-completeness matcher rejects an inert long-comment copy of the descendant proof",
		not hasCompleteCloneProof(inertCommentMutant)
	)

	local inertStringMutant = '\n\tassert(lab.model.Archivable, "enabled canonical validation requires an Archivable lab model")'
		.. "\n\tlocal inertProof = [=["
		.. DESCENDANT_BLOCK
		.. "\n\t]=]"
		.. "\n\tlocal cloneInstance = lab.model:Clone()"
	expect(
		"clone-completeness matcher rejects an inert long-string copy of the descendant proof",
		not hasCompleteCloneProof(inertStringMutant)
	)

	expect(
		"only the exact owned diagnostics overlay is removed before strict canonical validation",
		locateOwnedOverlay ~= nil
			and removeOwnedOverlay ~= nil
			and canonicalCapture ~= nil
			and locateOwnedOverlay < removeOwnedOverlay
			and removeOwnedOverlay < canonicalCapture
	)
	expect(
		"disposable canonical clone is destroyed before either success or propagated failure returns",
		canonicalCapture ~= nil
			and destroyClone ~= nil
			and propagate ~= nil
			and canonicalCapture < destroyClone
			and destroyClone < propagate
	)

	local evidenceStart =
		string.find(source, "function PhysicsLabStudioDiagnostics.runToggleEvidence(", 1, true)
	local evidenceReturn = evidenceStart and string.find(source, "return evidence", evidenceStart, true)
	local enable = evidenceStart
		and string.find(
			source,
			"local enabled = PhysicsLabStudioDiagnostics.enable(lab)",
			evidenceStart,
			true
		)
	local onSnapshot = evidenceStart
		and string.find(
			source,
			"local onSnapshot = captureCanonicalWhileDiagnosticsEnabled(lab)",
			evidenceStart,
			true
		)
	local onCompare = evidenceStart
		and string.find(
			source,
			"local onComparison = Validation.compare(baseline, onSnapshot, 0.001)",
			evidenceStart,
			true
		)
	local onDelta = evidenceStart
		and string.find(source, "for countName, delta in pairs(onComparison.delta) do", evidenceStart, true)
	local onEnvelope = onDelta and string.find(source, "onComparison.envelope.ok", onDelta, true)
	local disable = evidenceStart
		and string.find(
			source,
			"local disabled = PhysicsLabStudioDiagnostics.disable(lab)",
			evidenceStart,
			true
		)

	expect(
		"each enabled evidence window validates canonical truth before diagnostics are disabled",
		evidenceStart ~= nil
			and evidenceReturn ~= nil
			and enable ~= nil
			and onSnapshot ~= nil
			and onCompare ~= nil
			and onDelta ~= nil
			and onEnvelope ~= nil
			and disable ~= nil
			and enable < onSnapshot
			and onSnapshot < onCompare
			and onCompare < onDelta
			and onDelta < onEnvelope
			and disable < evidenceReturn
	)

	return failures
end

return run
