-- Picnic trips to the zones around the valley. A trip costs one Picnic
-- Basket (made on your farm), lasts Zones.TRIP_SECONDS, and lets you gather
-- resources and tame wild animals. There is no energy system.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")

local Net = require(Shared.Net)
local Zones = require(Shared.Config.Zones)
local Animals = require(Shared.Config.Animals)
local Economy = require(Shared.Config.Economy)
local Breeding = require(Shared.Logic.Breeding)
local Make = require(script.Parent.Parent.World.Make)
local WorldBuilder = require(script.Parent.Parent.World.WorldBuilder)

local DataService, Progress, PlotService, AnimalService, EventService

local ExplorationService = {}

local trips: { [Player]: { zone: string, untilTime: number } } = {}
local nodeCooldowns: { [Player]: { [string]: number } } = {}
local tameCooldowns: { [Player]: number } = {}
local rng = Random.new()

local WILD_PER_ZONE = 3
local WILD_RESPAWN = 120

function ExplorationService.tripOf(player: Player)
	return trips[player]
end

local function teleport(player: Player, pos: Vector3)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		root.CFrame = CFrame.new(pos + Vector3.new(0, 3, 0))
	end
end

function ExplorationService.returnHome(player: Player)
	trips[player] = nil
	local p = DataService.get(player)
	local idx = p and p.__plot
	if idx then
		local cf = PlotService.frame(idx) * CFrame.new(0, 2, WorldBuilder.PLOT_DEPTH / 2 - 6)
		teleport(player, cf.Position)
	else
		teleport(player, WorldBuilder.points.Spawn)
	end
	Net.push(player, "Trip", { ended = true })
end

local function enter(player: Player, zoneId: string)
	local zone = Zones.byId[zoneId]
	local p = DataService.get(player)
	if not zone or not p or trips[player] then
		return
	end
	if zone.locked then
		Net.notify(player, "note.zoneLocked", nil, "warn")
		return
	end
	if p.Level < zone.level then
		Net.notify(player, "note.needLevel", { level = zone.level }, "warn")
		return
	end
	if zone.deed and not p.Deeds[zone.deed] then
		Net.notify(player, "note.needDeed", { project = zone.deed }, "warn")
		return
	end
	if not Progress.take(player, Zones.ENTRY_ITEM, 1) then
		Net.notify(player, "note.needPicnic", nil, "warn")
		return
	end
	local untilTime = os.time() + Zones.TRIP_SECONDS
	trips[player] = { zone = zoneId, untilTime = untilTime }
	p.Stats.trips += 1
	Progress.addXp(player, Economy.XP.explore)
	Progress.emit(player, "explore", 1)
	teleport(player, WorldBuilder.points["Zone_" .. zoneId])
	Net.push(player, "Trip", { zone = zoneId, untilTime = untilTime, serverTime = os.time() })
end

local function gather(player: Player, nodeId: string, typeId: string)
	local trip = trips[player]
	if not trip or string.sub(nodeId, 1, #trip.zone + 1) ~= trip.zone .. "_" then
		Net.notify(player, "note.needTrip", nil, "warn")
		return
	end
	local nt = Zones.nodeTypes[typeId]
	if not nt then
		return
	end
	local cds = nodeCooldowns[player]
	if not cds then
		cds = {}
		nodeCooldowns[player] = cds
	end
	local now = os.time()
	if (cds[nodeId] or 0) > now then
		Net.notify(player, "note.nodeCooldown", { s = cds[nodeId] - now }, "info")
		return
	end
	cds[nodeId] = now + nt.cooldown
	local got = {}
	for _, d in nt.drops do
		if rng:NextNumber() < d.chance then
			local n = rng:NextInteger(d.min, d.max)
			Progress.give(player, d.item, n)
			table.insert(got, { item = d.item, n = n })
		end
	end
	Progress.addXp(player, 1)
	Net.push(player, "Gathered", got)
end

---------------------------------------------------------------- wild animals

local function spawnWild(zone, slot: number)
	local folder = WorldBuilder.zoneFolders[zone.id]
	if not folder or not zone.wild or #zone.wild == 0 then
		return
	end
	local species = zone.wild[rng:NextInteger(1, #zone.wild)]
	local s = Animals.species[species]
	local origin = Vector3.new(zone.origin[1], zone.origin[2], zone.origin[3])
	local pos = origin + Vector3.new(rng:NextNumber(-120, 120), 0, rng:NextNumber(-120, 80))
	if zone.id == "Mountain" then
		pos = origin + Vector3.new(rng:NextNumber(-60, 60), 0, rng:NextNumber(20, 90))
	end
	local m = Make.model("Wild_" .. zone.id .. "_" .. slot, folder)
	local color = Make.color(s.colors[1].rgb)
	local body = Make.part({ Name = "Body", Size = Vector3.new(s.size * 0.8, s.size * 0.7, s.size * 1.3), CFrame = CFrame.new(pos + Vector3.new(0, s.size * 0.4, 0)), Color = color, Parent = m })
	m.PrimaryPart = body
	local pp = Make.prompt(body, "prompt.tame", "Tame", 0.8, 10)
	pp:SetAttribute("WildSpecies", species)
	pp:SetAttribute("WildZone", zone.id)
	pp:SetAttribute("WildSlot", slot)
end

local function tame(player: Player, prompt: ProximityPrompt)
	local species = prompt:GetAttribute("WildSpecies")
	local zoneId = prompt:GetAttribute("WildZone")
	local slot = prompt:GetAttribute("WildSlot")
	local trip = trips[player]
	if not trip or trip.zone ~= zoneId then
		Net.notify(player, "note.needTrip", nil, "warn")
		return
	end
	local now = os.clock()
	if (tameCooldowns[player] or 0) > now then
		return
	end
	tameCooldowns[player] = now + 10
	local food = Zones.TAME_FOOD[species]
	if not food or not Progress.take(player, food, 1) then
		Net.notify(player, "note.tameNeedFood", { item = food or "?" }, "warn")
		return
	end
	local chance = Zones.TAME_CHANCE * (if EventService.weeklyEvent() == "Migration" then 2 else 1)
	if rng:NextNumber() >= chance then
		Net.notify(player, "note.tameFailed", nil, "info")
		return
	end
	local s = Animals.species[species]
	local common = s.colors[1].id
	local second = s.colors[math.min(2, #s.colors)].id
	local color = Breeding.pick(Breeding.breedOdds(species, common, second), function()
		return rng:NextNumber()
	end)
	if AnimalService.create(player, species, color) then
		Net.notify(player, "note.tamed", { species = species, color = color }, "celebrate")
		local model = prompt.Parent and prompt.Parent.Parent
		if model and model:IsA("Model") then
			model:Destroy()
		end
		local zone = Zones.byId[zoneId]
		task.delay(WILD_RESPAWN, function()
			spawnWild(zone, slot)
		end)
	end
end

function ExplorationService.init(services)
	DataService = services.DataService
	Progress = services.ProgressService
	PlotService = services.PlotService
	AnimalService = services.AnimalService
	EventService = services.EventService
end

function ExplorationService.start()
	for _, zone in Zones.list do
		if not zone.locked then
			for slot = 1, WILD_PER_ZONE do
				spawnWild(zone, slot)
			end
		end
	end

	ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
		local zoneId = prompt:GetAttribute("Zone")
		if zoneId then
			enter(player, zoneId)
			return
		end
		if prompt:GetAttribute("ReturnFrom") then
			if trips[player] then
				ExplorationService.returnHome(player)
			else
				teleport(player, WorldBuilder.points.Spawn)
			end
			return
		end
		local nodeId = prompt:GetAttribute("NodeId")
		if nodeId then
			gather(player, nodeId, prompt:GetAttribute("NodeType"))
			return
		end
		if prompt:GetAttribute("WildSpecies") then
			tame(player, prompt)
		end
	end)

	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function()
			if trips[player] then
				trips[player] = nil
				Net.push(player, "Trip", { ended = true })
			end
		end)
	end)
	Players.PlayerRemoving:Connect(function(player)
		trips[player] = nil
		nodeCooldowns[player] = nil
		tameCooldowns[player] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(1)
			local now = os.time()
			for player, trip in trips do
				if now >= trip.untilTime then
					Net.notify(player, "note.tripOver", nil, "info")
					ExplorationService.returnHome(player)
				end
			end
		end
	end)
end

return ExplorationService
