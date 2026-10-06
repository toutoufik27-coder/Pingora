-- Valley projects are built together by everyone in a server. When a project
-- completes, the whole server gets a temporary buff and every contributor
-- earns that project's deed, which unlocks something forever.

export type Project = {
	id: string,
	name: { en: string, ar: string },
	needs: { [string]: number },
	buff: { kind: string, value: number, seconds: number },
	deedText: { en: string, ar: string },
	color: { number },
}

local Projects = {}

Projects.MIN_CONTRIBUTION_FOR_DEED = 5 -- items

Projects.list = {
	{
		id = "Mill",
		name = { en = "Valley Mill", ar = "طاحونة الوادي" },
		needs = { Wheat = 120, Wood = 40 },
		buff = { kind = "workshopSpeed", value = 0.15, seconds = 1800 },
		deedText = { en = "Your Mill gets +1 queue slot", ar = "طاحونتك تحصل على خانة إضافية" },
		color = { 200, 170, 120 },
	},
	{
		id = "Bridge",
		name = { en = "Stone Bridge", ar = "الجسر الحجري" },
		needs = { Stone = 60, Wood = 80, Flour = 20 },
		buff = { kind = "growSpeed", value = 0.10, seconds = 1800 },
		deedText = { en = "Opens Cloud Mountain", ar = "يفتح جبل السحاب" },
		color = { 160, 160, 160 },
	},
	{
		id = "Fountain",
		name = { en = "Plaza Fountain", ar = "نافورة الساحة" },
		needs = { Stone = 100, Clay = 50, Lotus = 8 },
		buff = { kind = "mutationChance", value = 0.02, seconds = 1800 },
		deedText = { en = "+2% mutation chance on your farm", ar = "+2% فرصة طفرات في مزرعتك" },
		color = { 120, 180, 230 },
	},
	{
		id = "Lighthouse",
		name = { en = "River Lighthouse", ar = "منارة النهر" },
		needs = { Brick = 40, Wood = 100, OliveOil = 8 },
		buff = { kind = "sellBonus", value = 0.10, seconds = 1800 },
		deedText = { en = "+1 market listing slot", ar = "خانة إضافية في السوق" },
		color = { 240, 220, 200 },
	},
} :: { Project }

Projects.byId = {} :: { [string]: Project }
for _, p in Projects.list do
	Projects.byId[p.id] = p
end

-- A brand-new server starts its first project almost finished so newcomers
-- can complete it and see their name on the board.
Projects.START_PROGRESS = 0.85

return Projects
