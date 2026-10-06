-- Robux shop (passes, products, the fair-play promise), the fox-token shop
-- and settings.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")

local Net = require(Shared.Net)
local Products = require(Shared.Config.Products)
local Strings = require(Shared.Config.Strings)
local Kit = require(script.Parent.Parent.Kit)
local Common = require(script.Parent.Parent.Common)
local Locale = require(script.Parent.Parent.Parent.Locale)
local State = require(script.Parent.Parent.Parent.State)

return function(App)
	local function buy(kind: string, name: string, price: number)
		local p = State.profile
		local go = function()
			Net.action(kind, name)
		end
		-- gentle reminder after a lot of spending today
		if p and (p.SpentToday or 0) + price >= (p.SpendReminder or math.huge) then
			App.open("Confirm", { text = Locale.t("ui.spendReminder", { robux = p.SpentToday or 0 }), onYes = go })
		else
			go()
		end
	end

	App.register("RobuxShop", {
		title = "panel.shop",
		listens = { "Profile" },
		render = function(ctx)
			local p = State.profile
			if not p then
				return
			end
			local list = Kit.scroll(ctx.body, UDim2.fromScale(1, 1))
			local promise = Kit.label(Locale.t("ui.fairPromise"), {
				BackgroundColor3 = Color3.fromRGB(230, 245, 225),
				BackgroundTransparency = 0,
				TextSize = 14,
				LayoutOrder = 1,
				Parent = list,
			})
			Kit.corner(promise, 8)
			Kit.padding(promise, 8)
			local order = 2
			Kit.label(Locale.t("ui.passes"), { Font = Kit.font, TextSize = 18, LayoutOrder = order, Parent = list })
			for name, def in Products.passes do
				order += 1
				local owned = p.Passes and p.Passes[name]
				local row = Kit.row(64)
				row.LayoutOrder = order
				row.Parent = list
				Kit.label(Locale.pick(def.name) .. "\n" .. Locale.pick(def.desc), { Size = UDim2.new(1, -140, 1, 0), TextSize = 13, LayoutOrder = 1, Parent = row })
				local b = Kit.button(if owned then "✔" else ("R$ " .. def.price), function()
					buy("BuyPass", name, def.price)
				end, { Size = UDim2.fromOffset(120, 38), BackgroundColor3 = Kit.colors.gold, LayoutOrder = 2, Parent = row })
				Kit.setEnabled(b, not owned and p.ProductsEnabled and p.ProductsEnabled[name] == true)
			end
			order += 1
			Kit.label(Locale.t("ui.products"), { Font = Kit.font, TextSize = 18, LayoutOrder = order, Parent = list })
			for name, def in Products.devProducts do
				order += 1
				local row = Kit.row(64)
				row.LayoutOrder = order
				row.Parent = list
				Kit.label(Locale.pick(def.name) .. "\n" .. Locale.pick(def.desc), { Size = UDim2.new(1, -140, 1, 0), TextSize = 13, LayoutOrder = 1, Parent = row })
				local b = Kit.button("R$ " .. def.price, function()
					buy("BuyProduct", name, def.price)
				end, { Size = UDim2.fromOffset(120, 38), BackgroundColor3 = Kit.colors.gold, LayoutOrder = 2, Parent = row })
				Kit.setEnabled(b, p.ProductsEnabled and p.ProductsEnabled[name] == true)
			end
			-- fox tokens
			order += 1
			Kit.label(Locale.t("ui.tokenShop", { n = p.Inventory.FoxToken or 0 }), { Font = Kit.font, TextSize = 18, LayoutOrder = order, Parent = list })
			for _, offer in p.TokenShop or {} do
				order += 1
				local isTheme = string.sub(offer.id, 1, 6) == "theme:"
				local label
				if isTheme then
					local themeId = string.sub(offer.id, 7)
					for _, t in Products.themes do
						if t.id == themeId then
							label = Locale.t("ui.theme") .. ": " .. Locale.pick(t.name)
						end
					end
				else
					label = Locale.itemName(offer.id)
				end
				local row = Kit.row(48)
				row.LayoutOrder = order
				row.Parent = list
				Kit.label(label or offer.id, { Size = UDim2.new(1, -140, 1, 0), LayoutOrder = 1, Parent = row })
				local b = Kit.button("🦊 " .. offer.cost, function()
					Net.action("TokenShop", offer.id)
				end, { Size = UDim2.fromOffset(120, 36), LayoutOrder = 2, Parent = row })
				Kit.setEnabled(b, (p.Inventory.FoxToken or 0) >= offer.cost)
			end
			local _ = Common
		end,
	})

	App.register("Settings", {
		title = "panel.settings",
		render = function(ctx)
			local list = Kit.scroll(ctx.body, UDim2.fromScale(1, 1))
			Kit.label(Locale.t("ui.language"), { Font = Kit.font, LayoutOrder = 1, Parent = list })
			local codes = {}
			for code in Strings.languages do
				table.insert(codes, code)
			end
			table.sort(codes)
			for i, code in codes do
				Kit.button(Strings.languages[code] .. (if Locale.lang == code then " ✔" else ""), function()
					Locale.set(code)
				end, { Size = UDim2.new(1, 0, 0, 36), LayoutOrder = 1 + i, Parent = list })
			end
			local p = State.profile
			if p then
				local s = p.Stats
				Kit.label(Locale.t("ui.stats", {
					harvested = Locale.num(s.harvested),
					gleaned = s.gleaned,
					trips = s.trips,
					trades = s.trades,
					hours = math.floor(s.playtime / 3600),
				}), { TextColor3 = Kit.colors.muted, LayoutOrder = 50, Parent = list })
			end
		end,
	})
end
