local fs = require("@lune/fs")
local luau = require("@lune/luau")

local hostRequire = require

local ProductionLoader = {}
local Loader = {}
Loader.__index = Loader

local function dirname(path)
	return string.match(path, "^(.*)/[^/]+$") or "."
end

local function basename(path)
	return string.match(path, "([^/]+)$") or path
end

local function moduleName(path)
	return string.gsub(basename(path), "%.luau$", "")
end

local function join(root, relativePath)
	if root == "." then
		return relativePath
	end
	return `{root}/{relativePath}`
end

local function childPath(directory, entryName)
	if directory == "." then
		return entryName
	end
	return `{directory}/{entryName}`
end

function ProductionLoader.new(root)
	local loader = setmetatable({
		root = root or ".",
		cache = {},
		loading = {},
		nodes = {},
		sources = {},
		children = {
			["."] = {},
		},
	}, Loader)

	loader.children["."].src = {
		path = "src",
		kind = "directory",
	}
	loader:_indexDirectory("src")
	return loader
end

function Loader:_indexDirectory(relativeDirectory)
	if self.children[relativeDirectory] ~= nil then
		return
	end

	local indexedChildren = {}
	self.children[relativeDirectory] = indexedChildren

	for _, entryName in fs.readDir(join(self.root, relativeDirectory)) do
		local relativePath = childPath(relativeDirectory, entryName)
		local fullPath = join(self.root, relativePath)

		if fs.isFile(fullPath) then
			if string.match(entryName, "%.luau$") ~= nil then
				local name = moduleName(entryName)
				assert(
					indexedChildren[name] == nil,
					`duplicate production module tree child: {relativeDirectory}/{name}`
				)
				indexedChildren[name] = {
					path = relativePath,
					kind = "module",
				}
				self.sources[relativePath] = fs.readFile(fullPath)
			end
		elseif fs.isDir(fullPath) then
			assert(
				indexedChildren[entryName] == nil,
				`duplicate production module tree child: {relativeDirectory}/{entryName}`
			)
			indexedChildren[entryName] = {
				path = relativePath,
				kind = "directory",
			}
			self:_indexDirectory(relativePath)
		end
	end
end

function Loader:_makeNode(relativePath, kind)
	local cacheKey = `{kind}:{relativePath}`
	local cached = self.nodes[cacheKey]
	if cached ~= nil then
		return cached
	end

	local loader = self
	local node = {
		_path = relativePath,
		_kind = kind,
	}
	self.nodes[cacheKey] = node

	return setmetatable(node, {
		__index = function(_, key)
			if key == "Parent" then
				if relativePath == "." then
					return nil
				end
				return loader:_makeNode(dirname(relativePath), "directory")
			elseif key == "Name" then
				return moduleName(relativePath)
			end

			assert(type(key) == "string", "module tree keys must be strings")

			local directory = relativePath
			if kind == "module" then
				directory = dirname(relativePath)
			end

			local directoryChildren = loader.children[directory]
			local child = if directoryChildren == nil then nil else directoryChildren[key]
			if child ~= nil then
				return loader:_makeNode(child.path, child.kind)
			end

			error(`unable to resolve production module child {directory}/{key}`, 2)
		end,
	})
end

function Loader:_requirePath(relativePath)
	local cached = self.cache[relativePath]
	if cached ~= nil then
		return cached
	end

	assert(not self.loading[relativePath], `circular production require detected at {relativePath}`)
	local source = self.sources[relativePath]
	assert(source ~= nil, `production module does not exist: {relativePath}`)

	self.loading[relativePath] = true

	local environment = {
		script = self:_makeNode(relativePath, "module"),
	}
	environment.require = function(target)
		if type(target) == "table" then
			local targetPath = rawget(target, "_path")
			local targetKind = rawget(target, "_kind")
			if type(targetPath) == "string" and targetKind == "module" then
				return self:_requirePath(targetPath)
			end
		end
		return hostRequire(target)
	end

	local okLoad, chunkOrFailure = pcall(function()
		return luau.load(source, {
			debugName = relativePath,
			environment = environment,
			injectGlobals = true,
		})
	end)
	if not okLoad then
		self.loading[relativePath] = nil
		error(`failed to compile production module {relativePath}: {tostring(chunkOrFailure)}`, 2)
	end

	local okRun, result = pcall(chunkOrFailure)
	self.loading[relativePath] = nil
	if not okRun then
		error(`failed to execute production module {relativePath}: {tostring(result)}`, 2)
	end
	assert(result ~= nil, `production module returned nil: {relativePath}`)

	self.cache[relativePath] = result
	return result
end

function Loader:requireModule(relativePath)
	assert(type(relativePath) == "string" and relativePath ~= "", "module path must be a non-empty string")
	return self:_requirePath(relativePath)
end

return table.freeze(ProductionLoader)
