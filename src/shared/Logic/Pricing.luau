local Weather = require(script.Parent.Parent.Config.Weather)
local Economy = require(script.Parent.Parent.Config.Economy)
local ItemLogic = require(script.Parent.Items)

local Pricing = {}

-- Mutation multipliers stack additively: Wet (x2) + Frozen (x3) = x4.
-- Multiplicative stacking would explode the economy.
function Pricing.mutationMultiplier(mutations: { string }): number
	local m = 1
	for _, id in mutations do
		local def = Weather.mutations[id]
		if def then
			m += def.mult - 1
		end
	end
	return m
end

-- Reference value of one unit of an inventory key.
function Pricing.value(key: string): number
	local p = ItemLogic.parse(key)
	if not p.def then
		return 0
	end
	return p.def.value * Pricing.mutationMultiplier(p.mutations)
end

-- Kiosk sell price for one unit. `bonus` is a fraction (0.1 = +10%).
function Pricing.sellPrice(key: string, bonus: number?): number
	local v = Pricing.value(key) * (1 + (bonus or 0))
	return math.max(0, math.floor(v + 0.5))
end

-- Allowed unit price range on the global market.
function Pricing.marketBand(key: string): (number, number)
	local v = Pricing.value(key)
	local lo = math.max(1, math.floor(v * Economy.MARKET_BAND_MIN))
	local hi = math.max(lo, math.ceil(v * Economy.MARKET_BAND_MAX))
	return lo, hi
end

function Pricing.marketFee(total: number): number
	return math.floor(total * Economy.MARKET_FEE + 0.5)
end

export type Offer = { items: { [string]: number }, animals: { [string]: any }? }

-- Value of a trade offer; animals are valued by species price and colour rarity.
function Pricing.offerValue(offer: Offer, animalValue: ((any) -> number)?): number
	local total = 0
	for key, n in offer.items do
		total += Pricing.value(key) * n
	end
	if offer.animals and animalValue then
		for _, a in offer.animals do
			total += animalValue(a)
		end
	end
	return total
end

-- True when one side is worth at least TRADE_IMBALANCE_WARN times the other.
function Pricing.isImbalanced(a: number, b: number): boolean
	local hi, lo = math.max(a, b), math.min(a, b)
	if hi <= 0 then
		return false
	end
	if lo <= 0 then
		return hi >= 50
	end
	return hi / lo >= Economy.TRADE_IMBALANCE_WARN
end

return Pricing
