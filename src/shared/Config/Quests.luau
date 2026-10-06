-- Daily quests and the story chain. Quest progress is driven by gameplay
-- events emitted on the server (see Server/Services/QuestService).
--
-- Event names: "harvest", "harvestCrop:<id>", "sell" (coins), "glean",
-- "waterNeighbour", "craft", "collectAnimal", "explore", "contribute",
-- "trade", "plant", "mutation", "buyAnimal", "buyWorkshop", "chooseLand".

export type QuestDef = {
	id: string,
	event: string,
	target: number,
	text: { en: string, ar: string }, -- "{n}" is replaced by the target
	coins: number,
	xp: number,
	level: number?,
}

local Quests = {}

Quests.DAILY_COUNT = 3

Quests.dailyPool = {
	{ id = "harvest40", event = "harvest", target = 40, text = { en = "Harvest {n} crops", ar = "احصد {n} محصولًا" }, coins = 120, xp = 40 },
	{ id = "sell500", event = "sell", target = 500, text = { en = "Earn {n} coins selling", ar = "اربح {n} عملة من البيع" }, coins = 100, xp = 40 },
	{ id = "glean5", event = "glean", target = 5, text = { en = "Glean from neighbours {n} times", ar = "التقط من جيرانك {n} مرات" }, coins = 150, xp = 50 },
	{ id = "water10", event = "waterNeighbour", target = 10, text = { en = "Water neighbours' crops {n} times", ar = "اسقِ محاصيل جيرانك {n} مرات" }, coins = 120, xp = 50 },
	{ id = "craft5", event = "craft", target = 5, text = { en = "Make {n} goods in workshops", ar = "اصنع {n} سلع في الورش" }, coins = 150, xp = 60, level = 4 },
	{ id = "collect10", event = "collectAnimal", target = 10, text = { en = "Collect {n} animal products", ar = "اجمع {n} من منتجات الحيوانات" }, coins = 150, xp = 60, level = 3 },
	{ id = "explore1", event = "explore", target = 1, text = { en = "Go on {n} trip", ar = "اذهب في {n} رحلة" }, coins = 120, xp = 50, level = 6 },
	{ id = "contribute20", event = "contribute", target = 20, text = { en = "Give {n} items to the valley project", ar = "قدّم {n} غرضًا لمشروع الوادي" }, coins = 160, xp = 60 },
	{ id = "mutation3", event = "mutation", target = 3, text = { en = "Grow {n} mutated crops", ar = "ازرع {n} محاصيل متحوّرة" }, coins = 140, xp = 50 },
	{ id = "trade1", event = "trade", target = 1, text = { en = "Complete {n} trade", ar = "أكمل {n} تبادل" }, coins = 150, xp = 60, level = 8 },
} :: { QuestDef }

-- Story quests run in order and teach the systems.
Quests.story = {
	{ id = "s1", event = "harvest", target = 3, text = { en = "Harvest {n} ripe crops", ar = "احصد {n} محاصيل ناضجة" }, coins = 20, xp = 10 },
	{ id = "s2", event = "sell", target = 20, text = { en = "Sell crops at the kiosk", ar = "بِع المحاصيل في الكشك" }, coins = 20, xp = 10 },
	{ id = "s3", event = "plant", target = 4, text = { en = "Plant {n} seeds", ar = "ازرع {n} بذور" }, coins = 30, xp = 15 },
	{ id = "s4", event = "glean", target = 1, text = { en = "Glean a sparkling crop on a neighbour's farm", ar = "التقط محصولًا لامعًا من مزرعة جار" }, coins = 40, xp = 20 },
	{ id = "s5", event = "contribute", target = 5, text = { en = "Give 5 items to the valley project", ar = "قدّم 5 أغراض لمشروع الوادي" }, coins = 60, xp = 25 },
	{ id = "s6", event = "chooseLand", target = 1, text = { en = "Choose your land", ar = "اختر أرضك" }, coins = 50, xp = 25 },
	{ id = "s7", event = "buyWorkshop", target = 1, text = { en = "Build your first workshop", ar = "ابنِ أول ورشة" }, coins = 80, xp = 30 },
	{ id = "s8", event = "craft", target = 2, text = { en = "Make {n} goods", ar = "اصنع {n} سلع" }, coins = 80, xp = 30 },
	{ id = "s9", event = "buyAnimal", target = 1, text = { en = "Adopt an animal", ar = "تبنَّ حيوانًا" }, coins = 100, xp = 40 },
	{ id = "s10", event = "explore", target = 1, text = { en = "Take a picnic trip to the forest", ar = "اذهب في نزهة إلى الغابة" }, coins = 120, xp = 50 },
	{ id = "s11", event = "trade", target = 1, text = { en = "Trade with a neighbour", ar = "تبادل مع جار" }, coins = 150, xp = 60 },
} :: { QuestDef }

return Quests
