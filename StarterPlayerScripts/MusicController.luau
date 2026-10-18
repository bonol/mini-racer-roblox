local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage:WaitForChild("Constants"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))

local MusicController = {}

local BG_VOLUME = 0.22
local BG_DUCK = 0.08
local STING_VOLUME = 0.55

local function makeSound(name: string, soundId: string, looped: boolean, volume: number): Sound
	local existing = SoundService:FindFirstChild(name)
	if existing and existing:IsA("Sound") then
		existing:Destroy()
	end
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = soundId
	sound.Looped = looped
	sound.Volume = volume
	sound.Parent = SoundService
	return sound
end

local function playSting(sound: Sound)
	sound.TimePosition = 0
	sound:Play()
end

function MusicController.start()
	local ids = Constants.Audio
	local bg = makeSound("MiniRacerBackground", ids.Background, true, BG_VOLUME)
	local countdown = makeSound("MiniRacerCountdown", ids.Countdown, false, STING_VOLUME)
	local lap = makeSound("MiniRacerLap", ids.Lap, false, STING_VOLUME)
	local boost = makeSound("MiniRacerBoostPickup", ids.BoostPickup, false, STING_VOLUME)
	local winner = makeSound("MiniRacerWinner", ids.Winner, false, 0.65)
	local bombPickup = makeSound("MiniRacerBombPickup", ids.BombPickup, false, STING_VOLUME)
	local bombHit = makeSound("MiniRacerBombHit", ids.BombHit, false, STING_VOLUME)

	local phase = "Lobby"
	local lastLap = 0
	local lastSlow = 0
	local winnerPlayed = false
	bg:Play()

	Remotes.get("RaceStateChanged").OnClientEvent:Connect(function(payload)
		if typeof(payload) ~= "table" or typeof(payload.state) ~= "string" then
			return
		end
		local nextPhase = payload.state
		if nextPhase == "Countdown" and phase ~= "Countdown" then
			bg.Volume = BG_DUCK
			playSting(countdown)
			winnerPlayed = false
			lastLap = 0
		elseif nextPhase == "Racing" then
			if countdown.IsPlaying then
				countdown:Stop()
			end
			bg.Volume = BG_VOLUME
			if not bg.IsPlaying then
				bg:Play()
			end
		elseif nextPhase == "Lobby" or nextPhase == "Selecting" then
			bg.Volume = BG_VOLUME
			if not bg.IsPlaying then
				bg:Play()
			end
			winnerPlayed = false
			lastLap = 0
		end
		phase = nextPhase
		if typeof(payload.lap) == "number" then
			lastLap = payload.lap
		end
	end)

	Remotes.get("CheckpointPassed").OnClientEvent:Connect(function(payload)
		if typeof(payload) ~= "table" then
			return
		end
		if payload.index ~= Constants.Race.CheckpointCount then
			return
		end
		local newLap = payload.lap
		if typeof(newLap) ~= "number" then
			return
		end
		if newLap > lastLap and newLap < Constants.Race.LapCount then
			playSting(lap)
		end
		lastLap = newLap
	end)

	Remotes.get("RaceFinished").OnClientEvent:Connect(function()
		if winnerPlayed then
			return
		end
		winnerPlayed = true
		bg.Volume = BG_DUCK
		playSting(winner)
	end)

	Remotes.get("InventoryChanged").OnClientEvent:Connect(function(payload)
		if typeof(payload) ~= "table" then
			return
		end
		if payload.picked == "Booster" then
			playSting(boost)
		elseif payload.picked == "Bomb" then
			playSting(bombPickup)
		end
	end)

	Remotes.get("ItemStateChanged").OnClientEvent:Connect(function(payload)
		if typeof(payload) ~= "table" then
			return
		end
		local slow = payload.slowRemaining
		if typeof(slow) ~= "number" then
			return
		end
		if slow > lastSlow + 0.2 then
			playSting(bombHit)
		end
		lastSlow = slow
	end)
end

return MusicController
