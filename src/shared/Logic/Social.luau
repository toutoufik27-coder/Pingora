-- Gleaning, trades and daily quests: rules shared by server and client.

local Economy = require(script.Parent.Parent.Config.Economy)
local Quests = require(script.Parent.Parent.Config.Quests)
local Growth = require(script.Parent.Growth)
local ItemLogic = require(script.Parent.Items)
local Hash = require(script.Parent.Parent.Util.Hash)

local Social = {}

-- Can someone other than the owner harvest this crop?
-- Overripe crops are always gleanable; ripe ones only on shared tiles.
function Social.canGlean(stage: number, shared: boolean?): boolean
	if stage == Growth.STAGE_OVERRIPE then
		return true
	end
	return stage == Growth.STAGE_RIPE and shared == true
end

-- Splits a gleaned harvest. The owner keeps most of it and the gleaner gets
-- new units on top, so gleaning is positive-sum.
function Social.gleanSplit(yield: number, rng: () -> number): (number, number)
	local owner = math.ceil(yield * Economy.GLEAN_OWNER_SHARE)
	local raw = yield * Economy.GLEAN_GLEANER_SHARE
	local gleaner = math.floor(raw)
	if rng() < raw - gleaner then
		gleaner += 1
	end
	return owner, gleaner
end

-- A day index used for daily limits and quests (UTC days).
function Social.dayIndex(now: number): number
	return math.floor(now / 86400)
end

-- Checks that a trade offer only holds tradeable items the player owns.
-- `offerItems` is { [key] = count }, `offerAnimals` is a list of animal ids.
function Social.validateOffer(
	inventory: { [string]: number },
	animals: { [string]: any },
	offerItems: { [string]: number },
	offerAnimals: { string }
): (boolean, string?)
	local slots = 0
	for key, n in offerItems do
		slots += 1
		if not ItemLogic.isTradeable(key) then
			return false, "notTradeable"
		end
		if (inventory[key] or 0) < n then
			return false, "notEnough"
		end
	end
	local seen = {}
	for _, id in offerAnimals do
		slots += 1
		local a = animals[id]
		if not a or seen[id] then
			return false, "noAnimal"
		end
		if a.busy then
			return false, "animalBusy"
		end
		seen[id] = true
	end
	if slots > Economy.TRADE_MAX_SLOTS then
		return false, "tooMany"
	end
	return true, nil
end

-- Picks today's quests for a player (deterministic per player per day).
function Social.dailyQuests(day: number, userId: number, level: number): { string }
	local pool = {}
	for _, q in Quests.dailyPool do
		if (q.level or 1) <= level then
			table.insert(pool, q.id)
		end
	end
	local rng = Hash.stream(day * 131 + (userId % 100000))
	for i = #pool, 2, -1 do
		local j = math.clamp(math.floor(rng() * i) + 1, 1, i)
		pool[i], pool[j] = pool[j], pool[i]
	end
	local out = {}
	for i = 1, math.min(Quests.DAILY_COUNT, #pool) do
		table.insert(out, pool[i])
	end
	return out
end

return Social
