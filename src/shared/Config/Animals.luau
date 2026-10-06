-- Animals: products, jobs, colours and traits. Breeding and egg hatching use
-- the odds in Logic/Breeding, and those odds are always shown to the player.

export type Species = {
	id: string,
	name: { en: string, ar: string },
	price: number,
	level: number,
	product: string?, -- item id produced
	interval: number?, -- seconds between products when fed
	amount: number?,
	food: { string }?, -- crop ids it accepts as feed
	job: string?, -- "collector" | "clearer" | "truffle" | "pollinator" | "lucky" | "rider"
	colors: { { id: string, rarity: number, rgb: { number } } }, -- rarity 1..6
	size: number,
}

local Animals = {}

Animals.species = {
	Chicken = {
		id = "Chicken",
		name = { en = "Chicken", ar = "دجاجة" },
		price = 200,
		level = 2,
		product = "Egg",
		interval = 120,
		amount = 1,
		food = { "Wheat", "Corn", "Barley" },
		colors = {
			{ id = "White", rarity = 1, rgb = { 245, 245, 240 } },
			{ id = "Brown", rarity = 1, rgb = { 150, 100, 60 } },
			{ id = "Black", rarity = 2, rgb = { 40, 40, 45 } },
			{ id = "Speckled", rarity = 3, rgb = { 200, 190, 170 } },
			{ id = "Golden", rarity = 5, rgb = { 255, 210, 60 } },
			{ id = "Rainbow", rarity = 6, rgb = { 255, 120, 220 } },
		},
		size = 1.5,
	},
	Duck = {
		id = "Duck",
		name = { en = "Duck", ar = "بطة" },
		price = 350,
		level = 4,
		product = "DuckEgg",
		interval = 180,
		amount = 1,
		food = { "Rice", "Watercress" },
		colors = {
			{ id = "White", rarity = 1, rgb = { 250, 250, 250 } },
			{ id = "Mallard", rarity = 2, rgb = { 60, 120, 70 } },
			{ id = "Blue", rarity = 3, rgb = { 90, 130, 200 } },
			{ id = "Golden", rarity = 5, rgb = { 255, 210, 60 } },
		},
		size = 1.5,
	},
	Cow = {
		id = "Cow",
		name = { en = "Cow", ar = "بقرة" },
		price = 600,
		level = 5,
		product = "Milk",
		interval = 240,
		amount = 1,
		food = { "Clover", "Wheat", "Barley", "Corn" },
		colors = {
			{ id = "Spotted", rarity = 1, rgb = { 240, 240, 240 } },
			{ id = "Brown", rarity = 1, rgb = { 130, 80, 50 } },
			{ id = "Highland", rarity = 3, rgb = { 190, 110, 60 } },
			{ id = "Chocolate", rarity = 4, rgb = { 80, 45, 30 } },
			{ id = "Moon", rarity = 6, rgb = { 200, 210, 255 } },
		},
		size = 3,
	},
	Goat = {
		id = "Goat",
		name = { en = "Goat", ar = "ماعز" },
		price = 700,
		level = 6,
		product = "GoatMilk",
		interval = 240,
		amount = 1,
		food = { "Clover", "Barley", "Sage" },
		job = "clearer",
		colors = {
			{ id = "White", rarity = 1, rgb = { 240, 235, 225 } },
			{ id = "Grey", rarity = 1, rgb = { 150, 150, 150 } },
			{ id = "Mountain", rarity = 4, rgb = { 110, 90, 70 } },
			{ id = "Golden", rarity = 5, rgb = { 255, 210, 60 } },
		},
		size = 2,
	},
	Sheep = {
		id = "Sheep",
		name = { en = "Sheep", ar = "خروف" },
		price = 800,
		level = 7,
		product = "Wool",
		interval = 300,
		amount = 1,
		food = { "Clover", "Wheat" },
		colors = {
			{ id = "White", rarity = 1, rgb = { 245, 245, 240 } },
			{ id = "Black", rarity = 2, rgb = { 45, 45, 50 } },
			{ id = "Cream", rarity = 2, rgb = { 240, 225, 190 } },
			{ id = "Pink", rarity = 4, rgb = { 250, 170, 200 } },
			{ id = "Sky", rarity = 5, rgb = { 150, 200, 255 } },
			{ id = "Rainbow", rarity = 6, rgb = { 255, 120, 220 } },
		},
		size = 2,
	},
	Rabbit = {
		id = "Rabbit",
		name = { en = "Rabbit", ar = "أرنب" },
		price = 900,
		level = 8,
		product = "Truffle", -- digs up truffles
		interval = 600,
		amount = 1,
		food = { "Carrot", "Clover", "Mushroom" },
		job = "truffle",
		colors = {
			{ id = "White", rarity = 1, rgb = { 245, 245, 240 } },
			{ id = "Brown", rarity = 1, rgb = { 150, 110, 75 } },
			{ id = "Spotted", rarity = 2, rgb = { 230, 215, 200 } },
			{ id = "Black", rarity = 3, rgb = { 50, 45, 45 } },
			{ id = "Golden", rarity = 5, rgb = { 255, 210, 60 } },
		},
		size = 1.3,
	},
	Bee = {
		id = "Bee",
		name = { en = "Beehive", ar = "خلية نحل" },
		price = 1000,
		level = 8,
		product = "Honey", -- the honey flavour depends on nearby flowers
		interval = 300,
		amount = 1,
		food = nil,
		job = "pollinator",
		colors = {
			{ id = "Honey", rarity = 1, rgb = { 240, 180, 40 } },
			{ id = "Wild", rarity = 3, rgb = { 120, 90, 40 } },
			{ id = "Royal", rarity = 5, rgb = { 160, 60, 200 } },
		},
		size = 1.5,
	},
	Dog = {
		id = "Dog",
		name = { en = "Dog", ar = "كلب" },
		price = 500,
		level = 1,
		job = "collector",
		colors = {
			{ id = "Golden", rarity = 1, rgb = { 220, 170, 90 } },
			{ id = "Brown", rarity = 1, rgb = { 120, 80, 50 } },
			{ id = "Black", rarity = 2, rgb = { 40, 40, 40 } },
			{ id = "Spotted", rarity = 3, rgb = { 240, 240, 240 } },
			{ id = "Silver", rarity = 5, rgb = { 200, 200, 210 } },
		},
		size = 1.8,
	},
	Cat = {
		id = "Cat",
		name = { en = "Cat", ar = "قط" },
		price = 600,
		level = 4,
		job = "lucky",
		colors = {
			{ id = "Ginger", rarity = 1, rgb = { 230, 140, 60 } },
			{ id = "Tabby", rarity = 1, rgb = { 150, 130, 110 } },
			{ id = "Black", rarity = 2, rgb = { 35, 35, 40 } },
			{ id = "Calico", rarity = 3, rgb = { 240, 220, 200 } },
			{ id = "Moon", rarity = 6, rgb = { 200, 210, 255 } },
		},
		size = 1.4,
	},
	Horse = {
		id = "Horse",
		name = { en = "Horse", ar = "حصان" },
		price = 2500,
		level = 10,
		food = { "Carrot" },
		job = "rider",
		colors = {
			{ id = "Bay", rarity = 1, rgb = { 120, 70, 40 } },
			{ id = "White", rarity = 2, rgb = { 240, 240, 235 } },
			{ id = "Black", rarity = 2, rgb = { 30, 30, 35 } },
			{ id = "Palomino", rarity = 4, rgb = { 230, 190, 110 } },
			{ id = "Starlight", rarity = 6, rgb = { 220, 220, 255 } },
		},
		size = 3.5,
	},
} :: { [string]: Species }

Animals.order = { "Dog", "Chicken", "Duck", "Cat", "Cow", "Goat", "Sheep", "Rabbit", "Bee", "Horse" }

Animals.traits = {
	Productive = { id = "Productive", name = { en = "Productive", ar = "منتج" }, desc = { en = "+25% products", ar = "+25% منتجات" } },
	Swift = { id = "Swift", name = { en = "Swift", ar = "سريع" }, desc = { en = "Produces 20% faster", ar = "ينتج أسرع بـ 20%" } },
	Lucky = { id = "Lucky", name = { en = "Lucky", ar = "محظوظ" }, desc = { en = "+1% mutation chance on your farm", ar = "+1% فرصة طفرات في مزرعتك" } },
	Charming = { id = "Charming", name = { en = "Charming", ar = "جذاب" }, desc = { en = "Neighbours who visit get a small gift from it", ar = "الجيران الزائرون يحصلون منه على هدية صغيرة" } },
}
Animals.traitOrder = { "Productive", "Swift", "Lucky", "Charming" }

-- Which flowers flavour honey. The most common one within reach of the hive
-- (your farm and the farms next to it) decides the honey you get.
Animals.honeyFlowers = {
	Clover = "Honey_Clover",
	Lavender = "Honey_Lavender",
	Sunflower = "Honey_Sunflower",
	Lotus = "Honey_Lotus",
	Flax = "Honey_Flax",
}
Animals.DEFAULT_HONEY = "Honey_Wildflower"

Animals.MAX_PER_FARM = 24
Animals.MAX_COMPANIONS = 3
Animals.BREED_SECONDS = 600
Animals.HATCH_SECONDS = 300
Animals.FED_WINDOW = 2 -- an animal stays fed for interval * FED_WINDOW seconds

return Animals
