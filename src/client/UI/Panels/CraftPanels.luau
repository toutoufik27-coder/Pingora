-- Workshops (build, queue, recipes) and the valley project.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")

local Net = require(Shared.Net)
local Workshops = require(Shared.Config.Workshops)
local Projects = require(Shared.Config.Projects)
local Economy = require(Shared.Config.Economy)
local Kit = require(script.Parent.Parent.Kit)
local Common = require(script.Parent.Parent.Common)
local Locale = require(script.Parent.Parent.Parent.Locale)
local State = require(script.Parent.Parent.Parent.State)

return function(App)
	local function slotsFor(p: any, id: string): number
		local w = Workshops.byId[id]
		local n = w.slots
		if p.Passes and p.Passes.ExtraQueue then
			n += 1
		end
		if id == "Mill" and p.Deeds and p.Deeds.Mill then
			n += 1
		end
		return n
	end

	App.register("BuildWorkshop", {
		title = "panel.build",
		listens = { "Profile" },
		render = function(ctx)
			local p = State.profile
			local w = ctx.arg and Workshops.byId[ctx.arg.id]
			if not p or not w then
				return
			end
			if p.Workshops[w.id] then
				App.open("Workshop", { id = w.id })
				return
			end
			local list = Kit.scroll(ctx.body, UDim2.fromScale(1, 1))
			Kit.label(Locale.pick(w.name), { Font = Kit.font, TextSize = 20, LayoutOrder = 1, Parent = list })
			Kit.label(Locale.t("ui.buildCost", { coins = Locale.num(w.price), level = w.level }), { LayoutOrder = 2, Parent = list })
			local makes = {}
			for _, r in w.recipes do
				table.insert(makes, Locale.idName(r.output))
			end
			Kit.label(Locale.t("ui.makes") .. ": " .. table.concat(makes, ", "), { TextColor3 = Kit.colors.muted, LayoutOrder = 3, Parent = list })
			local b = Kit.button(Locale.t("ui.build"), function()
				Net.action("BuyWorkshop", w.id)
			end, { LayoutOrder = 4, Parent = list })
			Kit.setEnabled(b, p.Level >= w.level and p.Coins >= w.price)
		end,
	})

	App.register("Workshop", {
		title = "panel.workshop",
		listens = { "Profile" },
		render = function(ctx)
			local p = State.profile
			local w = ctx.arg and Workshops.byId[ctx.arg.id]
			if not p or not w then
				return
			end
			local state = p.Workshops[w.id]
			if not state then
				App.open("BuildWorkshop", { id = w.id })
				return
			end
			local list = Kit.scroll(ctx.body, UDim2.fromScale(1, 1))
			local now = State.now()
			local slots = slotsFor(p, w.id)
			Kit.label(Locale.pick(w.name) .. string.format("  (%d/%d)", #state.queue, slots), { Font = Kit.font, TextSize = 18, LayoutOrder = 1, Parent = list })
			local anyDone = false
			for i, job in state.queue do
				local r = Workshops.recipeById[job.recipe]
				local frac = math.clamp((now - job.start) / math.max(1, job.done - job.start), 0, 1)
				local done = now >= job.done
				anyDone = anyDone or done
				local row = Kit.row(46)
				row.LayoutOrder = 1 + i
				row.Parent = list
				Common.itemSwatch(r.output, 32).Parent = row
				local box = Kit.new("Frame", { Size = UDim2.new(1, -50, 1, 0), BackgroundTransparency = 1, LayoutOrder = 2, Parent = row })
				Kit.list(box, false, 2)
				Kit.label(Locale.idName(r.output) .. " · " .. (if done then Locale.t("ui.ready") else Locale.duration(job.done - now)), { TextSize = 13, LayoutOrder = 1, Parent = box })
				local bar = Kit.progress(frac)
				bar.LayoutOrder = 2
				bar.Parent = box
			end
			local row = Kit.new("Frame", { Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1, LayoutOrder = 20, Parent = list })
			Kit.list(row, true, 6)
			local c = Kit.button(Locale.t("ui.collect"), function()
				Net.action("CollectWorkshop", w.id)
			end, { LayoutOrder = 1, Parent = row })
			Kit.setEnabled(c, anyDone)
			if (p.SkipTokens or 0) > 0 then
				Kit.button(Locale.t("ui.useSkip", { n = p.SkipTokens }), function()
					Net.action("UseSkipToken")
				end, { BackgroundColor3 = Kit.colors.gold, Size = UDim2.fromOffset(160, 36), LayoutOrder = 2, Parent = row })
			elseif p.ProductsEnabled and p.ProductsEnabled.SkipWorkshop and #state.queue > 0 then
				Kit.button(Locale.t("ui.skipRobux"), function()
					Net.action("BuyProduct", "SkipWorkshop")
				end, { BackgroundColor3 = Kit.colors.gold, Size = UDim2.fromOffset(160, 36), LayoutOrder = 2, Parent = row })
			end
			Kit.label(Locale.t("ui.recipes"), { Font = Kit.font, LayoutOrder = 21, Parent = list })
			for i, r in w.recipes do
				local can = p.Level >= r.level and Common.hasNeeds(r.inputs, p.Inventory) and #state.queue < slots
				local detail = Common.needsText(r.inputs, p.Inventory) .. " · " .. Locale.duration(r.time)
				if p.Level < r.level then
					detail = Locale.t("ui.needLevel", { level = r.level })
				end
				local b = Kit.button(Locale.t("ui.make"), function()
					Net.action("StartJob", w.id, r.id)
				end)
				Kit.setEnabled(b, can)
				Common.itemRow(list, r.output, detail, { b }, 21 + i)
			end
		end,
	})

	App.register("Project", {
		title = "panel.project",
		listens = { "Profile", "Project" },
		render = function(ctx)
			local p = State.profile
			local proj = State.project
			if not p or not proj then
				Kit.label(Locale.t("ui.loading"), { Parent = ctx.body })
				return
			end
			local def = Projects.byId[proj.id]
			local list = Kit.scroll(ctx.body, UDim2.fromScale(1, 1))
			Kit.label(Locale.pick(def.name), { Font = Kit.font, TextSize = 20, LayoutOrder = 1, Parent = list })
			Kit.label(Locale.t("ui.projectReward") .. ": " .. Locale.pick(def.deedText) .. (if p.Deeds[def.id] then " ✔" else ""), { TextSize = 13, TextColor3 = Kit.colors.muted, LayoutOrder = 2, Parent = list })
			local bar = Kit.progress(proj.fraction, Kit.colors.gold, 14)
			bar.LayoutOrder = 3
			bar.Parent = list
			local order = 3
			local items = {}
			for item in def.needs do
				table.insert(items, item)
			end
			table.sort(items)
			for _, item in items do
				order += 1
				local need = def.needs[item]
				local have = proj.progress[item] or 0
				local mine = p.Inventory[item] or 0
				local missing = need - have
				local give10 = Kit.button(Locale.t("ui.give", { n = math.min(10, missing, mine) }), function()
					Net.action("Contribute", item, 10)
				end)
				local giveAll = Kit.button(Locale.t("ui.giveAll"), function()
					Net.action("Contribute", item, math.min(missing, mine))
				end, { BackgroundColor3 = Kit.colors.buttonAlt })
				Kit.setEnabled(give10, missing > 0 and mine > 0)
				Kit.setEnabled(giveAll, missing > 0 and mine > 0)
				Common.itemRow(list, item, string.format("%d/%d · %s %d", have, need, Locale.t("ui.youHave"), mine), { give10, giveAll }, order)
			end
			order += 1
			Kit.label(Locale.t("ui.topHelpers"), { Font = Kit.font, LayoutOrder = order, Parent = list })
			for _, t in proj.top or {} do
				order += 1
				Kit.label(t.name .. " — " .. t.n, { LayoutOrder = order, Parent = list })
			end
			order += 1
			Kit.label(Locale.t("ui.deedHelp", { n = Projects.MIN_CONTRIBUTION_FOR_DEED }), { TextSize = 13, TextColor3 = Kit.colors.muted, LayoutOrder = order, Parent = list })
			local _ = Economy
		end,
	})
end
