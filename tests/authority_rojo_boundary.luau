local fs = require("@lune/fs")
local serde = require("@lune/serde")

local function countPath(value: any, target: string): number
	if type(value) ~= "table" then
		return 0
	end

	local count = 0
	for key, child in pairs(value) do
		if key == "$path" and child == target then
			count += 1
		end
		count += countPath(child, target)
	end
	return count
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

	local project = serde.decode("json", fs.readFile("default.project.json")) :: any
	local tree = project.tree
	local replicatedStorage = tree and tree.ReplicatedStorage
	local serverScriptService = tree and tree.ServerScriptService
	local starterPlayer = tree and tree.StarterPlayer
	local sharedRoot = replicatedStorage and replicatedStorage.UNRENDERED
	local serverRoot = serverScriptService and serverScriptService.UNRENDERED_Server
	local clientRoot = starterPlayer
		and starterPlayer.StarterPlayerScripts
		and starterPlayer.StarterPlayerScripts.UNRENDERED_Client

	expect(
		"shared source remains mapped under ReplicatedStorage",
		type(sharedRoot) == "table" and sharedRoot["$path"] == "src/shared"
	)
	expect(
		"server source remains mapped under ServerScriptService",
		type(serverRoot) == "table" and serverRoot["$path"] == "src/server"
	)
	expect(
		"client source remains mapped under StarterPlayerScripts",
		type(clientRoot) == "table" and clientRoot["$path"] == "src/client"
	)
	expect("shared source mapping is unique", countPath(tree, "src/shared") == 1)
	expect("server source mapping is unique", countPath(tree, "src/server") == 1)
	expect("client source mapping is unique", countPath(tree, "src/client") == 1)

	return failures
end

return run
