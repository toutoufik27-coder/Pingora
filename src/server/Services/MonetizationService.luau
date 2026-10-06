-- Game passes and developer products. Receipts are processed idempotently
-- (each receipt id is recorded in the profile before it is granted).
-- Nothing sold here gives power over other players or random rewards.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")

local Net = require(Shared.Net)
local Products = require(Shared.Config.Products)
local Economy = require(Shared.Config.Economy)
local Social = require(Shared.Logic.Social)

local DataService, Progress

local MonetizationService = {}

local productHandlers: { [string]: (Player, any) -> () } = {}

function MonetizationService.hasPass(player: Player, name: string): boolean
	local p = DataService and DataService.get(player)
	return p ~= nil and p.__passes ~= nil and p.__passes[name] == true
end

-- Other services register what a developer product does.
function MonetizationService.onProduct(name: string, handler: (Player, any) -> ())
	productHandlers[name] = handler
end

local function passNameById(id: number): string?
	for name, def in Products.passes do
		if def.id ~= 0 and def.id == id then
			return name
		end
	end
	return nil
end

local function productNameById(id: number): string?
	for name, def in Products.devProducts do
		if def.id ~= 0 and def.id == id then
			return name
		end
	end
	return nil
end

local function trackSpend(p: any, robux: number)
	local day = Social.dayIndex(os.time())
	if p.Spend.day ~= day then
		p.Spend.day = day
		p.Spend.robux = 0
	end
	p.Spend.robux += robux
end

local function checkPasses(player: Player, p: any)
	p.__passes = p.__passes or {}
	for name, def in Products.passes do
		if def.id ~= 0 then
			local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, def.id)
			if ok and owns then
				p.__passes[name] = true
			end
		end
	end
	Progress.dirty(player)
end

local function processReceipt(info)
	local player = Players:GetPlayerByUserId(info.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local p = DataService.get(player)
	if not p then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if p.Purchases[info.PurchaseId] then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	local name = productNameById(info.ProductId)
	local handler = name and productHandlers[name]
	if not handler then
		warn("[Monetization] no handler for product " .. tostring(info.ProductId))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local ok, err = pcall(handler, player, p)
	if not ok then
		warn("[Monetization] product handler failed: " .. tostring(err))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	p.Purchases[info.PurchaseId] = os.time()
	-- keep the receipt log small
	local count = 0
	for _ in p.Purchases do
		count += 1
	end
	if count > 200 then
		local oldestId, oldest = nil, math.huge
		for id, t in p.Purchases do
			if t < oldest then
				oldestId, oldest = id, t
			end
		end
		if oldestId then
			p.Purchases[oldestId] = nil
		end
	end
	trackSpend(p, info.CurrencySpent or 0)
	DataService.save(player)
	Progress.dirty(player)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function MonetizationService.init(services)
	DataService = services.DataService
	Progress = services.ProgressService
end

function MonetizationService.start()
	MarketplaceService.ProcessReceipt = processReceipt

	DataService.Loaded:Connect(checkPasses)

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if not purchased then
			return
		end
		local name = passNameById(passId)
		local p = DataService.get(player)
		if name and p then
			p.__passes = p.__passes or {}
			p.__passes[name] = true
			trackSpend(p, Products.passes[name].price)
			Net.notify(player, "note.passOwned", { pass = name }, "celebrate")
			Progress.dirty(player)
		end
	end)

	Net.onAction("BuyPass", function(player, name)
		local def = type(name) == "string" and Products.passes[name]
		if def and def.id ~= 0 and not MonetizationService.hasPass(player, name) then
			MarketplaceService:PromptGamePassPurchase(player, def.id)
		end
	end, 1)

	Net.onAction("BuyProduct", function(player, name)
		local def = type(name) == "string" and Products.devProducts[name]
		if def and def.id ~= 0 then
			MarketplaceService:PromptProductPurchase(player, def.id)
		end
	end, 1)

	Progress.addSnapshotExtra(function(_player, p, s)
		local day = Social.dayIndex(os.time())
		s.SpentToday = if p.Spend.day == day then p.Spend.robux else 0
		s.SpendReminder = Economy.SPEND_REMINDER_ROBUX
		s.ProductsEnabled = {}
		for name, def in Products.devProducts do
			s.ProductsEnabled[name] = def.id ~= 0
		end
		for name, def in Products.passes do
			s.ProductsEnabled[name] = def.id ~= 0
		end
	end)
end

return MonetizationService
