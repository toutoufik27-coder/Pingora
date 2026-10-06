-- Land types. Each farm picks one primary land; crops native to it grow
-- faster and yield more. Foreign crops still grow (see Economy.FOREIGN_YIELD).

export type Land = {
	id: string,
	name: { en: string, ar: string },
	color: { number },
	weatherBonus: string?, -- weather id whose mutation chance doubles on this land
	animal: string, -- signature animal id
	available: boolean, -- false = arrives with a later season
	order: number,
}

local Lands: { [string]: Land } = {
	Meadow = {
		id = "Meadow",
		name = { en = "Meadow", ar = "المرج" },
		color = { 124, 186, 84 },
		weatherBonus = nil,
		animal = "Cow",
		available = true,
		order = 1,
	},
	Riverbank = {
		id = "Riverbank",
		name = { en = "Riverbank", ar = "ضفة النهر" },
		color = { 92, 160, 120 },
		weatherBonus = "Rain",
		animal = "Duck",
		available = true,
		order = 2,
	},
	Hillside = {
		id = "Hillside",
		name = { en = "Hillside", ar = "التل" },
		color = { 176, 166, 96 },
		weatherBonus = "Heat",
		animal = "Goat",
		available = true,
		order = 3,
	},
	Woodland = {
		id = "Woodland",
		name = { en = "Woodland", ar = "الغابة" },
		color = { 74, 120, 70 },
		weatherBonus = "Fog",
		animal = "Rabbit",
		available = true,
		order = 4,
	},
	Orchard = {
		id = "Orchard",
		name = { en = "Orchard", ar = "البستان" },
		color = { 140, 176, 90 },
		weatherBonus = "Wind",
		animal = "Chicken",
		available = false,
		order = 5,
	},
	Desert = {
		id = "Desert",
		name = { en = "Desert", ar = "الصحراء" },
		color = { 214, 186, 126 },
		weatherBonus = "Heat",
		animal = "Camel",
		available = false,
		order = 6,
	},
}

return Lands
