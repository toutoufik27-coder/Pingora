-- The Harvest Festival (rebirth). Resets coins, level, farm size, crops and
-- workshops; keeps animals, items, the almanac, deeds and cosmetics; grants a
-- permanent sell bonus (diminishing) and, from the first rebirth, a second land.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")

local Net = require(Shared.Net)
local Economy = require(Shared.Config.Economy)
local Levels = require(Shared.Logic.Levels)

local DataService, Progress, PlotService

local RebirthService = {}

local function rebirth(player: Player)
	local p = DataService.get(player)
	if not p or not Levels.canRebirth(p.Level, p.Coins, p.Rebirths) then
		return
	end
	p.Rebirths += 1
	p.Coins = Economy.START_COINS
	p.Level = 1
	p.XP = 0
	p.PlotSize = 6
	p.Tiles = {}
	p.Workshops = {}
	if p.__plot then
		PlotService.refreshAll(p.__plot)
	end
	Net.notifyAll("note.rebirthAll", { name = player.DisplayName, n = p.Rebirths }, "celebrate")
	Net.push(player, "Effect", { kind = "fireworks" })
	Progress.dirty(player)
	DataService.save(player)
end

function RebirthService.init(services)
	DataService = services.DataService
	Progress = services.ProgressService
	PlotService = services.PlotService
end

function RebirthService.start()
	Net.onAction("Rebirth", rebirth, 1)
end

return RebirthService
