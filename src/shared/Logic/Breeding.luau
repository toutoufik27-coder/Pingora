-- Breeding and hatching odds. The odds tables are shown to the player before
-- they breed or hatch, so this module is the single source of truth.

local Animals = require(script.Parent.Parent.Config.Animals)

local Breeding = {}

export type Odds = { { color: string, chance: number } }

local function colorDef(speciesId: string, colorId: string)
	for _, c in Animals.species[speciesId].colors do
		if c.id == colorId then
			return c
		end
	end
	return nil
end
Breeding.colorDef = colorDef

local function addTo(map: { [string]: number }, order: { string }, id: string, p: number)
	if p <= 0 then
		return
	end
	if map[id] == nil then
		map[id] = 0
		table.insert(order, id)
	end
	map[id] += p
end

local function spread(map, order, speciesId: string, total: number, filter: (number) -> boolean)
	local colors = Animals.species[speciesId].colors
	local weights, sum = {}, 0
	for _, c in colors do
		if filter(c.rarity) then
			local w = 1 / (2 ^ (c.rarity - 1))
			weights[c.id] = w
			sum += w
		end
	end
	if sum == 0 then
		return false
	end
	for _, c in colors do
		local w = weights[c.id]
		if w then
			addTo(map, order, c.id, total * w / sum)
		end
	end
	return true
end

local function finish(map, order): Odds
	local out = {}
	for _, id in order do
		table.insert(out, { color = id, chance = map[id] })
	end
	table.sort(out, function(a, b)
		return a.chance > b.chance
	end)
	return out
end

-- Baby colour odds from two parents of the same species.
function Breeding.breedOdds(speciesId: string, colorA: string, colorB: string): Odds
	local map, order = {}, {}
	addTo(map, order, colorA, 0.45)
	addTo(map, order, colorB, 0.45)
	spread(map, order, speciesId, 0.09, function()
		return true
	end)
	if not spread(map, order, speciesId, 0.01, function(r)
		return r >= 5
	end) then
		addTo(map, order, colorA, 0.01)
	end
	return finish(map, order)
end

-- Chick colour odds when hatching an egg laid by a hen of `parentColor`.
function Breeding.hatchOdds(speciesId: string, parentColor: string): Odds
	local map, order = {}, {}
	addTo(map, order, parentColor, 0.6)
	spread(map, order, speciesId, 0.35, function(r)
		return r <= 2
	end)
	if not spread(map, order, speciesId, 0.05, function(r)
		return r >= 4
	end) then
		addTo(map, order, parentColor, 0.05)
	end
	return finish(map, order)
end

-- Colour odds for an animal bought from the shop: common colours only.
function Breeding.shopOdds(speciesId: string): Odds
	local map, order = {}, {}
	spread(map, order, speciesId, 1, function(r)
		return r <= 2
	end)
	return finish(map, order)
end

function Breeding.pick(odds: Odds, rng: () -> number): string
	local roll = rng()
	for _, o in odds do
		roll -= o.chance
		if roll < 0 then
			return o.color
		end
	end
	return odds[#odds].color
end

-- Each parent trait passes on with 50%; 5% chance of a brand-new trait.
-- An animal carries at most 2 traits.
function Breeding.inheritTraits(a: { string }, b: { string }, rng: () -> number): { string }
	local out, seen = {}, {}
	local function try(t: string)
		if not seen[t] and #out < 2 then
			seen[t] = true
			table.insert(out, t)
		end
	end
	for _, t in a do
		if rng() < 0.5 then
			try(t)
		end
	end
	for _, t in b do
		if rng() < 0.5 then
			try(t)
		end
	end
	if rng() < 0.05 then
		local order = Animals.traitOrder
		try(order[math.clamp(math.floor(rng() * #order) + 1, 1, #order)])
	end
	return out
end

function Breeding.randomTraits(rng: () -> number): { string }
	if rng() < 0.3 then
		local order = Animals.traitOrder
		return { order[math.clamp(math.floor(rng() * #order) + 1, 1, #order)] }
	end
	return {}
end

-- Rough coin value of an animal, used for trade balance warnings.
function Breeding.value(animal: { species: string, color: string, traits: { string }? }): number
	local s = Animals.species[animal.species]
	if not s then
		return 0
	end
	local c = colorDef(animal.species, animal.color)
	local rarity = if c then c.rarity else 1
	return math.floor(s.price * (1 + (rarity - 1) * 0.75) * (1 + 0.25 * #(animal.traits or {})))
end

return Breeding
