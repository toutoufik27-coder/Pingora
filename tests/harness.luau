-- Test harness for pure Shared modules, run with tools/luau-runner:
--   luau-runner run tests/harness.luau
-- It builds a fake Roblox instance tree over src/shared so modules can use
-- `require(script.Parent.X)` exactly as they do in Roblox.

local ROOT = "src/shared"

local nodeCache = {}

local function makeNode(path: string, name: string, parent)
	local node = { Name = name, Parent = parent, _path = path }
	setmetatable(node, {
		__index = function(self, key)
			local base = rawget(self, "_path")
			for _, entry in __listdir(base) do
				local full = base .. "/" .. entry
				local stem = entry:gsub("%.luau$", ""):gsub("%.lua$", "")
				if stem == key and entry ~= "init.luau" then
					local cached = nodeCache[full]
					if cached then
						return cached
					end
					local child = makeNode(full, stem, self)
					nodeCache[full] = child
					return child
				end
			end
			error("no child '" .. tostring(key) .. "' under " .. base, 2)
		end,
	})
	return node
end

local moduleCache = {}

local function fakeRequire(node)
	local path = rawget(node, "_path")
	local file = path
	if __isdir(path) then
		file = path .. "/init.luau"
	end
	if moduleCache[file] ~= nil then
		return moduleCache[file]
	end
	local src = __readfile(file)
	assert(src, "cannot read " .. file)
	local fn = __compile("local script, require = ...; " .. src, file)
	local result = fn(node, fakeRequire)
	moduleCache[file] = result
	return result
end

local Shared = makeNode(ROOT, "Shared", nil)

local passed, failed = 0, 0
local currentSuite = ""

local T = {}

function T.suite(name: string)
	currentSuite = name
end

function T.test(name: string, fn: () -> ())
	local ok, err = pcall(fn)
	if ok then
		passed += 1
	else
		failed += 1
		print("FAIL [" .. currentSuite .. "] " .. name .. ": " .. tostring(err))
	end
end

function T.eq(a, b, msg: string?)
	if a ~= b then
		error((msg or "values differ") .. ": expected " .. tostring(b) .. ", got " .. tostring(a), 2)
	end
end

function T.near(a: number, b: number, eps: number?, msg: string?)
	if math.abs(a - b) > (eps or 1e-6) then
		error((msg or "not near") .. ": expected " .. tostring(b) .. ", got " .. tostring(a), 2)
	end
end

function T.truthy(v, msg: string?)
	if not v then
		error(msg or "expected truthy", 2)
	end
end

-- deterministic rng for tests
function T.seq(values: { number })
	local i = 0
	return function()
		i += 1
		return values[((i - 1) % #values) + 1]
	end
end

for _, entry in __listdir("tests") do
	if entry:match("%.spec%.luau$") then
		local src = __readfile("tests/" .. entry)
		local fn = __compile("local Shared, T, require = ...; " .. src, "tests/" .. entry)
		local ok, err = pcall(fn, Shared, T, fakeRequire)
		if not ok then
			failed += 1
			print("ERROR loading " .. entry .. ": " .. tostring(err))
		end
	end
end

print(string.format("%d passed, %d failed", passed, failed))
if failed > 0 then
	error("tests failed")
end
