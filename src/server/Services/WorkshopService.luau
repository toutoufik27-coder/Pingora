-- Workshops: build, start jobs, collect goods. Each workshop runs several
-- jobs in parallel (its slots). The Mill deed, the Extra Queue pass and the
-- workshop-speed buff improve them.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")

local Net = require(Shared.Net)
local Workshops = require(Shared.Config.Workshops)
local Economy = require(Shared.Config.Economy)
local Social = require(Shared.Logic.Social)
local Buffs = require(script.Parent.Parent.Buffs)

local DataService, Progress, PlotService, MonetizationService

local WorkshopService = {}

function WorkshopService.slots(player: Player, p: any, workshopId: string): number
	local w = Workshops.byId[workshopId]
	local n = w.slots
	if MonetizationService.hasPass(player, "ExtraQueue") then
		n += 1
	end
	if workshopId == "Mill" and p.Deeds.Mill then
		n += 1
	end
	return n
end

local function buy(player: Player, workshopId: any)
	local p = DataService.get(player)
	local w = type(workshopId) == "string" and Workshops.byId[workshopId]
	if not p or not w or p.Workshops[w.id] then
		return
	end
	if p.Level < w.level then
		Net.notify(player, "note.needLevel", { level = w.level }, "warn")
		return
	end
	if not Progress.spendCoins(player, w.price) then
		Net.notify(player, "note.notEnoughCoins", nil, "warn")
		return
	end
	p.Workshops[w.id] = { queue = {} }
	if p.__plot then
		PlotService.refreshBuildings(p.__plot)
	end
	Progress.emit(player, "buyWorkshop", 1)
	Net.notify(player, "note.workshopBuilt", { workshop = w.id }, "celebrate")
	Progress.dirty(player)
end

local function startJob(player: Player, workshopId: any, recipeId: any)
	local p = DataService.get(player)
	if not p or type(workshopId) ~= "string" or type(recipeId) ~= "string" then
		return
	end
	local state = p.Workshops[workshopId]
	local recipe = Workshops.recipeById[recipeId]
	if not state or not recipe or Workshops.recipeWorkshop[recipeId] ~= workshopId then
		return
	end
	if p.Level < recipe.level then
		Net.notify(player, "note.needLevel", { level = recipe.level }, "warn")
		return
	end
	if #state.queue >= WorkshopService.slots(player, p, workshopId) then
		Net.notify(player, "note.workshopBusy", nil, "warn")
		return
	end
	if not Progress.takeAll(player, recipe.inputs) then
		Net.notify(player, "note.missingIngredients", nil, "warn")
		return
	end
	local now = os.time()
	local time = math.max(5, math.floor(recipe.time * (1 - Buffs.get("workshopSpeed"))))
	table.insert(state.queue, { recipe = recipeId, start = now, done = now + time })
	Progress.dirty(player)
end

function WorkshopService.collect(player: Player, workshopId: string): number
	local p = DataService.get(player)
	local state = p and p.Workshops[workshopId]
	if not state then
		return 0
	end
	local now = os.time()
	local remaining = {}
	local made = 0
	for _, job in state.queue do
		if now >= job.done then
			local recipe = Workshops.recipeById[job.recipe]
			if recipe then
				Progress.give(player, recipe.output, recipe.amount)
				Progress.addXp(player, Economy.XP.craft)
				made += recipe.amount
			end
		else
			table.insert(remaining, job)
		end
	end
	state.queue = remaining
	if made > 0 then
		Progress.emit(player, "craft", made)
		Progress.dirty(player)
	end
	return made
end

-- Finishes the job closest to done. Used by the SkipWorkshop product and by
-- skip tokens. Returns true if a job was finished.
function WorkshopService.skipOne(player: Player, p: any): boolean
	local bestWs, bestJob = nil, nil
	for wsId, state in p.Workshops do
		for _, job in state.queue do
			if job.done > os.time() and (not bestJob or job.done < bestJob.done) then
				bestWs, bestJob = wsId, job
			end
		end
	end
	if not bestJob then
		return false
	end
	bestJob.done = os.time()
	WorkshopService.collect(player, bestWs)
	return true
end

local function skipAllowed(p: any): boolean
	local day = Social.dayIndex(os.time())
	if p.Skips.day ~= day then
		p.Skips.day = day
		p.Skips.count = 0
	end
	return p.Skips.count < Economy.SKIP_DAILY_LIMIT
end

local function useSkipToken(player: Player)
	local p = DataService.get(player)
	if not p or (p.SkipTokens or 0) <= 0 or not skipAllowed(p) then
		return
	end
	if WorkshopService.skipOne(player, p) then
		p.SkipTokens -= 1
		p.Skips.count += 1
		Progress.dirty(player)
	end
end

function WorkshopService.init(services)
	DataService = services.DataService
	Progress = services.ProgressService
	PlotService = services.PlotService
	MonetizationService = services.MonetizationService
end

function WorkshopService.start()
	Net.onAction("BuyWorkshop", buy, 1)
	Net.onAction("StartJob", startJob, 6)
	Net.onAction("CollectWorkshop", function(player, workshopId)
		if type(workshopId) == "string" then
			WorkshopService.collect(player, workshopId)
		end
	end, 6)
	Net.onAction("UseSkipToken", useSkipToken, 1)

	-- Buying the product always gives value: a job is finished now if one is
	-- running and today's limit allows it; otherwise the player keeps a token.
	MonetizationService.onProduct("SkipWorkshop", function(player, p)
		if skipAllowed(p) and WorkshopService.skipOne(player, p) then
			p.Skips.count += 1
		else
			p.SkipTokens = (p.SkipTokens or 0) + 1
		end
	end)

	game:GetService("ProximityPromptService").PromptTriggered:Connect(function(prompt, player)
		local ws = prompt:GetAttribute("Workshop")
		local plotIndex = prompt:GetAttribute("PlotIndex")
		local build = prompt:GetAttribute("BuildWorkshop")
		if build and plotIndex and PlotService.ownerOf(plotIndex) == player then
			Net.push(player, "Open", { panel = "BuildWorkshop", id = build })
			return
		end
		if ws and plotIndex and PlotService.ownerOf(plotIndex) == player then
			WorkshopService.collect(player, ws)
			Net.push(player, "Open", { panel = "Workshop", id = ws })
		end
	end)
end

return WorkshopService
