-- Coins, XP, kindness, items, the almanac, gameplay events, and syncing the
-- profile to the client. Every other service changes player state through
-- these functions so the client always gets an update.

local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")

local Net = require(Shared.Net)
local Economy = require(Shared.Config.Economy)
local Animals = require(Shared.Config.Animals)
local Signal = require(Shared.Util.Signal)
local Levels = require(Shared.Logic.Levels)
local Inventory = require(Shared.Logic.Inventory)
local ItemLogic = require(Shared.Logic.Items)
local Buffs = require(script.Parent.Parent.Buffs)

local DataService -- set in init

local Progress = {}

Progress.Events = Signal.new() -- (player, eventName, amount)
Progress.LevelUp = Signal.new() -- (player, newLevel)

local dirty: { [Player]: boolean } = {}
local snapshotExtras: { (Player, any, any) -> () } = {}

-- Other services can add fields to the client snapshot.
function Progress.addSnapshotExtra(fn: (Player, any, any) -> ())
	table.insert(snapshotExtras, fn)
end

local function snapshot(player: Player, p: any)
	local s = {
		Coins = p.Coins,
		Kindness = p.Kindness,
		Level = p.Level,
		XP = p.XP,
		XPNeed = if p.Level >= Economy.MAX_LEVEL then 0 else Economy.xpForLevel(p.Level),
		Rebirths = p.Rebirths,
		RebirthBonus = Levels.rebirthBonus(p.Rebirths),
		Land = p.Land,
		SecondLand = p.SecondLand,
		LandChanges = p.LandChanges,
		PlotSize = p.PlotSize,
		PlotIndex = p.__plot,
		Inventory = p.Inventory,
		Animals = p.Animals,
		Workshops = p.Workshops,
		Tools = p.Tools,
		SeedShop = p.SeedShop,
		Almanac = p.Almanac,
		Quests = p.Quests,
		Stats = {
			harvested = p.Stats.harvested,
			gleaned = p.Stats.gleaned,
			gleanCount = p.Stats.gleanCount,
			trips = p.Stats.trips,
			trades = p.Stats.trades,
			playtime = DataService.playtime(player),
		},
		Deeds = p.Deeds,
		Listings = p.Listings,
		Theme = p.Theme,
		OwnedThemes = p.OwnedThemes,
		Favorites = p.Favorites,
		Passes = p.__passes or {},
		Tutorial = p.Tutorial,
		Buffs = Buffs.list(),
		ServerTime = os.time(),
		AccountAge = player.AccountAge,
	}
	for _, fn in snapshotExtras do
		fn(player, p, s)
	end
	return s
end

function Progress.dirty(player: Player)
	if dirty[player] then
		return
	end
	dirty[player] = true
	task.delay(0.15, function()
		dirty[player] = nil
		local p = DataService.get(player)
		if p and player.Parent then
			Net.push(player, "Profile", snapshot(player, p))
		end
	end)
end

function Progress.emit(player: Player, name: string, amount: number?)
	Progress.Events:Fire(player, name, amount or 1)
end

function Progress.addCoins(player: Player, n: number)
	local p = DataService.get(player)
	if not p or n <= 0 then
		return
	end
	p.Coins += math.floor(n)
	Progress.dirty(player)
end

function Progress.spendCoins(player: Player, n: number): boolean
	local p = DataService.get(player)
	n = math.floor(n)
	if not p or n < 0 or p.Coins < n then
		return false
	end
	p.Coins -= n
	Progress.dirty(player)
	return true
end

function Progress.addXp(player: Player, n: number)
	local p = DataService.get(player)
	if not p or n <= 0 then
		return
	end
	local before = p.Level
	p.Level, p.XP = Levels.addXp(p.Level, p.XP, n)
	if p.Level > before then
		Net.notify(player, "note.levelUp", { level = p.Level }, "celebrate")
		Progress.LevelUp:Fire(player, p.Level)
	end
	Progress.dirty(player)
end

function Progress.addKindness(player: Player, n: number)
	local p = DataService.get(player)
	if not p or n <= 0 then
		return
	end
	p.Kindness += n
	Progress.dirty(player)
end

-- Records a discovery in the almanac. Returns true if it is new.
local function discover(p: any, key: string): boolean
	local parsed = ItemLogic.parse(key)
	if not parsed.def then
		return false
	end
	local new = false
	if parsed.def.kind == "crop" then
		local entry = p.Almanac.crops[parsed.id]
		if not entry then
			entry = {}
			p.Almanac.crops[parsed.id] = entry
		end
		if #parsed.mutations == 0 then
			if not entry.Normal then
				entry.Normal = true
				new = true
			end
		end
		for _, m in parsed.mutations do
			if not entry[m] then
				entry[m] = true
				new = true
			end
		end
	else
		if not p.Almanac.items[parsed.id] then
			p.Almanac.items[parsed.id] = true
			new = true
		end
	end
	return new
end

function Progress.discoverAnimal(player: Player, species: string, color: string)
	local p = DataService.get(player)
	if not p then
		return
	end
	local id = species .. ":" .. color
	if not p.Almanac.animals[id] then
		p.Almanac.animals[id] = true
		Net.notify(player, "note.almanacNew", { name = id }, "discover")
	end
end

function Progress.give(player: Player, key: string, n: number): boolean
	local p = DataService.get(player)
	if not p or n <= 0 or not ItemLogic.exists(key) then
		return false
	end
	Inventory.add(p.Inventory, key, n)
	if discover(p, key) then
		Net.push(player, "Discovered", key)
	end
	Progress.dirty(player)
	return true
end

function Progress.take(player: Player, key: string, n: number): boolean
	local p = DataService.get(player)
	if not p then
		return false
	end
	local ok = Inventory.remove(p.Inventory, key, n)
	if ok then
		Progress.dirty(player)
	end
	return ok
end

function Progress.takeAll(player: Player, needs: { [string]: number }): boolean
	local p = DataService.get(player)
	if not p then
		return false
	end
	local ok = Inventory.removeAll(p.Inventory, needs)
	if ok then
		Progress.dirty(player)
	end
	return ok
end

---------------------------------------------------------------- modifiers

-- Extra mutation chance from cats, Lucky animals, the Fountain deed and buffs.
function Progress.luck(p: any): number
	local luck = 0
	for _, a in p.Animals do
		local s = Animals.species[a.species]
		if s and s.job == "lucky" then
			luck += 0.01
		end
		for _, t in a.traits or {} do
			if t == "Lucky" then
				luck += 0.01
			end
		end
	end
	if p.Deeds.Fountain then
		luck += 0.02
	end
	luck += Buffs.get("mutationChance")
	return math.min(luck, 0.1)
end

function Progress.sellBonus(p: any): number
	return Levels.rebirthBonus(p.Rebirths) + Buffs.get("sellBonus")
end

function Progress.growBuff(_p: any): number
	return Buffs.get("growSpeed")
end

function Progress.lands(p: any): { string? }
	return { p.Land, p.SecondLand }
end

-- Distance from the player's character to a point (math.huge if no character).
function Progress.distance(player: Player, point: Vector3): number
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return math.huge
	end
	return (root.Position - point).Magnitude
end

function Progress.init(services)
	DataService = services.DataService
end

function Progress.start()
	Players.PlayerRemoving:Connect(function(player)
		dirty[player] = nil
	end)
	DataService.Loaded:Connect(function(player)
		Progress.dirty(player)
	end)
end

return Progress
