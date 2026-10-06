-- The Kinfield global market. Players list items at a price inside a band
-- around the item's reference value; anyone in any server can buy.
--
-- Storage: one MemoryStore sorted map per item key, sorted by unit price.
-- Listed items are held in escrow (removed from the seller's inventory).
-- Proceeds reach the seller through the mail store, even if offline. The
-- seller's profile keeps a record of each listing so unsold items always
-- come back after expiry.

local MemoryStoreService = game:GetService("MemoryStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")

local Net = require(Shared.Net)
local Economy = require(Shared.Config.Economy)
local Pricing = require(Shared.Logic.Pricing)
local ItemLogic = require(Shared.Logic.Items)
local WorldBuilder = require(script.Parent.Parent.World.WorldBuilder)

local DataService, Progress

local MarketService = {}

local EXPIRY_GRACE = 3 * 24 * 3600 -- map entries outlive listings so they can be reconciled
local maps: { [string]: MemorySortedMap } = {}

local function mapFor(key: string): MemorySortedMap?
	local m = maps[key]
	if m then
		return m
	end
	local ok, result = pcall(function()
		return MemoryStoreService:GetSortedMap("mkt1_" .. string.gsub(key, "[^%w]", "_"))
	end)
	if ok then
		maps[key] = result
		return result
	end
	return nil
end

local function maxListings(p: any): number
	return Economy.MARKET_MAX_LISTINGS + (if p.Deeds.Lighthouse then 1 else 0)
end

local function countListings(p: any): number
	local n = 0
	for _ in p.Listings do
		n += 1
	end
	return n
end

---------------------------------------------------------------- listing

local function list(player: Player, key: any, n: any, price: any)
	if type(key) ~= "string" or type(n) ~= "number" or type(price) ~= "number" or n ~= n or price ~= price then
		return
	end
	n = math.floor(n)
	price = math.floor(price)
	local p = DataService.get(player)
	if not p or n < 1 or n > 999 or not ItemLogic.isMarketable(key) then
		return
	end
	-- mutated crops go through the trade window, so every market listing
	-- stays findable under its plain item
	if #ItemLogic.parse(key).mutations > 0 then
		return
	end
	if Progress.distance(player, WorldBuilder.points.Market) > Economy.SHOP_DISTANCE then
		return
	end
	if countListings(p) >= maxListings(p) then
		Net.notify(player, "note.marketFull", nil, "warn")
		return
	end
	local lo, hi = Pricing.marketBand(key)
	if price < lo or price > hi then
		Net.notify(player, "note.marketBand", { lo = lo, hi = hi }, "warn")
		return
	end
	if (p.Inventory[key] or 0) < n then
		return
	end
	local map = mapFor(key)
	if not map then
		Net.notify(player, "note.marketUnavailable", nil, "warn")
		return
	end
	local id = HttpService:GenerateGUID(false)
	local expires = os.time() + Economy.MARKET_LISTING_TTL
	-- escrow first, then publish; refund if publishing fails
	if not Progress.take(player, key, n) then
		return
	end
	local ok = pcall(function()
		map:SetAsync(id, { s = player.UserId, n = n, p = price, e = expires, k = key }, Economy.MARKET_LISTING_TTL + EXPIRY_GRACE, price)
	end)
	if not ok then
		Progress.give(player, key, n)
		Net.notify(player, "note.marketUnavailable", nil, "warn")
		return
	end
	p.Listings[id] = { k = key, n = n, p = price, e = expires }
	Net.notify(player, "note.listed", { n = n, price = price }, "info")
	Progress.dirty(player)
	DataService.save(player)
end

-- Claims `n` units (or all remaining when n is nil) of a listing atomically.
-- Returns the number claimed and the listing value.
local function claim(map: MemorySortedMap, id: string, n: number?, forbidSeller: number?): (number, any?)
	local claimed, snapshot = 0, nil
	local ok = pcall(function()
		map:UpdateAsync(id, function(value, sortKey)
			if not value or value.n <= 0 then
				return nil
			end
			if forbidSeller and value.s == forbidSeller then
				return nil
			end
			if value.e < os.time() and forbidSeller then
				return nil -- expired listings cannot be bought
			end
			local take = if n then math.min(n, value.n) else value.n
			value.n -= take
			claimed = take
			snapshot = value
			return value, sortKey
		end, Economy.MARKET_LISTING_TTL + EXPIRY_GRACE)
	end)
	if not ok then
		return 0, nil
	end
	if snapshot and snapshot.n <= 0 then
		pcall(function()
			map:RemoveAsync(id)
		end)
	end
	return claimed, snapshot
end

local function buy(player: Player, key: any, id: any, n: any)
	if type(key) ~= "string" or type(id) ~= "string" or type(n) ~= "number" or n ~= n then
		return
	end
	n = math.clamp(math.floor(n), 1, 999)
	local p = DataService.get(player)
	local map = mapFor(key)
	if not p or not map then
		return
	end
	if Progress.distance(player, WorldBuilder.points.Market) > Economy.SHOP_DISTANCE then
		return
	end
	-- peek the price to check coins before claiming
	local okGet, value = pcall(function()
		return map:GetAsync(id)
	end)
	if not okGet or not value or value.n <= 0 then
		Net.notify(player, "note.listingGone", nil, "warn")
		return
	end
	n = math.min(n, value.n)
	if p.Coins < value.p * n then
		Net.notify(player, "note.notEnoughCoins", nil, "warn")
		return
	end
	local got, snap = claim(map, id, n, player.UserId)
	if got <= 0 or not snap then
		Net.notify(player, "note.listingGone", nil, "warn")
		return
	end
	local total = snap.p * got
	if not Progress.spendCoins(player, total) then
		-- coins vanished between the check and the claim: put the units back
		pcall(function()
			map:UpdateAsync(id, function(v, sk)
				if v then
					v.n += got
					return v, sk
				end
				return nil
			end, Economy.MARKET_LISTING_TTL + EXPIRY_GRACE)
		end)
		return
	end
	Progress.give(player, snap.k, got)
	local proceeds = total - Pricing.marketFee(total)
	DataService.sendMail(snap.s, { type = "sale", listing = id, n = got, coins = proceeds, item = snap.k })
	Net.notify(player, "note.bought", { n = got }, "info")
	DataService.save(player)
end

-- How many unsold units of a listing go back to the seller, or nil when the
-- store cannot be reached. A missing entry means "sold out" unless the map
-- entry's own lifetime has passed, in which case the profile record (kept up
-- to date by sale mails) says how many were left.
local function remainingFor(player: Player, id: string, rec: any): number?
	local map = mapFor(rec.k)
	if not map then
		return nil
	end
	local okGet, value = pcall(function()
		return map:GetAsync(id)
	end)
	if not okGet then
		return nil
	end
	if value then
		return (claim(map, id, nil, nil))
	end
	if os.time() >= rec.e + EXPIRY_GRACE - 60 then
		return math.max(0, rec.n)
	end
	return 0
end

local processMail -- defined below

local function cancel(player: Player, id: any)
	local p = DataService.get(player)
	if not p or type(id) ~= "string" then
		return
	end
	local rec = p.Listings[id]
	if not rec then
		return
	end
	processMail(player)
	rec = p.Listings[id]
	if not rec then
		return -- sold out meanwhile
	end
	local back = remainingFor(player, id, rec)
	if back == nil then
		Net.notify(player, "note.marketUnavailable", nil, "warn")
		return
	end
	p.Listings[id] = nil
	if back > 0 then
		Progress.give(player, rec.k, back)
	end
	Net.notify(player, "note.listingCancelled", { n = back }, "info")
	Progress.dirty(player)
	DataService.save(player)
end

---------------------------------------------------------------- mail & reconcile

function processMail(player: Player)
	local p = DataService.get(player)
	if not p then
		return
	end
	local mail = DataService.takeMail(player)
	local coins = 0
	for _, m in mail do
		if m.type == "sale" then
			coins += m.coins or 0
			local rec = p.Listings[m.listing]
			if rec then
				rec.n -= m.n or 0
				if rec.n <= 0 then
					p.Listings[m.listing] = nil
				end
			end
		elseif m.type == "coins" then
			coins += m.coins or 0
		elseif m.type == "item" and type(m.item) == "string" and type(m.n) == "number" then
			Progress.give(player, m.item, m.n)
		elseif m.type == "deed" and type(m.project) == "string" then
			if not p.Deeds[m.project] then
				p.Deeds[m.project] = true
				Net.notify(player, "note.deedEarned", { project = m.project }, "celebrate")
			end
		end
	end
	if coins > 0 then
		Progress.addCoins(player, coins)
		Net.notify(player, "note.marketSales", { coins = coins }, "celebrate")
	end
	if #mail > 0 then
		Progress.dirty(player)
		DataService.save(player)
	end
end

-- Returns unsold items of expired listings.
local function reconcile(player: Player)
	local p = DataService.get(player)
	if not p then
		return
	end
	local now = os.time()
	for id, rec in p.Listings do
		if rec.e <= now then
			local back = remainingFor(player, id, rec)
			if back == nil then
				continue -- store unavailable; try later
			end
			p.Listings[id] = nil
			if back > 0 then
				Progress.give(player, rec.k, back)
				Net.notify(player, "note.listingReturned", { n = back }, "info")
			end
		end
	end
	Progress.dirty(player)
end

local function getListings(_player: Player, key: any)
	if type(key) ~= "string" or not ItemLogic.isMarketable(key) then
		return nil
	end
	local map = mapFor(key)
	if not map then
		return nil
	end
	local ok, items = pcall(function()
		return map:GetRangeAsync(Enum.SortDirection.Ascending, 30)
	end)
	if not ok or not items then
		return nil
	end
	local now = os.time()
	local out = {}
	for _, entry in items do
		local v = entry.value
		if v and v.n > 0 and v.e > now then
			table.insert(out, { id = entry.key, n = v.n, price = v.p, seller = v.s })
			if #out >= 20 then
				break
			end
		end
	end
	local lo, hi = Pricing.marketBand(key)
	return { listings = out, lo = lo, hi = hi, reference = math.floor(Pricing.value(key)) }
end

function MarketService.init(services)
	DataService = services.DataService
	Progress = services.ProgressService
end

function MarketService.start()
	Net.onAction("MarketList", list, 1)
	Net.onAction("MarketBuy", buy, 2)
	Net.onAction("MarketCancel", cancel, 2)
	Net.onRequest("MarketListings", getListings, 4)

	WorldBuilder.prompts.Market.Triggered:Connect(function(player)
		Net.push(player, "Open", "Market")
	end)

	DataService.Loaded:Connect(function(player)
		processMail(player)
		reconcile(player)
	end)
	task.spawn(function()
		while true do
			task.wait(60)
			for _, player in Players:GetPlayers() do
				if DataService.get(player) then
					task.spawn(function()
						processMail(player)
						reconcile(player)
					end)
				end
			end
		end
	end)
end

return MarketService
