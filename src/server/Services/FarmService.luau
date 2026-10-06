-- Planting, watering, harvesting and gleaning.
--
-- Rules that keep the social side positive-sum:
--   * only the owner plants, digs and harvests ripe crops
--   * anyone may water any crop (the owner's crop grows faster, the waterer
--     earns kindness)
--   * neighbours may glean overripe crops, or ripe crops on shared tiles;
--     the owner still receives most of the harvest

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")

local Net = require(Shared.Net)
local Crops = require(Shared.Config.Crops)
local Economy = require(Shared.Config.Economy)
local Growth = require(Shared.Logic.Growth)
local Mutations = require(Shared.Logic.Mutations)
local ItemLogic = require(Shared.Logic.Items)
local Plot = require(Shared.Logic.Plot)
local Social = require(Shared.Logic.Social)

local DataService, Progress, PlotService, MonetizationService

local FarmService = {}

local rng = Random.new()
local function roll(): number
	return rng:NextNumber()
end

local function validTarget(player: Player, plotIndex: any, key: any): (Player?, any?, CFrame?)
	if type(plotIndex) ~= "number" or type(key) ~= "string" or #key > 8 then
		return nil
	end
	local owner = PlotService.ownerOf(plotIndex)
	if not owner then
		return nil
	end
	local op = DataService.get(owner)
	if not op or not Plot.isUnlocked(key, op.PlotSize) then
		return nil
	end
	local cf = PlotService.tileCFrame(plotIndex, key)
	if not cf or Progress.distance(player, cf.Position) > Economy.TILE_DISTANCE then
		return nil
	end
	return owner, op, cf
end

local function toolRadius(p: any, tool: string): number
	return math.clamp(p.Tools[tool] or 0, 0, 2)
end

local function resetDaily(stats: any, now: number)
	local day = Social.dayIndex(now)
	if stats.gleanDay ~= day then
		stats.gleanDay = day
		stats.gleanCount = 0
	end
	if stats.waterDay ~= day then
		stats.waterDay = day
		stats.waterCount = 0
	end
end

---------------------------------------------------------------- actions

local function plant(player: Player, plotIndex: any, key: any, cropId: any)
	if type(cropId) ~= "string" or not Crops.byId[cropId] then
		return
	end
	local owner, p = validTarget(player, plotIndex, key)
	if owner ~= player or not p then
		return
	end
	local seedKey = "Seed:" .. cropId
	local now = os.time()
	local planted = 0
	for _, k in Plot.area(key, toolRadius(p, "SeedBag"), p.PlotSize) do
		if not p.Tiles[k] then
			if (p.Inventory[seedKey] or 0) <= 0 then
				break
			end
			p.Inventory[seedKey] -= 1
			if p.Inventory[seedKey] <= 0 then
				p.Inventory[seedKey] = nil
			end
			p.Tiles[k] = Growth.plant(cropId, now, Progress.lands(p), Progress.growBuff(p))
			PlotService.refreshTile(plotIndex, k)
			planted += 1
		end
	end
	if planted > 0 then
		Progress.emit(player, "plant", planted)
		Progress.dirty(player)
	elseif (p.Inventory[seedKey] or 0) <= 0 then
		Net.notify(player, "note.noSeeds", { crop = cropId }, "warn")
	end
end

local function water(player: Player, plotIndex: any, key: any)
	local owner, op = validTarget(player, plotIndex, key)
	if not owner or not op then
		return
	end
	local p = DataService.get(player)
	if not p then
		return
	end
	local now = os.time()
	local isOwner = owner == player
	if not isOwner then
		resetDaily(p.Stats, now)
	end
	local count = 0
	for _, k in Plot.area(key, toolRadius(p, "Can"), op.PlotSize) do
		local tile = op.Tiles[k]
		if tile and not isOwner and p.Stats.waterCount >= Economy.WATER_NEIGHBOUR_DAILY_LIMIT then
			break
		end
		if tile and Growth.water(tile, now) then
			count += 1
			PlotService.refreshTile(plotIndex, k)
			if not isOwner then
				p.Stats.waterCount += 1
			end
		end
	end
	if count == 0 then
		return
	end
	if not isOwner then
		Progress.addKindness(player, Economy.KINDNESS_WATER * count)
		Progress.addXp(player, Economy.XP.water * count)
		Progress.emit(player, "waterNeighbour", count)
		Net.notify(owner, "note.wateredYou", { name = player.DisplayName, n = count }, "social")
	end
	Progress.dirty(player)
end

-- Harvests one tile for its owner. Returns units harvested.
local function harvestOwn(player: Player, p: any, plotIndex: number, k: string, now: number): number
	local tile = p.Tiles[k]
	if not tile or not Growth.isRipe(tile, now) then
		return 0
	end
	local lands = Progress.lands(p)
	local n = Growth.yield(tile.crop, lands)
	local muts = table.clone(tile.mutations or {})
	Mutations.growthRoll(muts, roll, Progress.luck(p))
	local itemKey = ItemLogic.cropKey(tile.crop, muts)
	Progress.give(player, itemKey, n)
	local crop = Crops.byId[tile.crop]
	Progress.addXp(player, Economy.XP.harvestPerTier * crop.tier)
	p.Stats.harvested += n
	Progress.emit(player, "harvest", n)
	Progress.emit(player, "harvestCrop:" .. tile.crop, n)
	if #muts > 0 then
		Progress.emit(player, "mutation", 1)
	end
	local cropId = tile.crop
	local kept = Growth.afterHarvest(tile, now, lands, Progress.growBuff(p))
	if not kept then
		p.Tiles[k] = nil
		-- Farmhand pass: replant with the same seed if the player has one
		if MonetizationService.hasPass(player, "Farmhand") and Progress.take(player, "Seed:" .. cropId, 1) then
			p.Tiles[k] = Growth.plant(cropId, now, lands, Progress.growBuff(p))
		end
	end
	PlotService.refreshTile(plotIndex, k)
	return n
end

local function glean(player: Player, owner: Player, op: any, plotIndex: number, k: string, now: number): boolean
	local tile = op.Tiles[k]
	if not tile then
		return false
	end
	local stage = Growth.stage(tile, now)
	if not Social.canGlean(stage, tile.shared) then
		return false
	end
	local p = DataService.get(player)
	if not p then
		return false
	end
	resetDaily(p.Stats, now)
	if p.Stats.gleanCount >= Economy.GLEAN_DAILY_LIMIT then
		Net.notify(player, "note.gleanLimit", nil, "warn")
		return false
	end
	if player.AccountAge < Economy.GLEAN_MIN_ACCOUNT_AGE_DAYS and not RunService:IsStudio() then
		Net.notify(player, "note.gleanTooNew", nil, "warn")
		return false
	end
	local lands = Progress.lands(op)
	local n = Growth.yield(tile.crop, lands)
	local ownerN, gleanerN = Social.gleanSplit(n, roll)
	local muts = table.clone(tile.mutations or {})
	Mutations.growthRoll(muts, roll, Progress.luck(op))
	local itemKey = ItemLogic.cropKey(tile.crop, muts)
	Progress.give(owner, itemKey, ownerN)
	op.Stats.harvested += ownerN
	if gleanerN > 0 then
		Progress.give(player, itemKey, gleanerN)
	end
	p.Stats.gleanCount += 1
	p.Stats.gleaned += 1
	Progress.addXp(player, Economy.XP.glean)
	Progress.emit(player, "glean", 1)
	if tile.shared then
		Progress.addKindness(owner, Economy.KINDNESS_SHARED_GLEAN)
	end
	local cropId = tile.crop
	local kept = Growth.afterHarvest(tile, now, lands, Progress.growBuff(op))
	if not kept then
		op.Tiles[k] = nil
	end
	PlotService.refreshTile(plotIndex, k)
	Net.notify(owner, "note.gleanedYou", { name = player.DisplayName, crop = cropId, n = ownerN }, "social")
	Net.notify(player, "note.gleaned", { name = owner.DisplayName, crop = cropId, n = gleanerN }, "social")
	return true
end

local function harvest(player: Player, plotIndex: any, key: any)
	local owner, op = validTarget(player, plotIndex, key)
	if not owner or not op then
		return
	end
	local now = os.time()
	if owner == player then
		local total = 0
		for _, k in Plot.area(key, toolRadius(op, "Basket"), op.PlotSize) do
			total += harvestOwn(player, op, plotIndex, k, now)
		end
		if total > 0 then
			Progress.dirty(player)
		end
	else
		-- gleaning is always one tile at a time
		if glean(player, owner, op, plotIndex, key, now) then
			Progress.dirty(player)
			Progress.dirty(owner)
		end
	end
end

local function dig(player: Player, plotIndex: any, key: any)
	local owner, p = validTarget(player, plotIndex, key)
	if owner ~= player or not p or not p.Tiles[key] then
		return
	end
	p.Tiles[key] = nil
	PlotService.refreshTile(plotIndex, key)
end

local function share(player: Player, plotIndex: any, key: any)
	local owner, p = validTarget(player, plotIndex, key)
	if owner ~= player or not p then
		return
	end
	local tile = p.Tiles[key]
	if tile then
		tile.shared = not tile.shared
		PlotService.refreshTile(plotIndex, key)
		Net.notify(player, if tile.shared then "note.sharedOn" else "note.sharedOff", nil, "info")
	end
end

---------------------------------------------------------------- kept scale

-- Returning after a break gives guaranteed mutations on growing crops.
local function applyKeptScale(player: Player, p: any)
	local before = p.__lastSeenBefore
	if not before then
		return
	end
	local away = os.time() - before
	local count = Mutations.keptScaleCount(away, Economy.KEPT_SCALE_SECONDS_PER_MUTATION)
	if count <= 0 then
		return
	end
	local keys = {}
	for k, tile in p.Tiles do
		if #(tile.mutations or {}) < 3 then
			table.insert(keys, k)
		end
	end
	local given = 0
	for _ = 1, count do
		if #keys == 0 then
			break
		end
		local idx = rng:NextInteger(1, #keys)
		local tile = p.Tiles[keys[idx]]
		tile.mutations = tile.mutations or {}
		if Mutations.add(tile.mutations, Mutations.keptScalePick(roll)) then
			given += 1
		else
			table.remove(keys, idx)
		end
	end
	if given > 0 then
		task.delay(4, function()
			if player.Parent then
				Net.notify(player, "note.keptScale", { n = given }, "celebrate")
			end
		end)
	end
end

function FarmService.init(services)
	DataService = services.DataService
	Progress = services.ProgressService
	PlotService = services.PlotService
	MonetizationService = services.MonetizationService
end

function FarmService.start()
	Net.onAction("Plant", plant, 12)
	Net.onAction("Water", water, 12)
	Net.onAction("Harvest", harvest, 12)
	Net.onAction("Dig", dig, 6)
	Net.onAction("Share", share, 4)
	DataService.Loaded:Connect(applyKeptScale)
	Players.PlayerRemoving:Connect(function() end)
end

return FarmService
