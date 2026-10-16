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
	status.Size = UDim2.fromOffset(520, 40)
	status.Font = Enum.Font.GothamBold
	status.TextSize = 22
	status.TextColor3 = Color3.fromRGB(255, 220, 80)
	status.TextStrokeTransparency = 0.5
	status.Text = "Get ready"
	status.Parent = gui

	local checkpoints = Instance.new("TextLabel")
	checkpoints.Name = "Checkpoints"
	checkpoints.BackgroundTransparency = 1
	checkpoints.Position = UDim2.fromScale(0.5, 0.17)
	checkpoints.AnchorPoint = Vector2.new(0.5, 0)
	checkpoints.Size = UDim2.fromOffset(400, 28)
	checkpoints.Font = Enum.Font.Gotham
	checkpoints.TextSize = 18
	checkpoints.TextColor3 = Color3.fromRGB(200, 200, 210)
	checkpoints.Text = "Checkpoints 0 / 4"
	checkpoints.Parent = gui

	local hint = Instance.new("TextLabel")
	hint.Name = "Hint"
	hint.BackgroundTransparency = 1
	hint.Position = UDim2.fromScale(0.5, 0.92)
	hint.AnchorPoint = Vector2.new(0.5, 0)
	hint.Size = UDim2.fromOffset(480, 24)
	hint.Font = Enum.Font.Gotham
	hint.TextSize = 16
	hint.TextColor3 = Color3.fromRGB(180, 180, 190)
	hint.Text = "WASD / arrows to drive · R to restart"
	hint.Parent = gui

	local state = {
		phase = "Idle",
		startedAt = nil :: number?,
		displayElapsed = 0,
		frozen = false,
	}

	Remotes.get("RaceStateChanged").OnClientEvent:Connect(function(payload)
		state.phase = payload.state
		checkpoints.Text = `Checkpoints {math.max(payload.nextCheckpoint - 1, 0)} / {payload.checkpointCount}`

		if payload.state == "Countdown" then
			state.frozen = true
			state.displayElapsed = 0
			timer.Text = "0:00.00"
			if payload.countdown and payload.countdown > 0 then
				status.Text = tostring(payload.countdown)
			else
				status.Text = "GO"
			end
		elseif payload.state == "Racing" then
			state.frozen = false
			state.startedAt = os.clock() - (payload.elapsed or 0)
			status.Text = "Time trial"
		elseif payload.state == "Finished" then
			state.frozen = true
			state.displayElapsed = payload.finishTime or payload.elapsed or 0
			timer.Text = formatTime(state.displayElapsed)
			local best = if payload.bestTime then formatTime(payload.bestTime) else "--"
			status.Text = `Finished · Best {best}`
		end
	end)

	Remotes.get("RaceFinished").OnClientEvent:Connect(function(payload)
		state.frozen = true
		state.displayElapsed = payload.finishTime
		timer.Text = formatTime(payload.finishTime)
		status.Text = `Finished · Best {formatTime(payload.bestTime)}`
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
