-- Server-wide temporary buffs (from completed valley projects and events).

local Buffs = {}

local active: { [string]: { value: number, untilTime: number } } = {}

function Buffs.set(kind: string, value: number, seconds: number)
	local current = active[kind]
	local untilTime = os.time() + seconds
	if current and current.untilTime > os.time() then
		value = math.max(value, current.value)
		untilTime = math.max(untilTime, current.untilTime)
	end
	active[kind] = { value = value, untilTime = untilTime }
end

function Buffs.get(kind: string): number
	local b = active[kind]
	if b and b.untilTime > os.time() then
		return b.value
	end
	return 0
end

function Buffs.list(): { { kind: string, value: number, untilTime: number } }
	local out = {}
	local now = os.time()
	for kind, b in active do
		if b.untilTime > now then
			table.insert(out, { kind = kind, value = b.value, untilTime = b.untilTime })
		end
	end
	return out
end

return Buffs
