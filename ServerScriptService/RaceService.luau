local Players = game:GetService("Players")

local Constants = require(game:GetService("ReplicatedStorage"):WaitForChild("Constants"))
local Remotes = require(game:GetService("ReplicatedStorage"):WaitForChild("Remotes"))
local TrackService = require(script.Parent:WaitForChild("TrackService"))
local VehicleService = require(script.Parent:WaitForChild("VehicleService"))

export type RaceState = "Idle" | "Countdown" | "Racing" | "Finished"

type Session = {
	state: RaceState,
	nextCheckpoint: number,
	startedAt: number?,
	finishedAt: number?,
	bestTime: number?,
	touching: { [BasePart]: boolean },
}

local RaceService = {}

local sessions: { [Player]: Session } = {}

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

local function getSession(player: Player): Session
	local session = sessions[player]
	if session == nil then
		session = {
			state = "Idle",
			nextCheckpoint = 1,
			touching = {},
		}
		sessions[player] = session
	end
	return session
end

local function fireState(player: Player, session: Session, extra: { [string]: any }?)
	local payload = extra or {}
	payload.state = session.state
	payload.nextCheckpoint = session.nextCheckpoint
	payload.checkpointCount = Constants.Race.CheckpointCount
	payload.bestTime = session.bestTime
	if session.startedAt then
		payload.elapsed = (session.finishedAt or os.clock()) - session.startedAt
	else
		payload.elapsed = 0
	end
	Remotes.get("RaceStateChanged"):FireClient(player, payload)
end

function RaceService.start(player: Player)
	local session = getSession(player)
	session.state = "Countdown"
	session.nextCheckpoint = 1
	session.startedAt = nil
	session.finishedAt = nil
	session.touching = {}
	VehicleService.spawnFor(player)
	VehicleService.setDrivingEnabled(player, false)
	fireState(player, session, { countdown = Constants.Race.CountdownSeconds })

	task.spawn(function()
		for remaining = Constants.Race.CountdownSeconds, 1, -1 do
			if sessions[player] ~= session or session.state ~= "Countdown" then
				return
			end
			fireState(player, session, { countdown = remaining })
			task.wait(1)
		end
		if sessions[player] ~= session or session.state ~= "Countdown" then
			return
		end
		session.state = "Racing"
		session.startedAt = os.clock()
		VehicleService.setDrivingEnabled(player, true)
		fireState(player, session, { countdown = 0 })
	end)
end

function RaceService.finish(player: Player)
	local session = sessions[player]
	if session == nil or session.state ~= "Racing" or session.startedAt == nil then
		return
	end
	session.state = "Finished"
	session.finishedAt = os.clock()
	VehicleService.setDrivingEnabled(player, false)
	local time = session.finishedAt - session.startedAt
	if session.bestTime == nil or time < session.bestTime then
		session.bestTime = time
	end
	fireState(player, session, { finishTime = time })
	Remotes.get("RaceFinished"):FireClient(player, {
		finishTime = time,
		bestTime = session.bestTime,
	})
end

local function tryPassCheckpoint(player: Player, checkpoint: BasePart)
	local session = sessions[player]
	if session == nil or session.state ~= "Racing" then
		return
	end
	if session.touching[checkpoint] then
		return
	end
	session.touching[checkpoint] = true

	local index = checkpoint:GetAttribute("Index")
	if index ~= session.nextCheckpoint then
		return
	end

	session.nextCheckpoint += 1
	Remotes.get("CheckpointPassed"):FireClient(player, {
		index = index,
		nextCheckpoint = session.nextCheckpoint,
		checkpointCount = Constants.Race.CheckpointCount,
	})
	fireState(player, session)

	if index >= Constants.Race.CheckpointCount then
		RaceService.finish(player)
	end
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

local function considerCarPosition(player: Player, pos: Vector3)
	for _, checkpoint in TrackService.getCheckpoints() do
		local rel = checkpoint.CFrame:PointToObjectSpace(pos)
		local half = checkpoint.Size * 0.5
		if math.abs(rel.X) <= half.X and math.abs(rel.Y) <= half.Y + 4 and math.abs(rel.Z) <= half.Z then
			tryPassCheckpoint(player, checkpoint)
		else
			local session = sessions[player]
			if session then
				session.touching[checkpoint] = nil
			end
		end
	end
end

function RaceService.bindCheckpoints()
	for _, checkpoint in TrackService.getCheckpoints() do
		checkpoint.Touched:Connect(function(hit)
			onCheckpointTouched(checkpoint, hit)
		end)
		checkpoint.TouchEnded:Connect(function()
			for _, session in sessions do
				session.touching[checkpoint] = nil
			end
		end)
	end

	Remotes.get("DriveInput").OnServerEvent:Connect(function(player, cf)
		if typeof(cf) ~= "CFrame" then
			return
		end
		considerCarPosition(player, cf.Position)
	end)
end

function RaceService.forget(player: Player)
	sessions[player] = nil
	VehicleService.despawn(player)
end

return RaceService
