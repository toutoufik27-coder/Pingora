-- Animals list, one animal, breeding and hatching (with visible odds), and
-- the animal shop.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")

local Net = require(Shared.Net)
local Animals = require(Shared.Config.Animals)
local Kit = require(script.Parent.Parent.Kit)
local Common = require(script.Parent.Parent.Common)
local Locale = require(script.Parent.Parent.Parent.Locale)
local State = require(script.Parent.Parent.Parent.State)

local function colorOf(a: any): Color3
	local s = Animals.species[a.species]
	for _, c in s.colors do
		if c.id == a.color then
			return Common.color(c.rgb)
		end
	end
	return Color3.new(1, 1, 1)
end

local function traitText(a: any): string
	local names = {}
	for _, t in a.traits or {} do
		local def = Animals.traits[t]
		table.insert(names, if def then Locale.pick(def.name) else t)
	end
	return table.concat(names, ", ")
end

local function animalLine(a: any): string
	local s = Animals.species[a.species]
	local parts = { Locale.pick(s.name) .. " · " .. a.color }
	if a.name then
		parts[1] = a.name .. " — " .. parts[1]
	end
	local traits = traitText(a)
	if traits ~= "" then
		table.insert(parts, traits)
	end
	if s.product then
		table.insert(parts, string.format("🍽 %d · 📦 %d", a.food or 0, a.stored or 0))
	end
	if a.companion then
		table.insert(parts, Locale.t("ui.companion"))
	end
	if a.busy then
		table.insert(parts, Locale.t("ui.busy"))
	end
	return table.concat(parts, "  ")
end

return function(App)
	local breedPick: { string } = {}

	App.register("Animals", {
		title = "panel.animals",
		listens = { "Profile" },
		render = function(ctx)
			local p = State.profile
			if not p then
				return
			end
			local list = Kit.scroll(ctx.body, UDim2.fromScale(1, 1))
			-- nursery
			local now = State.now()
			local order = 0
			local function nurseryRow(text: string, done: number)
				order += 1
				local row = Kit.row(48)
				row.LayoutOrder = order
				row.Parent = list
				Kit.label(text .. " · " .. (if now >= done then Locale.t("ui.ready") else Locale.duration(done - now)), { Size = UDim2.new(1, -110, 1, 0), LayoutOrder = 1, Parent = row })
				local b = Kit.button(Locale.t("ui.claim"), function()
					Net.action("ClaimNursery")
				end, { Size = UDim2.fromOffset(96, 34), LayoutOrder = 2, Parent = row })
				Kit.setEnabled(b, now >= done)
			end
			if p.Breeding then
				nurseryRow(Locale.t("ui.breeding"), p.Breeding.done)
			end
			if p.Hatching then
				nurseryRow(Locale.t("ui.hatching"), p.Hatching.done)
			end
			-- breeding picker
			order += 1
			local hint = if #breedPick == 1 then Locale.t("ui.breedPickSecond") else Locale.t("ui.breedHelp")
			Kit.label(hint, { TextColor3 = Kit.colors.muted, LayoutOrder = order, Parent = list })
			local ids = {}
			for id in p.Animals do
				table.insert(ids, id)
			end
			table.sort(ids, function(x, y)
				local a, b = p.Animals[x], p.Animals[y]
				if a.species ~= b.species then
					return a.species < b.species
				end
				return x < y
			end)
			if #ids == 0 then
				order += 1
				Kit.label(Locale.t("ui.noAnimals"), { LayoutOrder = order, Parent = list })
			end
			for _, id in ids do
				local a = p.Animals[id]
				order += 1
				local row = Kit.row(52)
				row.LayoutOrder = order
				row.Parent = list
				Kit.swatch(colorOf(a), utf8.char(utf8.codepoint(Locale.pick(Animals.species[a.species].name), 1, 1)), 36).Parent = row
				Kit.label(animalLine(a), { Size = UDim2.new(1, -250, 1, 0), TextSize = 13, LayoutOrder = 2, Parent = row })
				Kit.button(Locale.t("ui.open"), function()
					App.open("Animal", { id = id })
				end, { Size = UDim2.fromOffset(90, 34), LayoutOrder = 3, Parent = row })
				local selected = table.find(breedPick, id) ~= nil
				local bb = Kit.button(if selected then "❤" else "♡", function()
					if selected then
						table.remove(breedPick, table.find(breedPick, id) :: number)
						ctx.refresh()
						return
					end
					table.insert(breedPick, id)
					if #breedPick == 2 then
						local x, y = p.Animals[breedPick[1]], p.Animals[breedPick[2]]
						local pair = { breedPick[1], breedPick[2] }
						breedPick = {}
						if x and y and x.species == y.species then
							local odds = Net.request("Odds", "breed", x.species, x.color, y.color)
							App.open("Confirm", {
								text = Locale.t("ui.breedConfirm") .. "\n" .. Common.oddsText(odds),
								onYes = function()
									Net.action("Breed", pair[1], pair[2])
								end,
							})
							return
						end
					end
					ctx.refresh()
				end, { Size = UDim2.fromOffset(46, 34), BackgroundColor3 = Kit.colors.kind, LayoutOrder = 4, Parent = row })
				Kit.setEnabled(bb, not a.busy and a.species ~= "Bee" and Animals.species[a.species].colors ~= nil)
			end
		end,
	})

	App.register("Animal", {
		title = "panel.animal",
		listens = { "Profile" },
		render = function(ctx)
			local p = State.profile
			local id = ctx.arg and ctx.arg.id
			local a = p and id and p.Animals[id]
			if not a then
				Kit.label(Locale.t("ui.empty"), { Parent = ctx.body })
				return
			end
			local s = Animals.species[a.species]
			local list = Kit.scroll(ctx.body, UDim2.fromScale(1, 1))
			Kit.label(animalLine(a), { Font = Kit.font, LayoutOrder = 1, Parent = list })
			for _, t in a.traits or {} do
				local def = Animals.traits[t]
				if def then
					Kit.label("• " .. Locale.pick(def.name) .. ": " .. Locale.pick(def.desc), { TextSize = 13, LayoutOrder = 2, Parent = list })
				end
			end
			if s.food then
				local foods = {}
				for _, f in s.food do
					table.insert(foods, Locale.idName(f) .. " ×" .. (p.Inventory[f] or 0))
				end
				Kit.label(Locale.t("ui.eats") .. ": " .. table.concat(foods, ", "), { TextSize = 13, LayoutOrder = 3, Parent = list })
			end
			local row = Kit.new("Frame", { Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1, LayoutOrder = 4, Parent = list })
			Kit.list(row, true, 6)
			if s.food then
				Kit.button(Locale.t("ui.feed"), function()
					Net.action("AnimalAction", id, "feed")
				end, { LayoutOrder = 1, Parent = row })
			end
			if s.product then
				Kit.button(Locale.t("ui.collect"), function()
					Net.action("AnimalAction", id, "collect")
				end, { LayoutOrder = 2, Parent = row })
			end
			Kit.button(if a.companion then Locale.t("ui.sendHome") else Locale.t("ui.followMe"), function()
				Net.action("AnimalAction", id, "companion")
			end, { BackgroundColor3 = Kit.colors.buttonAlt, LayoutOrder = 3, Parent = row })
			local row2 = Kit.new("Frame", { Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1, LayoutOrder = 5, Parent = list })
			Kit.list(row2, true, 6)
			if a.species == "Chicken" then
				Kit.button(Locale.t("ui.hatch"), function()
					local odds = Net.request("Odds", "hatch", "Chicken", a.color)
					App.open("Confirm", {
						text = Locale.t("ui.hatchConfirm") .. "\n" .. Common.oddsText(odds),
						onYes = function()
							Net.action("Hatch", id)
						end,
					})
				end, { LayoutOrder = 1, Parent = row2 })
			end
			Kit.button(Locale.t("ui.retire"), function()
				App.open("Confirm", {
					text = Locale.t("ui.retireConfirm"),
					onYes = function()
						Net.action("AnimalAction", id, "retire")
					end,
				})
			end, { BackgroundColor3 = Kit.colors.danger, LayoutOrder = 2, Parent = row2 })
			-- rename
			local box = Kit.new("TextBox", {
				Size = UDim2.new(1, -110, 0, 34),
				PlaceholderText = Locale.t("ui.namePlaceholder"),
				Text = a.name or "",
				ClearTextOnFocus = false,
				Font = Kit.fontBody,
				TextSize = 15,
				BackgroundColor3 = Color3.new(1, 1, 1),
				LayoutOrder = 6,
				Parent = list,
			})
			Kit.corner(box, 6)
			Kit.button(Locale.t("ui.rename"), function()
				Net.action("RenameAnimal", id, string.sub(box.Text, 1, 20))
			end, { LayoutOrder = 7, Parent = list })
		end,
	})

	App.register("AnimalShop", {
		title = "panel.animalShop",
		listens = { "Profile" },
		render = function(ctx)
			local p = State.profile
			if not p then
				return
			end
			local list = Kit.scroll(ctx.body, UDim2.fromScale(1, 1))
			Kit.label(Locale.t("ui.animalShopHelp"), { TextColor3 = Kit.colors.muted, LayoutOrder = 0, Parent = list })
			for i, sid in Animals.order do
				local s = Animals.species[sid]
				local row = Kit.row(56)
				row.LayoutOrder = i
				row.Parent = list
				Kit.swatch(Common.color(s.colors[1].rgb), utf8.char(utf8.codepoint(Locale.pick(s.name), 1, 1)), 38).Parent = row
				local job = if s.job then Locale.t("job." .. s.job) else (if s.product then Locale.idName(if s.product == "Honey" then Animals.DEFAULT_HONEY else s.product) else "")
				Kit.label(Locale.pick(s.name) .. "\n" .. string.format("🪙%s · Lv%d · %s", Locale.num(s.price), s.level, job), { Size = UDim2.new(1, -250, 1, 0), TextSize = 13, LayoutOrder = 2, Parent = row })
				Kit.button(Locale.t("ui.odds"), function()
					local odds = Net.request("Odds", "shop", sid)
					App.open("Confirm", {
						text = Locale.t("ui.shopOdds") .. "\n" .. Common.oddsText(odds),
						onYes = function()
							Net.action("BuyAnimal", sid)
						end,
					})
				end, { Size = UDim2.fromOffset(80, 34), BackgroundColor3 = Kit.colors.buttonAlt, LayoutOrder = 3, Parent = row })
				local b = Kit.button(Locale.t("ui.adopt"), function()
					Net.action("BuyAnimal", sid)
				end, { Size = UDim2.fromOffset(90, 34), LayoutOrder = 4, Parent = row })
				Kit.setEnabled(b, p.Level >= s.level and p.Coins >= s.price)
			end
		end,
	})
end
