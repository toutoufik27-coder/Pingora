-- The global market and the trade window.

local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")

local Net = require(Shared.Net)
local Items = require(Shared.Config.Items)
local Animals = require(Shared.Config.Animals)
local ItemLogic = require(Shared.Logic.Items)
local Pricing = require(Shared.Logic.Pricing)
local Kit = require(script.Parent.Parent.Kit)
local Common = require(script.Parent.Parent.Common)
local Locale = require(script.Parent.Parent.Parent.Locale)
local State = require(script.Parent.Parent.Parent.State)

local MARKET_TABS = {
	{ id = "buy", key = "tab.buy" },
	{ id = "sell", key = "tab.sell" },
	{ id = "mine", key = "tab.myListings" },
}

local CATEGORIES = { "crop", "seed", "product", "good", "material" }

return function(App)
	---------------------------------------------------------------- market
	local tab = "buy"
	local category = "crop"
	local selected: string? = nil
	local cache: { [string]: { at: number, data: any } } = {}
	local sellCount, sellPrice = 1, 0

	local function listings(key: string, force: boolean?): any
		local c = cache[key]
		if c and not force and os.clock() - c.at < 10 then
			return c.data
		end
		local data = Net.request("MarketListings", key)
		cache[key] = { at = os.clock(), data = data }
		return data
	end

	local function catalog(list: Instance, kinds: { string }, onPick: (string) -> ())
		local ids = {}
		for id, def in Items.byId do
			if def.market and table.find(kinds, def.kind) then
				table.insert(ids, id)
			end
		end
		table.sort(ids, function(a, b)
			local da, db = Items.byId[a], Items.byId[b]
			if da.tier ~= db.tier then
				return da.tier < db.tier
			end
			return a < b
		end)
		for i, id in ids do
			Common.itemRow(list, id, "🪙~" .. math.floor(Pricing.value(id)), {
				Kit.button(Locale.t("ui.view"), function()
					onPick(id)
				end),
			}, i + 1)
		end
	end

	App.register("Market", {
		title = "panel.market",
		listens = { "Profile" },
		wide = true,
		render = function(ctx)
			local p = State.profile
			if not p then
				return
			end
			Common.tabs(ctx.body, MARKET_TABS, tab, function(id)
				tab = id
				selected = nil
				ctx.refresh()
			end)
			local list = Kit.scroll(ctx.body, UDim2.new(1, 0, 1, -40), UDim2.fromOffset(0, 38))
			if tab == "mine" then
				local any = false
				for id, rec in p.Listings or {} do
					any = true
					Common.itemRow(list, rec.k, string.format("×%d · 🪙%d · %s", rec.n, rec.p, Locale.duration(rec.e - State.now())), {
						Kit.button(Locale.t("ui.cancel"), function()
							Net.action("MarketCancel", id)
						end, { BackgroundColor3 = Kit.colors.danger }),
					})
				end
				if not any then
					Kit.label(Locale.t("ui.noListings"), { Parent = list })
				end
				return
			end
			if tab == "buy" then
				if not selected then
					local cats = {}
					for _, c in CATEGORIES do
						table.insert(cats, { id = c, key = "tab." .. c .. "s" })
					end
					local bar = Common.tabs(list, cats, category, function(id)
						category = id
						ctx.refresh()
					end)
					bar.LayoutOrder = 0
					catalog(list, { category }, function(id)
						selected = id
						ctx.refresh()
					end)
					return
				end
				local key = selected
				Kit.button("← " .. Locale.t("ui.back"), function()
					selected = nil
					ctx.refresh()
				end, { LayoutOrder = 0, Parent = list })
				local data = listings(key)
				if not data then
					Kit.label(Locale.t("note.marketUnavailable"), { LayoutOrder = 1, Parent = list })
					return
				end
				Kit.label(Locale.itemName(key) .. " · " .. Locale.t("ui.reference", { coins = data.reference }), { Font = Kit.font, LayoutOrder = 1, Parent = list })
				if #data.listings == 0 then
					Kit.label(Locale.t("ui.noListings"), { LayoutOrder = 2, Parent = list })
				end
				for i, l in data.listings do
					local mine = l.seller == Players.LocalPlayer.UserId
					local b1 = Kit.button(Locale.t("ui.buy1"), function()
						Net.action("MarketBuy", key, l.id, 1)
						cache[key] = nil
					end)
					local bAll = Kit.button(Locale.t("ui.buyAll"), function()
						Net.action("MarketBuy", key, l.id, l.n)
						cache[key] = nil
					end, { BackgroundColor3 = Kit.colors.buttonAlt })
					Kit.setEnabled(b1, not mine and p.Coins >= l.price)
					Kit.setEnabled(bAll, not mine and p.Coins >= l.price * l.n)
					Common.itemRow(list, key, string.format("×%d · 🪙%d %s%s", l.n, l.price, Locale.t("ui.each"), if mine then " · " .. Locale.t("ui.yours") else ""), { b1, bAll }, 2 + i)
				end
				Kit.button(Locale.t("ui.refresh"), function()
					listings(key, true)
					ctx.refresh()
				end, { LayoutOrder = 100, Parent = list })
				return
			end
			-- sell tab
			if not selected then
				Kit.label(Locale.t("ui.marketSellHelp"), { TextColor3 = Kit.colors.muted, LayoutOrder = 0, Parent = list })
				for i, key in Common.inventoryKeys(p.Inventory, CATEGORIES) do
					if ItemLogic.isMarketable(key) and #ItemLogic.parse(key).mutations == 0 then
						Common.itemRow(list, key, "×" .. p.Inventory[key], {
							Kit.button(Locale.t("ui.list"), function()
								selected = key
								sellCount = 1
								sellPrice = math.floor(Pricing.value(key))
								ctx.refresh()
							end),
						}, i)
					end
				end
				return
			end
			local key = selected
			local have = p.Inventory[key] or 0
			local lo, hi = Pricing.marketBand(key)
			sellPrice = math.clamp(sellPrice, lo, hi)
			sellCount = math.clamp(sellCount, 1, math.max(1, have))
			Kit.button("← " .. Locale.t("ui.back"), function()
				selected = nil
				ctx.refresh()
			end, { LayoutOrder = 0, Parent = list })
			Kit.label(Locale.itemName(key) .. " · " .. Locale.t("ui.youHave") .. " " .. have, { Font = Kit.font, LayoutOrder = 1, Parent = list })
			Kit.label(Locale.t("ui.amount"), { LayoutOrder = 2, Parent = list })
			local countStep = Kit.stepper(sellCount, 1, math.max(1, have), 1, function(v)
				sellCount = v
			end)
			countStep.LayoutOrder = 3
			countStep.Parent = list
			Kit.label(Locale.t("ui.pricePer", { lo = lo, hi = hi }), { LayoutOrder = 4, Parent = list })
			local priceStep = Kit.stepper(sellPrice, lo, hi, math.max(1, math.floor((hi - lo) / 20)), function(v)
				sellPrice = v
			end)
			priceStep.LayoutOrder = 5
			priceStep.Parent = list
			Kit.label(Locale.t("ui.marketFee"), { TextSize = 13, TextColor3 = Kit.colors.muted, LayoutOrder = 6, Parent = list })
			local b = Kit.button(Locale.t("ui.list"), function()
				Net.action("MarketList", key, sellCount, sellPrice)
				selected = nil
				tab = "mine"
				task.delay(0.5, ctx.refresh)
			end, { LayoutOrder = 7, Parent = list })
			Kit.setEnabled(b, have > 0)
		end,
	})

	---------------------------------------------------------------- trading
	App.register("TradeList", {
		title = "panel.trade",
		render = function(ctx)
			local list = Kit.scroll(ctx.body, UDim2.fromScale(1, 1))
			Kit.label(Locale.t("ui.tradeHelp"), { TextColor3 = Kit.colors.muted, Parent = list })
			for _, pl in Players:GetPlayers() do
				if pl ~= Players.LocalPlayer then
					local row = Kit.row(48)
					row.Parent = list
					Kit.label(pl.DisplayName, { Size = UDim2.new(1, -130, 1, 0), Font = Kit.font, LayoutOrder = 1, Parent = row })
					Kit.button(Locale.t("ui.invite"), function()
						Net.action("TradeRequest", pl.UserId)
					end, { Size = UDim2.fromOffset(110, 34), LayoutOrder = 2, Parent = row })
				end
			end
		end,
	})

	App.register("TradeInvite", {
		title = "panel.tradeInvite",
		render = function(ctx)
			local data = ctx.arg or {}
			Kit.label(Locale.t("ui.tradeInviteFrom", { name = data.name or "?" }), { TextSize = 18, Parent = ctx.body })
			local row = Kit.new("Frame", { Size = UDim2.new(1, 0, 0, 44), Position = UDim2.new(0, 0, 1, -48), BackgroundTransparency = 1, Parent = ctx.body })
			Kit.list(row, true, 10).HorizontalAlignment = Enum.HorizontalAlignment.Center
			Kit.button(Locale.t("ui.accept"), function()
				Net.action("TradeRespond", data.userId, true)
				App.close()
			end, { LayoutOrder = 1, Parent = row })
			Kit.button(Locale.t("ui.decline"), function()
				Net.action("TradeRespond", data.userId, false)
				App.close()
			end, { BackgroundColor3 = Kit.colors.danger, LayoutOrder = 2, Parent = row })
		end,
	})

	local function sideFor(t: any): (any, any)
		local me = Players.LocalPlayer.UserId
		if t.a.userId == me then
			return t.a, t.b
		end
		return t.b, t.a
	end

	App.register("Trade", {
		title = "panel.trade",
		listens = { "Trade", "Profile" },
		wide = true,
		render = function(ctx)
			local t = State.trade
			local p = State.profile
			if not t or not p then
				Kit.label(Locale.t("ui.noTrade"), { Parent = ctx.body })
				return
			end
			local mine, theirs = sideFor(t)
			local function offerColumn(side: any, x: number, title: string, isMine: boolean)
				local col = Kit.new("Frame", { Size = UDim2.new(0.5, -6, 0.55, 0), Position = UDim2.new(x, if x > 0 then 6 else 0, 0, 0), BackgroundColor3 = Kit.colors.bg, Parent = ctx.body })
				Kit.corner(col, 8)
				local scroll = Kit.scroll(col, UDim2.fromScale(1, 1))
				Kit.label(title .. string.format(" · 🪙%s %s", Locale.num(side.value), if side.ready then "✔" else ""), { Font = Kit.font, LayoutOrder = 0, Parent = scroll })
				local i = 0
				for key, n in side.items do
					i += 1
					local buttons = nil
					if isMine then
						buttons = {
							Kit.button("-1", function()
								local items = table.clone(mine.items)
								items[key] = (items[key] or 0) - 1
								if items[key] <= 0 then
									items[key] = nil
								end
								local ids = {}
								for _, a in mine.animals do
									table.insert(ids, a.id)
								end
								Net.action("TradeOffer", items, ids)
							end, { BackgroundColor3 = Kit.colors.danger }),
						}
					end
					Common.itemRow(scroll, key, "×" .. n, buttons, i)
				end
				for _, a in side.animals do
					i += 1
					local s = Animals.species[a.species]
					Kit.label("🐾 " .. Locale.pick(s.name) .. " · " .. a.color, { LayoutOrder = i, Parent = scroll })
				end
			end
			offerColumn(mine, 0, Locale.t("ui.youGive"), true)
			offerColumn(theirs, 0.5, Locale.t("ui.theyGive", { name = theirs.name }), false)

			-- my tradeable things to add
			local add = Kit.new("Frame", { Size = UDim2.new(1, 0, 0.3, -8), Position = UDim2.new(0, 0, 0.55, 6), BackgroundTransparency = 1, Parent = ctx.body })
			local addList = Kit.scroll(add, UDim2.fromScale(1, 1))
			for i, key in Common.inventoryKeys(p.Inventory) do
				if ItemLogic.isTradeable(key) then
					local inOffer = mine.items[key] or 0
					local b = Kit.button("+1", function()
						local items = table.clone(mine.items)
						items[key] = inOffer + 1
						local ids = {}
						for _, a in mine.animals do
							table.insert(ids, a.id)
						end
						Net.action("TradeOffer", items, ids)
					end)
					Kit.setEnabled(b, inOffer < p.Inventory[key])
					Common.itemRow(addList, key, string.format("×%d", p.Inventory[key] - inOffer), { b }, i)
				end
			end
			local order = 1000
			for id, a in p.Animals do
				local offered = false
				for _, o in mine.animals do
					if o.id == id then
						offered = true
					end
				end
				if not a.busy then
					order += 1
					local row = Kit.row(40)
					row.LayoutOrder = order
					row.Parent = addList
					Kit.label("🐾 " .. Locale.pick(Animals.species[a.species].name) .. " · " .. a.color, { Size = UDim2.new(1, -110, 1, 0), LayoutOrder = 1, Parent = row })
					Kit.button(if offered then "-" else "+", function()
						local ids = {}
						for _, o in mine.animals do
							if o.id ~= id then
								table.insert(ids, o.id)
							end
						end
						if not offered then
							table.insert(ids, id)
						end
						Net.action("TradeOffer", mine.items, ids)
					end, { Size = UDim2.fromOffset(90, 30), LayoutOrder = 2, Parent = row })
				end
			end

			-- footer
			local footer = Kit.new("Frame", { Size = UDim2.new(1, 0, 0, 44), Position = UDim2.new(0, 0, 1, -44), BackgroundTransparency = 1, Parent = ctx.body })
			Kit.list(footer, true, 8).VerticalAlignment = Enum.VerticalAlignment.Center
			local status = ""
			if t.countdownEnd then
				status = Locale.t("ui.tradeCountdown", { s = math.max(0, t.countdownEnd - State.now()) })
			end
			if t.imbalanced then
				status = "⚠ " .. Locale.t("ui.tradeImbalanced") .. "  " .. status
			end
			Kit.label(status, { Size = UDim2.new(1, -260, 1, 0), TextColor3 = if t.imbalanced then Kit.colors.danger else Kit.colors.text, Font = Kit.font, LayoutOrder = 1, Parent = footer })
			Kit.button(if mine.ready then Locale.t("ui.notReady") else Locale.t("ui.ready"), function()
				Net.action("TradeReady", not mine.ready)
			end, { Size = UDim2.fromOffset(120, 38), BackgroundColor3 = if mine.ready then Kit.colors.buttonAlt else Kit.colors.button, LayoutOrder = 2, Parent = footer })
			Kit.button(Locale.t("ui.cancel"), function()
				Net.action("TradeCancel")
			end, { Size = UDim2.fromOffset(110, 38), BackgroundColor3 = Kit.colors.danger, LayoutOrder = 3, Parent = footer })
			if t.countdownEnd then
				task.delay(1, function()
					if State.trade == t then
						ctx.refresh()
					end
				end)
			end
		end,
	})
end
