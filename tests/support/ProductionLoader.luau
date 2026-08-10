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

function ProductionLoader.new(root)
	return setmetatable({
		root = root or ".",
		cache = {},
		loading = {},
	}, Loader)
end

function Loader:_makeNode(relativePath, kind)
	local loader = self
	local node = {
		_path = relativePath,
		_kind = kind,
	}

	return setmetatable(node, {
		__index = function(_, key)
			if key == "Parent" then
				return loader:_makeNode(dirname(relativePath), "directory")
			elseif key == "Name" then
				return moduleName(relativePath)
			end

			assert(type(key) == "string", "module tree keys must be strings")

			local directory = relativePath
			if kind == "module" then
				directory = dirname(relativePath)
			end

			local candidateBase = `{directory}/{key}`
			local candidateModule = `{candidateBase}.luau`
			if fs.isFile(join(loader.root, candidateModule)) then
				return loader:_makeNode(candidateModule, "module")
			end
			if fs.isDir(join(loader.root, candidateBase)) then
				return loader:_makeNode(candidateBase, "directory")
			end

			error(`unable to resolve production module child {candidateBase}`, 2)
		end,
	})
end

function Loader:_requirePath(relativePath)
	local cached = self.cache[relativePath]
	if cached ~= nil then
		return cached
	end

	assert(not self.loading[relativePath], `circular production require detected at {relativePath}`)
	local fullPath = join(self.root, relativePath)
	assert(fs.isFile(fullPath), `production module does not exist: {relativePath}`)

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
		return luau.load(fs.readFile(fullPath), {
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
