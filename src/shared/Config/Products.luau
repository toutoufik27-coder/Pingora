-- Robux products. Set the ids after creating the passes/products on the
-- Creator Dashboard. An id of 0 disables the product in game.
-- Nothing here sells seeds, random items, power, or anything that affects
-- another player.

local Products = {}

Products.passes = {
	Farmhand = {
		id = 0,
		price = 399,
		name = { en = "Farmhand", ar = "العامل المساعد" },
		desc = { en = "Auto-replants harvested tiles with the same seed", ar = "يعيد زرع المربعات المحصودة بنفس البذرة تلقائيًا" },
	},
	ExtraQueue = {
		id = 0,
		price = 249,
		name = { en = "Extra Queue", ar = "طابور إضافي" },
		desc = { en = "+1 queue slot in every workshop", ar = "+1 خانة في كل ورشة" },
	},
	BuilderPack = {
		id = 0,
		price = 299,
		name = { en = "Builder Pack", ar = "حزمة البنّاء" },
		desc = { en = "Unlocks farm themes and fence styles", ar = "يفتح ثيمات المزرعة وأشكال السياج" },
	},
}

Products.devProducts = {
	ValleyGift = {
		id = 0,
		price = 99,
		name = { en = "Valley Gift", ar = "هدية الوادي" },
		desc = { en = "Fireworks and a small gift for everyone in the server", ar = "ألعاب نارية وهدية صغيرة لكل من في السيرفر" },
	},
	SkipWorkshop = {
		id = 0,
		price = 25,
		name = { en = "Finish Workshop Job", ar = "إنهاء مهمة ورشة" },
		desc = { en = "Finishes one workshop job now (3 per day)", ar = "ينهي مهمة ورشة واحدة الآن (3 يوميًا)" },
	},
}

-- Farm themes unlocked by BuilderPack (purely visual).
Products.themes = {
	{ id = "Classic", name = { en = "Classic", ar = "كلاسيكي" }, fence = { 150, 110, 70 }, path = { 200, 180, 140 }, free = true },
	{ id = "Blossom", name = { en = "Blossom", ar = "أزهار" }, fence = { 240, 170, 200 }, path = { 250, 220, 230 } },
	{ id = "Desert", name = { en = "Oasis", ar = "واحة" }, fence = { 210, 160, 100 }, path = { 230, 200, 150 } },
	{ id = "Winter", name = { en = "Winter", ar = "شتوي" }, fence = { 200, 220, 240 }, path = { 240, 245, 250 } },
	{ id = "Zen", name = { en = "Zen", ar = "زِن" }, fence = { 60, 60, 60 }, path = { 180, 180, 170 } },
	-- earned at a Legacy level, never sold
	{ id = "Legacy", name = { en = "Golden Legacy", ar = "الإرث الذهبي" }, fence = { 230, 190, 60 }, path = { 245, 225, 160 }, legacy = true },
}

return Products
