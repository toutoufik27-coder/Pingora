local Weather = require(script.Parent.Parent.Config.Weather)

local Mutations = {}

function Mutations.has(list: { string }?, id: string): boolean
	if not list then
		return false
	end
	for _, m in list do
		if m == id then
			return true
		end
	end
	return false
end

-- Adds a mutation if it is new and there is room. Returns true if added.
function Mutations.add(list: { string }, id: string): boolean
	if #list >= Weather.MAX_MUTATIONS or Mutations.has(list, id) then
		return false
	end
	table.insert(list, id)
	return true
end

-- One weather tick for one crop. `chance` already includes land and luck bonuses.
function Mutations.weatherRoll(list: { string }, mutationId: string, chance: number, rng: () -> number): boolean
	if rng() < chance then
		return Mutations.add(list, mutationId)
	end
	return false
end

-- Chance for a crop on a given land during a given weather.
function Mutations.chanceFor(weatherId: string, landBonusWeather: string?, luck: number?): number
	local c = Weather.BASE_CHANCE
	if landBonusWeather == weatherId then
		c *= 2
	end
	return c + (luck or 0)
end

-- Growth mutations rolled at harvest (independent of weather).
function Mutations.growthRoll(list: { string }, rng: () -> number, luck: number?)
	for _, g in Weather.GROWTH_MUTATIONS do
		if rng() < g.chance + (luck or 0) * 0.2 then
			Mutations.add(list, g.id)
		end
	end
end

-- How many guaranteed mutations a returning player gets.
function Mutations.keptScaleCount(secondsAway: number, secondsPer: number): number
	if secondsAway <= 0 then
		return 0
	end
	return math.min(Weather.KEPT_SCALE_MAX, math.floor(secondsAway / secondsPer))
end

function Mutations.keptScalePick(rng: () -> number): string
	local pool = Weather.KEPT_SCALE_POOL
	return pool[math.clamp(math.floor(rng() * #pool) + 1, 1, #pool)]
end

return Mutations
