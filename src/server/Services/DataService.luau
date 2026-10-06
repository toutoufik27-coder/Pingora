-- Player profiles in DataStores with session locking.
--
-- A profile record is { data = <profile>, lock = { job = JobId, time = os.time() } }.
-- A server only loads a profile if no other live server holds its lock, and
-- only saves while it still owns the lock. This stops item duplication when
-- players hop between servers quickly.
--
-- In Studio without "Enable Studio Access to API Services", profiles fall
-- back to memory so the game is still playable for testing.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Economy = require(Shared.Config.Economy)
local Signal = require(Shared.Util.Signal)

local DataService = {}

local PROFILE_STORE = "KinfieldProfiles_v1"
local MAIL_STORE = "KinfieldMail_v1"
local AUTOSAVE_SECONDS = 60
local LOCK_STALE_SECONDS = 180
local LOAD_ATTEMPTS = 6
local MAIL_CAP = 200

DataService.VERSION = 1
DataService.Loaded = Signal.new() -- (player, profile)
DataService.Releasing = Signal.new() -- (player, profile) before the final save

local profiles: { [Player]: any } = {}
local memoryOnly = false
local profileStore: DataStore?
local mailStore: DataStore?
local jobId = if game.JobId ~= "" then game.JobId else ("studio-" .. HttpService:GenerateGUID(false))

local function deepCopy(t)
	if type(t) ~= "table" then
		return t
	end
	local out = {}
	for k, v in t do
		out[k] = deepCopy(v)
	end
	return out
end

function DataService.defaultProfile(): any
	local inv = {}
	for k, v in Economy.START_SEEDS do
		inv[k] = v
	end
	for k, v in Economy.START_ITEMS do
		inv[k] = v
	end
	return {
		Version = DataService.VERSION,
		Coins = Economy.START_COINS,
		Kindness = 0,
		Level = 1,
		XP = 0,
		Rebirths = 0,
		Land = nil, -- chosen after the first minutes
		SecondLand = nil,
		LandChanges = 0,
		PlotSize = 6,
		Tiles = {}, -- [tileKey] = Growth.Tile
		Inventory = inv,
		Animals = {}, -- [guid] = animal
		Workshops = {}, -- [workshopId] = { queue = { {recipe, start, done} } }
		Tools = { Basket = 0, Can = 0, SeedBag = 0 },
		SeedShop = { slot = -1, stock = {}, wish = nil, pity = 0 },
		Almanac = { crops = {}, animals = {}, items = {} },
		Quests = { day = -1, daily = {}, progress = {}, claimed = {}, story = 1, storyProgress = 0 },
		Stats = {
			harvested = 0,
			gleaned = 0,
			sold = 0,
			playtime = 0,
			gleanDay = -1,
			gleanCount = 0,
			waterDay = -1,
			waterCount = 0,
			trips = 0,
			trades = 0,
		},
		Deeds = {}, -- [projectId] = true
		Listings = {}, -- [listingId] = { item, count, price, expires }
		Purchases = {}, -- [receiptId] = time (idempotency)
		Skips = { day = -1, count = 0 },
		Spend = { day = -1, robux = 0 },
		Favorites = {}, -- [itemKey] = true: never sold by "sell all"
		Breeding = nil, -- { a, b, done }
		Hatching = nil, -- { hen, done }
		SkipTokens = 0,
		Blocked = {}, -- [userId string] = true
		TradeLog = {},
		Theme = "Classic",
		OwnedThemes = { Classic = true },
		Tutorial = 0,
		Created = os.time(),
		LastSeen = os.time(),
	}
end

-- Fills in keys added after a profile was first created.
local function reconcile(data, template)
	for k, v in template do
		if data[k] == nil then
			data[k] = deepCopy(v)
		elseif type(v) == "table" and type(data[k]) == "table" and next(v) ~= nil then
			-- only recurse into record-like templates, not id maps
			local isRecord = true
			for tk in v do
				if type(tk) ~= "string" then
					isRecord = false
					break
				end
			end
			if isRecord and (k == "Stats" or k == "Quests" or k == "SeedShop" or k == "Tools" or k == "Almanac" or k == "Skips" or k == "Spend") then
				reconcile(data[k], v)
			end
		end
	end
end

local function migrate(data)
	data.Version = data.Version or 1
	-- future migrations go here: if data.Version < 2 then ... end
	data.Version = DataService.VERSION
	return data
end

local function initStores()
	local ok, err = pcall(function()
		profileStore = DataStoreService:GetDataStore(PROFILE_STORE)
		mailStore = DataStoreService:GetDataStore(MAIL_STORE)
		-- probe access (fails fast in Studio without API access)
		profileStore:GetAsync("__probe")
	end)
	if not ok then
		memoryOnly = true
		warn("[DataService] DataStores unavailable, using memory-only profiles: " .. tostring(err))
	end
end

local function loadRecord(player: Player): (any?, string?)
	if memoryOnly then
		return DataService.defaultProfile(), nil
	end
	local key = "u_" .. player.UserId
	for attempt = 1, LOAD_ATTEMPTS do
		local lockedByOther = false
		local result
		local ok, err = pcall(function()
			profileStore:UpdateAsync(key, function(record)
				record = record or { data = nil, lock = nil }
				local lock = record.lock
				local now = os.time()
				if lock and lock.job ~= jobId and now - (lock.time or 0) < LOCK_STALE_SECONDS then
					lockedByOther = true
					return nil -- cancel the write
				end
				record.lock = { job = jobId, time = now }
				result = record.data
				return record
			end)
		end)
		if ok and not lockedByOther then
			local data = result or DataService.defaultProfile()
			return data, nil
		end
		if not ok then
			warn("[DataService] load attempt " .. attempt .. " failed: " .. tostring(err))
		end
		task.wait(if lockedByOther then 5 else 2)
		if not player.Parent then
			return nil, "left"
		end
	end
	return nil, "locked"
end

local function saveRecord(player: Player, data: any, release: boolean): boolean
	if memoryOnly then
		return true
	end
	local key = "u_" .. player.UserId
	local saved = false
	local ok, err = pcall(function()
		profileStore:UpdateAsync(key, function(record)
			record = record or {}
			local lock = record.lock
			if lock and lock.job ~= jobId then
				-- another server took over; never overwrite its data
				return nil
			end
			data.LastSeen = os.time()
			record.data = data
			record.lock = if release then nil else { job = jobId, time = os.time() }
			saved = true
			return record
		end)
	end)
	if not ok then
		warn("[DataService] save failed for " .. player.Name .. ": " .. tostring(err))
	end
	return ok and saved
end

function DataService.get(player: Player): any?
	return profiles[player]
end

function DataService.isMemoryOnly(): boolean
	return memoryOnly
end

function DataService.save(player: Player)
	local data = profiles[player]
	if data then
		saveRecord(player, data, false)
	end
end

---------------------------------------------------------------- mail
-- Mail carries things to players who may be offline or in another server:
-- market sale proceeds, returned listings, and so on.

function DataService.sendMail(userId: number, entry: { [string]: any }): boolean
	if memoryOnly then
		-- deliver directly if the player is here
		local p = Players:GetPlayerByUserId(userId)
		local data = p and profiles[p]
		if data then
			data.__mailbox = data.__mailbox or {}
			table.insert(data.__mailbox, entry)
			return true
		end
		return false
	end
	local ok = pcall(function()
		mailStore:UpdateAsync("m_" .. userId, function(list)
			list = list or {}
			if #list >= MAIL_CAP then
				table.remove(list, 1)
			end
			table.insert(list, entry)
			return list
		end)
	end)
	return ok
end

-- Takes all pending mail for a player (atomically empties the mailbox).
function DataService.takeMail(player: Player): { any }
	local data = profiles[player]
	if memoryOnly then
		local list = data and data.__mailbox or {}
		if data then
			data.__mailbox = nil
		end
		return list
	end
	local taken = {}
	pcall(function()
		mailStore:UpdateAsync("m_" .. player.UserId, function(list)
			if not list or #list == 0 then
				return nil
			end
			taken = list
			return {}
		end)
	end)
	return taken
end

---------------------------------------------------------------- lifecycle

local function onPlayerAdded(player: Player)
	local data, err = loadRecord(player)
	if not data then
		if err == "locked" and player.Parent then
			player:Kick("Your farm is still saving from another server. Please rejoin in a minute.")
		end
		return
	end
	if not player.Parent then
		saveRecord(player, data, true)
		return
	end
	migrate(data)
	reconcile(data, DataService.defaultProfile())
	data.__joinedAt = os.time()
	data.__lastSeenBefore = data.LastSeen
	profiles[player] = data
	DataService.Loaded:Fire(player, data)
end

local function release(player: Player)
	local data = profiles[player]
	if not data then
		return
	end
	DataService.Releasing:Fire(player, data)
	task.wait() -- let releasing handlers run first
	data.Stats.playtime += os.time() - (data.__joinedAt or os.time())
	data.__joinedAt = nil
	data.__lastSeenBefore = nil
	data.__mailbox = nil
	local clean = {}
	for k, v in data do
		if type(k) ~= "string" or string.sub(k, 1, 2) ~= "__" then
			clean[k] = v
		end
	end
	saveRecord(player, clean, true)
	profiles[player] = nil
end

-- Total playtime including the current session.
function DataService.playtime(player: Player): number
	local data = profiles[player]
	if not data then
		return 0
	end
	return data.Stats.playtime + (os.time() - (data.__joinedAt or os.time()))
end

function DataService.init()
	initStores()
end

function DataService.start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, p in Players:GetPlayers() do
		task.spawn(onPlayerAdded, p)
	end
	Players.PlayerRemoving:Connect(release)

	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_SECONDS)
			for player, data in profiles do
				if player.Parent then
					local clean = {}
					for k, v in data do
						if type(k) ~= "string" or string.sub(k, 1, 2) ~= "__" then
							clean[k] = v
						end
					end
					task.spawn(saveRecord, player, clean, false)
				end
			end
		end
	end)

	game:BindToClose(function()
		if RunService:IsStudio() and memoryOnly then
			return
		end
		local pending = 0
		for player in profiles do
			pending += 1
			task.spawn(function()
				release(player)
				pending -= 1
			end)
		end
		local start = os.clock()
		while pending > 0 and os.clock() - start < 25 do
			task.wait(0.2)
		end
	end)
end

return DataService
