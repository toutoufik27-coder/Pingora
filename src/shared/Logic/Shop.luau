-- Personal seed shop stock. Each player has their own stock, so nobody camps
-- the shop competing with others. A wished seed is guaranteed within
-- Economy.SHOP_WISH_PITY restocks.

local Crops = require(script.Parent.Parent.Config.Crops)
local Economy = require(script.Parent.Parent.Config.Economy)

local Shop = {}

local APPEAR = { 1, 0.6, 0.3 }
local AMOUNT = { { 5, 10 }, { 2, 5 }, { 1, 2 } }

function Shop.eligible(level: number): { string }
	local out = {}
	for _, c in Crops.list do
		if c.source == "shop" and c.seed and c.level <= level then
			table.insert(out, c.id)
		end
	end
	return out
end

local function amountFor(tier: number, rng: () -> number): number
	local range = AMOUNT[math.clamp(tier, 1, 3)]
	return range[1] + math.floor(rng() * (range[2] - range[1] + 1))
end

-- Returns stock { [cropId] = count } and the new pity counter.
function Shop.restock(level: number, wish: string?, pity: number, rng: () -> number): ({ [string]: number }, number)
	local stock: { [string]: number } = {}
	local count = 0
	-- starters always available
	for _, id in { "Carrot", "Wheat" } do
		stock[id] = amountFor(1, rng)
		count += 1
	end
	local pool = Shop.eligible(level)
	-- shuffle
	for i = #pool, 2, -1 do
		local j = math.clamp(math.floor(rng() * i) + 1, 1, i)
		pool[i], pool[j] = pool[j], pool[i]
	end
	for _, id in pool do
		if count >= Economy.SHOP_SLOTS then
			break
		end
		if not stock[id] then
			local c = Crops.byId[id]
			if rng() < APPEAR[math.clamp(c.tier, 1, 3)] then
				stock[id] = amountFor(c.tier, rng)
				count += 1
			end
		end
	end
	local newPity = pity
	if wish and Crops.byId[wish] and Crops.byId[wish].source == "shop" and Crops.byId[wish].level <= level then
		if stock[wish] then
			newPity = 0
		else
			newPity += 1
			if newPity >= Economy.SHOP_WISH_PITY then
				stock[wish] = amountFor(Crops.byId[wish].tier, rng)
				newPity = 0
			end
		end
	end
	return stock, newPity
end

return Shop
