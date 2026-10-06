local Config = Shared.Config
local Logic = Shared.Logic
local Util = Shared.Util

local Items = require(Config.Items)
local Crops = require(Config.Crops)
local Workshops = require(Config.Workshops)
local Animals = require(Config.Animals)
local Zones = require(Config.Zones)
local Projects = require(Config.Projects)
local Quests = require(Config.Quests)
local Economy = require(Config.Economy)
local ItemLogic = require(Logic.Items)
local Pricing = require(Logic.Pricing)
local Growth = require(Logic.Growth)
local WeatherLogic = require(Logic.WeatherLogic)
local Mutations = require(Logic.Mutations)
local Breeding = require(Logic.Breeding)
local Inventory = require(Logic.Inventory)
local Levels = require(Logic.Levels)
local Shop = require(Logic.Shop)
local Plot = require(Logic.Plot)
local Social = require(Logic.Social)
local Hash = require(Util.Hash)

T.suite("Config integrity")

T.test("every recipe input and output is a known item", function()
	for _, w in Workshops.list do
		for _, r in w.recipes do
			T.truthy(Items.byId[r.output], "output " .. r.output)
			for input in r.inputs do
				T.truthy(Items.byId[input], "input " .. input .. " in " .. r.id)
			end
		end
	end
end)

T.test("every zone drop, project need and animal product exists", function()
	for _, nt in Zones.nodeTypes do
		for _, d in nt.drops do
			T.truthy(Items.byId[d.item], "drop " .. d.item)
		end
	end
	for _, p in Projects.list do
		for item in p.needs do
			T.truthy(Items.byId[item], "project need " .. item)
		end
	end
	for _, s in Animals.species do
		if s.product and s.product ~= "Honey" then
			T.truthy(Items.byId[s.product], "product " .. s.product)
		end
		for _, f in s.food or {} do
			T.truthy(Crops.byId[f], "food " .. f)
		end
	end
	for _, honey in Animals.honeyFlowers do
		T.truthy(Items.byId[honey], honey)
	end
	T.truthy(Items.byId[Animals.DEFAULT_HONEY])
	for _, food in Zones.TAME_FOOD do
		T.truthy(Items.byId[food], "tame food " .. food)
	end
end)

T.test("hybrid parents and results exist", function()
	for _, h in Crops.hybrids do
		T.truthy(Crops.byId[h.a] and Crops.byId[h.b] and Crops.byId[h.result])
		T.eq(Crops.byId[h.result].source, "hybrid")
	end
end)

T.test("quest ids are unique and story is ordered", function()
	local seen = {}
	for _, q in Quests.dailyPool do
		T.truthy(not seen[q.id], "dup " .. q.id)
		seen[q.id] = true
	end
	T.truthy(#Quests.story >= 5)
end)

T.test("good values are positive and above their inputs", function()
	T.truthy(Items.byId.Bread.value > Items.byId.Flour.value * 2)
	T.truthy(Items.byId.TrufflePasta.value > 300)
end)

T.suite("Items")

T.test("crop keys sort and dedupe mutations", function()
	T.eq(ItemLogic.cropKey("Wheat", { "Wet", "Golden", "Wet" }), "Wheat#Golden+Wet")
	T.eq(ItemLogic.cropKey("Wheat", {}), "Wheat")
	local p = ItemLogic.parse("Wheat#Golden+Wet")
	T.eq(p.id, "Wheat")
	T.eq(#p.mutations, 2)
	T.eq(p.def.kind, "crop")
end)

T.test("tradeable rules", function()
	T.eq(ItemLogic.isTradeable("Wheat"), false)
	T.eq(ItemLogic.isTradeable("Wheat#Wet"), true)
	T.eq(ItemLogic.isTradeable("Seed:Sunberry"), true)
	T.eq(ItemLogic.isTradeable("Seed:Wheat"), false)
	T.eq(ItemLogic.isTradeable("FoxToken"), false)
	T.eq(ItemLogic.exists("Flour#Wet"), false)
	T.eq(ItemLogic.exists("Nope"), false)
end)

T.suite("Pricing")

T.test("mutations stack additively", function()
	T.eq(Pricing.mutationMultiplier({ "Wet", "Frozen" }), 4)
	T.eq(Pricing.sellPrice("Carrot"), 6)
	T.eq(Pricing.sellPrice("Carrot#Wet"), 12)
	T.eq(Pricing.sellPrice("Carrot", 0.5), 9)
end)

T.test("market band and imbalance", function()
	local lo, hi = Pricing.marketBand("Truffle")
	T.eq(lo, 100)
	T.eq(hi, 300)
	T.eq(Pricing.isImbalanced(100, 250), false)
	T.eq(Pricing.isImbalanced(100, 300), true)
	T.eq(Pricing.isImbalanced(0, 0), false)
end)

T.suite("Growth")

T.test("native crops grow faster, foreign yield less", function()
	local tile = Growth.plant("Wheat", 1000, { "Meadow" })
	T.eq(tile.ready, 1000 + 60 * Economy.NATIVE_GROW_MULT)
	local tile2 = Growth.plant("Wheat", 1000, { "Riverbank" })
	T.eq(tile2.ready, 1060)
	T.eq(Growth.yield("Wheat", { "Meadow" }), 3)
	T.eq(Growth.yield("Wheat", { "Riverbank" }), 2)
	T.eq(Growth.yield("Carrot", {}), 1)
end)

T.test("stages progress and watering shortens remaining time", function()
	local tile = Growth.plant("Carrot", 0, {})
	T.eq(Growth.stage(tile, 0), Growth.STAGE_SEED)
	T.eq(Growth.stage(tile, 10), Growth.STAGE_SPROUT)
	T.eq(Growth.stage(tile, 25), Growth.STAGE_GROWING)
	T.truthy(Growth.water(tile, 10))
	T.eq(tile.ready, 10 + 20 * Economy.WATER_GROW_MULT)
	T.eq(Growth.water(tile, 11), false)
	T.eq(Growth.stage(tile, tile.ready), Growth.STAGE_RIPE)
	T.eq(Growth.stage(tile, tile.ready + 179), Growth.STAGE_RIPE)
	T.eq(Growth.stage(tile, tile.ready + 180), Growth.STAGE_OVERRIPE)
end)

T.test("regrow crops restart, others clear", function()
	local tile = Growth.plant("Strawberry", 0, {})
	local after = Growth.afterHarvest(tile, 200, {})
	T.truthy(after)
	T.eq(after.ready, 260)
	T.eq(after.harvests, 1)
	T.eq(Growth.afterHarvest(Growth.plant("Carrot", 0, {}), 50, {}), nil)
end)

T.suite("Weather")

T.test("forecast is deterministic and covers several types", function()
	local seen = {}
	for slot = 1, 2000 do
		local id = WeatherLogic.weatherForSlot(slot)
		T.eq(id, WeatherLogic.weatherForSlot(slot))
		seen[id] = (seen[id] or 0) + 1
	end
	T.truthy(seen.Clear and seen.Clear > 600 and seen.Clear < 1000, "clear share " .. tostring(seen.Clear))
	T.truthy(seen.Rain and seen.Heat and seen.Frost and seen.Wind)
	T.eq(seen.Meteor, nil)
end)

T.test("active window", function()
	local info = WeatherLogic.at(480 * 1000 + 10)
	T.eq(info.slot, 1000)
	T.eq(info.endsAt, 480 * 1000 + 180)
	local o = WeatherLogic.at(5, { id = "Meteor", untilTime = 100 })
	T.eq(o.id, "Meteor")
	T.eq(o.active, true)
	T.eq(#WeatherLogic.forecast(0, 3), 3)
end)

T.test("hash spreads values in [0,1)", function()
	local sum = 0
	for i = 1, 1000 do
		local u = Hash.unit(i, 3)
		T.truthy(u >= 0 and u < 1)
		sum += u
	end
	T.truthy(sum > 450 and sum < 550, "mean " .. sum / 1000)
end)

T.suite("Mutations")

T.test("max three, no duplicates", function()
	local list = {}
	T.truthy(Mutations.add(list, "Wet"))
	T.eq(Mutations.add(list, "Wet"), false)
	Mutations.add(list, "Frozen")
	Mutations.add(list, "Golden")
	T.eq(Mutations.add(list, "Big"), false)
	T.eq(#list, 3)
end)

T.test("land bonus doubles chance and kept scale caps", function()
	T.near(Mutations.chanceFor("Rain", "Rain"), 0.10)
	T.near(Mutations.chanceFor("Rain", nil), 0.05)
	T.eq(Mutations.keptScaleCount(3 * 3600, 3600), 3)
	T.eq(Mutations.keptScaleCount(100 * 3600, 3600), 8)
	T.eq(Mutations.keptScaleCount(-5, 3600), 0)
end)

T.suite("Breeding")

T.test("odds sum to one", function()
	for _, s in Animals.species do
		local function sum(o)
			local t = 0
			for _, e in o do
				t += e.chance
			end
			return t
		end
		local c1, c2 = s.colors[1].id, s.colors[#s.colors].id
		T.near(sum(Breeding.breedOdds(s.id, c1, c2)), 1, 1e-9, s.id .. " breed")
		T.near(sum(Breeding.hatchOdds(s.id, c1)), 1, 1e-9, s.id .. " hatch")
		T.near(sum(Breeding.shopOdds(s.id)), 1, 1e-9, s.id .. " shop")
	end
end)

T.test("pick respects the table", function()
	local odds = { { color = "A", chance = 0.5 }, { color = "B", chance = 0.5 } }
	T.eq(Breeding.pick(odds, function()
		return 0.1
	end), "A")
	T.eq(Breeding.pick(odds, function()
		return 0.9
	end), "B")
	local traits = Breeding.inheritTraits({ "Swift", "Lucky" }, { "Charming" }, function()
		return 0.1
	end)
	T.eq(#traits, 2)
end)

T.suite("Inventory, levels, shop, plot, social")

T.test("inventory add/remove", function()
	local inv = {}
	Inventory.add(inv, "Wheat", 3)
	T.eq(Inventory.remove(inv, "Wheat", 4), false)
	T.truthy(Inventory.remove(inv, "Wheat", 3))
	T.eq(inv.Wheat, nil)
	Inventory.add(inv, "Wood", 5)
	T.eq(Inventory.removeAll(inv, { Wood = 2, Stone = 1 }), false)
	T.eq(inv.Wood, 5)
	T.eq(Inventory.cleanCounts({ Wood = -1 }, 5), nil)
	T.eq(Inventory.cleanCounts({ Wood = 2.7 }, 5).Wood, 2)
end)

T.test("levels", function()
	local lvl, xp, gained = Levels.addXp(1, 0, 1000)
	T.truthy(lvl > 1 and gained == lvl - 1)
	-- reaching the cap keeps counting into Legacy levels, nothing resets
	local need49 = Economy.xpForLevel(49)
	local l2, xp2, g2, legacy2, lg2 = Levels.addXp(49, 0, need49 + Economy.LEGACY_XP * 2 + 5)
	T.eq(l2, 50)
	T.eq(g2, 1)
	T.eq(legacy2, 2)
	T.eq(lg2, 2)
	T.eq(xp2, 5)
	local l3, _, _, legacy3 = Levels.addXp(50, 0, Economy.LEGACY_XP, 4)
	T.eq(l3, 50)
	T.eq(legacy3, 5)
	T.near(Levels.legacyBonus(2), 0.18)
	T.eq(Levels.legacyTitle(0), nil)
	T.truthy(Levels.legacyTitle(99))
	T.eq(Levels.xpNeed(50), Economy.LEGACY_XP)
	T.eq(Levels.nextPlotStep(6).size, 8)
	T.eq(Levels.nextPlotStep(20), nil)
end)

T.test("shop restock with wish pity", function()
	local pity = 0
	local got = false
	for i = 1, Economy.SHOP_WISH_PITY do
		local stock
		stock, pity = Shop.restock(20, "Almond", pity, function()
			return 0.99
		end)
		if stock.Almond then
			got = true
			break
		end
	end
	T.truthy(got, "wish must appear within pity")
	local stock = Shop.restock(1, nil, 0, math.random)
	T.truthy(stock.Carrot and stock.Wheat)
end)

T.test("plot keys stay stable as the plot grows", function()
	local lo, hi = Plot.bounds(6)
	T.eq(lo, 8)
	T.eq(hi, 13)
	T.eq(#Plot.unlockedKeys(6), 36)
	T.truthy(Plot.isUnlocked("8_8", 6))
	T.eq(Plot.isUnlocked("7_8", 6), false)
	T.truthy(Plot.isUnlocked("7_8", 8))
	T.eq(#Plot.area("8_8", 1, 6), 4)
end)

T.test("gleaning is positive-sum", function()
	local owner, gleaner = Social.gleanSplit(3, function()
		return 0.5
	end)
	T.eq(owner, 3)
	T.eq(gleaner, 1)
	local o1, g1 = Social.gleanSplit(1, function()
		return 0.99
	end)
	T.eq(o1, 1)
	T.eq(g1, 0)
	T.eq(Social.canGlean(Growth.STAGE_RIPE, false), false)
	T.eq(Social.canGlean(Growth.STAGE_RIPE, true), true)
	T.eq(Social.canGlean(Growth.STAGE_OVERRIPE, false), true)
end)

T.test("trade validation", function()
	local inv = { ["Wheat#Wet"] = 2, Wheat = 10 }
	local animals = { a1 = { species = "Cow" }, a2 = { species = "Dog", busy = true } }
	T.eq((Social.validateOffer(inv, animals, { ["Wheat#Wet"] = 2 }, { "a1" })), true)
	local ok, err = Social.validateOffer(inv, animals, { Wheat = 1 }, {})
	T.eq(ok, false)
	T.eq(err, "notTradeable")
	T.eq((Social.validateOffer(inv, animals, { ["Wheat#Wet"] = 3 }, {})), false)
	T.eq((Social.validateOffer(inv, animals, {}, { "a2" })), false)
	T.eq((Social.validateOffer(inv, animals, {}, { "a1", "a1" })), false)
end)

T.test("daily quests are stable and level-gated", function()
	local a = Social.dailyQuests(100, 12345, 1)
	local b = Social.dailyQuests(100, 12345, 1)
	T.eq(#a, 3)
	T.eq(table.concat(a, ","), table.concat(b, ","))
	for _, id in a do
		T.truthy(id ~= "trade1" and id ~= "explore1")
	end
end)
