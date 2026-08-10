local TestHarness = {}

local Assertions = {}
Assertions.__index = Assertions

local Runner = {}
Runner.__index = Runner

local function formatValue(value)
	if type(value) == "string" then
		return string.format("%q", value)
	end
	return tostring(value)
end

local function withDetail(message, detail)
	if detail == nil then
		return message
	end
	return `{message} ({detail})`
end

function Assertions:equal(actual, expected, detail)
	if actual ~= expected then
		error(withDetail(`expected {formatValue(expected)}, got {formatValue(actual)}`, detail), 2)
	end
end

function Assertions:notEqual(actual, unexpected, detail)
	if actual == unexpected then
		error(withDetail(`expected value to differ from {formatValue(unexpected)}`, detail), 2)
	end
end

function Assertions:truthy(value, detail)
	if not value then
		error(withDetail(`expected truthy value, got {formatValue(value)}`, detail), 2)
	end
end

function Assertions:falsy(value, detail)
	if value then
		error(withDetail(`expected falsy value, got {formatValue(value)}`, detail), 2)
	end
end

function Assertions:throws(callback, expectedMessage, detail)
	local ok, failure = pcall(callback)
	if ok then
		error(withDetail("expected callback to throw", detail), 2)
	end

	if expectedMessage ~= nil and string.find(tostring(failure), expectedMessage, 1, true) == nil then
		error(
			withDetail(
				`expected error containing {formatValue(expectedMessage)}, got {formatValue(tostring(failure))}`,
				detail
			),
			2
		)
	end
end

function TestHarness.new()
	return setmetatable({ tests = {} }, Runner)
end

function Runner:test(name, reproKey, callback)
	assert(type(name) == "string" and name ~= "", "test name must be a non-empty string")
	assert(reproKey == nil or type(reproKey) == "string", "repro key must be a string or nil")
	assert(type(callback) == "function", "test callback must be a function")

	table.insert(self.tests, {
		name = name,
		reproKey = reproKey,
		callback = callback,
	})
end

function Runner:run()
	local passed = 0
	local failed = 0
	local assertions = setmetatable({}, Assertions)

	for _, testCase in self.tests do
		local ok, failure = pcall(testCase.callback, assertions)
		if ok then
			passed += 1
			print(`PASS {testCase.name}`)
		else
			failed += 1
			print(`FAIL {testCase.name}`)
			print(`  {tostring(failure)}`)
			if testCase.reproKey ~= nil then
				print(`  REPRO {testCase.reproKey}`)
			end
		end
	end

	print(`UNRENDERED deterministic tests: {passed} passed, {failed} failed`)
	return failed == 0
end

return table.freeze(TestHarness)
