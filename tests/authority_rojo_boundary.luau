local fs = require("@lune/fs")

local function countLiteral(haystack: string, needle: string): number
	local count = 0
	local cursor = 1
	while true do
		local startIndex = haystack:find(needle, cursor, true)
		if startIndex == nil then
			return count
		end
		count += 1
		cursor = startIndex + #needle
	end
end

local function run(): number
	local failures = 0

	local function expect(name: string, condition: boolean)
		if not condition then
			failures += 1
			print(`FAIL authority-rojo {name}`)
		else
			print(`PASS authority-rojo {name}`)
		end
	end

	local project = fs.readFile("default.project.json")
	local replicatedStorage = project:find('"ReplicatedStorage"', 1, true)
	local serverScriptService = project:find('"ServerScriptService"', 1, true)
	local starterPlayer = project:find('"StarterPlayer"', 1, true)
	local sharedPath = project:find('"$path": "src/shared"', 1, true)
	local serverPath = project:find('"$path": "src/server"', 1, true)
	local clientPath = project:find('"$path": "src/client"', 1, true)

	expect("Rojo project declares ReplicatedStorage", replicatedStorage ~= nil)
	expect("Rojo project declares ServerScriptService", serverScriptService ~= nil)
	expect("Rojo project declares StarterPlayer", starterPlayer ~= nil)
	expect("shared source mapping is unique", countLiteral(project, '"$path": "src/shared"') == 1)
	expect("server source mapping is unique", countLiteral(project, '"$path": "src/server"') == 1)
	expect("client source mapping is unique", countLiteral(project, '"$path": "src/client"') == 1)

	if replicatedStorage ~= nil and serverScriptService ~= nil and sharedPath ~= nil then
		expect(
			"only shared source is mapped inside ReplicatedStorage authority window",
			replicatedStorage < sharedPath and sharedPath < serverScriptService
		)
	end
	if serverScriptService ~= nil and starterPlayer ~= nil and serverPath ~= nil then
		expect(
			"server source remains below ServerScriptService and outside client replication",
			serverScriptService < serverPath and serverPath < starterPlayer
		)
	end
	if starterPlayer ~= nil and clientPath ~= nil then
		expect("client source remains below StarterPlayer", starterPlayer < clientPath)
	end

	return failures
end

return run
