-- Daily quests (3 per day, claimable) and the story chain (auto-completes and
-- teaches each system in order).

local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")

local Net = require(Shared.Net)
local Quests = require(Shared.Config.Quests)
local Social = require(Shared.Logic.Social)

local DataService, Progress

local QuestService = {}

local dailyById = {}
for _, q in Quests.dailyPool do
	dailyById[q.id] = q
end

local function refreshDaily(player: Player, p: any)
	local day = Social.dayIndex(os.time())
	if p.Quests.day == day then
		return
	end
	p.Quests.day = day
	p.Quests.daily = Social.dailyQuests(day, player.UserId, p.Level)
	p.Quests.progress = {}
	p.Quests.claimed = {}
	Progress.dirty(player)
end

local function onEvent(player: Player, name: string, amount: number)
	local p = DataService.get(player)
	if not p then
		return
	end
	refreshDaily(player, p)
	local changed = false
	for _, id in p.Quests.daily do
		local q = dailyById[id]
		if q and q.event == name and not p.Quests.claimed[id] then
			local before = p.Quests.progress[id] or 0
			if before < q.target then
				p.Quests.progress[id] = math.min(q.target, before + amount)
				changed = true
				if p.Quests.progress[id] >= q.target then
					Net.notify(player, "note.questReady", nil, "celebrate")
				end
			end
		end
	end
	local step = Quests.story[p.Quests.story]
	if step and step.event == name then
		p.Quests.storyProgress = (p.Quests.storyProgress or 0) + amount
		changed = true
		if p.Quests.storyProgress >= step.target then
			p.Quests.story += 1
			p.Quests.storyProgress = 0
			Progress.addCoins(player, step.coins)
			Progress.addXp(player, step.xp)
			Net.notify(player, "note.storyDone", { coins = step.coins }, "celebrate")
		end
	end
	if changed then
		Progress.dirty(player)
	end
end

local function claim(player: Player, id: any)
	local p = DataService.get(player)
	local q = type(id) == "string" and dailyById[id]
	if not p or not q or not table.find(p.Quests.daily, id) or p.Quests.claimed[id] then
		return
	end
	if (p.Quests.progress[id] or 0) < q.target then
		return
	end
	p.Quests.claimed[id] = true
	Progress.addCoins(player, q.coins)
	Progress.addXp(player, q.xp)
	Progress.dirty(player)
end

function QuestService.init(services)
	DataService = services.DataService
	Progress = services.ProgressService
end

function QuestService.start()
	Progress.Events:Connect(onEvent)
	Net.onAction("ClaimQuest", claim, 2)
	DataService.Loaded:Connect(refreshDaily)
	task.spawn(function()
		while true do
			task.wait(30)
			for _, player in Players:GetPlayers() do
				local p = DataService.get(player)
				if p then
					refreshDaily(player, p)
				end
			end
		end
	end)
end

return QuestService
