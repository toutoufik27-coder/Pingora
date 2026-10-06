-- Workshops and their recipes. Many valuable recipes need ingredients from a
-- land other than yours, so trading with neighbours matters.

export type Recipe = {
	id: string,
	output: string,
	amount: number,
	inputs: { [string]: number },
	time: number,
	level: number,
}

export type Workshop = {
	id: string,
	name: { en: string, ar: string },
	price: number,
	level: number,
	slots: number,
	color: { number },
	recipes: { Recipe },
}

local function r(id: string, output: string, amount: number, inputs: { [string]: number }, time: number, level: number): Recipe
	return { id = id, output = output, amount = amount, inputs = inputs, time = time, level = level }
end

local Workshops = {}

Workshops.list = {
	{
		id = "Mill",
		name = { en = "Mill", ar = "طاحونة" },
		price = 300,
		level = 3,
		slots = 2,
		color = { 200, 170, 120 },
		recipes = {
			r("Flour", "Flour", 1, { Wheat = 3 }, 60, 3),
			r("Cornmeal", "Cornmeal", 1, { Corn = 2 }, 90, 6),
			r("RiceFlour", "RiceFlour", 1, { Rice = 3 }, 90, 5),
			r("Malt", "Malt", 1, { Barley = 3 }, 120, 6),
		},
	},
	{
		id = "Bakery",
		name = { en = "Bakery", ar = "مخبز" },
		price = 800,
		level = 4,
		slots = 2,
		color = { 220, 150, 100 },
		recipes = {
			r("Bread", "Bread", 1, { Flour = 2 }, 120, 4),
			r("Cornbread", "Cornbread", 1, { Cornmeal = 2, Egg = 1 }, 180, 7),
			r("Cake", "Cake", 1, { Flour = 2, Egg = 1, Milk = 1 }, 300, 8),
			r("BlueberryPie", "BlueberryPie", 1, { Flour = 2, Blueberry = 3 }, 300, 9),
			r("PumpkinPie", "PumpkinPie", 1, { Pumpkin = 1, Sugar = 1, Egg = 1 }, 400, 12),
		},
	},
	{
		id = "Press",
		name = { en = "Press", ar = "معصرة" },
		price = 1200,
		level = 5,
		slots = 2,
		color = { 150, 110, 160 },
		recipes = {
			r("StrawberryJuice", "StrawberryJuice", 1, { Strawberry = 3 }, 90, 5),
			r("GrapeJuice", "GrapeJuice", 1, { Grape = 3 }, 120, 6),
			r("OliveOil", "OliveOil", 1, { Olive = 4 }, 240, 10),
			r("Sugar", "Sugar", 1, { Sugarcane = 3 }, 120, 10),
		},
	},
	{
		id = "Kitchen",
		name = { en = "Kitchen", ar = "مطبخ" },
		price = 1500,
		level = 6,
		slots = 2,
		color = { 240, 200, 160 },
		recipes = {
			r("PicnicBasket", "PicnicBasket", 1, { Bread = 1, StrawberryJuice = 1 }, 60, 6),
			r("PicnicBasketGrape", "PicnicBasket", 1, { Bread = 1, GrapeJuice = 1 }, 60, 6),
			r("RiverSalad", "RiverSalad", 1, { Watercress = 2, Tomato = 2, OliveOil = 1 }, 180, 10),
			r("RiceCake", "RiceCake", 1, { RiceFlour = 2, Milk = 1, Sugar = 1 }, 240, 11),
			r("TrufflePasta", "TrufflePasta", 1, { Flour = 2, Truffle = 1, OliveOil = 1 }, 600, 13),
			r("HoneyTea", "HoneyTea", 1, { Sage = 2, Honey_Lavender = 1 }, 180, 10),
		},
	},
	{
		id = "Dairy",
		name = { en = "Dairy", ar = "ملبنة" },
		price = 2000,
		level = 8,
		slots = 2,
		color = { 240, 240, 230 },
		recipes = {
			r("Butter", "Butter", 1, { Milk = 2 }, 120, 8),
			r("Cheese", "Cheese", 1, { Milk = 2, Sage = 1 }, 300, 9),
			r("GoatCheese", "GoatCheese", 1, { GoatMilk = 2 }, 300, 9),
		},
	},
	{
		id = "Kiln",
		name = { en = "Kiln", ar = "فرن الفخار" },
		price = 3000,
		level = 9,
		slots = 2,
		color = { 170, 90, 60 },
		recipes = {
			r("Pot", "Pot", 1, { Clay = 3 }, 180, 9),
			r("Brick", "Brick", 1, { Clay = 2, Stone = 1 }, 180, 9),
		},
	},
	{
		id = "Loom",
		name = { en = "Loom", ar = "نول" },
		price = 2500,
		level = 10,
		slots = 2,
		color = { 200, 180, 220 },
		recipes = {
			r("Yarn", "Yarn", 1, { Wool = 2 }, 180, 10),
			r("Linen", "Linen", 1, { Flax = 3 }, 240, 12),
		},
	},
	{
		id = "DyeWorks",
		name = { en = "Dye Works", ar = "مصبغة" },
		price = 4000,
		level = 12,
		slots = 2,
		color = { 120, 160, 220 },
		recipes = {
			r("PinkYarn", "PinkYarn", 1, { Yarn = 1, Lotus = 1 }, 180, 12),
			r("BlueYarn", "BlueYarn", 1, { Yarn = 1, Blueberry = 2 }, 180, 12),
			r("YellowYarn", "YellowYarn", 1, { Yarn = 1, Sunflower = 1 }, 180, 12),
		},
	},
} :: { Workshop }

Workshops.byId = {} :: { [string]: Workshop }
Workshops.recipeById = {} :: { [string]: Recipe }
Workshops.recipeWorkshop = {} :: { [string]: string }
for _, w in Workshops.list do
	Workshops.byId[w.id] = w
	for _, rec in w.recipes do
		Workshops.recipeById[rec.id] = rec
		Workshops.recipeWorkshop[rec.id] = w.id
	end
end

return Workshops
