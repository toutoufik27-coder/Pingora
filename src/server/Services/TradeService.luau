-- Safe trading between two players in the same server.
--
--   1. A sends an invite, B accepts.
--   2. Both put items/animals in their offer. Any change un-readies both.
--   3. Both press Ready -> a countdown starts. Any change cancels it.
--   4. When it ends, both offers are re-checked and swapped atomically.
--
-- The client shows each side's market value and a warning when the trade is
-- very unbalanced. There is no "drop on the floor" and no one-sided giving
-- of valuable items, which removes the classic Roblox trade scams.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")

local Net = require(Shared.Net)
local Economy = require(Shared.Config.Economy)
local Pricing = require(Shared.Logic.Pricing)
local Breeding = require(Shared.Logic.Breeding)
local Inventory = require(Shared.Logic.Inventory)
local Social = require(Shared.Logic.Social)

local DataService, Progress, PlotService, AnimalService

local TradeService = {}

type Side = { player: Player, items: { [string]: number }, animals: { string }, ready: boolean }
type Session = { id: number, a: Side, b: Side, version: number, countdownEnd: number? }

local sessions: { [Player]: Session } = {}
local invites: { [Player]: { [Player]: number } } = {} -- target -> from -> expiry
local nextId = 0

local function canTrade(player: Player): (boolean, string?)
	local p = DataService.get(player)
	if not p then
		return false, "note.tradeNotReady"
	end
	if RunService:IsStudio() then
		return true
	end
	if player.AccountAge < Economy.TRADE_MIN_ACCOUNT_AGE_DAYS then
		return false, "note.tradeTooNew"
	end
	if DataService.playtime(player) < Economy.TRADE_MIN_PLAYTIME then
		return false, "note.tradePlaytime"
	end
	return true
end

local function animalValue(owner: Player)
	local p = DataService.get(owner)
	return function(id: string): number
		local a = p and p.Animals[id]
		return if a then Breeding.value(a) else 0
	end
end

local function sideView(side: Side)
	local p = DataService.get(side.player)
	local animals = {}
	for _, id in side.animals do
		local a = p and p.Animals[id]
		if a then
			table.insert(animals, { id = id, species = a.species, color = a.color, traits = a.traits })
		end
	end
	local value = Pricing.offerValue({ items = side.items, animals = side.animals }, animalValue(side.player))
	return {
		userId = side.player.UserId,
		name = side.player.DisplayName,
		items = side.items,
		animals = animals,
		ready = side.ready,
		value = math.floor(value),
	}
end

local function pushState(s: Session)
	local a, b = sideView(s.a), sideView(s.b)
	local state = {
		id = s.id,
		a = a,
		b = b,
		countdownEnd = s.countdownEnd,
		imbalanced = Pricing.isImbalanced(a.value, b.value),
		serverTime = os.time(),
	}
	Net.push(s.a.player, "Trade", state)
	Net.push(s.b.player, "Trade", state)
end

local function close(s: Session, reasonKey: string?)
	for _, side in { s.a, s.b } do
		if sessions[side.player] == s then
			sessions[side.player] = nil
		end
		Net.push(side.player, "Trade", { closed = true, reason = reasonKey })
	end
end

local function sideOf(player: Player): (Session?, Side?, Side?)
	local s = sessions[player]
	if not s then
		return nil, nil, nil
	end
	if s.a.player == player then
		return s, s.a, s.b
	end
	return s, s.b, s.a
end

local function unready(s: Session)
	s.a.ready = false
	s.b.ready = false
	s.countdownEnd = nil
	s.version += 1
end

local function execute(s: Session)
	local pa, pb = DataService.get(s.a.player), DataService.get(s.b.player)
	if not pa or not pb then
		close(s, "note.tradeFailed")
		return
	end
	local okA = Social.validateOffer(pa.Inventory, pa.Animals, s.a.items, s.a.animals)
	local okB = Social.validateOffer(pb.Inventory, pb.Animals, s.b.items, s.b.animals)
	if not okA or not okB then
		close(s, "note.tradeFailed")
		return
	end
	-- count animals after the swap
	local function count(t)
		local n = 0
		for _ in t do
			n += 1
		end
		return n
	end
	if count(pa.Animals) - #s.a.animals + #s.b.animals > 24 or count(pb.Animals) - #s.b.animals + #s.a.animals > 24 then
		close(s, "note.farmFull")
		return
	end
	-- items (removeAll is all-or-nothing; validated above so both succeed)
	Inventory.removeAll(pa.Inventory, s.a.items)
	Inventory.removeAll(pb.Inventory, s.b.items)
	for key, n in s.a.items do
		Progress.give(s.b.player, key, n)
	end
	for key, n in s.b.items do
		Progress.give(s.a.player, key, n)
	end
	-- animals
	local function move(from: any, to: any, ids: { string }, toPlayer: Player)
		for _, id in ids do
			local a = from.Animals[id]
			from.Animals[id] = nil
			a.companion = false
			a.busy = nil
			to.Animals[id] = a
			Progress.discoverAnimal(toPlayer, a.species, a.color)
		end
	end
	move(pa, pb, s.a.animals, s.b.player)
	move(pb, pa, s.b.animals, s.a.player)

	for _, pair in { { s.a, pa, s.b }, { s.b, pb, s.a } } do
		local side, prof, other = pair[1], pair[2], pair[3]
		prof.Stats.trades += 1
		table.insert(prof.TradeLog, 1, { t = os.time(), with = other.player.UserId, gave = side.items, got = other.items })
		while #prof.TradeLog > 20 do
			table.remove(prof.TradeLog)
		end
		Progress.addXp(side.player, Economy.XP.tradeDone)
		Progress.emit(side.player, "trade", 1)
		AnimalService.refreshCompanions(side.player)
		if prof.__plot then
			PlotService.refreshAnimals(prof.__plot)
		end
		Progress.dirty(side.player)
		DataService.save(side.player)
	end
	close(s, "note.tradeDone")
end

---------------------------------------------------------------- actions

local function request(player: Player, targetId: any)
	if type(targetId) ~= "number" then
		return
	end
	local target = Players:GetPlayerByUserId(targetId)
	if not target or target == player or sessions[player] or sessions[target] then
		return
	end
	local ok, why = canTrade(player)
	if not ok then
		Net.notify(player, why :: string, nil, "warn")
		return
	end
	local okT = canTrade(target)
	if not okT then
		Net.notify(player, "note.tradeTargetCannot", nil, "warn")
		return
	end
	local tp = DataService.get(target)
	if tp and tp.Blocked[tostring(player.UserId)] then
		return -- silently ignored
	end
	invites[target] = invites[target] or {}
	invites[target][player] = os.time() + 30
	Net.push(target, "TradeInvite", { userId = player.UserId, name = player.DisplayName })
	Net.notify(player, "note.tradeInviteSent", { name = target.DisplayName }, "info")
end

local function respond(player: Player, fromId: any, accept: any)
	if type(fromId) ~= "number" then
		return
	end
	local from = Players:GetPlayerByUserId(fromId)
	local list = invites[player]
	if not from or not list or not list[from] or list[from] < os.time() then
		return
	end
	list[from] = nil
	if accept ~= true then
		Net.notify(from, "note.tradeDeclined", { name = player.DisplayName }, "info")
		return
	end
	if sessions[player] or sessions[from] then
		return
	end
	nextId += 1
	local s: Session = {
		id = nextId,
		a = { player = from, items = {}, animals = {}, ready = false },
		b = { player = player, items = {}, animals = {}, ready = false },
		version = 0,
		countdownEnd = nil,
	}
	sessions[from] = s
	sessions[player] = s
	pushState(s)
end

local function setOffer(player: Player, rawItems: any, rawAnimals: any)
	local s, me = sideOf(player)
	if not s or not me then
		return
	end
	local items = Inventory.cleanCounts(rawItems or {}, Economy.TRADE_MAX_SLOTS)
	if not items then
		return
	end
	local animals = {}
	if type(rawAnimals) == "table" then
		for _, id in rawAnimals do
			if type(id) == "string" and #animals < Economy.TRADE_MAX_SLOTS then
				table.insert(animals, id)
			end
		end
	end
	local p = DataService.get(player)
	local ok, err = Social.validateOffer(p.Inventory, p.Animals, items, animals)
	if not ok then
		Net.notify(player, "note.trade_" .. tostring(err), nil, "warn")
		return
	end
	me.items = items
	me.animals = animals
	unready(s)
	pushState(s)
end

local function setReady(player: Player, ready: any)
	local s, me, other = sideOf(player)
	if not s or not me or not other then
		return
	end
	me.ready = ready == true
	if not me.ready then
		s.countdownEnd = nil
		s.version += 1
		pushState(s)
		return
	end
	if me.ready and other.ready then
		s.version += 1
		local version = s.version
		s.countdownEnd = os.time() + Economy.TRADE_COUNTDOWN
		pushState(s)
		task.delay(Economy.TRADE_COUNTDOWN, function()
			if sessions[s.a.player] == s and s.version == version and s.a.ready and s.b.ready then
				execute(s)
			end
		end)
	else
		pushState(s)
	end
end

local function cancel(player: Player)
	local s = sessions[player]
	if s then
		close(s, "note.tradeCancelled")
	end
end

local function block(player: Player, userId: any)
	local p = DataService.get(player)
	if p and type(userId) == "number" then
		p.Blocked[tostring(userId)] = true
		Net.notify(player, "note.blocked", nil, "info")
	end
end

function TradeService.init(services)
	DataService = services.DataService
	Progress = services.ProgressService
	PlotService = services.PlotService
	AnimalService = services.AnimalService
end

function TradeService.start()
	Net.onAction("TradeRequest", request, 1)
	Net.onAction("TradeRespond", respond, 2)
	Net.onAction("TradeOffer", setOffer, 6)
	Net.onAction("TradeReady", setReady, 4)
	Net.onAction("TradeCancel", cancel, 2)
	Net.onAction("BlockPlayer", block, 1)
	Players.PlayerRemoving:Connect(function(player)
		cancel(player)
		invites[player] = nil
		for _, list in invites do
			list[player] = nil
		end
	end)
end

return TradeService
