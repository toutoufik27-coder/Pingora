-- Deterministic pseudo-random numbers that do not depend on Roblox APIs, so
-- every server (and the unit tests) compute the same values.

local Hash = {}

local MOD = 4294967296 -- 2^32

-- (a * b) % 2^32 for a, b < 2^32 without losing precision in doubles.
local function mulmod(a: number, b: number): number
	local bLo = b % 65536
	local bHi = math.floor(b / 65536)
	local hi = ((a * bHi) % MOD) * 65536 % MOD
	return (hi + a * bLo) % MOD
end

local function mix(x: number): number
	x = x % MOD
	x = mulmod(x, 2654435761)
	x = (x + 2654435769) % MOD
	x = (x + math.floor(x / 65536)) % MOD
	x = mulmod(x, 2246822519)
	x = (x + math.floor(x / 8192)) % MOD
	x = mulmod(x, 3266489917)
	x = (x + math.floor(x / 65536)) % MOD
	return x
end

-- Returns a number in [0, 1) for the given integer seed(s).
function Hash.unit(a: number, b: number?): number
	local x = mix(math.floor(a) % MOD)
	if b then
		x = mix((x + math.floor(b)) % MOD)
	end
	return x / MOD
end

-- Returns a function rng() -> [0, 1) seeded deterministically.
function Hash.stream(seed: number): () -> number
	local i = 0
	return function()
		i += 1
		return Hash.unit(seed, i)
	end
end

return Hash
