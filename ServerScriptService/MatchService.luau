local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage:WaitForChild("Constants"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))
local KartPrototype = require(ReplicatedStorage:WaitForChild("KartPrototype"))
local TrackService = require(script.Parent:WaitForChild("TrackService"))
local VehicleService = require(script.Parent:WaitForChild("VehicleService"))
local CreditService = require(script.Parent:WaitForChild("CreditService"))
local InventoryService = require(script.Parent:WaitForChild("InventoryService"))
local ItemService = require(script.Parent:WaitForChild("ItemService"))
local PickupService = require(script.Parent:WaitForChild("PickupService"))

export type MatchState = "Lobby" | "Selecting" | "Countdown" | "Racing" | "Podium"

type Racer = {
	paletteId: string?,
	locked: boolean,
	lap: number,
	nextCheckpoint: number,
	finishedAt: number?,
	onGrid: boolean,
	spectator: boolean,
	touching: { [BasePart]: boolean },
}

type Match = {
	state: MatchState,
	gen: number,
	startedAt: number?,
	winner: Player?,
	lobbyArmed: boolean,
	lobbyRemaining: number?,
	racers: { [Player]: Racer },
}

local MatchService = {}

local match: Match = {
	state = "Lobby",
	gen = 0,
	lobbyArmed = false,
	racers = {},
}

local stipendPaidGen: { [Player]: number } = {}
local lastDrivePos: { [Player]: Vector3 } = {}
local PAYOUT_REASONS = { "1st", "2nd", "3rd" }

local function grantRoundStipend(player: Player)
	if stipendPaidGen[player] == match.gen then
		return
	end
	stipendPaidGen[player] = match.gen
	CreditService.add(player, Constants.Credits.Stipend, "stipend")
end

local function newRacer(spectator: boolean): Racer
	return {
		locked = false,
		lap = 0,
		nextCheckpoint = 1,
		onGrid = false,
		spectator = spectator,
		touching = {},
	}
end

local function playerFromHit(hit: BasePart): Player?
	local model = hit:FindFirstAncestorOfClass("Model")
	while model do
		local fromCharacter = Players:GetPlayerFromCharacter(model)
		if fromCharacter then
			return fromCharacter
		end
		local seat = model:FindFirstChild("Seat")
		if seat and seat:IsA("VehicleSeat") and seat.Occupant then
			return Players:GetPlayerFromCharacter(seat.Occupant.Parent)
		end
		local parent = model.Parent
		model = if parent then parent:FindFirstAncestorOfClass("Model") else nil
	end
	return nil
end

local function eligible(racer: Racer): boolean
	return not racer.spectator
end

local function countEligible(): number
	local n = 0
	for _, racer in match.racers do
		if eligible(racer) then
			n += 1
		end
	end
	return n
end

local function rankedPlayers(): { Player }
	local list = {}
	for player, racer in match.racers do
		if racer.onGrid or (match.state ~= "Racing" and match.state ~= "Podium" and eligible(racer)) then
			table.insert(list, player)
		end
	end
	table.sort(list, function(a, b)
		local ra = match.racers[a]
		local rb = match.racers[b]
		if ra.finishedAt ~= nil and rb.finishedAt ~= nil then
			return ra.finishedAt < rb.finishedAt
		end
		if ra.finishedAt ~= nil then
			return true
		end
		if rb.finishedAt ~= nil then
			return false
		end
		if ra.lap ~= rb.lap then
			return ra.lap > rb.lap
		end
		return ra.nextCheckpoint > rb.nextCheckpoint
	end)
	return list
end

local function payPodium()
	local paid = 0
	for _, player in rankedPlayers() do
		local racer = match.racers[player]
		if racer and racer.onGrid and racer.finishedAt ~= nil then
			paid += 1
			local amount = Constants.Credits.Payout[paid]
			local reason = PAYOUT_REASONS[paid]
			if amount and reason then
				CreditService.add(player, amount, reason)
			end
			if paid >= 3 then
				break
			end
		end
	end
end

local function allLocked(): boolean
	local any = false
	for _, racer in match.racers do
		if eligible(racer) then
			any = true
			if not racer.locked then
				return false
			end
		end
	end
	return any
end

local function allGridFinished(): boolean
	local any = false
	for _, racer in match.racers do
		if racer.onGrid then
			any = true
			if racer.finishedAt == nil then
				return false
			end
		end
	end
	return any
end

local function broadcast(extra: { [string]: any }?)
	local ranking = rankedPlayers()
	local places: { [Player]: number } = {}
	for i, player in ranking do
		places[player] = i
	end

	local racersPayload = {}
	for player, racer in match.racers do
		table.insert(racersPayload, {
			userId = player.UserId,
			name = player.Name,
			lap = racer.lap,
			nextCheckpoint = racer.nextCheckpoint,
			place = places[player],
			paletteId = racer.paletteId,
			locked = racer.locked,
			spectator = racer.spectator,
			onGrid = racer.onGrid,
		})
	end

	local shared = extra or {}
	shared.state = match.state
	shared.lapCount = Constants.Race.LapCount
	shared.checkpointCount = Constants.Race.CheckpointCount
	shared.racers = racersPayload
	shared.lobbyRemaining = match.lobbyRemaining
	if match.winner then
		shared.winnerName = match.winner.Name
		shared.winnerUserId = match.winner.UserId
	end
	if match.startedAt then
		shared.elapsed = (os.clock() - match.startedAt)
	else
		shared.elapsed = 0
	end

	for player, racer in match.racers do
		local payload = table.clone(shared)
		payload.lap = racer.lap
		payload.nextCheckpoint = racer.nextCheckpoint
		payload.place = places[player]
		payload.locked = racer.locked
		payload.paletteId = racer.paletteId
		payload.spectator = racer.spectator
		payload.onGrid = racer.onGrid
		payload.credits = CreditService.get(player)
		Remotes.get("RaceStateChanged"):FireClient(player, payload)
	end
end

local enterLobby
local beginSelecting
local beginCountdown
local enterPodium
local maybeStartLobbyTimer

function enterLobby()
	match.gen += 1
	match.state = "Lobby"
	match.startedAt = nil
	match.winner = nil
	match.lobbyArmed = false
	match.lobbyRemaining = Constants.Race.LobbyWaitSeconds
	for player, racer in match.racers do
		match.racers[player] = newRacer(false)
		VehicleService.despawn(player)
		VehicleService.freezeForSelect(player)
	end
	broadcast()
	maybeStartLobbyTimer()
end

function maybeStartLobbyTimer()
	if match.state ~= "Lobby" then
		return
	end
	if countEligible() < Constants.Race.MinPlayers then
		return
	end
	if match.lobbyArmed then
		return
	end
	match.lobbyArmed = true
	local gen = match.gen
	task.spawn(function()
		for remaining = Constants.Race.LobbyWaitSeconds, 1, -1 do
			if match.gen ~= gen or match.state ~= "Lobby" then
				return
			end
			match.lobbyRemaining = remaining
			broadcast()
			task.wait(1)
		end
		if match.gen ~= gen or match.state ~= "Lobby" then
			return
		end
		beginSelecting()
	end)
end

function beginSelecting()
	match.gen += 1
	match.state = "Selecting"
	match.lobbyRemaining = nil
	match.winner = nil
	match.startedAt = nil
	local gen = match.gen
	for player, racer in match.racers do
		if racer.spectator then
			continue
		end
		match.racers[player] = newRacer(false)
		VehicleService.despawn(player)
		VehicleService.freezeForSelect(player)
		grantRoundStipend(player)
	end
	broadcast({ selectRemaining = Constants.Race.SelectSeconds })

	task.spawn(function()
		for remaining = Constants.Race.SelectSeconds, 1, -1 do
			if match.gen ~= gen or match.state ~= "Selecting" then
				return
			end
			broadcast({ selectRemaining = remaining })
			task.wait(1)
		end
		if match.gen ~= gen or match.state ~= "Selecting" then
			return
		end
		beginCountdown()
	end)
end

function beginCountdown()
	if match.state ~= "Selecting" then
		return
	end
	match.gen += 1
	match.state = "Countdown"
	match.startedAt = nil
	match.winner = nil
	local gen = match.gen

	local starters = {}
	for player, racer in match.racers do
		if eligible(racer) then
			table.insert(starters, player)
		end
	end
	table.sort(starters, function(a, b)
		return a.UserId < b.UserId
	end)
	if #starters == 0 then
		enterLobby()
		return
	end

	local slotCount = math.min(#starters, Constants.Race.MaxPlayers)
	for i, player in starters do
		if i > Constants.Race.MaxPlayers then
			local racer = match.racers[player]
			racer.spectator = true
			racer.onGrid = false
			continue
		end
		local racer = match.racers[player]
		local paletteId = KartPrototype.getPalette(racer.paletteId or Constants.Car.DefaultPalette).Id
		racer.paletteId = paletteId
		racer.locked = true
		racer.lap = 0
		racer.nextCheckpoint = 1
		racer.finishedAt = nil
		racer.touching = {}
		racer.onGrid = true
		racer.spectator = false
		lastDrivePos[player] = nil
		VehicleService.spawnFor(player, paletteId, i, slotCount)
		VehicleService.setDrivingEnabled(player, false)
	end

	broadcast({ countdown = Constants.Race.CountdownSeconds })

	task.spawn(function()
		for remaining = Constants.Race.CountdownSeconds, 1, -1 do
			if match.gen ~= gen or match.state ~= "Countdown" then
				return
			end
			broadcast({ countdown = remaining })
			task.wait(1)
		end
		if match.gen ~= gen or match.state ~= "Countdown" then
			return
		end
		match.state = "Racing"
		match.startedAt = os.clock()
		for player, racer in match.racers do
			if racer.onGrid then
				VehicleService.setDrivingEnabled(player, true)
			end
		end
		broadcast({ countdown = 0 })
	end)
end

function enterPodium()
	if match.state ~= "Racing" then
		return
	end
	match.gen += 1
	match.state = "Podium"
	local gen = match.gen
	for player, racer in match.racers do
		if racer.onGrid then
			VehicleService.setDrivingEnabled(player, false)
		end
	end
	payPodium()
	ItemService.clearRound()
	broadcast({ podiumRemaining = Constants.Race.PodiumSeconds })

	if match.winner then
		local winner = match.winner
		local winnerRacer = match.racers[winner]
		Remotes.get("RaceFinished"):FireAllClients({
			winnerName = winner.Name,
			winnerUserId = winner.UserId,
			finishTime = if winnerRacer and winnerRacer.finishedAt and match.startedAt
				then winnerRacer.finishedAt - match.startedAt
				else 0,
		})
	end

	task.spawn(function()
		for remaining = Constants.Race.PodiumSeconds, 1, -1 do
			if match.gen ~= gen or match.state ~= "Podium" then
				return
			end
			broadcast({ podiumRemaining = remaining })
			task.wait(1)
		end
		if match.gen ~= gen or match.state ~= "Podium" then
			return
		end
		enterLobby()
	end)
end

local function onWinner(player: Player)
	if match.winner == nil then
		match.winner = player
	end
	if allGridFinished() then
		enterPodium()
		return
	end
	local gen = match.gen
	task.spawn(function()
		task.wait(Constants.Race.DnfAfterWinnerSeconds)
		if match.gen ~= gen or match.state ~= "Racing" then
			return
		end
		enterPodium()
	end)
end

local function tryPassCheckpoint(player: Player, checkpoint: BasePart)
	local racer = match.racers[player]
	if racer == nil or match.state ~= "Racing" or not racer.onGrid or racer.finishedAt ~= nil then
		return
	end
	if racer.touching[checkpoint] then
		return
	end
	racer.touching[checkpoint] = true

	local index = checkpoint:GetAttribute("Index")
	if index ~= racer.nextCheckpoint then
		return
	end

	if index >= Constants.Race.CheckpointCount then
		local nextLap = racer.lap + 1
		if nextLap >= Constants.Race.LapCount then
			racer.lap = Constants.Race.LapCount
			racer.nextCheckpoint = Constants.Race.CheckpointCount
			racer.finishedAt = os.clock()
			VehicleService.setDrivingEnabled(player, false)
			CreditService.add(player, Constants.Credits.FinishBonus, "finish")
			Remotes.get("CheckpointPassed"):FireClient(player, {
				index = index,
				nextCheckpoint = racer.nextCheckpoint,
				checkpointCount = Constants.Race.CheckpointCount,
				lap = racer.lap,
			})
			broadcast()
			onWinner(player)
			return
		end
		racer.lap = nextLap
		racer.nextCheckpoint = 1
	else
		racer.nextCheckpoint += 1
	end

	Remotes.get("CheckpointPassed"):FireClient(player, {
		index = index,
		nextCheckpoint = racer.nextCheckpoint,
		checkpointCount = Constants.Race.CheckpointCount,
		lap = racer.lap,
	})
	broadcast()
end

local function onCheckpointTouched(checkpoint: BasePart, hit: BasePart)
	if not hit:IsA("BasePart") then
		return
	end
	local player = playerFromHit(hit)
	if player then
		tryPassCheckpoint(player, checkpoint)
	end
end

local function pointInCheckpoint(checkpoint: BasePart, pos: Vector3): boolean
	local rel = checkpoint.CFrame:PointToObjectSpace(pos)
	local half = checkpoint.Size * 0.5
	return math.abs(rel.X) <= half.X and math.abs(rel.Y) <= half.Y + 8 and math.abs(rel.Z) <= half.Z
end

local function considerCarPosition(player: Player, pos: Vector3)
	local racer = match.racers[player]
	if racer == nil then
		return
	end
	local prev = lastDrivePos[player] or pos
	lastDrivePos[player] = pos
	local dist = (pos - prev).Magnitude
	local steps = math.max(1, math.ceil(dist / 2))
	for _, checkpoint in TrackService.getCheckpoints() do
		local hit = false
		for s = 1, steps do
			if pointInCheckpoint(checkpoint, prev:Lerp(pos, s / steps)) then
				hit = true
				break
			end
		end
		if hit then
			tryPassCheckpoint(player, checkpoint)
		else
			racer.touching[checkpoint] = nil
		end
	end
	PickupService.consider(player, prev, pos)
end

function MatchService.chooseKart(player: Player, paletteId: any)
	if typeof(paletteId) ~= "string" then
		return
	end
	if match.state ~= "Selecting" then
		return
	end
	local racer = match.racers[player]
	if racer == nil or racer.spectator or racer.locked then
		return
	end
	racer.paletteId = KartPrototype.getPalette(paletteId).Id
	racer.locked = true
	broadcast()
	if allLocked() then
		beginCountdown()
	end
end

function MatchService.addPlayer(player: Player)
	local existing = match.racers[player]
	if existing then
		if match.state == "Lobby" or match.state == "Selecting" then
			VehicleService.freezeForSelect(player)
		end
		broadcast()
		return
	end

	local spectator = match.state == "Countdown" or match.state == "Racing" or match.state == "Podium"
	if countEligible() >= Constants.Race.MaxPlayers and match.state ~= "Lobby" then
		spectator = true
	end
	match.racers[player] = newRacer(spectator)
	if not spectator then
		VehicleService.freezeForSelect(player)
	end
	CreditService.sync(player)
	InventoryService.sync(player)
	broadcast()
	if match.state == "Lobby" then
		maybeStartLobbyTimer()
	elseif match.state == "Selecting" then
		grantRoundStipend(player)
		broadcast({ selectRemaining = Constants.Race.SelectSeconds })
	end
end

function MatchService.removePlayer(player: Player)
	match.racers[player] = nil
	stipendPaidGen[player] = nil
	lastDrivePos[player] = nil
	VehicleService.despawn(player)
	if match.winner == player then
		match.winner = nil
	end
	if match.state == "Racing" and allGridFinished() then
		enterPodium()
	elseif match.state == "Selecting" and allLocked() then
		beginCountdown()
	elseif match.state == "Lobby" then
		broadcast()
	end
end

function MatchService.requestRestart(player: Player)
	if match.racers[player] == nil then
		return
	end
	if match.state == "Podium" then
		enterLobby()
	end
end

function MatchService.start()
	for _, checkpoint in TrackService.getCheckpoints() do
		checkpoint.Touched:Connect(function(hit)
			onCheckpointTouched(checkpoint, hit)
		end)
		checkpoint.TouchEnded:Connect(function()
			for _, racer in match.racers do
				racer.touching[checkpoint] = nil
			end
		end)
	end

	Remotes.get("DriveInput").OnServerEvent:Connect(function(player, cf)
		if typeof(cf) ~= "CFrame" then
			return
		end
		considerCarPosition(player, cf.Position)
	end)

	Remotes.get("SelectKart").OnServerEvent:Connect(function(player, paletteId)
		MatchService.chooseKart(player, paletteId)
	end)
	VehicleService.setPaddockHandler(function(player, paletteId)
		MatchService.chooseKart(player, paletteId)
	end)
end

function MatchService.getState(): MatchState
	return match.state
end

function MatchService.isRacing(player: Player): boolean
	local racer = match.racers[player]
	return match.state == "Racing" and racer ~= nil and racer.onGrid and racer.finishedAt == nil
end

return MatchService
