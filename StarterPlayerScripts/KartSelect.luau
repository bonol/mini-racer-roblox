local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Remotes = require(game:GetService("ReplicatedStorage"):WaitForChild("Remotes"))
local KartPrototype = require(game:GetService("ReplicatedStorage"):WaitForChild("KartPrototype"))

local KartSelect = {}

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
	return c
end

local function stroke(parent: Instance, color: Color3, thickness: number): UIStroke
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
	return s
end

function KartSelect.start()
	local player = Players.LocalPlayer
	local gui = Instance.new("ScreenGui")
	gui.Name = "KartSelect"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 20
	gui.Enabled = false
	gui.Parent = player:WaitForChild("PlayerGui")

	local dim = Instance.new("Frame")
	dim.Name = "Dim"
	dim.BackgroundColor3 = Color3.fromRGB(6, 10, 18)
	dim.BackgroundTransparency = 1
	dim.Active = false
	dim.BorderSizePixel = 0
	dim.Size = UDim2.fromScale(1, 1)
	dim.Parent = gui

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.AnchorPoint = Vector2.new(0.5, 0)
	title.Position = UDim2.fromScale(0.5, 0.02)
	title.Size = UDim2.fromOffset(420, 28)
	title.Font = Enum.Font.GothamBlack
	title.Text = "CHOOSE YOUR RACER"
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.TextSize = 22
	title.TextStrokeTransparency = 0.5
	title.Parent = gui

	local subtitle = Instance.new("TextLabel")
	subtitle.BackgroundTransparency = 1
	subtitle.AnchorPoint = Vector2.new(0.5, 0)
	subtitle.Position = UDim2.fromScale(0.5, 0.055)
	subtitle.Size = UDim2.fromOffset(520, 18)
	subtitle.Font = Enum.Font.Gotham
	subtitle.Text = "Walk the shop · click a kart · sit before green"
	subtitle.TextColor3 = Color3.fromRGB(200, 208, 220)
	subtitle.TextSize = 13
	subtitle.Parent = gui

	local clock = Instance.new("TextLabel")
	clock.Name = "Clock"
	clock.BackgroundColor3 = Color3.fromRGB(12, 16, 24)
	clock.BackgroundTransparency = 0.25
	clock.AnchorPoint = Vector2.new(1, 0)
	clock.Position = UDim2.new(1, -16, 0, 12)
	clock.Size = UDim2.fromOffset(56, 32)
	clock.Font = Enum.Font.GothamBlack
	clock.Text = "20"
	clock.TextColor3 = Color3.fromRGB(255, 220, 80)
	clock.TextSize = 22
	clock.TextStrokeTransparency = 0.45
	clock.Parent = gui
	corner(clock, 8)

	local dock = Instance.new("Frame")
	dock.Name = "Dock"
	dock.BackgroundColor3 = Color3.fromRGB(8, 12, 20)
	dock.BackgroundTransparency = 0.35
	dock.BorderSizePixel = 0
	dock.AnchorPoint = Vector2.new(0.5, 1)
	dock.Position = UDim2.new(0.5, 0, 1, -12)
	dock.Size = UDim2.fromOffset(520, 124)
	dock.Parent = gui
	corner(dock, 12)

	local row = Instance.new("Frame")
	row.Name = "Row"
	row.BackgroundTransparency = 1
	row.AnchorPoint = Vector2.new(0.5, 0.5)
	row.Position = UDim2.fromScale(0.5, 0.5)
	row.Size = UDim2.new(1, -12, 1, -8)
	row.Parent = dock

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 8)
	layout.Parent = row

	local chosen = false
	local function pick(id: string)
		if chosen or gui.Enabled == false then
			return
		end
		chosen = true
		subtitle.Text = "Waiting for others"
		Remotes.get("SelectKart"):FireServer(id)
	end

	for index, palette in KartPrototype.Palettes do
		local card = Instance.new("TextButton")
		card.Name = palette.Id
		card.AutoButtonColor = false
		card.BackgroundColor3 = palette.Body
		card.BorderSizePixel = 0
		card.Size = UDim2.fromOffset(75, 105)
		card.Text = ""
		card.Parent = row
		corner(card, 8)
		local isDefault = palette.Id == "Default"
		local border = stroke(card, if isDefault then Color3.fromRGB(255, 220, 80) else Color3.fromRGB(255, 255, 255), if isDefault then 2 else 0)
		border.Transparency = if isDefault then 0 else 0.7

		local stripe = Instance.new("Frame")
		stripe.BackgroundColor3 = palette.Stripe
		stripe.BorderSizePixel = 0
		stripe.Size = UDim2.new(1, 0, 0, 8)
		stripe.Parent = card
		local stripeCorner = Instance.new("UICorner")
		stripeCorner.CornerRadius = UDim.new(0, 8)
		stripeCorner.Parent = stripe

		local rear = Instance.new("Frame")
		rear.BackgroundColor3 = palette.Rear
		rear.BorderSizePixel = 0
		rear.AnchorPoint = Vector2.new(0.5, 0)
		rear.Position = UDim2.new(0.5, 0, 0, 8)
		rear.Size = UDim2.new(0.7, 0, 0, 5)
		rear.Parent = card

		local rim = Instance.new("Frame")
		rim.BackgroundColor3 = palette.Rim
		rim.BorderSizePixel = 0
		rim.AnchorPoint = Vector2.new(0.5, 0.5)
		rim.Position = UDim2.new(0.5, 0, 0.5, 2)
		rim.Size = UDim2.fromOffset(26, 26)
		rim.Parent = card
		corner(rim, 13)
		stroke(rim, palette.Tire, 4)

		local name = Instance.new("TextLabel")
		name.BackgroundTransparency = 1
		name.AnchorPoint = Vector2.new(0.5, 1)
		name.Position = UDim2.new(0.5, 0, 1, -4)
		name.Size = UDim2.new(1, -6, 0, 16)
		name.Font = Enum.Font.GothamBold
		name.Text = palette.Name
		name.TextColor3 = Color3.fromRGB(255, 255, 255)
		name.TextSize = 11
		name.TextStrokeTransparency = 0.4
		name.Parent = card

		local badge = Instance.new("TextLabel")
		badge.BackgroundColor3 = Color3.fromRGB(12, 16, 24)
		badge.BackgroundTransparency = 0.2
		badge.Position = UDim2.fromOffset(4, 12)
		badge.Size = UDim2.fromOffset(16, 16)
		badge.Font = Enum.Font.GothamBlack
		badge.Text = tostring(index)
		badge.TextColor3 = Color3.fromRGB(255, 255, 255)
		badge.TextSize = 10
		badge.Parent = card
		corner(badge, 4)

		card.MouseEnter:Connect(function()
			border.Thickness = 2
			border.Transparency = 0
			card.Size = UDim2.fromOffset(79, 110)
		end)
		card.MouseLeave:Connect(function()
			if isDefault then
				border.Thickness = 2
				border.Transparency = 0
			else
				border.Thickness = 0
				border.Transparency = 0.7
			end
			card.Size = UDim2.fromOffset(75, 105)
		end)
		card.MouseButton1Click:Connect(function()
			pick(palette.Id)
		end)
	end

	Remotes.get("RaceStateChanged").OnClientEvent:Connect(function(payload)
		if payload.state == "Selecting" then
			gui.Enabled = true
			if payload.locked then
				chosen = true
				subtitle.Text = "Waiting for others"
			else
				chosen = false
				subtitle.Text = "Walk the shop · click a kart · sit before green"
			end
			local remaining = payload.selectRemaining
			if typeof(remaining) == "number" then
				clock.Text = tostring(remaining)
				if remaining <= 5 then
					clock.TextColor3 = Color3.fromRGB(255, 90, 80)
				else
					clock.TextColor3 = Color3.fromRGB(255, 220, 80)
				end
			end
		else
			gui.Enabled = false
		end
	end)

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or gui.Enabled == false then
			return
		end
		local map = {
			[Enum.KeyCode.One] = 1,
			[Enum.KeyCode.Two] = 2,
			[Enum.KeyCode.Three] = 3,
			[Enum.KeyCode.Four] = 4,
			[Enum.KeyCode.Five] = 5,
			[Enum.KeyCode.Six] = 6,
		}
		local index = map[input.KeyCode]
		if index then
			local palette = KartPrototype.Palettes[index]
			if palette then
				pick(palette.Id)
			end
		end
	end)
end

return KartSelect
