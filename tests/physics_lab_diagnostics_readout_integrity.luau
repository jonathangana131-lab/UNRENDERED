local fs = require("@lune/fs")

local DIAGNOSTICS_SOURCE = "src/server/PhysicsLab/PhysicsLabStudioDiagnostics.luau"

local function run(): number
	local failures = 0

	local function expect(name: string, condition: boolean)
		if not condition then
			failures += 1
			print(`FAIL diagnostics-readout-integrity {name}`)
		else
			print(`PASS diagnostics-readout-integrity {name}`)
		end
	end

	local source = fs.readFile(DIAGNOSTICS_SOURCE)
	local function position(needle: string, init: number?): number?
		return string.find(source, needle, init or 1, true)
	end

	local readoutTextHelper = position("local function readoutText(")
	local readoutShapeHelper = position("local function assertReadoutShape(")
	local readoutContentHelper = position("local function assertReadoutContent(")
	local expectedAdornee = position("local expectedAdornee = adorneeFor(representation)", readoutContentHelper)
	local adorneeMatch = position("readout.Adornee == expectedAdornee", readoutContentHelper)
	local expectedText = position("local expectedText = readoutText(", readoutContentHelper)
	local textMatch = position("label.Text == expectedText", readoutContentHelper)
	local captureFunction = position("function PhysicsLabStudioDiagnostics.capture")
	local captureRepresentations = position("local representations = directRepresentations(lab, model)", captureFunction)
	local captureFingerprint = position(
		'local fingerprint = requireStringAttribute(model, "UNRENDERED_ResolvedRegionFingerprint")',
		captureFunction
	)
	local captureReproKey = position(
		'local reproKey = requireStringAttribute(model, "UNRENDERED_ResolvedRegionReproKey")',
		captureFunction
	)
	local captureShape = position("diagnosticInstanceCount = assertReadoutShape(folder, entities)", captureFunction)
	local captureContent = position(
		"assertReadoutContent(folder, entities, representations, fingerprint, reproKey)",
		captureFunction
	)
	local snapshotFingerprint = position("resolvedRegionFingerprint = fingerprint", captureFunction)
	local snapshotReproKey = position("resolvedRegionReproKey = reproKey", captureFunction)
	local enableFunction = position("function PhysicsLabStudioDiagnostics.enable")
	local renderedText = position("label.Text = readoutText(", enableFunction)

	expect(
		"live diagnostics bind each billboard to the authoritative representation adornee",
		readoutContentHelper ~= nil
			and expectedAdornee ~= nil
			and adorneeMatch ~= nil
			and readoutContentHelper < expectedAdornee
			and expectedAdornee < adorneeMatch
	)
	expect(
		"live diagnostics compare rendered text against the shared authoritative text contract",
		readoutTextHelper ~= nil
			and readoutContentHelper ~= nil
			and expectedText ~= nil
			and textMatch ~= nil
			and readoutTextHelper < readoutContentHelper
			and readoutContentHelper < expectedText
			and expectedText < textMatch
	)
	expect(
		"machine-readable capture validates shape before exact visual content",
		readoutShapeHelper ~= nil
			and captureFunction ~= nil
			and captureRepresentations ~= nil
			and captureShape ~= nil
			and captureContent ~= nil
			and readoutShapeHelper < captureFunction
			and captureFunction < captureRepresentations
			and captureRepresentations < captureShape
			and captureShape < captureContent
	)
	expect(
		"capture validates and publishes the same fingerprint and repro identity",
		captureFingerprint ~= nil
			and captureReproKey ~= nil
			and captureContent ~= nil
			and snapshotFingerprint ~= nil
			and snapshotReproKey ~= nil
			and captureFingerprint < captureContent
			and captureReproKey < captureContent
			and captureContent < snapshotFingerprint
			and captureContent < snapshotReproKey
	)
	expect(
		"readout realization consumes the same deterministic text formatter used by validation",
		readoutTextHelper ~= nil
			and enableFunction ~= nil
			and renderedText ~= nil
			and readoutTextHelper < enableFunction
			and enableFunction < renderedText
	)

	return failures
end

return run
