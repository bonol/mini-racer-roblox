local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Remotes = require(game:GetService("ReplicatedStorage"):WaitForChild("Remotes"))

local WrongWay = {}

local SHOW_DOT = -0.22
local HIDE_DOT = 0.12
local HOLD_ON = 0.28
local HOLD_OFF = 0.35
local SEARCH_RADIUS = 140

local roads: { BasePart } = {}
local roadsAt = 0

local function flatten(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function refreshRoads()
	table.clear(roads)
	local track = Workspace:FindFirstChild("MiniRacerTrack")
	if track == nil then
		return
	end
	for _, child in track:GetChildren() do
		if child.Name == "Road" and child:IsA("BasePart") then
			table.insert(roads, child)
		end
	end
end

local function trackForwardAt(pos: Vector3): Vector3?
	if os.clock() - roadsAt > 2 or #roads == 0 then
		refreshRoads()
		roadsAt = os.clock()
	end
	local best: Vector3? = nil
	local bestDist = SEARCH_RADIUS
	local flat = flatten(pos)
	for _, road in roads do
		if road.Parent == nil then
			continue
		end
		local dist = (flatten(road.Position) - flat).Magnitude
		if dist < bestDist then
			local look = flatten(road.CFrame.LookVector)
			if look.Magnitude > 0.05 then
				bestDist = dist
				best = look.Unit
			end
		end
	end
	return best
end

local function seatedCar(player: Player): Model?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local seat = humanoid and humanoid.SeatPart
	local car = seat and seat.Parent
	if car and car:IsA("Model") and car.PrimaryPart then
		return car
	end
	return nil
end

function WrongWay.start()
	local player = Players.LocalPlayer
	local gui = Instance.new("ScreenGui")
	gui.Name = "WrongWay"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 40
	gui.Enabled = false
	gui.Parent = player:WaitForChild("PlayerGui")

	local banner = Instance.new("TextLabel")
	banner.Name = "Banner"
	banner.BackgroundColor3 = Color3.fromRGB(160, 18, 28)
	banner.BackgroundTransparency = 0.12
	banner.BorderSizePixel = 0
	banner.AnchorPoint = Vector2.new(0.5, 0.5)
	banner.Position = UDim2.fromScale(0.5, 0.38)
	banner.Size = UDim2.fromOffset(580, 120)
	banner.Font = Enum.Font.GothamBlack
	banner.Text = "WRONG WAY"
	banner.TextColor3 = Color3.fromRGB(255, 236, 80)
	banner.TextSize = 52
	banner.TextYAlignment = Enum.TextYAlignment.Top
	banner.TextStrokeTransparency = 0.35
	banner.Parent = gui
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 18)
	pad.Parent = banner
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = banner
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 220, 70)
	stroke.Thickness = 3
	stroke.Parent = banner

	local sub = Instance.new("TextLabel")
	sub.BackgroundTransparency = 1
	sub.AnchorPoint = Vector2.new(0.5, 0)
	sub.Position = UDim2.new(0.5, 0, 1, -16)
	sub.Size = UDim2.new(1, -24, 0, 22)
	sub.Font = Enum.Font.GothamBold
	sub.Text = "Turn around"
	sub.TextColor3 = Color3.fromRGB(255, 255, 255)
	sub.TextSize = 20
	sub.Parent = banner

	local racing = false
	local showing = false
	local onTime = 0
	local offTime = 0
	local pulse = 0

	Remotes.get("RaceStateChanged").OnClientEvent:Connect(function(payload)
		racing = payload.state == "Racing" and payload.spectator ~= true
		if not racing then
			showing = false
			onTime = 0
			offTime = 0
			gui.Enabled = false
		end
	end)

	RunService.RenderStepped:Connect(function(dt)
		if not racing then
			return
		end
		pulse += dt
		if showing then
			banner.BackgroundTransparency = 0.08 + 0.14 * (0.5 + 0.5 * math.sin(pulse * 10))
		end

		local car = seatedCar(player)
		if car == nil or car.PrimaryPart == nil then
			gui.Enabled = false
			showing = false
			return
		end

		local forward = trackForwardAt(car.PrimaryPart.Position)
		if forward == nil then
			return
		end
		local look = flatten(car.PrimaryPart.CFrame.LookVector)
		if look.Magnitude < 0.05 then
			return
		end
		local dot = look.Unit:Dot(forward)
		if dot < SHOW_DOT then
			onTime += dt
			offTime = 0
			if onTime >= HOLD_ON then
				showing = true
				gui.Enabled = true
			end
		elseif dot > HIDE_DOT then
			offTime += dt
			onTime = 0
			if offTime >= HOLD_OFF then
				showing = false
				gui.Enabled = false
			end
		else
			onTime = 0
		end
	end)
end

return WrongWay
