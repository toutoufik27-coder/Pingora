-- All crops. Times are in seconds, prices in coins.
-- land = "Any" means no land is native for it (grows at full rate everywhere).
-- source: "shop" (seed shop), "wild" (exploration), "hybrid" (wind
-- cross-pollination), "event" (events only). Non-shop seeds are never sold
-- for Robux.

export type Crop = {
	id: string,
	name: { en: string, ar: string },
	land: string,
	tier: number, -- 1 common .. 6 mythic
	grow: number,
	regrow: number?, -- multi-harvest: seconds between later harvests
	yield: number,
	sell: number, -- coins per unit
	seed: number?, -- seed shop price (nil = not sold)
	level: number, -- unlock level for the seed shop
	source: string,
	color: { number },
	shape: string, -- visual hint for the client: "bush" | "stalk" | "ball" | "tree" | "flower"
}

local function crop(t)
	return t :: Crop
end

local list: { Crop } = {
	-- Any land: starters
	crop({ id = "Carrot", name = { en = "Carrot", ar = "جزر" }, land = "Any", tier = 1, grow = 30, yield = 1, sell = 6, seed = 3, level = 1, source = "shop", color = { 240, 130, 40 }, shape = "stalk" }),
	crop({ id = "Potato", name = { en = "Potato", ar = "بطاطا" }, land = "Any", tier = 1, grow = 60, yield = 2, sell = 5, seed = 5, level = 1, source = "shop", color = { 190, 150, 100 }, shape = "bush" }),
	crop({ id = "Lettuce", name = { en = "Lettuce", ar = "خس" }, land = "Any", tier = 1, grow = 45, yield = 1, sell = 8, seed = 4, level = 2, source = "shop", color = { 140, 210, 90 }, shape = "bush" }),
	crop({ id = "Strawberry", name = { en = "Strawberry", ar = "فراولة" }, land = "Any", tier = 2, grow = 120, regrow = 60, yield = 2, sell = 10, seed = 25, level = 3, source = "shop", color = { 220, 40, 60 }, shape = "bush" }),
	crop({ id = "Tomato", name = { en = "Tomato", ar = "طماطم" }, land = "Any", tier = 2, grow = 150, regrow = 90, yield = 3, sell = 9, seed = 30, level = 4, source = "shop", color = { 230, 60, 40 }, shape = "bush" }),
	crop({ id = "Corn", name = { en = "Corn", ar = "ذرة" }, land = "Any", tier = 2, grow = 240, yield = 4, sell = 9, seed = 35, level = 6, source = "shop", color = { 245, 210, 60 }, shape = "stalk" }),
	crop({ id = "Onion", name = { en = "Onion", ar = "بصل" }, land = "Any", tier = 1, grow = 90, yield = 2, sell = 7, seed = 8, level = 5, source = "shop", color = { 200, 120, 160 }, shape = "ball" }),
	crop({ id = "Pumpkin", name = { en = "Pumpkin", ar = "يقطين" }, land = "Any", tier = 3, grow = 900, yield = 1, sell = 120, seed = 150, level = 10, source = "shop", color = { 240, 140, 30 }, shape = "ball" }),

	-- Meadow
	crop({ id = "Wheat", name = { en = "Wheat", ar = "قمح" }, land = "Meadow", tier = 1, grow = 60, yield = 3, sell = 4, seed = 6, level = 1, source = "shop", color = { 230, 200, 110 }, shape = "stalk" }),
	crop({ id = "Barley", name = { en = "Barley", ar = "شعير" }, land = "Meadow", tier = 2, grow = 180, yield = 4, sell = 7, seed = 20, level = 5, source = "shop", color = { 210, 190, 120 }, shape = "stalk" }),
	crop({ id = "Sunflower", name = { en = "Sunflower", ar = "عباد الشمس" }, land = "Meadow", tier = 2, grow = 300, yield = 2, sell = 30, seed = 45, level = 7, source = "shop", color = { 250, 210, 40 }, shape = "flower" }),
	crop({ id = "Clover", name = { en = "Clover", ar = "برسيم" }, land = "Meadow", tier = 1, grow = 75, yield = 3, sell = 4, seed = 6, level = 3, source = "shop", color = { 90, 180, 80 }, shape = "flower" }),
	crop({ id = "Flax", name = { en = "Flax", ar = "كتان" }, land = "Meadow", tier = 3, grow = 600, yield = 3, sell = 40, seed = 90, level = 12, source = "shop", color = { 120, 140, 220 }, shape = "flower" }),
	crop({ id = "Cabbage", name = { en = "Cabbage", ar = "ملفوف" }, land = "Meadow", tier = 2, grow = 360, yield = 2, sell = 35, seed = 50, level = 9, source = "shop", color = { 150, 200, 120 }, shape = "ball" }),

	-- Riverbank
	crop({ id = "Rice", name = { en = "Rice", ar = "أرز" }, land = "Riverbank", tier = 1, grow = 90, yield = 3, sell = 5, seed = 8, level = 2, source = "shop", color = { 200, 220, 150 }, shape = "stalk" }),
	crop({ id = "Watercress", name = { en = "Watercress", ar = "جرجير الماء" }, land = "Riverbank", tier = 1, grow = 60, yield = 2, sell = 6, seed = 6, level = 3, source = "shop", color = { 70, 160, 90 }, shape = "bush" }),
	crop({ id = "Lotus", name = { en = "Lotus", ar = "لوتس" }, land = "Riverbank", tier = 3, grow = 600, yield = 1, sell = 110, seed = 120, level = 11, source = "shop", color = { 240, 150, 200 }, shape = "flower" }),
	crop({ id = "Cranberry", name = { en = "Cranberry", ar = "توت بري أحمر" }, land = "Riverbank", tier = 2, grow = 240, regrow = 120, yield = 3, sell = 12, seed = 55, level = 8, source = "shop", color = { 180, 20, 50 }, shape = "bush" }),
	crop({ id = "Sugarcane", name = { en = "Sugarcane", ar = "قصب السكر" }, land = "Riverbank", tier = 2, grow = 420, regrow = 240, yield = 3, sell = 14, seed = 70, level = 10, source = "shop", color = { 170, 210, 120 }, shape = "stalk" }),
	crop({ id = "Taro", name = { en = "Taro", ar = "قلقاس" }, land = "Riverbank", tier = 2, grow = 300, yield = 2, sell = 28, seed = 40, level = 6, source = "shop", color = { 140, 110, 160 }, shape = "bush" }),

	-- Hillside
	crop({ id = "Grape", name = { en = "Grape", ar = "عنب" }, land = "Hillside", tier = 2, grow = 300, regrow = 150, yield = 3, sell = 12, seed = 60, level = 5, source = "shop", color = { 120, 50, 140 }, shape = "bush" }),
	crop({ id = "Olive", name = { en = "Olive", ar = "زيتون" }, land = "Hillside", tier = 3, grow = 1200, regrow = 400, yield = 4, sell = 25, seed = 200, level = 9, source = "shop", color = { 110, 130, 60 }, shape = "tree" }),
	crop({ id = "Lavender", name = { en = "Lavender", ar = "لافندر" }, land = "Hillside", tier = 2, grow = 240, yield = 2, sell = 22, seed = 30, level = 4, source = "shop", color = { 150, 120, 220 }, shape = "flower" }),
	crop({ id = "Almond", name = { en = "Almond", ar = "لوز" }, land = "Hillside", tier = 3, grow = 1500, regrow = 500, yield = 4, sell = 30, seed = 260, level = 14, source = "shop", color = { 230, 200, 180 }, shape = "tree" }),
	crop({ id = "Sage", name = { en = "Sage", ar = "مريمية" }, land = "Hillside", tier = 1, grow = 90, yield = 2, sell = 7, seed = 8, level = 3, source = "shop", color = { 140, 170, 140 }, shape = "bush" }),
	crop({ id = "Pepper", name = { en = "Pepper", ar = "فلفل" }, land = "Hillside", tier = 2, grow = 200, regrow = 100, yield = 2, sell = 14, seed = 40, level = 7, source = "shop", color = { 220, 50, 30 }, shape = "bush" }),

	-- Woodland
	crop({ id = "Mushroom", name = { en = "Mushroom", ar = "فطر" }, land = "Woodland", tier = 1, grow = 80, yield = 2, sell = 7, seed = 7, level = 2, source = "shop", color = { 200, 170, 140 }, shape = "ball" }),
	crop({ id = "Blueberry", name = { en = "Blueberry", ar = "توت أزرق" }, land = "Woodland", tier = 2, grow = 240, regrow = 120, yield = 3, sell = 11, seed = 50, level = 6, source = "shop", color = { 60, 80, 200 }, shape = "bush" }),
	crop({ id = "Chestnut", name = { en = "Chestnut", ar = "كستناء" }, land = "Woodland", tier = 3, grow = 1500, regrow = 500, yield = 4, sell = 28, seed = 240, level = 13, source = "shop", color = { 130, 80, 50 }, shape = "tree" }),
	crop({ id = "WildGarlic", name = { en = "Wild Garlic", ar = "ثوم بري" }, land = "Woodland", tier = 1, grow = 70, yield = 2, sell = 6, seed = 6, level = 3, source = "shop", color = { 220, 230, 210 }, shape = "flower" }),
	crop({ id = "Ginseng", name = { en = "Ginseng", ar = "جينسنغ" }, land = "Woodland", tier = 3, grow = 900, yield = 1, sell = 140, seed = 160, level = 12, source = "shop", color = { 210, 180, 120 }, shape = "bush" }),
	crop({ id = "Fiddlehead", name = { en = "Fiddlehead", ar = "سرخس" }, land = "Woodland", tier = 2, grow = 180, yield = 3, sell = 9, seed = 25, level = 5, source = "shop", color = { 100, 160, 70 }, shape = "flower" }),

	-- Wild seeds (exploration only)
	crop({ id = "BlackTomato", name = { en = "Black Tomato", ar = "طماطم سوداء" }, land = "Any", tier = 4, grow = 480, regrow = 240, yield = 3, sell = 60, seed = nil, level = 1, source = "wild", color = { 60, 30, 40 }, shape = "bush" }),
	crop({ id = "AncientWheat", name = { en = "Ancient Wheat", ar = "قمح قديم" }, land = "Meadow", tier = 4, grow = 600, yield = 4, sell = 55, seed = nil, level = 1, source = "wild", color = { 200, 150, 70 }, shape = "stalk" }),
	crop({ id = "WildStrawberry", name = { en = "Wild Strawberry", ar = "فراولة برية" }, land = "Woodland", tier = 4, grow = 360, regrow = 180, yield = 2, sell = 70, seed = nil, level = 1, source = "wild", color = { 250, 80, 100 }, shape = "bush" }),

	-- Hybrids (wind cross-pollination between neighbours)
	crop({ id = "Sunberry", name = { en = "Sunberry", ar = "توت الشمس" }, land = "Any", tier = 5, grow = 600, regrow = 300, yield = 3, sell = 150, seed = nil, level = 1, source = "hybrid", color = { 255, 170, 60 }, shape = "bush" }),
	crop({ id = "Moonrice", name = { en = "Moonrice", ar = "أرز القمر" }, land = "Riverbank", tier = 5, grow = 720, yield = 4, sell = 130, seed = nil, level = 1, source = "hybrid", color = { 200, 210, 255 }, shape = "stalk" }),
	crop({ id = "Dreamclover", name = { en = "Dreamclover", ar = "برسيم الأحلام" }, land = "Meadow", tier = 5, grow = 540, yield = 3, sell = 140, seed = nil, level = 1, source = "hybrid", color = { 190, 140, 255 }, shape = "flower" }),
	crop({ id = "RubyGrape", name = { en = "Ruby Grape", ar = "عنب الياقوت" }, land = "Hillside", tier = 5, grow = 900, regrow = 400, yield = 3, sell = 180, seed = nil, level = 1, source = "hybrid", color = { 200, 20, 80 }, shape = "bush" }),
	crop({ id = "Glowcap", name = { en = "Glowcap", ar = "فطر مضيء" }, land = "Woodland", tier = 5, grow = 720, yield = 2, sell = 220, seed = nil, level = 1, source = "hybrid", color = { 120, 255, 200 }, shape = "ball" }),

	-- Event only
	crop({ id = "GiantPumpkin", name = { en = "Giant Pumpkin", ar = "يقطين عملاق" }, land = "Any", tier = 6, grow = 1800, yield = 1, sell = 900, seed = nil, level = 1, source = "event", color = { 255, 120, 0 }, shape = "ball" }),
	crop({ id = "Starfruit", name = { en = "Starfruit", ar = "فاكهة النجمة" }, land = "Any", tier = 6, grow = 1200, regrow = 600, yield = 2, sell = 600, seed = nil, level = 1, source = "event", color = { 255, 240, 120 }, shape = "tree" }),
}

local Crops = {
	list = list,
	byId = {} :: { [string]: Crop },
	tierNames = {
		{ en = "Common", ar = "عادي" },
		{ en = "Uncommon", ar = "غير شائع" },
		{ en = "Rare", ar = "نادر" },
		{ en = "Epic", ar = "ملحمي" },
		{ en = "Legendary", ar = "أسطوري" },
		{ en = "Mythic", ar = "خرافي" },
	},
	-- Hybrid recipes: when the wind blows, a farmer growing `a` next to a
	-- neighbour growing `b` (or the reverse) may receive a `result` seed.
	hybrids = {
		{ a = "Sunflower", b = "Blueberry", result = "Sunberry" },
		{ a = "Rice", b = "Lotus", result = "Moonrice" },
		{ a = "Clover", b = "Lavender", result = "Dreamclover" },
		{ a = "Grape", b = "Cranberry", result = "RubyGrape" },
		{ a = "Mushroom", b = "Sage", result = "Glowcap" },
	},
}

for _, c in list do
	Crops.byId[c.id] = c
end

return Crops
