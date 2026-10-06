-- Valley projects: everyone in the server contributes items to one shared
-- build. On completion the server gets a temporary buff and every
-- contributor who gave enough earns the project's deed (a permanent unlock).
-- Any amount counts, and absent players are never penalised.

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")

local Net = require(Shared.Net)
local Projects = require(Shared.Config.Projects)
local Economy = require(Shared.Config.Economy)
local Make = require(script.Parent.Parent.World.Make)
local WorldBuilder = require(script.Parent.Parent.World.WorldBuilder)
local Buffs = require(script.Parent.Parent.Buffs)

local DataService, Progress

local ProjectService = {}

local state = {
	index = 1,
	progress = {} :: { [string]: number },
	contributors = {} :: { [number]: number }, -- userId -> items given
	completedCount = 0,
}

local scaffold: BasePart?

local function current()
	return Projects.list[state.index]
end

local function fraction(): number
	local proj = current()
	local need, have = 0, 0
	for item, n in proj.needs do
		need += n
		have += math.min(n, state.progress[item] or 0)
	end
	return if need > 0 then have / need else 1
end

local function payload()
	local proj = current()
	local top = {}
	for userId, n in state.contributors do
		local pl = Players:GetPlayerByUserId(userId)
		table.insert(top, { name = if pl then pl.DisplayName else tostring(userId), n = n })
	end
	table.sort(top, function(a, b)
		return a.n > b.n
	end)
	while #top > 5 do
		table.remove(top)
	end
	return {
		id = proj.id,
		needs = proj.needs,
		progress = state.progress,
		fraction = fraction(),
		top = top,
		completed = state.completedCount,
	}
end

local pushQueued = false
local function pushAll()
	if pushQueued then
		return
	end
	pushQueued = true
	task.delay(0.3, function()
		pushQueued = false
		Net.pushAll("Project", payload())
		if scaffold then
			local f = fraction()
			local h = 1 + f * 16
			scaffold.Size = Vector3.new(14, h, 14)
			scaffold.CFrame = CFrame.new(WorldBuilder.points.Project + Vector3.new(0, h / 2 + 0.5, 0))
			scaffold.Color = Make.color(current().color)
			scaffold:SetAttribute("SignOffset", h / 2 + 4)
			scaffold:SetAttribute("SignKey", "sign.project")
			scaffold:SetAttribute("SignVars", HttpService:JSONEncode({ project = current().id, pct = math.floor(f * 100) }))
		end
	end)
end

local function startProject(index: number, startFraction: number)
	state.index = index
	state.progress = {}
	state.contributors = {}
	local proj = current()
	for item, n in proj.needs do
		state.progress[item] = math.floor(n * startFraction)
	end
	pushAll()
end

local function complete()
	local proj = current()
	Buffs.set(proj.buff.kind, proj.buff.value, proj.buff.seconds)
	for userId, n in state.contributors do
		if n >= Projects.MIN_CONTRIBUTION_FOR_DEED then
			local pl = Players:GetPlayerByUserId(userId)
			local p = pl and DataService.get(pl)
			if p then
				if not p.Deeds[proj.id] then
					p.Deeds[proj.id] = true
					Net.notify(pl :: Player, "note.deedEarned", { project = proj.id }, "celebrate")
				end
				Progress.dirty(pl :: Player)
			else
				-- contributors who already left still get their deed
				task.spawn(DataService.sendMail, userId, { type = "deed", project = proj.id })
			end
		end
	end
	Net.notifyAll("note.projectDone", { project = proj.id }, "celebrate")
	Net.pushAll("Effect", { kind = "fireworks", at = WorldBuilder.points.Project })
	state.completedCount += 1
	for _, pl in Players:GetPlayers() do
		Progress.dirty(pl)
	end
	startProject((state.index % #Projects.list) + 1, 0)
end

local function contribute(player: Player, item: any, n: any)
	if type(item) ~= "string" or type(n) ~= "number" or n ~= n then
		return
	end
	n = math.clamp(math.floor(n), 1, 9999)
	if Progress.distance(player, WorldBuilder.points.Project) > Economy.SHOP_DISTANCE then
		return
	end
	local proj = current()
	local need = proj.needs[item]
	if not need then
		return
	end
	local missing = need - (state.progress[item] or 0)
	n = math.min(n, missing)
	if n <= 0 then
		return
	end
	local p = DataService.get(player)
	if not p or (p.Inventory[item] or 0) < n then
		return
	end
	Progress.take(player, item, n)
	state.progress[item] = (state.progress[item] or 0) + n
	local before = state.contributors[player.UserId] or 0
	state.contributors[player.UserId] = before + n
	Progress.addXp(player, Economy.XP.project * n)
	Progress.emit(player, "contribute", n)
	local kindness = math.floor((before + n) / 10) - math.floor(before / 10)
	if kindness > 0 then
		Progress.addKindness(player, kindness * Economy.KINDNESS_PROJECT_PER_10)
	end
	pushAll()
	if fraction() >= 1 then
		complete()
	end
end

function ProjectService.init(services)
	DataService = services.DataService
	Progress = services.ProgressService
end

function ProjectService.start()
	scaffold = Make.part({
		Name = "ProjectScaffold",
		Size = Vector3.new(14, 1, 14),
		CFrame = CFrame.new(WorldBuilder.points.Project + Vector3.new(0, 1, 0)),
		Color = Make.color(current().color),
		Material = Enum.Material.WoodPlanks,
		Parent = WorldBuilder.root,
	})
	startProject(1, Projects.START_PROGRESS)

	Net.onAction("Contribute", contribute, 6)
	Net.onRequest("Project", function()
		return payload()
	end, 2)
	WorldBuilder.prompts.Project.Triggered:Connect(function(player)
		Net.push(player, "Open", "Project")
	end)
	Players.PlayerAdded:Connect(function(player)
		task.wait(3)
		Net.push(player, "Project", payload())
	end)
end

return ProjectService
