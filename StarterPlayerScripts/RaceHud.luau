local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Remotes = require(game:GetService("ReplicatedStorage"):WaitForChild("Remotes"))

local RaceHud = {}

local function formatTime(seconds: number): string
	local minutes = math.floor(seconds / 60)
	local rest = seconds - minutes * 60
	return string.format("%d:%05.2f", minutes, rest)
end

function RaceHud.start()
	local player = Players.LocalPlayer
	local gui = Instance.new("ScreenGui")
	gui.Name = "MiniRacerHud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Parent = player:WaitForChild("PlayerGui")

	local timer = Instance.new("TextLabel")
	timer.Name = "Timer"
	timer.BackgroundTransparency = 1
	timer.Position = UDim2.fromScale(0.5, 0.04)
	timer.AnchorPoint = Vector2.new(0.5, 0)
	timer.Size = UDim2.fromOffset(280, 48)
	timer.Font = Enum.Font.GothamBlack
	timer.TextSize = 36
	timer.TextColor3 = Color3.new(1, 1, 1)
	timer.TextStrokeTransparency = 0.4
	timer.Text = "0:00.00"
	timer.Parent = gui

	local status = Instance.new("TextLabel")
	status.Name = "Status"
	status.BackgroundTransparency = 1
	status.Position = UDim2.fromScale(0.5, 0.12)
	status.AnchorPoint = Vector2.new(0.5, 0)
	status.Size = UDim2.fromOffset(640, 40)
	status.Font = Enum.Font.GothamBold
	status.TextSize = 22
	status.TextColor3 = Color3.fromRGB(255, 220, 80)
	status.TextStrokeTransparency = 0.5
	status.Text = "Lobby"
	status.Parent = gui

	local standings = Instance.new("TextLabel")
	standings.Name = "Standings"
	standings.BackgroundTransparency = 1
	standings.Position = UDim2.fromScale(0.5, 0.17)
	standings.AnchorPoint = Vector2.new(0.5, 0)
	standings.Size = UDim2.fromOffset(520, 28)
	standings.Font = Enum.Font.Gotham
	standings.TextSize = 18
	standings.TextColor3 = Color3.fromRGB(200, 200, 210)
	standings.Text = "Lap 1 / 20    P-"
	standings.Parent = gui

	local hint = Instance.new("TextLabel")
	hint.Name = "Hint"
	hint.BackgroundTransparency = 1
	hint.Position = UDim2.fromScale(0.5, 0.92)
	hint.AnchorPoint = Vector2.new(0.5, 0)
	hint.Size = UDim2.fromOffset(560, 24)
	hint.Font = Enum.Font.Gotham
	hint.TextSize = 16
	hint.TextColor3 = Color3.fromRGB(180, 180, 190)
	hint.Text = "Waiting for the race"
	hint.Parent = gui

	local state = {
		phase = "Lobby",
		startedAt = nil :: number?,
		displayElapsed = 0,
		frozen = true,
		lapCount = 20,
		lap = 0,
		place = nil :: number?,
		checkpointCount = 4,
		nextCheckpoint = 1,
	}

	local function currentLapLabel(): string
		local lapCount = state.lapCount
		local shown = if state.lap >= lapCount then lapCount else math.max(state.lap + 1, 1)
		local place = if state.place then `P{state.place}` else "P-"
		return `Lap {shown} / {lapCount}    {place}`
	end

	Remotes.get("RaceStateChanged").OnClientEvent:Connect(function(payload)
		state.phase = payload.state
		state.lapCount = payload.lapCount or state.lapCount
		state.checkpointCount = payload.checkpointCount or state.checkpointCount
		state.lap = payload.lap or 0
		state.place = payload.place
		state.nextCheckpoint = payload.nextCheckpoint or 1
		standings.Text = currentLapLabel()

		if payload.state == "Lobby" then
			state.frozen = true
			state.displayElapsed = 0
			timer.Visible = false
			standings.Visible = false
			timer.Text = "0:00.00"
			local waitFor = payload.lobbyRemaining
			if typeof(waitFor) == "number" then
				status.Text = `Lobby  {waitFor}`
			else
				status.Text = "Lobby"
			end
			hint.Text = "Race starts soon"
		elseif payload.state == "Selecting" then
			state.frozen = true
			state.displayElapsed = 0
			timer.Visible = false
			standings.Visible = false
			timer.Text = "0:00.00"
			if payload.locked then
				status.Text = "Waiting for others"
				hint.Text = "Locked in — wait for the field"
			else
				status.Text = "Pick a racer"
				hint.Text = "Pick a racer to lock in"
			end
		elseif payload.state == "Countdown" then
			state.frozen = true
			state.displayElapsed = 0
			timer.Visible = true
			standings.Visible = true
			timer.Text = "0:00.00"
			hint.Text = "WASD / arrows to drive"
			if payload.spectator then
				status.Text = "Waiting for next race"
			elseif payload.countdown and payload.countdown > 0 then
				status.Text = tostring(payload.countdown)
			else
				status.Text = "GO"
			end
		elseif payload.state == "Racing" then
			timer.Visible = true
			standings.Visible = true
			if payload.spectator then
				state.frozen = true
				status.Text = "Waiting for next race"
				hint.Text = "You join the next round"
			else
				hint.Text = "WASD / arrows to drive"
				state.frozen = false
				state.startedAt = os.clock() - (payload.elapsed or 0)
				status.Text = "Racing"
			end
		elseif payload.state == "Podium" then
			state.frozen = true
			timer.Visible = true
			standings.Visible = true
			if payload.elapsed then
				state.displayElapsed = payload.elapsed
				timer.Text = formatTime(payload.elapsed)
			end
			local winner = payload.winnerName or "Someone"
			status.Text = `{winner} wins`
			hint.Text = "Next round soon"
		end
	end)

	Remotes.get("RaceFinished").OnClientEvent:Connect(function(payload)
		if typeof(payload.winnerName) == "string" then
			status.Text = `{payload.winnerName} wins`
		end
	end)

	RunService.RenderStepped:Connect(function()
		if state.frozen or state.phase ~= "Racing" or state.startedAt == nil then
			return
		end
		timer.Text = formatTime(os.clock() - state.startedAt)
	end)

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.R then
			Remotes.get("RequestRestart"):FireServer()
		end
	end)
end

return RaceHud
