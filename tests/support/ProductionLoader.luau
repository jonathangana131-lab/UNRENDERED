local fs = require("@lune/fs")
local luau = require("@lune/luau")

local ProductionLoader = {}

local NodeMetatable = {}
NodeMetatable.__index = function(node, key)
	if key == "Name" then
		return rawget(node, "_name")
	elseif key == "Parent" then
		return rawget(node, "_parent")
	elseif key == "ClassName" then
		return if rawget(node, "_isModule") then "ModuleScript" else "Folder"
	end

	local children = rawget(node, "_children")
	return children[key]
end

local function newNode(name, parent, path, isModule)
	return setmetatable({
		_name = name,
		_parent = parent,
		_path = path,
		_isModule = isModule,
		_children = {},
	}, NodeMetatable)
end

local root = newNode("shared", nil, "src/shared", false)

local function scanDirectory(path, parent)
	for _, entryName in fs.readDir(path) do
		local childPath = `{path}/{entryName}`
		if fs.isDir(childPath) then
			local child = newNode(entryName, parent, childPath, false)
			parent._children[entryName] = child
			scanDirectory(childPath, child)
		elseif fs.isFile(childPath) then
			local moduleName = string.match(entryName, "^(.*)%.luau$") or string.match(entryName, "^(.*)%.lua$")
			if moduleName ~= nil then
				parent._children[moduleName] = newNode(moduleName, parent, childPath, true)
			end
		end
	end
end

scanDirectory(root._path, root)

local moduleCache = {}
local loading = {}

local loadNode

local function productionRequire(target)
	if type(target) ~= "table" or getmetatable(target) ~= NodeMetatable or not target._isModule then
		error("ProductionLoader only supports Roblox-style ModuleScript references", 2)
	end
	return loadNode(target)
end

loadNode = function(node)
	local path = node._path
	local cached = moduleCache[path]
	if cached ~= nil then
		return cached
	end
	if loading[path] then
		error(`ProductionLoader circular require: {path}`, 2)
	end
	loading[path] = true

	local environment = {
		script = node,
		require = productionRequire,
	}
	local chunk = luau.load(fs.readFile(path), {
		debugName = path,
		environment = environment,
		injectGlobals = true,
	})
	local result = chunk()
	loading[path] = nil

	if result == nil then
		error(`ProductionLoader module returned nil: {path}`, 2)
	end
	moduleCache[path] = result
	return result
end

function ProductionLoader.requireShared(modulePath)
	assert(type(modulePath) == "string" and modulePath ~= "", "modulePath must be a non-empty string")

	local node = root
	for segment in string.gmatch(modulePath, "[^/]+") do
		node = node._children[segment]
		assert(node ~= nil, `ProductionLoader missing shared module path segment {segment} in {modulePath}`)
	end
	assert(node._isModule, `ProductionLoader target is not a ModuleScript: {modulePath}`)
	return loadNode(node)
end

return table.freeze(ProductionLoader)
