-- Inventory, almanac and quests.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")

local Net = require(Shared.Net)
local Crops = require(Shared.Config.Crops)
local Weather = require(Shared.Config.Weather)
local Animals = require(Shared.Config.Animals)
local Items = require(Shared.Config.Items)
local Quests = require(Shared.Config.Quests)
local ItemLogic = require(Shared.Logic.Items)
local Pricing = require(Shared.Logic.Pricing)
local Kit = require(script.Parent.Parent.Kit)
local Common = require(script.Parent.Parent.Common)
local Locale = require(script.Parent.Parent.Parent.Locale)
local State = require(script.Parent.Parent.Parent.State)

local INVENTORY_TABS = {
	{ id = "crop", key = "tab.crops" },
	{ id = "seed", key = "tab.seeds" },
	{ id = "product", key = "tab.products" },
	{ id = "good", key = "tab.goods" },
	{ id = "material", key = "tab.materials" },
}

local ALMANAC_TABS = {
	{ id = "crops", key = "tab.crops" },
	{ id = "animals", key = "tab.animals" },
	{ id = "items", key = "tab.items" },
}

return function(App, Farming)
	local invTab = "crop"
	local almTab = "crops"

	App.register("Inventory", {
		title = "panel.inventory",
		listens = { "Profile" },
		render = function(ctx)
			local p = State.profile
			if not p then
				return
			end
			Common.tabs(ctx.body, INVENTORY_TABS, invTab, function(id)
				invTab = id
				ctx.refresh()
			end)
			local list = Kit.scroll(ctx.body, UDim2.new(1, 0, 1, -40), UDim2.fromOffset(0, 38))
			local keys = Common.inventoryKeys(p.Inventory, { invTab })
			if invTab == "product" then
				for _, k in Common.inventoryKeys(p.Inventory, { "special" }) do
					table.insert(keys, k)
				end
			end
			if #keys == 0 then
				Kit.label(Locale.t("ui.empty"), { TextColor3 = Kit.colors.muted, Parent = list })
			end
			for i, key in keys do
				local def = ItemLogic.def(key)
				local fav = p.Favorites and p.Favorites[key]
				local detail = string.format("×%d · 🪙%d", p.Inventory[key], math.floor(Pricing.value(key)))
				if ItemLogic.isTradeable(key) then
					detail ..= " · " .. Locale.t("ui.tradeable")
				end
				local buttons = {
					Kit.button(if fav then "★" else "☆", function()
						Net.action("ToggleFavorite", key)
					end, { BackgroundColor3 = Kit.colors.gold }),
				}
				if def.kind == "seed" then
					table.insert(buttons, Kit.button(Locale.t("ui.plant"), function()
						Farming.selectSeed(def.cropId)
						App.close()
					end))
				end
				Common.itemRow(list, key, detail, buttons, i)
			end
		end,
	})

	App.register("Almanac", {
		title = "panel.almanac",
		listens = { "Profile" },
		render = function(ctx)
			local p = State.profile
			if not p then
				return
			end
			Common.tabs(ctx.body, ALMANAC_TABS, almTab, function(id)
				almTab = id
				ctx.refresh()
			end)
			local list = Kit.scroll(ctx.body, UDim2.new(1, 0, 1, -40), UDim2.fromOffset(0, 38))
			if almTab == "crops" then
				local mutationIds = { "Normal" }
				for id in Weather.mutations do
					table.insert(mutationIds, id)
				end
				table.sort(mutationIds)
				local total, found = 0, 0
				for i, c in Crops.list do
					local entry = p.Almanac.crops[c.id] or {}
					local marks = {}
					local count = 0
					for _, m in mutationIds do
						total += 1
						if entry[m] then
							found += 1
							count += 1
							table.insert(marks, if m == "Normal" then "●" else "✦")
						else
							table.insert(marks, "·")
						end
					end
					local mastery = if count >= 5 then " · " .. Locale.t("ui.mastery") else ""
					local known = entry.Normal or count > 0
					local row = Common.itemRow(list, c.id, table.concat(marks, " ") .. mastery, nil, i + 1)
					if not known then
						row.BackgroundTransparency = 0.5
					end
				end
				Kit.label(Locale.t("ui.almanacProgress", { pct = math.floor(found / math.max(1, total) * 100) }), { Font = Kit.font, LayoutOrder = 0, Parent = list })
			elseif almTab == "animals" then
				local order = 0
				for _, sid in Animals.order do
					local s = Animals.species[sid]
					for _, c in s.colors do
						order += 1
						local found = p.Almanac.animals[sid .. ":" .. c.id]
						local row = Kit.row(40)
						row.LayoutOrder = order
						row.Parent = list
						Kit.swatch(if found then Common.color(c.rgb) else Color3.fromRGB(200, 200, 200), if found then "✔" else "?", 30).Parent = row
						Kit.label(Locale.pick(s.name) .. " · " .. c.id .. string.rep(" ★", c.rarity - 1), { Size = UDim2.new(1, -50, 1, 0), LayoutOrder = 2, Parent = row })
					end
				end
			else
				local ids = {}
				for id, def in Items.byId do
					if def.kind ~= "crop" and def.kind ~= "seed" and def.kind ~= "special" then
						table.insert(ids, id)
					end
				end
				table.sort(ids)
				for i, id in ids do
					local found = p.Almanac.items[id]
					local row = Common.itemRow(list, id, if found then Locale.t("ui.discovered") else "???", nil, i)
					if not found then
						row.BackgroundTransparency = 0.5
					end
				end
			end
		end,
	})

	App.register("Quests", {
		title = "panel.quests",
		listens = { "Profile" },
		render = function(ctx)
			local p = State.profile
			if not p then
				return
			end
			local list = Kit.scroll(ctx.body, UDim2.fromScale(1, 1))
			local step = Quests.story[p.Quests.story]
			Kit.label(Locale.t("ui.story"), { Font = Kit.font, TextSize = 18, LayoutOrder = 1, Parent = list })
			if step then
				local text = string.gsub(Locale.pick(step.text), "{n}", tostring(step.target))
				Kit.label(text, { LayoutOrder = 2, Parent = list })
				local bar = Kit.progress((p.Quests.storyProgress or 0) / step.target)
				bar.LayoutOrder = 3
				bar.Parent = list
			else
				Kit.label(Locale.t("ui.storyDone"), { LayoutOrder = 2, Parent = list })
			end
			Kit.label(Locale.t("ui.daily"), { Font = Kit.font, TextSize = 18, LayoutOrder = 4, Parent = list })
			local byId = {}
			for _, q in Quests.dailyPool do
				byId[q.id] = q
			end
			for i, id in p.Quests.daily or {} do
				local q = byId[id]
				if q then
					local prog = p.Quests.progress[id] or 0
					local claimed = p.Quests.claimed[id]
					local row = Kit.row(64)
					row.LayoutOrder = 4 + i
					row.Parent = list
					local box = Kit.new("Frame", { Size = UDim2.new(1, -110, 1, 0), BackgroundTransparency = 1, LayoutOrder = 1, Parent = row })
					Kit.list(box, false, 2)
					Kit.label((string.gsub(Locale.pick(q.text), "{n}", tostring(q.target))), { Font = Kit.font, TextSize = 14, LayoutOrder = 1, Parent = box })
					Kit.label(string.format("%d/%d · 🪙%d · XP %d", math.min(prog, q.target), q.target, q.coins, q.xp), { TextSize = 13, TextColor3 = Kit.colors.muted, LayoutOrder = 2, Parent = box })
					local bar = Kit.progress(prog / q.target)
					bar.LayoutOrder = 3
					bar.Parent = box
					local b = Kit.button(if claimed then "✔" else Locale.t("ui.claim"), function()
						Net.action("ClaimQuest", id)
					end, { Size = UDim2.fromOffset(96, 36), LayoutOrder = 2, Parent = row })
					Kit.setEnabled(b, not claimed and prog >= q.target)
				end
			end
			local _ = Items
		end,
	})
end
