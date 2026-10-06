-- Tuning numbers. These are first-pass targets to be adjusted after playtests.

local Economy = {}

-- Start
Economy.START_COINS = 60
Economy.START_SEEDS = { ["Seed:Carrot"] = 6, ["Seed:Wheat"] = 4 }
Economy.START_ITEMS = { PicnicBasket = 2 }

-- Farming
Economy.NATIVE_GROW_MULT = 0.8 -- native crops grow 20% faster
Economy.FOREIGN_YIELD = 0.7 -- foreign crops yield 70%
Economy.WATER_GROW_MULT = 0.75 -- watered crops grow 25% faster
Economy.FRESH_WINDOW_MULT = 2 -- a ripe crop stays "fresh" for grow time * this
Economy.FRESH_WINDOW_MIN = 180
Economy.TILE_SIZE = 4 -- studs

-- Plot expansion: plot side length in tiles, cost to reach it
Economy.PLOT_SIZES = {
	{ size = 6, coins = 0, wood = 0, stone = 0, level = 1 },
	{ size = 8, coins = 500, wood = 10, stone = 0, level = 4 },
	{ size = 10, coins = 2000, wood = 25, stone = 10, level = 8 },
	{ size = 12, coins = 6000, wood = 50, stone = 25, level = 12 },
	{ size = 14, coins = 15000, wood = 80, stone = 50, level = 18 },
	{ size = 16, coins = 40000, wood = 120, stone = 90, level = 25 },
	{ size = 18, coins = 90000, wood = 180, stone = 140, level = 33 },
	{ size = 20, coins = 200000, wood = 250, stone = 200, level = 42 },
}
Economy.MAX_PLOT_SIZE = 20

-- Gleaning
Economy.GLEAN_OWNER_SHARE = 0.85
Economy.GLEAN_GLEANER_SHARE = 0.30
Economy.GLEAN_DAILY_LIMIT = 20
Economy.GLEAN_MIN_ACCOUNT_AGE_DAYS = 3
Economy.WATER_NEIGHBOUR_DAILY_LIMIT = 30

-- Kindness rewards
Economy.KINDNESS_WATER = 1
Economy.KINDNESS_SHARED_GLEAN = 1
Economy.KINDNESS_PROJECT_PER_10 = 1
Economy.KINDNESS_RETIRE_ANIMAL = 5

-- Trading
Economy.TRADE_MIN_PLAYTIME = 2 * 3600
Economy.TRADE_MIN_ACCOUNT_AGE_DAYS = 3
Economy.TRADE_COUNTDOWN = 5
Economy.TRADE_IMBALANCE_WARN = 3 -- warn when one side is worth 3x the other
Economy.TRADE_MAX_SLOTS = 9

-- Market
Economy.MARKET_FEE = 0.05
Economy.MARKET_BAND_MIN = 0.5
Economy.MARKET_BAND_MAX = 1.5
Economy.MARKET_LISTING_TTL = 24 * 3600
Economy.MARKET_MAX_LISTINGS = 10

-- Seed shop
Economy.SHOP_RESTOCK_SECONDS = 600
Economy.SHOP_WISH_PITY = 6 -- the wished seed appears after at most this many restocks
Economy.SHOP_SLOTS = 8

-- Workshops
Economy.SKIP_DAILY_LIMIT = 3

-- Levels
Economy.MAX_LEVEL = 50
function Economy.xpForLevel(level: number): number
	-- XP needed to go from `level` to `level + 1`
	return math.floor(40 * level ^ 1.55)
end

Economy.XP = {
	harvestPerTier = 2,
	glean = 3,
	water = 1,
	craft = 4,
	animalCollect = 2,
	project = 1, -- per item contributed
	explore = 10,
	tradeDone = 5,
}

-- Rebirth ("Harvest Festival")
Economy.REBIRTH_LEVEL = 50
Economy.REBIRTH_COINS = 250000
Economy.REBIRTH_MAX = 10
Economy.REBIRTH_BONUSES = { 0.10, 0.08, 0.06, 0.05, 0.05, 0.04, 0.04, 0.03, 0.03, 0.02 }

-- Kept scale (guaranteed mutations after a break)
Economy.KEPT_SCALE_SECONDS_PER_MUTATION = 3600

-- Spending reminder
Economy.SPEND_REMINDER_ROBUX = 1000

return Economy
