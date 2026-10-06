-- Item registry. Every inventory key resolves to one of these definitions
-- (mutated crops resolve to their crop; see Logic/Items).

local Crops = require(script.Parent.Crops)
local Workshops = require(script.Parent.Workshops)

export type Item = {
	id: string,
	kind: string, -- "crop" | "seed" | "product" | "good" | "material" | "special"
	name: { en: string, ar: string },
	value: number, -- reference value in coins (kiosk sell price for most items)
	tier: number,
	trade: boolean, -- may appear in the trade window
	market: boolean, -- may be listed on the global market
	color: { number },
	cropId: string?,
}

local Items = {}
local byId: { [string]: Item } = {}
Items.byId = byId

local function add(item: Item)
	byId[item.id] = item
end

-- Crops and seeds
for _, c in Crops.list do
	add({
		id = c.id,
		kind = "crop",
		name = c.name,
		value = c.sell,
		tier = c.tier,
		trade = c.tier >= 3,
		market = true,
		color = c.color,
		cropId = c.id,
	})
	local seedValue = c.seed or c.sell * 2
	add({
		id = "Seed:" .. c.id,
		kind = "seed",
		name = { en = c.name.en .. " Seed", ar = "بذرة " .. c.name.ar },
		value = math.max(1, math.floor(seedValue / 2)),
		tier = c.tier,
		trade = c.source ~= "shop",
		market = c.source ~= "shop",
		color = c.color,
		cropId = c.id,
	})
end

local function simple(id: string, kind: string, en: string, ar: string, value: number, tier: number, trade: boolean, color: { number })
	add({ id = id, kind = kind, name = { en = en, ar = ar }, value = value, tier = tier, trade = trade, market = true, color = color })
end

-- Animal products
simple("Egg", "product", "Egg", "بيضة", 15, 1, false, { 250, 245, 230 })
simple("DuckEgg", "product", "Duck Egg", "بيضة بط", 25, 2, false, { 210, 230, 220 })
simple("Milk", "product", "Milk", "حليب", 30, 2, false, { 250, 250, 255 })
simple("GoatMilk", "product", "Goat Milk", "حليب ماعز", 35, 2, false, { 245, 245, 235 })
simple("Wool", "product", "Wool", "صوف", 45, 2, false, { 240, 240, 240 })
simple("Truffle", "product", "Truffle", "كمأ", 200, 4, true, { 80, 60, 50 })
simple("Honey_Wildflower", "product", "Wildflower Honey", "عسل الزهور البرية", 40, 2, false, { 230, 170, 40 })
simple("Honey_Clover", "product", "Clover Honey", "عسل البرسيم", 50, 2, false, { 240, 200, 80 })
simple("Honey_Lavender", "product", "Lavender Honey", "عسل اللافندر", 80, 3, true, { 190, 160, 230 })
simple("Honey_Sunflower", "product", "Sunflower Honey", "عسل عباد الشمس", 90, 3, true, { 250, 200, 40 })
simple("Honey_Flax", "product", "Flax Honey", "عسل الكتان", 110, 3, true, { 160, 170, 230 })
simple("Honey_Lotus", "product", "Lotus Honey", "عسل اللوتس", 150, 4, true, { 240, 160, 210 })

-- Exploration finds
simple("Fish", "product", "Fish", "سمك", 20, 1, false, { 120, 160, 200 })
simple("Pearl", "material", "Pearl", "لؤلؤة", 300, 5, true, { 245, 240, 255 })
simple("Wood", "material", "Wood", "خشب", 5, 1, false, { 150, 110, 70 })
simple("Stone", "material", "Stone", "حجر", 6, 1, false, { 150, 150, 150 })
simple("Clay", "material", "Clay", "طين", 6, 1, false, { 190, 120, 90 })
simple("Iron", "material", "Iron", "حديد", 25, 2, false, { 120, 120, 130 })
simple("Gem", "material", "Gem", "جوهرة", 150, 4, true, { 120, 220, 255 })
simple("Fossil", "material", "Fossil", "أحفورة", 250, 5, true, { 220, 210, 180 })

-- Specials (never traded or listed)
add({ id = "FoxToken", kind = "special", name = { en = "Fox Token", ar = "رمز الثعلب" }, value = 0, tier = 3, trade = false, market = false, color = { 240, 120, 40 } })

-- Goods: names here, values derived from recipes below.
local goodNames: { [string]: { en: string, ar: string } } = {
	Flour = { en = "Flour", ar = "دقيق" },
	Cornmeal = { en = "Cornmeal", ar = "دقيق الذرة" },
	RiceFlour = { en = "Rice Flour", ar = "دقيق الأرز" },
	Malt = { en = "Malt", ar = "شعير مملّح" },
	Bread = { en = "Bread", ar = "خبز" },
	Cornbread = { en = "Cornbread", ar = "خبز الذرة" },
	Cake = { en = "Cake", ar = "كعكة" },
	BlueberryPie = { en = "Blueberry Pie", ar = "فطيرة التوت" },
	PumpkinPie = { en = "Pumpkin Pie", ar = "فطيرة اليقطين" },
	StrawberryJuice = { en = "Strawberry Juice", ar = "عصير فراولة" },
	GrapeJuice = { en = "Grape Juice", ar = "عصير عنب" },
	OliveOil = { en = "Olive Oil", ar = "زيت زيتون" },
	Sugar = { en = "Sugar", ar = "سكر" },
	PicnicBasket = { en = "Picnic Basket", ar = "سلة نزهة" },
	RiverSalad = { en = "River Salad", ar = "سلطة النهر" },
	RiceCake = { en = "Rice Cake", ar = "كعكة الأرز" },
	TrufflePasta = { en = "Truffle Pasta", ar = "معكرونة الكمأ" },
	HoneyTea = { en = "Honey Tea", ar = "شاي بالعسل" },
	Butter = { en = "Butter", ar = "زبدة" },
	Cheese = { en = "Cheese", ar = "جبن" },
	GoatCheese = { en = "Goat Cheese", ar = "جبن الماعز" },
	Pot = { en = "Clay Pot", ar = "قدر فخاري" },
	Brick = { en = "Brick", ar = "طوب" },
	Yarn = { en = "Yarn", ar = "غزل" },
	Linen = { en = "Linen", ar = "كتان منسوج" },
	PinkYarn = { en = "Pink Yarn", ar = "غزل وردي" },
	BlueYarn = { en = "Blue Yarn", ar = "غزل أزرق" },
	YellowYarn = { en = "Yellow Yarn", ar = "غزل أصفر" },
}

Items.GOOD_VALUE_FACTOR = 1.4

-- Resolve good values in dependency order (a recipe can use other goods).
local pending = {}
for _, w in Workshops.list do
	for _, rec in w.recipes do
		table.insert(pending, { rec = rec, color = w.color })
	end
end
local guard = 0
while #pending > 0 and guard < 20 do
	guard += 1
	local nextPending = {}
	for _, p in pending do
		local rec = p.rec
		local total = 0
		local ready = true
		for input, count in rec.inputs do
			local def = byId[input]
			if not def then
				ready = false
				break
			end
			total += def.value * count
		end
		if ready then
			if not byId[rec.output] then
				local value = math.floor(total * Items.GOOD_VALUE_FACTOR / rec.amount + 0.5)
				local tier = if value >= 300 then 4 elseif value >= 120 then 3 elseif value >= 40 then 2 else 1
				add({
					id = rec.output,
					kind = "good",
					name = goodNames[rec.output] or { en = rec.output, ar = rec.output },
					value = value,
					tier = tier,
					trade = value >= 150,
					market = rec.output ~= "PicnicBasket",
					color = p.color,
				})
			end
		else
			table.insert(nextPending, p)
		end
	end
	pending = nextPending
end
assert(#pending == 0, "unresolved recipe inputs in Workshops config")

return Items
