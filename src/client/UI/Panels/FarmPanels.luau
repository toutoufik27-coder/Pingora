-- Seed picker, seed shop, sell menu, tools, farm settings and visiting.

local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")

local Net = require(Shared.Net)
local Crops = require(Shared.Config.Crops)
local Lands = require(Shared.Config.Lands)
local Economy = require(Shared.Config.Economy)
local Products = require(Shared.Config.Products)
local Pricing = require(Shared.Logic.Pricing)
local ItemLogic = require(Shared.Logic.Items)
local Levels = require(Shared.Logic.Levels)
local Kit = require(script.Parent.Parent.Kit)
local Common = require(script.Parent.Parent.Common)
local Locale = require(script.Parent.Parent.Parent.Locale)
local State = require(script.Parent.Parent.Parent.State)

return function(App, Farming)
	-- seed picker -----------------------------------------------------------
	App.register("Seeds", {
		title = "panel.seeds",
		listens = { "Profile" },
		render = function(ctx)
			local p = State.profile
			if not p then
				return
			end
			local list = Kit.scroll(ctx.body, UDim2.fromScale(1, 1))
			local keys = Common.inventoryKeys(p.Inventory, { "seed" })
			if #keys == 0 then
				Kit.label(Locale.t("ui.noSeeds"), { Parent = list })
			end
			for i, key in keys do
				local def = ItemLogic.def(key)
				local crop = Crops.byId[def.cropId]
				local native = crop.land == "Any" or crop.land == p.Land or crop.land == p.SecondLand
				local detail = string.format("×%d · %s · %s", p.Inventory[key], Locale.duration(crop.grow), if native then Locale.t("ui.native") else Locale.t("ui.foreign"))
				Common.itemRow(list, key, detail, {
					Kit.button(Locale.t("ui.select"), function()
						Farming.selectSeed(def.cropId)
						App.close()
					end),
				}, i)
			end
		end,
	})

	-- seed shop --------------------------------------------------------------
	App.register("SeedShop", {
		title = "panel.seedShop",
		listens = { "Profile" },
		render = function(ctx)
			local p = State.profile
			if not p then
				return
			end
			local shop = p.SeedShop
			Kit.label(Locale.t("ui.restockIn", { t = Locale.duration((shop.nextAt or State.now()) - State.now()) }), { TextColor3 = Kit.colors.muted, Parent = ctx.body })
			local list = Kit.scroll(ctx.body, UDim2.new(1, 0, 1, -30), UDim2.fromOffset(0, 28))
			local ids = {}
			for id in shop.stock or {} do
				table.insert(ids, id)
			end
			table.sort(ids, function(a, b)
				return Crops.byId[a].seed < Crops.byId[b].seed
			end)
			for i, id in ids do
				local crop = Crops.byId[id]
				local n = shop.stock[id]
				local detail = string.format("🪙%d · %s %d · %s", crop.seed, Locale.t("ui.left"), n, Locale.duration(crop.grow))
				local buy1 = Kit.button(Locale.t("ui.buy1"), function()
					Net.action("BuySeed", id, 1)
				end)
				local buy5 = Kit.button(Locale.t("ui.buy5"), function()
					Net.action("BuySeed", id, 5)
				end, { BackgroundColor3 = Kit.colors.buttonAlt })
				Kit.setEnabled(buy1, n > 0 and p.Coins >= crop.seed)
				Kit.setEnabled(buy5, n > 0 and p.Coins >= crop.seed)
				Common.itemRow(list, "Seed:" .. id, detail, { buy1, buy5 }, i)
			end
			-- wish list: any shop seed the player has unlocked
			Kit.label(Locale.t("ui.wishHelp"), { Font = Kit.font, LayoutOrder = 500, Parent = list })
			local order = 501
			for _, c in Crops.list do
				if c.source == "shop" and c.level <= p.Level and not (shop.stock or {})[c.id] then
					order += 1
					local isWish = shop.wish == c.id
					Common.itemRow(list, "Seed:" .. c.id, if isWish then Locale.t("ui.wished", { n = Economy.SHOP_WISH_PITY - (shop.pity or 0) }) else Locale.t("ui.notInStock"), {
						Kit.button(if isWish then "★" else "☆", function()
							Net.action("SetWish", if isWish then nil else c.id)
						end, { BackgroundColor3 = Kit.colors.gold }),
					}, order)
				end
			end
		end,
	})

	-- sell menu ---------------------------------------------------------------
	App.register("Sell", {
		title = "panel.sell",
		listens = { "Profile" },
		render = function(ctx)
			local p = State.profile
			if not p then
				return
			end
			Kit.button(Locale.t("ui.sellAllCrops"), function()
				Net.action("SellAll")
			end, { Size = UDim2.new(1, 0, 0, 36), BackgroundColor3 = Kit.colors.buttonAlt, Parent = ctx.body })
			local list = Kit.scroll(ctx.body, UDim2.new(1, 0, 1, -44), UDim2.fromOffset(0, 42))
			local bonus = p.LegacyBonus or 0
			for i, key in Common.inventoryKeys(p.Inventory, { "crop", "product", "good", "material" }) do
				local n = p.Inventory[key]
				local price = Pricing.sellPrice(key, bonus)
				local fav = p.Favorites and p.Favorites[key]
				Common.itemRow(list, key, string.format("×%d · 🪙%d %s%s", n, price, Locale.t("ui.each"), if fav then " · ★" else ""), {
					Kit.button(Locale.t("ui.sell1"), function()
						Net.action("SellItem", key, 1)
					end),
					Kit.button(Locale.t("ui.sellAll"), function()
						Net.action("SellItem", key, n)
					end, { BackgroundColor3 = Kit.colors.buttonAlt }),
				}, i)
			end
		end,
	})

	-- tools -------------------------------------------------------------------
	App.register("Tools", {
		title = "panel.tools",
		listens = { "Profile" },
		render = function(ctx)
			local p = State.profile
			if not p then
				return
			end
			local list = Kit.scroll(ctx.body, UDim2.fromScale(1, 1))
			Kit.label(Locale.t("ui.toolsHelp"), { TextColor3 = Kit.colors.muted, Parent = list })
			for i, tool in Economy.TOOLS do
				local tier = p.Tools[tool] or 0
				local nextTier = Economy.TOOL_TIERS[tier + 1]
				local row = Kit.row(56)
				row.LayoutOrder = i + 1
				row.Parent = list
				local area = (tier * 2 + 1)
				Kit.label(Locale.t("tool." .. string.lower(tool)) .. string.format("  %d×%d", area, area), { Size = UDim2.new(0.55, 0, 1, 0), Font = Kit.font, LayoutOrder = 1, Parent = row })
				if nextTier then
					local b = Kit.button(string.format("🪙%s · Lv%d", Locale.num(nextTier.coins), nextTier.level), function()
						Net.action("UpgradeTool", tool)
					end, { Size = UDim2.fromOffset(170, 36), LayoutOrder = 2, Parent = row })
					Kit.setEnabled(b, p.Coins >= nextTier.coins and p.Level >= nextTier.level)
				else
					Kit.label(Locale.t("ui.maxed"), { Size = UDim2.fromOffset(120, 36), LayoutOrder = 2, Parent = row })
				end
			end
		end,
	})

	-- my farm: land, expansion, themes, legacy -------------------------------
	App.register("Farm", {
		title = "panel.farm",
		listens = { "Profile" },
		render = function(ctx)
			local p = State.profile
			if not p then
				return
			end
			local list = Kit.scroll(ctx.body, UDim2.fromScale(1, 1))
			-- land
			Kit.label(Locale.t("ui.landTitle"), { Font = Kit.font, TextSize = 18, LayoutOrder = 1, Parent = list })
			local landHelp = if p.Land then Locale.t("ui.landCurrent", { land = Locale.pick(Lands[p.Land].name) }) else Locale.t("ui.landHelp")
			if p.Land and p.LandChanges >= 1 then
				landHelp ..= " " .. Locale.t("ui.landChangeCost", { coins = Locale.num(Economy.LAND_CHANGE_COST) })
			end
			Kit.label(landHelp, { TextColor3 = Kit.colors.muted, LayoutOrder = 2, Parent = list })
			local order = 3
			local landIds = {}
			for id, l in Lands do
				if l.available then
					table.insert(landIds, id)
				end
			end
			table.sort(landIds, function(a, b)
				return Lands[a].order < Lands[b].order
			end)
			for _, id in landIds do
				local land = Lands[id]
				order += 1
				local row = Kit.row(48)
				row.LayoutOrder = order
				row.Parent = list
				Kit.swatch(Common.color(land.color), "", 32).Parent = row
				local natives = {}
				for _, c in Crops.list do
					if c.land == id and c.source == "shop" then
						table.insert(natives, Locale.pick(c.name))
					end
				end
				Kit.label(Locale.pick(land.name) .. ": " .. table.concat(natives, ", "), { Size = UDim2.new(1, -170, 1, 0), TextSize = 13, LayoutOrder = 2, Parent = row })
				local b = Kit.button(if p.Land == id then "✔" else Locale.t("ui.choose"), function()
					Net.action("ChooseLand", id)
				end, { Size = UDim2.fromOffset(110, 34), LayoutOrder = 3, Parent = row })
				Kit.setEnabled(b, p.Land ~= id and p.Level >= Economy.LAND_CHOICE_LEVEL)
			end
			if (p.Legacy or 0) >= Economy.LEGACY_SECOND_LAND then
				order += 1
				Kit.label(Locale.t("ui.secondLand", { land = p.SecondLand and Locale.pick(Lands[p.SecondLand].name) or "—" }), { LayoutOrder = order, Parent = list })
				for _, id in landIds do
					if id ~= p.Land then
						order += 1
						Kit.button(Locale.pick(Lands[id].name), function()
							Net.action("ChooseSecondLand", id)
						end, { LayoutOrder = order, Parent = list })
					end
				end
			end
			-- expansion
			order += 1
			Kit.label(Locale.t("ui.expandTitle", { size = p.PlotSize }), { Font = Kit.font, TextSize = 18, LayoutOrder = order, Parent = list })
			local step = Levels.nextPlotStep(p.PlotSize)
			order += 1
			if step then
				local needs = {}
				if step.wood > 0 then
					needs.Wood = step.wood
				end
				if step.stone > 0 then
					needs.Stone = step.stone
				end
				Kit.label(Locale.t("ui.expandCost", { size = step.size, coins = Locale.num(step.coins), level = step.level }) .. "\n" .. Common.needsText(needs, p.Inventory), { TextColor3 = Kit.colors.muted, LayoutOrder = order, Parent = list })
				order += 1
				local b = Kit.button(Locale.t("ui.expand"), function()
					Net.action("ExpandPlot")
				end, { LayoutOrder = order, Parent = list })
				Kit.setEnabled(b, p.Level >= step.level and Common.hasNeeds(needs, p.Inventory))
			else
				Kit.label(Locale.t("ui.maxed"), { LayoutOrder = order, Parent = list })
			end
			-- themes
			order += 1
			Kit.label(Locale.t("ui.themes"), { Font = Kit.font, TextSize = 18, LayoutOrder = order, Parent = list })
			for _, t in Products.themes do
				order += 1
				local owned = t.free or (p.OwnedThemes and p.OwnedThemes[t.id]) or (p.Passes and p.Passes.BuilderPack)
				local b = Kit.button(Locale.pick(t.name) .. (if p.Theme == t.id then " ✔" elseif owned then "" else " 🔒"), function()
					if owned then
						Net.action("SetTheme", t.id)
					elseif t.legacy then
						-- required lazily: Feedback depends on App
						local Feedback = require(script.Parent.Parent.Parent.Controllers.Feedback)
						Feedback.toast(Locale.t("ui.legacyThemeHint", { n = Economy.LEGACY_THEME }), "info")
					else
						App.open("RobuxShop")
					end
				end, { Size = UDim2.new(1, 0, 0, 34), BackgroundColor3 = Common.color(t.fence), LayoutOrder = order, Parent = list })
				local _ = b
			end
			-- legacy: past the max level, xp keeps counting and nothing resets
			local legacy = p.Legacy or 0
			order += 1
			Kit.label(Locale.t("ui.legacyTitle"), { Font = Kit.font, TextSize = 18, LayoutOrder = order, Parent = list })
			order += 1
			local title = Levels.legacyTitle(legacy)
			local lines = {
				Locale.t("ui.legacyHelp", { level = Economy.MAX_LEVEL }),
				Locale.t("ui.legacyLevel", { n = legacy }) .. (if title then " · " .. Locale.pick(title) else ""),
				Locale.t("ui.legacyBonus", { bonus = math.floor((p.LegacyBonus or 0) * 100 + 0.5) }),
			}
			if p.Level >= Economy.MAX_LEVEL then
				table.insert(lines, Locale.t("ui.legacyProgress", { xp = Locale.num(p.XP), need = Locale.num(p.XPNeed) }))
			end
			local unlocks = {
				{ at = Economy.LEGACY_SECOND_LAND, key = "ui.legacyUnlockLand" },
				{ at = Economy.LEGACY_COMPANION_SLOT, key = "ui.legacyUnlockCompanion" },
				{ at = Economy.LEGACY_THEME, key = "ui.legacyUnlockTheme" },
			}
			for _, u in unlocks do
				table.insert(lines, (if legacy >= u.at then "✔ " else "🔒 ") .. Locale.t(u.key, { n = u.at }))
			end
			Kit.label(table.concat(lines, "\n"), { TextColor3 = Kit.colors.muted, LayoutOrder = order, Parent = list })
		end,
	})

	-- visiting someone else's farm -----------------------------------------------
	App.register("Visit", {
		title = "panel.visit",
		render = function(ctx)
			local list = Kit.scroll(ctx.body, UDim2.fromScale(1, 1))
			Kit.label(Locale.t("ui.visitHelp"), { Parent = list })
			for _, pl in Players:GetPlayers() do
				if pl ~= Players.LocalPlayer then
					local row = Kit.row(48)
					row.Parent = list
					Kit.label(pl.DisplayName, { Size = UDim2.new(1, -220, 1, 0), Font = Kit.font, LayoutOrder = 1, Parent = row })
					Kit.button(Locale.t("ui.trade"), function()
						Net.action("TradeRequest", pl.UserId)
					end, { Size = UDim2.fromOffset(100, 34), LayoutOrder = 2, Parent = row })
					Kit.button(Locale.t("ui.block"), function()
						Net.action("BlockPlayer", pl.UserId)
					end, { Size = UDim2.fromOffset(90, 34), BackgroundColor3 = Kit.colors.danger, LayoutOrder = 3, Parent = row })
				end
			end
		end,
	})

	-- generic confirmation ----------------------------------------------------------
	App.register("Confirm", {
		title = "panel.confirm",
		render = function(ctx)
			local arg = ctx.arg or {}
			Kit.label(arg.text or "", { TextSize = 18, Parent = ctx.body })
			local row = Kit.new("Frame", { Size = UDim2.new(1, 0, 0, 44), Position = UDim2.new(0, 0, 1, -48), BackgroundTransparency = 1, Parent = ctx.body })
			Kit.list(row, true, 10).HorizontalAlignment = Enum.HorizontalAlignment.Center
			Kit.button(Locale.t("ui.yes"), function()
				App.close()
				if arg.onYes then
					arg.onYes()
				end
			end, { LayoutOrder = 1, Parent = row })
			Kit.button(Locale.t("ui.no"), App.close, { BackgroundColor3 = Kit.colors.danger, LayoutOrder = 2, Parent = row })
		end,
	})
end
