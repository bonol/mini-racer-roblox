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
	gui.DisplayOrder = 50
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
	standings.Text = "Lap 1 / 3    P-"
	standings.Parent = gui

	local creditPanel = Instance.new("Frame")
	creditPanel.Name = "CreditPanel"
	creditPanel.BackgroundColor3 = Color3.fromRGB(8, 12, 20)
	creditPanel.BackgroundTransparency = 0.28
	creditPanel.BorderSizePixel = 0
	creditPanel.Position = UDim2.fromScale(0.02, 0.03)
	creditPanel.Size = UDim2.fromOffset(220, 48)
	creditPanel.Parent = gui
	local creditCorner = Instance.new("UICorner")
	creditCorner.CornerRadius = UDim.new(0, 8)
	creditCorner.Parent = creditPanel

	local credits = Instance.new("TextLabel")
	credits.Name = "Credits"
	credits.BackgroundTransparency = 1
	credits.Position = UDim2.fromOffset(12, 0)
	credits.Size = UDim2.new(1, -16, 1, 0)
	credits.Font = Enum.Font.GothamBold
	credits.TextSize = 22
	credits.TextXAlignment = Enum.TextXAlignment.Left
	credits.TextColor3 = Color3.fromRGB(255, 236, 140)
	credits.TextStrokeTransparency = 0.45
	credits.Text = "Credits: 0"
	credits.Parent = creditPanel

	local toast = Instance.new("TextLabel")
	toast.Name = "CreditToast"
	toast.BackgroundTransparency = 1
	toast.Position = UDim2.fromScale(0.02, 0.105)
	toast.Size = UDim2.fromOffset(320, 24)
	toast.Font = Enum.Font.Gotham
	toast.TextSize = 18
	toast.TextXAlignment = Enum.TextXAlignment.Left
	toast.TextColor3 = Color3.fromRGB(140, 255, 170)
	toast.TextStrokeTransparency = 0.5
	toast.Text = ""
	toast.Parent = gui

	local bag = Instance.new("TextLabel")
	bag.Name = "Inventory"
	bag.BackgroundTransparency = 1
	bag.Position = UDim2.fromScale(0.02, 0.145)
	bag.Size = UDim2.fromOffset(360, 22)
	bag.Font = Enum.Font.Gotham
	bag.TextSize = 16
	bag.TextXAlignment = Enum.TextXAlignment.Left
	bag.TextColor3 = Color3.fromRGB(200, 210, 220)
	bag.TextStrokeTransparency = 0.55
	bag.Text = "Booster x0    Landmine x0"
	bag.Parent = gui

	local effect = Instance.new("TextLabel")
	effect.Name = "ItemEffect"
	effect.BackgroundTransparency = 1
	effect.Position = UDim2.fromScale(0.02, 0.175)
	effect.Size = UDim2.fromOffset(360, 22)
	effect.Font = Enum.Font.GothamBold
	effect.TextSize = 16
	effect.TextXAlignment = Enum.TextXAlignment.Left
	effect.TextColor3 = Color3.fromRGB(160, 220, 255)
	effect.TextStrokeTransparency = 0.5
	effect.Text = ""
	effect.Parent = gui

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
		lapCount = 3,
		lap = 0,
		place = nil :: number?,
		checkpointCount = 4,
		nextCheckpoint = 1,
		credits = 0,
		toastUntil = 0,
		booster = 0,
		landmine = 0,
		boostRemaining = 0,
		slowRemaining = 0,
	}

	local function showToast(text: string, ok: boolean)
		toast.Text = text
		toast.TextColor3 = if ok then Color3.fromRGB(140, 255, 170) else Color3.fromRGB(255, 150, 150)
		state.toastUntil = os.clock() + 3
	end

	local function renderBag()
		bag.Text = `Booster x{state.booster}    Landmine x{state.landmine}`
	end

	local function renderEffect()
		if state.slowRemaining > 0.05 then
			effect.Text = `Slowed  {string.format("%.1f", state.slowRemaining)}s`
			effect.TextColor3 = Color3.fromRGB(255, 140, 140)
		elseif state.boostRemaining > 0.05 then
			effect.Text = `Boosted  {string.format("%.1f", state.boostRemaining)}s`
			effect.TextColor3 = Color3.fromRGB(160, 220, 255)
		else
			effect.Text = ""
		end
	end

	local function renderCredits(n: number)
		state.credits = n
		credits.Text = `Credits: {n}`
	end

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
		if typeof(payload.credits) == "number" then
			renderCredits(payload.credits)
		end
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
			hint.Text = "WASD drive · E boost · Q mine"
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
				hint.Text = "WASD drive · E boost · Q mine"
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

	Remotes.get("CheckpointPassed").OnClientEvent:Connect(function(payload)
		if typeof(payload) ~= "table" then
			return
		end
		if typeof(payload.lap) == "number" then
			state.lap = payload.lap
		end
		if typeof(payload.nextCheckpoint) == "number" then
			state.nextCheckpoint = payload.nextCheckpoint
		end
		if typeof(payload.checkpointCount) == "number" then
			state.checkpointCount = payload.checkpointCount
		end
		standings.Text = currentLapLabel()
		standings.Visible = true
	end)

	Remotes.get("RaceFinished").OnClientEvent:Connect(function(payload)
		if typeof(payload.winnerName) == "string" then
			status.Text = `{payload.winnerName} wins`
		end
	end)

	Remotes.get("CreditsChanged").OnClientEvent:Connect(function(payload)
		if typeof(payload) ~= "table" then
			return
		end
		if typeof(payload.credits) == "number" then
			renderCredits(payload.credits)
		end
		local delta = payload.delta
		local reason = payload.reason
		if typeof(delta) == "number" and delta ~= 0 then
			local sign = if delta > 0 then "+" else ""
			local why = if typeof(reason) == "string" then `  {reason}` else ""
			showToast(`{sign}{delta}{why}`, delta > 0)
		end
	end)

	Remotes.get("InventoryChanged").OnClientEvent:Connect(function(payload)
		if typeof(payload) ~= "table" then
			return
		end
		local inv = payload.inventory
		if typeof(inv) == "table" then
			if typeof(inv.Booster) == "number" then
				state.booster = inv.Booster
			end
			if typeof(inv.Landmine) == "number" then
				state.landmine = inv.Landmine
			end
			renderBag()
		end
		if typeof(payload.error) == "string" then
			showToast(payload.error, false)
		elseif typeof(payload.picked) == "string" then
			showToast(`picked up {payload.picked}`, true)
		elseif typeof(payload.bought) == "string" then
			showToast(`bought {payload.bought}`, true)
		end
	end)

	Remotes.get("ItemStateChanged").OnClientEvent:Connect(function(payload)
		if typeof(payload) ~= "table" then
			return
		end
		if typeof(payload.boostRemaining) == "number" then
			state.boostRemaining = payload.boostRemaining
		end
		if typeof(payload.slowRemaining) == "number" then
			state.slowRemaining = payload.slowRemaining
		end
		renderEffect()
	end)

	RunService.RenderStepped:Connect(function(dt)
		if state.toastUntil > 0 and os.clock() > state.toastUntil then
			toast.Text = ""
			state.toastUntil = 0
		end
		if state.boostRemaining > 0 then
			state.boostRemaining = math.max(0, state.boostRemaining - dt)
		end
		if state.slowRemaining > 0 then
			state.slowRemaining = math.max(0, state.slowRemaining - dt)
		end
		renderEffect()
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
