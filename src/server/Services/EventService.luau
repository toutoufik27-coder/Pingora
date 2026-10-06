-- Recurring events that change how the valley plays.
--
--   Weekly rule event  one of Flood / Drought / Swarm / Migration / Caravan
--   Fox chase          every 30 min: foxes grab ripe harvests and run; catch
--                      one to return the harvest to its owner and earn a token.
--                      Uncaught harvests are still returned at the end, so
--                      nobody ever loses anything.
--   Plaza field        every 30 min (offset): a shared field nobody owns;
--                      everyone races to pick it.
--   Live show          started by the creator (/liveshow): meteor shower in
--                      every server at once.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local MessagingService = game:GetService("MessagingService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")

local Net = require(Shared.Net)
local Crops = require(Shared.Config.Crops)
local Economy = require(Shared.Config.Economy)
local Growth = require(Shared.Logic.Growth)
local Mutations = require(Shared.Logic.Mutations)
local ItemLogic = require(Shared.Logic.Items)
local Make = require(script.Parent.Parent.World.Make)
local WorldBuilder = require(script.Parent.Parent.World.WorldBuilder)

local DataService, Progress, PlotService, WeatherService, MonetizationService

local EventService = {}

EventService.WEEKLY = { "Flood", "Drought", "Swarm", "Migration", "Caravan" }
EventService.FOX_EVERY = 1800
EventService.FIELD_EVERY = 1800
EventService.FIELD_OFFSET = 900
EventService.ADMINS = {} -- extra user ids allowed to start the live show

EventService.tokenShop = {
	{ id = "Seed:GiantPumpkin", cost = 10, n = 1 },
	{ id = "Seed:Starfruit", cost = 15, n = 1 },
	{ id = "theme:Blossom", cost = 30, n = 1 },
	{ id = "theme:Winter", cost = 30, n = 1 },
}

local rng = Random.new()
local LIVE_TOPIC = "KinfieldLive"

function EventService.weeklyEvent(): string
	local week = math.floor(os.time() / 604800)
	return EventService.WEEKLY[(week % #EventService.WEEKLY) + 1]
end

-- Extra sell bonus for one item under this week's rule event.
function EventService.itemSellBonus(key: string): number
	local ev = EventService.weeklyEvent()
	local parsed = ItemLogic.parse(key)
	local def = parsed.def
	if not def then
		return 0
	end
	if def.kind == "crop" then
		local c = Crops.byId[parsed.id]
		if ev == "Flood" and c.land == "Riverbank" then
			return 0.5
		elseif ev == "Drought" and (c.land == "Hillside" or c.land == "Desert") then
			return 0.5
		end
	elseif ev == "Caravan" and def.kind == "good" then
		return 0.25
	elseif ev == "Swarm" and string.sub(parsed.id, 1, 6) == "Honey_" then
		return 0.5
	end
	return 0
end

---------------------------------------------------------------- fox chase

local foxes: { [Model]: { owner: number, key: string, n: number, caught: boolean } } = {}

local function returnLoot(ownerId: number, key: string, n: number, keyNote: string)
	local owner = Players:GetPlayerByUserId(ownerId)
	if owner and DataService.get(owner) then
		Progress.give(owner, key, n)
		Net.notify(owner, keyNote, { n = n }, "social")
	else
		DataService.sendMail(ownerId, { type = "item", item = key, n = n })
	end
end

local function spawnFox(start: CFrame, loot)
	local folder = Make.folder("Foxes", WorldBuilder.root :: Folder)
	local m = Make.model("Fox", folder)
	local body = Make.part({ Name = "Body", Size = Vector3.new(1.6, 1.4, 2.8), CFrame = start, Color = Color3.fromRGB(230, 120, 40), CanCollide = false, Parent = m })
	Make.part({ Name = "Tail", Size = Vector3.new(0.6, 0.6, 1.6), CFrame = start * CFrame.new(0, 0.3, 1.9), Color = Color3.fromRGB(250, 240, 230), CanCollide = false, Parent = m })
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = body
	weld.Part1 = m:FindFirstChild("Tail") :: BasePart
	weld.Parent = body
	;(m:FindFirstChild("Tail") :: BasePart).Anchored = false
	m.PrimaryPart = body
	local pp = Make.prompt(body, "prompt.catchFox", "Catch!", 0, 12)
	pp:SetAttribute("Fox", true)
	foxes[m] = loot
	-- run toward the forest portal side of the valley
	local goal = CFrame.new(380, start.Y, rng:NextNumber(-200, 200))
	local tween = TweenService:Create(body, TweenInfo.new(70, Enum.EasingStyle.Linear), { CFrame = goal })
	tween:Play()
	task.delay(72, function()
		local data = foxes[m]
		if data and not data.caught then
			returnLoot(data.owner, data.key, data.n, "note.foxDropped")
		end
		foxes[m] = nil
		m:Destroy()
	end)
end

local function foxChase()
	local occupied = PlotService.occupied()
	if #occupied == 0 then
		return
	end
	local now = os.time()
	local spawned = 0
	local maxFoxes = math.min(6, #occupied * 2)
	for _, entry in occupied do
		if spawned >= maxFoxes then
			break
		end
		local p = entry.profile
		for key, tile in p.Tiles do
			if Growth.isRipe(tile, now) then
				local lands = Progress.lands(p)
				local n = Growth.yield(tile.crop, lands)
				local muts = table.clone(tile.mutations or {})
				Mutations.growthRoll(muts, function()
					return rng:NextNumber()
				end, Progress.luck(p))
				local itemKey = ItemLogic.cropKey(tile.crop, muts)
				if not Growth.afterHarvest(tile, now, lands, Progress.growBuff(p)) then
					p.Tiles[key] = nil
				end
				PlotService.refreshTile(entry.index, key)
				local cf = PlotService.tileCFrame(entry.index, key) :: CFrame
				spawnFox(CFrame.new(cf.Position + Vector3.new(0, 1, 0)), { owner = entry.player.UserId, key = itemKey, n = n, caught = false })
				spawned += 1
				break
			end
		end
	end
	if spawned > 0 then
		Net.notifyAll("note.foxChase", { n = spawned }, "event")
	end
end

local function catchFox(player: Player, prompt: ProximityPrompt)
	local body = prompt.Parent
	local m = body and body.Parent
	local data = m and foxes[m :: Model]
	if not data or data.caught then
		return
	end
	data.caught = true
	returnLoot(data.owner, data.key, data.n, "note.foxReturned")
	Progress.give(player, "FoxToken", 1)
	Progress.addCoins(player, 5)
	Progress.addXp(player, 5)
	Net.notify(player, "note.foxCaught", nil, "celebrate")
	foxes[m :: Model] = nil
	;(m :: Model):Destroy()
end

---------------------------------------------------------------- plaza field

local fieldPickups: Folder?

local function plazaField()
	if fieldPickups then
		fieldPickups:Destroy()
	end
	local folder = Make.folder("FieldPickups", WorldBuilder.root :: Folder)
	fieldPickups = folder
	local center = WorldBuilder.points.PlazaField
	local pool = { "Carrot", "Wheat", "Potato", "Lettuce", "Strawberry", "Tomato", "Corn", "Onion" }
	for i = 1, 40 do
		local cropId = pool[rng:NextInteger(1, #pool)]
		local c = Crops.byId[cropId]
		local pos = center + Vector3.new(rng:NextNumber(-18, 18), 1.2, rng:NextNumber(-18, 18))
		local part = Make.part({ Name = "Pickup_" .. i, Shape = Enum.PartType.Ball, Size = Vector3.new(1.6, 1.6, 1.6), CFrame = CFrame.new(pos), Color = Make.color(c.color), Parent = folder })
		local pp = Make.prompt(part, "prompt.pick", "Pick", 0.2, 8)
		pp:SetAttribute("FieldCrop", cropId)
	end
	Net.notifyAll("note.plazaField", nil, "event")
	task.delay(90, function()
		if fieldPickups == folder then
			folder:Destroy()
			fieldPickups = nil
		end
	end)
end

local function pick(player: Player, prompt: ProximityPrompt)
	local cropId = prompt:GetAttribute("FieldCrop")
	local part = prompt.Parent
	if not cropId or not part or not part.Parent then
		return
	end
	part:Destroy()
	local muts = {}
	if rng:NextNumber() < 0.1 then
		Mutations.add(muts, Mutations.keptScalePick(function()
			return rng:NextNumber()
		end))
	end
	Progress.give(player, ItemLogic.cropKey(cropId, muts), rng:NextInteger(1, 3))
	Progress.addXp(player, 2)
end

---------------------------------------------------------------- live show

local function startLiveShow()
	WeatherService.setOverride("Meteor", 180)
	Net.notifyAll("note.liveShow", nil, "event")
	Net.pushAll("Effect", { kind = "fireworks", at = WorldBuilder.points.Spawn })
	plazaField()
end

local function isAdmin(player: Player): boolean
	if player.UserId == game.CreatorId then
		return true
	end
	return table.find(EventService.ADMINS, player.UserId) ~= nil
end

---------------------------------------------------------------- token shop

local function buyToken(player: Player, id: any)
	local p = DataService.get(player)
	if not p or type(id) ~= "string" then
		return
	end
	local offer
	for _, o in EventService.tokenShop do
		if o.id == id then
			offer = o
		end
	end
	if not offer then
		return
	end
	if string.sub(id, 1, 6) == "theme:" then
		local themeId = string.sub(id, 7)
		if p.OwnedThemes[themeId] then
			return
		end
		if not Progress.take(player, "FoxToken", offer.cost) then
			Net.notify(player, "note.needTokens", { n = offer.cost }, "warn")
			return
		end
		p.OwnedThemes[themeId] = true
	else
		if not Progress.take(player, "FoxToken", offer.cost) then
			Net.notify(player, "note.needTokens", { n = offer.cost }, "warn")
			return
		end
		Progress.give(player, offer.id, offer.n)
	end
	Net.notify(player, "note.tokenBought", nil, "celebrate")
	Progress.dirty(player)
end

function EventService.init(services)
	DataService = services.DataService
	Progress = services.ProgressService
	PlotService = services.PlotService
	WeatherService = services.WeatherService
	MonetizationService = services.MonetizationService
end

function EventService.start()
	ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
		if prompt:GetAttribute("Fox") then
			catchFox(player, prompt)
		elseif prompt:GetAttribute("FieldCrop") then
			pick(player, prompt)
		end
	end)

	Net.onAction("TokenShop", buyToken, 2)

	MonetizationService.onProduct("ValleyGift", function(buyer)
		for _, pl in Players:GetPlayers() do
			if DataService.get(pl) then
				Progress.addCoins(pl, 50)
				local pool = { "Carrot", "Wheat", "Lettuce", "Potato" }
				Progress.give(pl, "Seed:" .. pool[rng:NextInteger(1, #pool)], 3)
			end
		end
		Net.notifyAll("note.valleyGift", { name = buyer.DisplayName }, "celebrate")
		Net.pushAll("Effect", { kind = "fireworks", at = WorldBuilder.points.Spawn })
	end)

	pcall(function()
		MessagingService:SubscribeAsync(LIVE_TOPIC, function()
			startLiveShow()
		end)
	end)
	local function hookChat(player: Player)
		player.Chatted:Connect(function(msg)
			if msg == "/liveshow" and isAdmin(player) then
				local ok = pcall(function()
					MessagingService:PublishAsync(LIVE_TOPIC, { t = os.time() })
				end)
				if not ok then
					startLiveShow() -- at least run it in this server
				end
			end
		end)
	end
	Players.PlayerAdded:Connect(hookChat)
	for _, pl in Players:GetPlayers() do
		hookChat(pl)
	end

	Progress.addSnapshotExtra(function(_player, _p, s)
		s.WeeklyEvent = EventService.weeklyEvent()
		s.NextFox = (math.floor(os.time() / EventService.FOX_EVERY) + 1) * EventService.FOX_EVERY
		s.NextField = (math.floor((os.time() - EventService.FIELD_OFFSET) / EventService.FIELD_EVERY) + 1) * EventService.FIELD_EVERY + EventService.FIELD_OFFSET
		s.TokenShop = EventService.tokenShop
	end)

	task.spawn(function()
		local lastFox = math.floor(os.time() / EventService.FOX_EVERY)
		local lastField = math.floor((os.time() - EventService.FIELD_OFFSET) / EventService.FIELD_EVERY)
		while true do
			task.wait(1)
			local now = os.time()
			local foxSlot = math.floor(now / EventService.FOX_EVERY)
			if foxSlot ~= lastFox then
				lastFox = foxSlot
				foxChase()
			end
			local fieldSlot = math.floor((now - EventService.FIELD_OFFSET) / EventService.FIELD_EVERY)
			if fieldSlot ~= lastField then
				lastField = fieldSlot
				plazaField()
			end
		end
	end)
end

return EventService
