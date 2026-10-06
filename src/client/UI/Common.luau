-- Shared bits for panels: item rows, need lists, odds tables.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Items = require(Shared.Config.Items)
local Weather = require(Shared.Config.Weather)
local ItemLogic = require(Shared.Logic.Items)
local Kit = require(script.Parent.Kit)
local Locale = require(script.Parent.Parent.Locale)

local Common = {}

function Common.color(rgb: { number }): Color3
	return Color3.fromRGB(rgb[1], rgb[2], rgb[3])
end

function Common.itemSwatch(key: string, size: number?): Frame
	local p = ItemLogic.parse(key)
	local def = p.def
	local color = if def then Common.color(def.color) else Color3.fromRGB(150, 150, 150)
	local name = Locale.itemName(key)
	local letter = string.upper(utf8.char(utf8.codepoint(name, 1, 1)))
	local sw = Kit.swatch(color, letter, size)
	if #p.mutations > 0 then
		local m = Weather.mutations[p.mutations[1]]
		if m then
			Kit.stroke(sw, Common.color(m.color), 3)
		end
	end
	return sw
end

-- A row: swatch, name and detail text, then the given buttons.
function Common.itemRow(parent: Instance, key: string, detail: string, buttons: { TextButton }?, order: number?): Frame
	local row = Kit.row(52)
	row.LayoutOrder = order or 0
	local sw = Common.itemSwatch(key, 38)
	sw.LayoutOrder = 1
	sw.Parent = row
	local textBox = Kit.new("Frame", { Size = UDim2.new(1, -(44 + 8 + #(buttons or {}) * 96), 1, 0), BackgroundTransparency = 1, LayoutOrder = 2, Parent = row })
	Kit.list(textBox, false, 0)
	Kit.label(Locale.itemName(key), { Font = Kit.font, TextSize = 15, LayoutOrder = 1, Parent = textBox })
	Kit.label(detail, { TextSize = 13, TextColor3 = Kit.colors.muted, LayoutOrder = 2, Parent = textBox })
	for i, b in buttons or {} do
		b.Size = UDim2.fromOffset(88, 34)
		b.LayoutOrder = 10 + i
		b.Parent = row
	end
	row.Parent = parent
	return row
end

-- "Wheat 3/5, Wood 10/40" with colours for what is missing.
function Common.needsText(needs: { [string]: number }, inventory: { [string]: number }): string
	local parts = {}
	for key, n in needs do
		local have = inventory[key] or 0
		local mark = if have >= n then "✔" else "✖"
		table.insert(parts, string.format("%s %s %d/%d", mark, Locale.idName(key), have, n))
	end
	table.sort(parts)
	return table.concat(parts, "   ")
end

function Common.hasNeeds(needs: { [string]: number }, inventory: { [string]: number }): boolean
	for key, n in needs do
		if (inventory[key] or 0) < n then
			return false
		end
	end
	return true
end

-- Sorted inventory keys, optionally filtered by item kind.
function Common.inventoryKeys(inventory: { [string]: number }, kinds: { string }?): { string }
	local out = {}
	for key in inventory do
		local def = ItemLogic.def(key)
		if def and (not kinds or table.find(kinds, def.kind)) then
			table.insert(out, key)
		end
	end
	table.sort(out, function(a, b)
		local da, db = ItemLogic.def(a), ItemLogic.def(b)
		if da.tier ~= db.tier then
			return da.tier > db.tier
		end
		return a < b
	end)
	return out
end

function Common.oddsText(odds: { { color: string, chance: number } }?): string
	if not odds then
		return ""
	end
	local parts = {}
	for _, o in odds do
		table.insert(parts, string.format("%s %.1f%%", o.color, o.chance * 100))
	end
	return table.concat(parts, " · ")
end

function Common.tabs(parent: Instance, tabs: { { id: string, key: string } }, current: string, onPick: (string) -> ()): Frame
	local bar = Kit.new("Frame", { Size = UDim2.new(1, 0, 0, 34), BackgroundTransparency = 1, Parent = parent })
	Kit.list(bar, true, 4)
	for i, t in tabs do
		Kit.button(Locale.t(t.key), function()
			onPick(t.id)
		end, {
			Size = UDim2.fromOffset(92, 30),
			TextSize = 13,
			LayoutOrder = i,
			BackgroundColor3 = if t.id == current then Kit.colors.buttonAlt else Kit.colors.disabled,
			Parent = bar,
		})
	end
	return bar
end

Common.Items = Items

return Common
