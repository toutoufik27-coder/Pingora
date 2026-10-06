-- Animals: buying, feeding, products, honey, breeding, hatching, retiring
-- and companions that follow the player.
--
-- Production is lazy: each animal stores up to MAX_STORED products and eats
-- one unit of food per product. Feeding adds up to MAX_FOOD units.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")

local Net = require(Shared.Net)
local Animals = require(Shared.Config.Animals)
local Economy = require(Shared.Config.Economy)
local Breeding = require(Shared.Logic.Breeding)
local Make = require(script.Parent.Parent.World.Make)
local WorldBuilder = require(script.Parent.Parent.World.WorldBuilder)

local DataService, Progress, PlotService

local AnimalService = {}

local MAX_STORED = 3
local MAX_FOOD = 3
local rng = Random.new()
local function roll()
	return rng:NextNumber()
end

local companions: { [Player]: { [string]: Model } } = {}

local function hasTrait(a: any, t: string): boolean
	return table.find(a.traits or {}, t) ~= nil
end

local function intervalOf(a: any): number
	local s = Animals.species[a.species]
	local i = s.interval or 300
	if hasTrait(a, "Swift") then
		i *= 0.8
	end
	return i
end

local function needsFood(s: any): boolean
	return s.product ~= nil and s.food ~= nil
end

-- Which honey a hive makes: the most common flower on this farm and the
-- farms next to it.
function AnimalService.honeyFor(plotIndex: number?): string
	if not plotIndex then
		return Animals.DEFAULT_HONEY
	end
	local counts = {}
	local indices = { plotIndex }
	for _, n in PlotService.neighbourIndices(plotIndex) do
		table.insert(indices, n)
	end
	for _, idx in indices do
		local owner = PlotService.ownerOf(idx)
		local op = owner and DataService.get(owner)
		if op then
			for _, tile in op.Tiles do
				if Animals.honeyFlowers[tile.crop] then
					counts[tile.crop] = (counts[tile.crop] or 0) + 1
				end
			end
		end
	end
	local best, bestN = nil, 0
	for crop, n in counts do
		if n > bestN or (n == bestN and best and crop < best) then
			best, bestN = crop, n
		end
	end
	return if best then Animals.honeyFlowers[best] else Animals.DEFAULT_HONEY
end

-- Advances production up to now.
local function produce(a: any, now: number)
	local s = Animals.species[a.species]
	if not s.product then
		return
	end
	a.stored = a.stored or 0
	a.food = a.food or 0
	a.tick = a.tick or now
	local interval = intervalOf(a)
	local cycles = math.floor((now - a.tick) / interval)
	if cycles <= 0 then
		return
	end
	local canMake = MAX_STORED - a.stored
	if needsFood(s) then
		canMake = math.min(canMake, a.food)
	end
	local made = math.min(cycles, canMake)
	if made > 0 then
		a.stored += made
		if needsFood(s) then
			a.food -= made
		end
	end
	if made < cycles then
		a.tick = now -- starving or full: production waits from now
	else
		a.tick += cycles * interval
	end
end

function AnimalService.create(player: Player, species: string, color: string?, traits: { string }?): string?
	local p = DataService.get(player)
	if not p then
		return nil
	end
	local count = 0
	for _ in p.Animals do
		count += 1
	end
	if count >= Animals.MAX_PER_FARM then
		Net.notify(player, "note.farmFull", nil, "warn")
		return nil
	end
	local id = string.sub(HttpService:GenerateGUID(false), 1, 12)
	local chosen = color or Breeding.pick(Breeding.shopOdds(species), roll)
	p.Animals[id] = {
		id = id,
		species = species,
		color = chosen,
		traits = traits or Breeding.randomTraits(roll),
		born = os.time(),
		food = 0,
		stored = 0,
		tick = os.time(),
		companion = false,
	}
	Progress.discoverAnimal(player, species, chosen)
	if p.__plot then
		PlotService.refreshAnimals(p.__plot)
	end
	Progress.dirty(player)
	return id
end

local function collectFrom(player: Player, p: any, a: any): number
	produce(a, os.time())
	local n = a.stored or 0
	if n <= 0 then
		return 0
	end
	local s = Animals.species[a.species]
	local item = s.product
	if item == "Honey" then
		item = AnimalService.honeyFor(p.__plot)
	end
	local total = n
	for _ = 1, n do
		if hasTrait(a, "Productive") and roll() < 0.25 then
			total += 1
		end
	end
	a.stored = 0
	Progress.give(player, item, total)
	Progress.addXp(player, Economy.XP.animalCollect * total)
	Progress.emit(player, "collectAnimal", total)
	return total
end

local function feed(player: Player, p: any, a: any): boolean
	local s = Animals.species[a.species]
	if not needsFood(s) then
		return false
	end
	produce(a, os.time())
	local fed = false
	while (a.food or 0) < MAX_FOOD do
		local used = false
		for _, f in s.food do
			if Progress.take(player, f, 1) then
				a.food = (a.food or 0) + 1
				used = true
				fed = true
				break
			end
		end
		if not used then
			break
		end
	end
	if fed and (a.stored or 0) == 0 then
		a.tick = math.max(a.tick or 0, os.time() - 1)
	end
	return fed
end

local function owned(player: Player, id: any): (any?, any?)
	local p = DataService.get(player)
	if not p or type(id) ~= "string" then
		return nil, nil
	end
	return p, p.Animals[id]
end

---------------------------------------------------------------- actions

local function buyAnimal(player: Player, species: any)
	local p = DataService.get(player)
	local s = type(species) == "string" and Animals.species[species]
	if not p or not s then
		return
	end
	if Progress.distance(player, WorldBuilder.points.AnimalShop) > Economy.SHOP_DISTANCE then
		return
	end
	if p.Level < s.level then
		Net.notify(player, "note.needLevel", { level = s.level }, "warn")
		return
	end
	if p.Coins < s.price then
		Net.notify(player, "note.notEnoughCoins", nil, "warn")
		return
	end
	Progress.spendCoins(player, s.price)
	if AnimalService.create(player, species) then
		Progress.emit(player, "buyAnimal", 1)
		Net.notify(player, "note.animalAdopted", { species = species }, "celebrate")
	else
		Progress.addCoins(player, s.price) -- refund when the farm is full
	end
end

local function careAll(player: Player)
	local p = DataService.get(player)
	if not p then
		return
	end
	local collected, fedCount = 0, 0
	for _, a in p.Animals do
		if not a.companion then
			collected += collectFrom(player, p, a)
			if feed(player, p, a) then
				fedCount += 1
			end
		end
	end
	Net.notify(player, "note.careDone", { collected = collected, fed = fedCount }, "info")
	Progress.dirty(player)
end

local function animalAction(player: Player, id: any, what: any)
	local p, a = owned(player, id)
	if not p or not a or a.busy then
		return
	end
	if what == "feed" then
		if not feed(player, p, a) then
			Net.notify(player, "note.noFood", { species = a.species }, "warn")
		end
	elseif what == "collect" then
		collectFrom(player, p, a)
	elseif what == "companion" then
		local count = 0
		for _, other in p.Animals do
			if other.companion then
				count += 1
			end
		end
		if not a.companion and count >= Animals.MAX_COMPANIONS then
			Net.notify(player, "note.companionsFull", nil, "warn")
			return
		end
		a.companion = not a.companion
		AnimalService.refreshCompanions(player)
		if p.__plot then
			PlotService.refreshAnimals(p.__plot)
		end
	elseif what == "retire" then
		p.Animals[id] = nil
		Progress.addKindness(player, Economy.KINDNESS_RETIRE_ANIMAL)
		Net.notify(player, "note.retired", nil, "info")
		AnimalService.refreshCompanions(player)
		if p.__plot then
			PlotService.refreshAnimals(p.__plot)
		end
	end
	Progress.dirty(player)
end

local function rename(player: Player, id: any, name: any)
	local p, a = owned(player, id)
	if not p or not a or type(name) ~= "string" or #name > 20 then
		return
	end
	local ok, filtered = pcall(function()
		local TextService = game:GetService("TextService")
		local result = TextService:FilterStringAsync(name, player.UserId)
		return result:GetNonChatStringForBroadcastAsync()
	end)
	if ok then
		a.name = filtered
		Progress.dirty(player)
	end
end

local function breed(player: Player, idA: any, idB: any)
	local p, a = owned(player, idA)
	local _, b = owned(player, idB)
	if not p or not a or not b or idA == idB or a.species ~= b.species or a.busy or b.busy then
		return
	end
	if p.Breeding then
		Net.notify(player, "note.alreadyBreeding", nil, "warn")
		return
	end
	if a.species == "Bee" then
		return
	end
	a.busy = true
	b.busy = true
	p.Breeding = { a = idA, b = idB, done = os.time() + Animals.BREED_SECONDS }
	Progress.dirty(player)
end

local function hatch(player: Player, henId: any)
	local p, hen = owned(player, henId)
	if not p or not hen or hen.species ~= "Chicken" or hen.busy then
		return
	end
	if p.Hatching then
		Net.notify(player, "note.alreadyHatching", nil, "warn")
		return
	end
	if not Progress.take(player, "Egg", 1) then
		Net.notify(player, "note.needEgg", nil, "warn")
		return
	end
	p.Hatching = { hen = henId, color = hen.color, done = os.time() + Animals.HATCH_SECONDS }
	Progress.dirty(player)
end

local function claimNursery(player: Player)
	local p = DataService.get(player)
	if not p then
		return
	end
	local now = os.time()
	local br = p.Breeding
	if br and now >= br.done then
		local a, b = p.Animals[br.a], p.Animals[br.b]
		p.Breeding = nil
		if a and b then
			a.busy = nil
			b.busy = nil
			local color = Breeding.pick(Breeding.breedOdds(a.species, a.color, b.color), roll)
			local traits = Breeding.inheritTraits(a.traits or {}, b.traits or {}, roll)
			if AnimalService.create(player, a.species, color, traits) then
				Net.notify(player, "note.babyBorn", { species = a.species, color = color }, "celebrate")
			end
		end
	end
	local h = p.Hatching
	if h and now >= h.done then
		p.Hatching = nil
		local color = Breeding.pick(Breeding.hatchOdds("Chicken", h.color), roll)
		if AnimalService.create(player, "Chicken", color, Breeding.randomTraits(roll)) then
			Net.notify(player, "note.chickHatched", { color = color }, "celebrate")
		end
	end
	Progress.dirty(player)
end

---------------------------------------------------------------- companions

function AnimalService.refreshCompanions(player: Player)
	local existing = companions[player]
	if existing then
		for _, m in existing do
			m:Destroy()
		end
	end
	companions[player] = {}
	local p = DataService.get(player)
	if not p then
		return
	end
	local speed = 16
	local folder = Make.folder("Companions", (WorldBuilder.root :: Folder))
	for id, a in p.Animals do
		if a.companion then
			local s = Animals.species[a.species]
			local color = Color3.new(1, 1, 1)
			for _, c in s.colors do
				if c.id == a.color then
					color = Make.color(c.rgb)
				end
			end
			local m = Make.model("Companion_" .. player.UserId .. "_" .. id, folder)
			local size = math.min(s.size, 2.5)
			local body = Make.part({ Name = "Body", Size = Vector3.new(size * 0.8, size * 0.7, size * 1.3), CFrame = CFrame.new(0, -100, 0), Color = color, CanCollide = false, Parent = m })
			body.CanQuery = false
			m.PrimaryPart = body
			companions[player][id] = m
			if s.job == "rider" then
				speed = 22
			end
		end
	end
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.WalkSpeed = speed
	end
end

local function updateCompanions(dt: number)
	for player, list in companions do
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			local i = 0
			for _, m in list do
				i += 1
				local offset = root.CFrame * CFrame.new((i - 2) * 3, -2, 5)
				local current = m:GetPivot()
				local target = CFrame.new(offset.Position) * (root.CFrame - root.CFrame.Position)
				m:PivotTo(current:Lerp(target, math.clamp(dt * 6, 0, 1)))
			end
		end
	end
end

---------------------------------------------------------------- jobs

-- Dogs collect products for their owner every 30 seconds.
local function dogJobs()
	for _, player in Players:GetPlayers() do
		local p = DataService.get(player)
		if p then
			local hasDog = false
			for _, a in p.Animals do
				if Animals.species[a.species].job == "collector" then
					hasDog = true
					break
				end
			end
			if hasDog then
				local n = 0
				for _, a in p.Animals do
					if not a.companion and not a.busy then
						n += collectFrom(player, p, a)
					end
				end
				if n > 0 then
					Progress.dirty(player)
				end
			end
		end
	end
end

function AnimalService.init(services)
	DataService = services.DataService
	Progress = services.ProgressService
	PlotService = services.PlotService
end

function AnimalService.start()
	Net.onAction("BuyAnimal", buyAnimal, 2)
	Net.onAction("AnimalAction", animalAction, 8)
	Net.onAction("CareAll", careAll, 1)
	Net.onAction("RenameAnimal", rename, 1)
	Net.onAction("Breed", breed, 1)
	Net.onAction("Hatch", hatch, 1)
	Net.onAction("ClaimNursery", claimNursery, 2)
	Net.onRequest("Odds", function(_player, kind, species, a, b)
		if type(species) ~= "string" or not Animals.species[species] then
			return nil
		end
		if kind == "breed" and type(a) == "string" and type(b) == "string" then
			return Breeding.breedOdds(species, a, b)
		elseif kind == "hatch" and type(a) == "string" then
			return Breeding.hatchOdds(species, a)
		elseif kind == "shop" then
			return Breeding.shopOdds(species)
		end
		return nil
	end, 4)

	WorldBuilder.prompts.AnimalShop.Triggered:Connect(function(player)
		Net.push(player, "Open", "AnimalShop")
	end)

	-- prompts created by PlotService on each farm
	game:GetService("ProximityPromptService").PromptTriggered:Connect(function(prompt, player)
		local yard = prompt:GetAttribute("YardCare")
		if yard then
			if PlotService.ownerOf(yard) == player then
				careAll(player)
			end
			return
		end
		local animalId = prompt:GetAttribute("AnimalId")
		if animalId then
			local plotIndex = prompt:GetAttribute("PlotIndex")
			if PlotService.ownerOf(plotIndex) == player then
				Net.push(player, "Open", { panel = "Animal", id = animalId })
			else
				-- a visitor petting a Charming animal gets a tiny gift
				local owner = PlotService.ownerOf(plotIndex)
				local op = owner and DataService.get(owner)
				local a = op and op.Animals[animalId]
				if a and hasTrait(a, "Charming") then
					local p = DataService.get(player)
					if p and (p.__lastPet or 0) + 60 < os.time() then
						p.__lastPet = os.time()
						Progress.addCoins(player, 10)
						Net.notify(player, "note.petGift", nil, "social")
					end
				end
			end
		end
	end)

	DataService.Loaded:Connect(function(player, p)
		for _, a in p.Animals do
			a.busy = nil
		end
		if p.Breeding then
			for _, id in { p.Breeding.a, p.Breeding.b } do
				if p.Animals[id] then
					p.Animals[id].busy = true
				end
			end
		end
		player.CharacterAdded:Connect(function()
			task.wait(1)
			AnimalService.refreshCompanions(player)
		end)
		if player.Character then
			AnimalService.refreshCompanions(player)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		local list = companions[player]
		if list then
			for _, m in list do
				m:Destroy()
			end
		end
		companions[player] = nil
	end)

	RunService.Heartbeat:Connect(updateCompanions)
	task.spawn(function()
		while true do
			task.wait(30)
			dogJobs()
		end
	end)

	Progress.addSnapshotExtra(function(_player, p, s)
		s.Breeding = p.Breeding
		s.Hatching = p.Hatching
		s.SkipTokens = p.SkipTokens
	end)
end

return AnimalService
