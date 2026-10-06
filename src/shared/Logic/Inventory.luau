-- Inventory helpers. An inventory is { [key] = count } with no zero entries.

local Inventory = {}

function Inventory.count(inv: { [string]: number }, key: string): number
	return inv[key] or 0
end

function Inventory.add(inv: { [string]: number }, key: string, n: number)
	if n <= 0 then
		return
	end
	inv[key] = (inv[key] or 0) + math.floor(n)
end

function Inventory.remove(inv: { [string]: number }, key: string, n: number): boolean
	n = math.floor(n)
	if n <= 0 then
		return true
	end
	local have = inv[key] or 0
	if have < n then
		return false
	end
	if have == n then
		inv[key] = nil
	else
		inv[key] = have - n
	end
	return true
end

function Inventory.hasAll(inv: { [string]: number }, needs: { [string]: number }): boolean
	for key, n in needs do
		if (inv[key] or 0) < n then
			return false
		end
	end
	return true
end

-- Removes everything in `needs` or nothing.
function Inventory.removeAll(inv: { [string]: number }, needs: { [string]: number }): boolean
	if not Inventory.hasAll(inv, needs) then
		return false
	end
	for key, n in needs do
		Inventory.remove(inv, key, n)
	end
	return true
end

-- Sanitises a client-sent { [key] = count } map: positive integers only.
function Inventory.cleanCounts(raw: any, maxEntries: number): { [string]: number }?
	if type(raw) ~= "table" then
		return nil
	end
	local out, n = {}, 0
	for k, v in raw do
		if type(k) ~= "string" or type(v) ~= "number" or v ~= v or v < 1 or v > 1e9 then
			return nil
		end
		n += 1
		if n > maxEntries then
			return nil
		end
		out[k] = math.floor(v)
	end
	return out
end

return Inventory
