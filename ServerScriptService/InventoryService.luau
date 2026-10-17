local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))

local ITEM_IDS = {
	Booster = true,
	Landmine = true,
}

local InventoryService = {}

local bags: { [Player]: { [string]: number } } = {}
local started = false

local function bagFor(player: Player): { [string]: number }
	local bag = bags[player]
	if bag == nil then
		bag = { Booster = 0, Landmine = 0 }
		bags[player] = bag
	end
	return bag
end

local function snapshot(player: Player): { [string]: number }
	local bag = bagFor(player)
	return {
		Booster = bag.Booster or 0,
		Landmine = bag.Landmine or 0,
	}
end

local function fire(player: Player, extra: { [string]: any }?)
	local payload = extra or {}
	payload.inventory = snapshot(player)
	Remotes.get("InventoryChanged"):FireClient(player, payload)
end

function InventoryService.get(player: Player): { [string]: number }
	return snapshot(player)
end

function InventoryService.add(player: Player, itemId: string, n: number)
	if not ITEM_IDS[itemId] then
		return
	end
	if typeof(n) ~= "number" or n == 0 then
		return
	end
	local bag = bagFor(player)
	bag[itemId] = math.max(0, (bag[itemId] or 0) + math.floor(n))
	fire(player, { bought = if n > 0 then itemId else nil })
end

function InventoryService.tryConsume(player: Player, itemId: string): boolean
	if not ITEM_IDS[itemId] then
		return false
	end
	local bag = bagFor(player)
	if (bag[itemId] or 0) <= 0 then
		return false
	end
	bag[itemId] -= 1
	fire(player)
	return true
end

function InventoryService.sync(player: Player)
	fire(player)
end

function InventoryService.reject(player: Player, reason: string)
	fire(player, { error = reason })
end

function InventoryService.start()
	if started then
		return
	end
	started = true
	Players.PlayerRemoving:Connect(function(player)
		bags[player] = nil
	end)
end

return InventoryService
