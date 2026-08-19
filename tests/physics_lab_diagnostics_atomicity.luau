local fs = require("@lune/fs")

local DIAGNOSTICS_SOURCE = "src/server/PhysicsLab/PhysicsLabStudioDiagnostics.luau"

local function run(): number
	local failures = 0

	local function expect(name: string, condition: boolean)
		if not condition then
			failures += 1
			print(`FAIL diagnostics-atomicity {name}`)
		else
			print(`PASS diagnostics-atomicity {name}`)
		end
	end

	local source = fs.readFile(DIAGNOSTICS_SOURCE)
	local function position(needle: string, init: number?): number?
		return string.find(source, needle, init or 1, true)
	end

	local metadataHelper = position("local function assertRepresentationMetadata(")
	local recipeKeyRead =
		position('requireStringAttribute(representation, "UNRENDERED_RecipeKey")', metadataHelper)
	local representationRevisionRead = position(
		'requireNonNegativeIntegerAttribute(representation, "UNRENDERED_RepresentationRevision")',
		metadataHelper
	)
	local stateRevisionRead = position(
		'requireNonNegativeIntegerAttribute(representation, "UNRENDERED_StateRevision")',
		metadataHelper
	)
	local recipeKeyMatch = position("expectedRecipeKey == representedRecipeKey", metadataHelper)
	local representationRevisionMatch =
		position("expectedRepresentationRevision == representedRepresentationRevision", metadataHelper)
	local stateRevisionMatch = position("expectedStateRevision == representedStateRevision", metadataHelper)
	local enumerationFunction = position("local function directRepresentations")
	local uniqueIdSet = position("local seenEntityIds: { [string]: boolean } = {}", enumerationFunction)
	local enumeratedIdRead = position(
		'local entityId = requireStringAttribute(child, "UNRENDERED_WorldEntityId")',
		enumerationFunction
	)
	local duplicateIdGuard = position("seenEntityIds[entityId] ~= true", enumerationFunction)
	local uniqueIdRecord = position("seenEntityIds[entityId] = true", enumerationFunction)
	local representedCountRead = position(
		'requireNonNegativeIntegerAttribute(model, "UNRENDERED_RepresentedCount")',
		enumerationFunction
	)
	local enumerationCountMatch = position("#representations == representedCount", enumerationFunction)
	local readoutShapeHelper = position("local function assertReadoutShape(")
	local readoutChildCount = position("#readouts == #entities", readoutShapeHelper)
	local readoutNameCheck = position("readout.Name == expectedName", readoutShapeHelper)
	local readoutClassCheck = position('readout:IsA("BillboardGui")', readoutShapeHelper)
	local readoutLabelCheck = position('label ~= nil and label:IsA("TextLabel")', readoutShapeHelper)
	local readoutDescendantCount = position("descendantCount == #entities * 2", readoutShapeHelper)
	local preflightFunction = position("local function preflightReadouts")
	local captureFunction = position("function PhysicsLabStudioDiagnostics.capture")
	local enableFunction = position("function PhysicsLabStudioDiagnostics.enable")
	local preflightEnumeration = position("directRepresentations(model)", preflightFunction)
	local captureEnumeration = position("directRepresentations(model)", captureFunction)
	local preflightMetadataCheck = position("assertRepresentationMetadata(", preflightFunction)
	local captureMetadataCheck = position("assertRepresentationMetadata(", captureFunction)
	local captureReadoutShapeCheck =
		position("diagnosticInstanceCount = assertReadoutShape(folder, entities)", captureFunction)
	local preflight = position("local plans = preflightReadouts(lab, model)")
	local transaction = position("local ok, result = pcall(function(): Snapshot")
	local rootName = position("folder.Name = DIAGNOSTICS_ROOT_NAME")
	local rootOwnership = position('folder:SetAttribute("UNRENDERED_PhysicsLabDiagnosticsOwned", true)')
	local parentMutation = position("folder.Parent = model")
	local billboardOwnership = position("billboard.Parent = folder")
	local billboardConfiguration = position("billboard.AlwaysOnTop = true")
	local labelOwnership = position("label.Parent = billboard")
	local labelConfiguration = position("label.BackgroundTransparency = 0.2")
	local representationRevision = position("representationRevision = record.representationRevision")
	local stateRevision = position("stateRevision = record.stateRevision")
	local visualRevisionReadout = position("reprRev=%d | stateRev=%d")
	local capture = position("return PhysicsLabStudioDiagnostics.capture(lab)")
	local transactionEnd = position("\tend)\n\n\tif not ok then")
	local rollback = position("folder:Destroy()")
	local propagate = position("error(result, 0)")
	local toggleEvidence = position("function PhysicsLabStudioDiagnostics.runToggleEvidence(")
	local toggleInitial = position("local initial = PhysicsLabStudioDiagnostics.capture(lab)")
	local toggleDefaultOff = position("not initial.enabled and initial.diagnosticInstanceCount == 0")
	local toggleBaseline = position("local baseline = Validation.captureFull(lab.model)")
	local firstToggleDisable = position("local disabled = PhysicsLabStudioDiagnostics.disable(lab)")
	local legacyDefaultOffNormalizer = position("PhysicsLabStudioDiagnostics.disable(lab)\n\tlocal baseline")
	local toggleFinalSnapshot = position("local finalSnapshot = PhysicsLabStudioDiagnostics.capture(lab)")
	local toggleFinalOff =
		position("not finalSnapshot.enabled and finalSnapshot.diagnosticInstanceCount == 0")
	local toggleFinalPublication = position("finallyEnabled = finalSnapshot.enabled")

	expect(
		"diagnostics fail closed when physical recipe/revision metadata drifts from authoritative state",
		metadataHelper ~= nil
			and recipeKeyRead ~= nil
			and representationRevisionRead ~= nil
			and stateRevisionRead ~= nil
			and recipeKeyMatch ~= nil
			and representationRevisionMatch ~= nil
			and stateRevisionMatch ~= nil
	)
	expect(
		"representation enumeration rejects duplicate WorldEntityIds before cardinality can mask an omission",
		enumerationFunction ~= nil
			and uniqueIdSet ~= nil
			and enumeratedIdRead ~= nil
			and duplicateIdGuard ~= nil
			and uniqueIdRecord ~= nil
			and representedCountRead ~= nil
			and enumerationFunction < uniqueIdSet
			and uniqueIdSet < enumeratedIdRead
			and enumeratedIdRead < duplicateIdGuard
			and duplicateIdGuard < uniqueIdRecord
			and uniqueIdRecord < representedCountRead
	)
	expect(
		"representation enumeration fails closed when identity-tagged children do not match represented count",
		enumerationFunction ~= nil
			and representedCountRead ~= nil
			and enumerationCountMatch ~= nil
			and enumerationFunction < representedCountRead
			and representedCountRead < enumerationCountMatch
	)
	expect(
		"enabled diagnostics fail closed on partial or malformed visual readout trees",
		readoutShapeHelper ~= nil
			and readoutChildCount ~= nil
			and readoutNameCheck ~= nil
			and readoutClassCheck ~= nil
			and readoutLabelCheck ~= nil
			and readoutDescendantCount ~= nil
			and readoutShapeHelper < readoutChildCount
			and readoutChildCount < readoutNameCheck
			and readoutNameCheck < readoutClassCheck
			and readoutClassCheck < readoutLabelCheck
			and readoutLabelCheck < readoutDescendantCount
	)
	expect(
		"machine-readable capture validates visual readout shape before publishing an enabled snapshot",
		captureFunction ~= nil
			and captureReadoutShapeCheck ~= nil
			and enableFunction ~= nil
			and captureFunction < captureReadoutShapeCheck
			and captureReadoutShapeCheck < enableFunction
	)
	expect(
		"readout preflight uses the represented-count cardinality guard before diagnostics realization",
		preflightFunction ~= nil
			and preflightEnumeration ~= nil
			and enableFunction ~= nil
			and preflightFunction < preflightEnumeration
			and preflightEnumeration < enableFunction
	)
	expect(
		"machine-readable capture uses the same represented-count cardinality guard",
		captureFunction ~= nil
			and captureEnumeration ~= nil
			and enableFunction ~= nil
			and captureFunction < captureEnumeration
			and captureEnumeration < enableFunction
	)
	expect(
		"readout preflight validates physical metadata before diagnostics realization",
		preflightFunction ~= nil
			and preflightMetadataCheck ~= nil
			and enableFunction ~= nil
			and preflightFunction < preflightMetadataCheck
			and preflightMetadataCheck < enableFunction
	)
	expect(
		"diagnostics capture validates physical metadata instead of masking stale representation attributes",
		captureFunction ~= nil
			and captureMetadataCheck ~= nil
			and enableFunction ~= nil
			and captureFunction < captureMetadataCheck
			and captureMetadataCheck < enableFunction
	)
	expect(
		"all readout dependencies are preflighted before the owned root is parented",
		preflight ~= nil and parentMutation ~= nil and preflight < parentMutation
	)
	expect(
		"authoritative revisions are preflighted before the owned root is parented",
		representationRevision ~= nil
			and stateRevision ~= nil
			and parentMutation ~= nil
			and representationRevision < parentMutation
			and stateRevision < parentMutation
	)
	expect("live readouts expose both authoritative revision counters", visualRevisionReadout ~= nil)
	expect(
		"Instance realization begins inside a protected transaction",
		transaction ~= nil and parentMutation ~= nil and transaction < parentMutation
	)
	expect(
		"diagnostics root identity is established inside the transaction before parenting",
		transaction ~= nil
			and rootName ~= nil
			and rootOwnership ~= nil
			and parentMutation ~= nil
			and transaction < rootName
			and rootName < rootOwnership
			and rootOwnership < parentMutation
	)
	expect(
		"BillboardGui is owned before fallible configuration",
		billboardOwnership ~= nil
			and billboardConfiguration ~= nil
			and billboardOwnership < billboardConfiguration
	)
	expect(
		"TextLabel is owned before fallible configuration",
		labelOwnership ~= nil and labelConfiguration ~= nil and labelOwnership < labelConfiguration
	)
	expect(
		"post-realization capture remains inside the protected transaction",
		capture ~= nil
			and transaction ~= nil
			and transactionEnd ~= nil
			and transaction < capture
			and capture < transactionEnd
	)
	expect(
		"failed realization destroys the owned diagnostics tree before propagating",
		rollback ~= nil
			and propagate ~= nil
			and transactionEnd ~= nil
			and transactionEnd < rollback
			and rollback < propagate
	)
	expect(
		"toggle evidence observes and rejects a default-on state before baseline or cleanup",
		toggleEvidence ~= nil
			and toggleInitial ~= nil
			and toggleDefaultOff ~= nil
			and toggleBaseline ~= nil
			and firstToggleDisable ~= nil
			and toggleEvidence < toggleInitial
			and toggleInitial < toggleDefaultOff
			and toggleDefaultOff < toggleBaseline
			and toggleBaseline < firstToggleDisable
			and legacyDefaultOffNormalizer == nil
	)
	expect(
		"toggle evidence rejects a final diagnostics-on state before publishing success",
		toggleFinalSnapshot ~= nil
			and toggleFinalOff ~= nil
			and toggleFinalPublication ~= nil
			and toggleFinalSnapshot < toggleFinalOff
			and toggleFinalOff < toggleFinalPublication
	)

	return failures
end

return run
