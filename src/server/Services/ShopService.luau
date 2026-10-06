-- Selling at the kiosk, the personal seed shop, tool upgrades, land choice,
-- plot expansion and farm themes.

local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")

local Net = require(Shared.Net)
local Crops = require(Shared.Config.Crops)
local Lands = require(Shared.Config.Lands)
local Economy = require(Shared.Config.Economy)
local Products = require(Shared.Config.Products)
local Pricing = require(Shared.Logic.Pricing)
local ItemLogic = require(Shared.Logic.Items)
local Shop = require(Shared.Logic.Shop)
local Levels = require(Shared.Logic.Levels)
local WorldBuilder = require(script.Parent.Parent.World.WorldBuilder)

local DataService, Progress, PlotService, MonetizationService, EventService

local ShopService = {}

local rng = Random.new()

local function near(player: Player, pointName: string): boolean
	local point = WorldBuilder.points[pointName]
	return point ~= nil and Progress.distance(player, point) <= Economy.SHOP_DISTANCE
end

---------------------------------------------------------------- selling

local function sellKeys(player: Player, p: any, entries: { { key: string, n: number } }): number
	local bonus = Progress.sellBonus(p)
	local total = 0
	for _, e in entries do
		local have = p.Inventory[e.key] or 0
		local n = math.min(have, e.n)
		if n > 0 then
			local price = Pricing.sellPrice(e.key, bonus + EventService.itemSellBonus(e.key))
			if price > 0 and Progress.take(player, e.key, n) then
				total += price * n
			end
		end
	end
	if total > 0 then
		Progress.addCoins(player, total)
		p.Stats.sold += total
		Progress.emit(player, "sell", total)
		Net.push(player, "Sold", total)
	end
	return total
end

function ShopService.sellAllCrops(player: Player)
	local p = DataService.get(player)
	if not p then
		return
	end
	local entries = {}
	for key, n in p.Inventory do
		if ItemLogic.kind(key) == "crop" and not p.Favorites[key] then
			table.insert(entries, { key = key, n = n })
		end
	end
	if #entries == 0 then
		Net.notify(player, "note.nothingToSell", nil, "info")
		return
	end
	sellKeys(player, p, entries)
end

local function sellItem(player: Player, key: any, n: any)
	if type(key) ~= "string" or type(n) ~= "number" or n ~= n or n < 1 then
		return
	end
	local p = DataService.get(player)
	if not p or not near(player, "Kiosk") then
		return
	end
	local def = ItemLogic.def(key)
	if not def or def.kind == "special" or def.kind == "seed" then
		return
	end
	sellKeys(player, p, { { key = key, n = math.floor(n) } })
end

local function toggleFavorite(player: Player, key: any)
	local p = DataService.get(player)
	if not p or type(key) ~= "string" or not ItemLogic.exists(key) then
		return
	end
	p.Favorites[key] = if p.Favorites[key] then nil else true
	Progress.dirty(player)
end

---------------------------------------------------------------- seed shop

function ShopService.ensureStock(player: Player, p: any)
	local slot = math.floor(os.time() / Economy.SHOP_RESTOCK_SECONDS)
	if p.SeedShop.slot == slot then
		return
	end
	local stock, pity = Shop.restock(p.Level, p.SeedShop.wish, p.SeedShop.pity or 0, function()
		return rng:NextNumber()
	end)
	p.SeedShop.slot = slot
	p.SeedShop.stock = stock
	p.SeedShop.pity = pity
	p.SeedShop.nextAt = (slot + 1) * Economy.SHOP_RESTOCK_SECONDS
	Progress.dirty(player)
end

local function buySeed(player: Player, cropId: any, n: any)
	if type(cropId) ~= "string" or type(n) ~= "number" or n ~= n then
		return
	end
	n = math.clamp(math.floor(n), 1, 99)
	local p = DataService.get(player)
	local crop = Crops.byId[cropId]
	if not p or not crop or not crop.seed or not near(player, "SeedShop") then
		return
	end
	ShopService.ensureStock(player, p)
	local available = p.SeedShop.stock[cropId] or 0
	n = math.min(n, available)
	if n <= 0 then
		Net.notify(player, "note.soldOut", nil, "warn")
		return
	end
	if not Progress.spendCoins(player, crop.seed * n) then
		Net.notify(player, "note.notEnoughCoins", nil, "warn")
		return
	end
	p.SeedShop.stock[cropId] = available - n
	Progress.give(player, "Seed:" .. cropId, n)
end

local function setWish(player: Player, cropId: any)
	local p = DataService.get(player)
	if not p then
		return
	end
	if cropId == nil then
		p.SeedShop.wish = nil
	elseif type(cropId) == "string" and Crops.byId[cropId] and Crops.byId[cropId].source == "shop" then
		p.SeedShop.wish = cropId
		p.SeedShop.pity = 0
	end
	Progress.dirty(player)
end

---------------------------------------------------------------- tools

local function upgradeTool(player: Player, tool: any)
	if type(tool) ~= "string" or not table.find(Economy.TOOLS, tool) then
		return
	end
	local p = DataService.get(player)
	if not p or not near(player, "ToolShed") then
		return
	end
	local tier = p.Tools[tool] or 0
	local nextTier = Economy.TOOL_TIERS[tier + 1]
	if not nextTier then
		return
	end
	if p.Level < nextTier.level then
		Net.notify(player, "note.needLevel", { level = nextTier.level }, "warn")
		return
	end
	if not Progress.spendCoins(player, nextTier.coins) then
		Net.notify(player, "note.notEnoughCoins", nil, "warn")
		return
	end
	p.Tools[tool] = tier + 1
	Net.notify(player, "note.toolUpgraded", { tool = tool, tier = tier + 1 }, "celebrate")
	Progress.dirty(player)
end

---------------------------------------------------------------- land & plot

local function chooseLand(player: Player, landId: any)
	local p = DataService.get(player)
	local land = type(landId) == "string" and Lands[landId]
	if not p or not land or not land.available or p.Land == landId then
		return
	end
	if p.Level < Economy.LAND_CHOICE_LEVEL then
		Net.notify(player, "note.needLevel", { level = Economy.LAND_CHOICE_LEVEL }, "warn")
		return
	end
	if p.Land ~= nil then
		-- the first change is free, later ones cost coins
		if p.LandChanges >= 1 and not Progress.spendCoins(player, Economy.LAND_CHANGE_COST) then
			Net.notify(player, "note.notEnoughCoins", nil, "warn")
			return
		end
		p.LandChanges += 1
	end
	p.Land = landId
	if p.__plot then
		PlotService.refreshAll(p.__plot)
	end
	Progress.emit(player, "chooseLand", 1)
	Net.notify(player, "note.landChosen", { land = landId }, "celebrate")
	Progress.dirty(player)
end

local function chooseSecondLand(player: Player, landId: any)
	local p = DataService.get(player)
	local land = type(landId) == "string" and Lands[landId]
	if not p or not land or not land.available or landId == p.Land then
		return
	end
	if p.Legacy < Economy.LEGACY_SECOND_LAND then
		return
	end
	p.SecondLand = landId
	Progress.dirty(player)
end

-- Goats clear brush: each one takes 10% off expansion coins (max 30%).
function ShopService.clearDiscount(p: any): number
	local goats = 0
	for _, a in p.Animals do
		if a.species == "Goat" then
			goats += 1
		end
	end
	return math.min(0.3, goats * 0.1)
end

local function expandPlot(player: Player)
	local p = DataService.get(player)
	if not p then
		return
	end
	local step = Levels.nextPlotStep(p.PlotSize)
	if not step then
		return
	end
	if p.Level < step.level then
		Net.notify(player, "note.needLevel", { level = step.level }, "warn")
		return
	end
	local needs = {}
	if step.wood > 0 then
		needs.Wood = step.wood
	end
	if step.stone > 0 then
		needs.Stone = step.stone
	end
	local inv = p.Inventory
	if (inv.Wood or 0) < step.wood or (inv.Stone or 0) < step.stone then
		Net.notify(player, "note.needMaterials", nil, "warn")
		return
	end
	local coins = math.floor(step.coins * (1 - ShopService.clearDiscount(p)))
	if p.Coins < coins then
		Net.notify(player, "note.notEnoughCoins", nil, "warn")
		return
	end
	Progress.spendCoins(player, coins)
	Progress.takeAll(player, needs)
	p.PlotSize = step.size
	if p.__plot then
		PlotService.refreshAll(p.__plot)
	end
	Net.notify(player, "note.plotExpanded", { size = step.size }, "celebrate")
	Progress.dirty(player)
end

local function setTheme(player: Player, themeId: any)
	local p = DataService.get(player)
	if not p or type(themeId) ~= "string" then
		return
	end
	local theme
	for _, t in Products.themes do
		if t.id == themeId then
			theme = t
		end
	end
	if not theme then
		return
	end
	local owned = theme.free or p.OwnedThemes[themeId] or MonetizationService.hasPass(player, "BuilderPack")
	if not owned then
		Net.notify(player, "note.themeLocked", nil, "warn")
		return
	end
	p.Theme = themeId
	if p.__plot then
		PlotService.refreshAll(p.__plot)
	end
	Progress.dirty(player)
end

function ShopService.init(services)
	DataService = services.DataService
	Progress = services.ProgressService
	PlotService = services.PlotService
	MonetizationService = services.MonetizationService
	EventService = services.EventService
end

function ShopService.start()
	Net.onAction("SellItem", sellItem, 10)
	Net.onAction("SellAll", function(player)
		if near(player, "Kiosk") then
			ShopService.sellAllCrops(player)
		end
	end, 2)
	Net.onAction("ToggleFavorite", toggleFavorite, 6)
	Net.onAction("BuySeed", buySeed, 8)
	Net.onAction("SetWish", setWish, 2)
	Net.onAction("UpgradeTool", upgradeTool, 2)
	Net.onAction("ChooseLand", chooseLand, 1)
	Net.onAction("ChooseSecondLand", chooseSecondLand, 1)
	Net.onAction("ExpandPlot", expandPlot, 1)
	Net.onAction("SetTheme", setTheme, 2)

	WorldBuilder.prompts.Sell.Triggered:Connect(function(player)
		ShopService.sellAllCrops(player)
	end)
	WorldBuilder.prompts.SellMenu.Triggered:Connect(function(player)
		Net.push(player, "Open", "Sell")
	end)
	WorldBuilder.prompts.SeedShop.Triggered:Connect(function(player)
		local p = DataService.get(player)
		if p then
			ShopService.ensureStock(player, p)
			Net.push(player, "Open", "SeedShop")
		end
	end)
	WorldBuilder.prompts.ToolShed.Triggered:Connect(function(player)
		Net.push(player, "Open", "Tools")
	end)
	for i = 1, WorldBuilder.PLOT_COUNT do
		local pp = WorldBuilder.prompts["Plot" .. i]
		pp.Triggered:Connect(function(player)
			if PlotService.ownerOf(i) == player then
				Net.push(player, "Open", "Farm")
			else
				Net.push(player, "Open", "Visit")
			end
		end)
	end

	-- restock seed shops as slots roll over
	task.spawn(function()
		while true do
			task.wait(5)
			for _, player in Players:GetPlayers() do
				local p = DataService.get(player)
				if p then
					ShopService.ensureStock(player, p)
				end
			end
		end
	end)
end

return ShopService
