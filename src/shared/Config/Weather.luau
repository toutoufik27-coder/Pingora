-- Weather and mutations. Weather is global: every server computes the same
-- forecast from the clock, so players everywhere share the same skies.

local Weather = {}

Weather.SLOT_SECONDS = 480 -- one weather slot every 8 minutes
Weather.ACTIVE_SECONDS = 180 -- weather is active for the first 3 minutes of a slot
Weather.TICK_SECONDS = 15 -- how often mutation rolls happen during weather
Weather.BASE_CHANCE = 0.05 -- per crop per tick
Weather.MAX_MUTATIONS = 3

export type Mutation = {
	id: string,
	name: { en: string, ar: string },
	mult: number, -- price multiplier; stacking is additive (see Logic/Pricing)
	color: { number },
}

Weather.mutations = {
	Wet = { id = "Wet", name = { en = "Wet", ar = "مبلل" }, mult = 2, color = { 80, 160, 255 } },
	Sunkissed = { id = "Sunkissed", name = { en = "Sunkissed", ar = "مشمس" }, mult = 2, color = { 255, 200, 60 } },
	Frozen = { id = "Frozen", name = { en = "Frozen", ar = "متجمد" }, mult = 3, color = { 170, 230, 255 } },
	Moonlit = { id = "Moonlit", name = { en = "Moonlit", ar = "قمري" }, mult = 3, color = { 180, 170, 255 } },
	Charged = { id = "Charged", name = { en = "Charged", ar = "مشحون" }, mult = 5, color = { 255, 255, 120 } },
	Rainbow = { id = "Rainbow", name = { en = "Rainbow", ar = "قزحي" }, mult = 10, color = { 255, 120, 220 } },
	Starry = { id = "Starry", name = { en = "Starry", ar = "نجمي" }, mult = 20, color = { 255, 255, 255 } },
	Golden = { id = "Golden", name = { en = "Golden", ar = "ذهبي" }, mult = 5, color = { 255, 215, 0 } },
	Big = { id = "Big", name = { en = "Big", ar = "ضخم" }, mult = 3, color = { 120, 220, 120 } },
} :: { [string]: Mutation }

-- Growth mutations can happen at harvest time, online or not.
Weather.GROWTH_MUTATIONS = {
	{ id = "Golden", chance = 0.01 },
	{ id = "Big", chance = 0.02 },
}

-- Mutations granted by the "kept scale" when a player returns after a break.
Weather.KEPT_SCALE_POOL = { "Wet", "Sunkissed", "Frozen", "Moonlit" }
Weather.KEPT_SCALE_MAX = 8

export type WeatherType = {
	id: string,
	name: { en: string, ar: string },
	weight: number, -- relative chance of being picked for a slot
	mutation: string?, -- mutation rolled during this weather
	special: string?, -- "crosspollinate" for wind
	sky: { number },
}

Weather.types = {
	Clear = { id = "Clear", name = { en = "Clear", ar = "صحو" }, weight = 40, mutation = nil, sky = { 170, 210, 255 } },
	Rain = { id = "Rain", name = { en = "Rain", ar = "مطر" }, weight = 18, mutation = "Wet", sky = { 120, 140, 170 } },
	Heat = { id = "Heat", name = { en = "Heatwave", ar = "شمس حارة" }, weight = 15, mutation = "Sunkissed", sky = { 255, 210, 150 } },
	Frost = { id = "Frost", name = { en = "Frost", ar = "صقيع" }, weight = 8, mutation = "Frozen", sky = { 200, 230, 255 } },
	Fog = { id = "Fog", name = { en = "Moon Fog", ar = "ضباب قمري" }, weight = 8, mutation = "Moonlit", sky = { 140, 140, 180 } },
	Wind = { id = "Wind", name = { en = "Windy", ar = "رياح" }, weight = 7, mutation = nil, special = "crosspollinate", sky = { 190, 220, 240 } },
	Thunder = { id = "Thunder", name = { en = "Thunderstorm", ar = "عاصفة رعدية" }, weight = 3, mutation = "Charged", sky = { 70, 70, 100 } },
	Rainbow = { id = "Rainbow", name = { en = "Rainbow", ar = "قوس قزح" }, weight = 1, mutation = "Rainbow", sky = { 220, 200, 255 } },
	-- Meteor shower is never rolled; it is started by the live show.
	Meteor = { id = "Meteor", name = { en = "Meteor Shower", ar = "زخة شهب" }, weight = 0, mutation = "Starry", sky = { 40, 30, 80 } },
} :: { [string]: WeatherType }

-- Stable roll order (dictionary iteration order is not guaranteed).
Weather.order = { "Clear", "Rain", "Heat", "Frost", "Fog", "Wind", "Thunder", "Rainbow" }

Weather.HYBRID_CHANCE = 0.08 -- per eligible pair per tick while windy

return Weather
