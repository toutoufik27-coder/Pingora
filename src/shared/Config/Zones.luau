-- Exploration zones. Entering costs one Picnic Basket and gives a trip of
-- TRIP_SECONDS. Zones are built far from the valley in the same place.

export type Drop = { item: string, min: number, max: number, chance: number }
export type NodeType = {
	id: string,
	name: { en: string, ar: string },
	color: { number },
	shape: string, -- "tree" | "rock" | "bush" | "water" | "mound" | "crystal"
	cooldown: number, -- per player, seconds
	drops: { Drop },
}
export type Zone = {
	id: string,
	name: { en: string, ar: string },
	level: number,
	deed: string?, -- project deed required
	locked: boolean?, -- arrives in a later season
	origin: { number }, -- world position of the zone centre
	ground: { number },
	nodes: { [string]: number }, -- node type -> count
	wild: { string }?, -- wild animals that can be tamed here
}

local Zones = {}

Zones.TRIP_SECONDS = 300
Zones.ENTRY_ITEM = "PicnicBasket"

Zones.nodeTypes = {
	Tree = {
		id = "Tree",
		name = { en = "Tree", ar = "شجرة" },
		color = { 70, 130, 60 },
		shape = "tree",
		cooldown = 90,
		drops = { { item = "Wood", min = 2, max = 4, chance = 1 } },
	},
	BerryBush = {
		id = "BerryBush",
		name = { en = "Wild Bush", ar = "شجيرة برية" },
		color = { 160, 60, 90 },
		shape = "bush",
		cooldown = 120,
		drops = {
			{ item = "Seed:WildStrawberry", min = 1, max = 1, chance = 0.04 },
			{ item = "Seed:BlackTomato", min = 1, max = 1, chance = 0.03 },
			{ item = "Blueberry", min = 1, max = 3, chance = 0.6 },
		},
	},
	Mushrooms = {
		id = "Mushrooms",
		name = { en = "Mushrooms", ar = "فطر" },
		color = { 210, 170, 130 },
		shape = "mound",
		cooldown = 90,
		drops = {
			{ item = "Mushroom", min = 2, max = 4, chance = 1 },
			{ item = "Truffle", min = 1, max = 1, chance = 0.03 },
		},
	},
	FishingSpot = {
		id = "FishingSpot",
		name = { en = "Fishing Spot", ar = "مكان صيد" },
		color = { 80, 150, 220 },
		shape = "water",
		cooldown = 45,
		drops = {
			{ item = "Fish", min = 1, max = 2, chance = 0.9 },
			{ item = "Pearl", min = 1, max = 1, chance = 0.02 },
		},
	},
	ClayBank = {
		id = "ClayBank",
		name = { en = "Clay Bank", ar = "ضفة طينية" },
		color = { 180, 110, 80 },
		shape = "mound",
		cooldown = 90,
		drops = { { item = "Clay", min = 2, max = 4, chance = 1 } },
	},
	Reeds = {
		id = "Reeds",
		name = { en = "Reeds", ar = "قصب" },
		color = { 150, 180, 100 },
		shape = "bush",
		cooldown = 120,
		drops = {
			{ item = "Seed:Lotus", min = 1, max = 1, chance = 0.08 },
			{ item = "Watercress", min = 2, max = 3, chance = 0.8 },
		},
	},
	Rock = {
		id = "Rock",
		name = { en = "Rock", ar = "صخرة" },
		color = { 140, 140, 140 },
		shape = "rock",
		cooldown = 90,
		drops = {
			{ item = "Stone", min = 2, max = 4, chance = 1 },
			{ item = "Iron", min = 1, max = 1, chance = 0.25 },
			{ item = "Gem", min = 1, max = 1, chance = 0.02 },
		},
	},
	AlpineHerbs = {
		id = "AlpineHerbs",
		name = { en = "Alpine Herbs", ar = "أعشاب جبلية" },
		color = { 120, 170, 140 },
		shape = "bush",
		cooldown = 150,
		drops = {
			{ item = "Sage", min = 2, max = 3, chance = 0.8 },
			{ item = "Seed:AncientWheat", min = 1, max = 1, chance = 0.05 },
			{ item = "Fossil", min = 1, max = 1, chance = 0.01 },
		},
	},
} :: { [string]: NodeType }

Zones.list = {
	{
		id = "Forest",
		name = { en = "Whispering Forest", ar = "الغابة الهامسة" },
		level = 1,
		origin = { 1200, 0, 0 },
		ground = { 70, 110, 60 },
		nodes = { Tree = 14, BerryBush = 8, Mushrooms = 8 },
		wild = { "Rabbit", "Dog" },
	},
	{
		id = "River",
		name = { en = "River Rapids", ar = "شلالات النهر" },
		level = 5,
		origin = { 0, 0, 1200 },
		ground = { 90, 140, 110 },
		nodes = { FishingSpot = 10, ClayBank = 8, Reeds = 8 },
		wild = { "Duck" },
	},
	{
		id = "Mountain",
		name = { en = "Cloud Mountain", ar = "جبل السحاب" },
		level = 8,
		deed = "Bridge",
		origin = { -1200, 0, 0 },
		ground = { 130, 125, 115 },
		nodes = { Rock = 16, AlpineHerbs = 8, Tree = 4 },
		wild = { "Goat" },
	},
	{
		id = "Caves",
		name = { en = "Crystal Caves", ar = "الكهوف البلورية" },
		level = 20,
		locked = true,
		origin = { 0, 0, -1200 },
		ground = { 60, 60, 80 },
		nodes = {},
	},
} :: { Zone }

Zones.byId = {} :: { [string]: Zone }
for _, z in Zones.list do
	Zones.byId[z.id] = z
end

-- Taming: chance per offering of the right food while on a trip.
Zones.TAME_CHANCE = 0.25
Zones.TAME_FOOD = {
	Rabbit = "Mushroom",
	Dog = "Carrot",
	Duck = "Rice",
	Goat = "Sage",
}

return Zones
