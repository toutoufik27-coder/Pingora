-- Localisation on the client. Server messages arrive as keys; this turns
-- them into text in the player's language.

local LocalizationService = game:GetService("LocalizationService")
local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")

local Strings = require(Shared.Config.Strings)
local Items = require(Shared.Config.Items)
local Weather = require(Shared.Config.Weather)
local ItemLogic = require(Shared.Logic.Items)
local Signal = require(Shared.Util.Signal)

local Locale = {}

Locale.Changed = Signal.new()

local function detect(): string
	local ok, id = pcall(function()
		return LocalizationService.RobloxLocaleId
	end)
	if not ok or type(id) ~= "string" then
		local player = Players.LocalPlayer
		id = player and player.LocaleId or "en-us"
	end
	local code = string.lower(string.sub(id, 1, 2))
	if Strings.languages[code] then
		return code
	end
	return "en"
end

Locale.lang = detect()

function Locale.isRtl(): boolean
	return Locale.lang == "ar"
end

function Locale.set(lang: string)
	if Strings.languages[lang] then
		Locale.lang = lang
		Locale.Changed:Fire(lang)
	end
end

local function interpolate(text: string, vars: { [string]: any }?): string
	if not vars then
		return text
	end
	return (string.gsub(text, "{(%w+)}", function(k)
		local v = vars[k]
		if v == nil then
			return "{" .. k .. "}"
		end
		return tostring(v)
	end))
end

-- Text for a key. Missing keys fall back to English, then to the key itself.
function Locale.t(key: string, vars: { [string]: any }?): string
	local entry = Strings.text[key]
	if not entry then
		return interpolate(key, vars)
	end
	return interpolate(entry[Locale.lang] or entry.en or key, vars)
end

-- Picks the right language from a { en = ..., ar = ... } table.
function Locale.pick(t: { [string]: string }?): string
	if not t then
		return "?"
	end
	return t[Locale.lang] or t.en or "?"
end

function Locale.itemName(key: string): string
	local p = ItemLogic.parse(key)
	if not p.def then
		return key
	end
	local name = Locale.pick(p.def.name)
	if #p.mutations > 0 then
		local muts = {}
		for _, m in p.mutations do
			local def = Weather.mutations[m]
			table.insert(muts, if def then Locale.pick(def.name) else m)
		end
		name = name .. " (" .. table.concat(muts, ", ") .. ")"
	end
	return name
end

function Locale.idName(id: string): string
	local def = Items.byId[id]
	return if def then Locale.pick(def.name) else id
end

-- Short number formatting: 1.2K, 3.4M
function Locale.num(n: number): string
	n = math.floor(n)
	local abs = math.abs(n)
	if abs >= 1e9 then
		return string.format("%.1fB", n / 1e9)
	elseif abs >= 1e6 then
		return string.format("%.1fM", n / 1e6)
	elseif abs >= 1e4 then
		return string.format("%.1fK", n / 1e3)
	end
	return tostring(n)
end

function Locale.duration(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	if seconds >= 3600 then
		return string.format("%dh %02dm", seconds // 3600, (seconds % 3600) // 60)
	elseif seconds >= 60 then
		return string.format("%dm %02ds", seconds // 60, seconds % 60)
	end
	return seconds .. "s"
end

return Locale
