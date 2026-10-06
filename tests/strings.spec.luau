local Strings = require(Shared.Config.Strings)
local Economy = require(Shared.Config.Economy)
local Animals = require(Shared.Config.Animals)

T.suite("Strings")

local function walk(dir: string, out: { string })
	for _, entry in __listdir(dir) do
		local path = dir .. "/" .. entry
		if __isdir(path) then
			walk(path, out)
		elseif string.match(entry, "%.luau$") then
			table.insert(out, path)
		end
	end
end

T.test("every key used in code has a translation", function()
	local files = {}
	walk("src", files)
	local missing = {}
	local prefixes = { "ui", "note", "sign", "prompt", "tool", "panel", "tab", "job", "tile" }
	for _, f in files do
		if not string.find(f, "Strings.luau", 1, true) then
			local src = __readfile(f)
			for key in string.gmatch(src, '"(%a+%.[%w_]+)"') do
				local prefix = string.match(key, "^(%a+)%.")
				if table.find(prefixes, prefix) and key ~= "note.trade_" and not Strings.text[key] then
					missing[key] = f
				end
			end
		end
	end
	-- keys built at runtime
	for _, tool in Economy.TOOLS do
		local k = "tool." .. string.lower(tool)
		if not Strings.text[k] then
			missing[k] = "Economy.TOOLS"
		end
	end
	for _, s in Animals.species do
		if s.job and not Strings.text["job." .. s.job] then
			missing["job." .. s.job] = "Animals"
		end
	end
	for _, reason in { "notTradeable", "notEnough", "noAnimal", "animalBusy", "tooMany" } do
		if not Strings.text["note.trade_" .. reason] then
			missing["note.trade_" .. reason] = "Social.validateOffer"
		end
	end
	local list = {}
	for k, f in missing do
		table.insert(list, k .. " (" .. f .. ")")
	end
	table.sort(list)
	T.eq(#list, 0, "missing: " .. table.concat(list, ", "))
end)

T.test("every entry has every language", function()
	for key, entry in Strings.text do
		for code in Strings.languages do
			T.truthy(type(entry[code]) == "string" and #entry[code] > 0, key .. " lacks " .. code)
		end
	end
end)
