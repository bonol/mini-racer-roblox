local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage:WaitForChild("Constants"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))

local CreditService = {}

local wallets: { [Player]: number } = {}
local started = false

local function fire(player: Player, delta: number, reason: string)
	Remotes.get("CreditsChanged"):FireClient(player, {
		credits = wallets[player] or 0,
		delta = delta,
		reason = reason,
	})
end

local function ensureJoin(player: Player): number
	if wallets[player] == nil then
		wallets[player] = Constants.Credits.StartingBalance
		fire(player, Constants.Credits.StartingBalance, "join")
	end
	return wallets[player]
end

function CreditService.get(player: Player): number
	return ensureJoin(player)
end

function CreditService.add(player: Player, amount: number, reason: string)
	if typeof(amount) ~= "number" or amount <= 0 then
		return
	end
	ensureJoin(player)
	wallets[player] += math.floor(amount)
	fire(player, math.floor(amount), reason)
end

function CreditService.trySpend(player: Player, amount: number): boolean
	if typeof(amount) ~= "number" or amount <= 0 then
		return false
	end
	amount = math.floor(amount)
	local bal = ensureJoin(player)
	if bal < amount then
		return false
	end
	wallets[player] = bal - amount
	fire(player, -amount, "spend")
	return true
end

function CreditService.sync(player: Player)
	ensureJoin(player)
	fire(player, 0, "sync")
end

function CreditService.start()
	if started then
		return
	end
	started = true
	Players.PlayerRemoving:Connect(function(player)
		wallets[player] = nil
	end)
end

return CreditService
