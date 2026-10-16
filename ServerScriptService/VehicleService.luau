local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Constants = require(game:GetService("ReplicatedStorage"):WaitForChild("Constants"))
local Remotes = require(game:GetService("ReplicatedStorage"):WaitForChild("Remotes"))
local TrackService = require(script.Parent:WaitForChild("TrackService"))

local VehicleService = {}

local DEFAULT_WALK_SPEED = 16
local DEFAULT_JUMP_POWER = 50
local DEFAULT_JUMP_HEIGHT = 7.2
local EXIT_OFFSET = 6

local cars: { [Player]: Model } = {}
local canDrive: { [Player]: boolean } = {}
local occupantConns: { [Player]: RBXScriptConnection } = {}
local promptConns: { [Player]: RBXScriptConnection } = {}
local driveConnection: RBXScriptConnection? = nil
local inputConnection: RBXScriptConnection? = nil

local function weld(a: BasePart, b: BasePart)
	local w = Instance.new("WeldConstraint")
	w.Part0 = a
	w.Part1 = b
	w.Parent = a
end

local function setCarAnchored(model: Model, anchored: boolean)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = anchored
		end
	end
end

local function restoreHumanoid(humanoid: Humanoid)
	humanoid.WalkSpeed = DEFAULT_WALK_SPEED
	humanoid.JumpPower = DEFAULT_JUMP_POWER
	humanoid.JumpHeight = DEFAULT_JUMP_HEIGHT
	humanoid.AutoRotate = true
	humanoid.PlatformStand = false
end

local function placeBesideCar(character: Model, body: BasePart)
	local root = character:FindFirstChild("HumanoidRootPart")
	if root == nil or not root:IsA("BasePart") then
		return
	end
	root.CFrame = CFrame.new(body.Position + body.CFrame.RightVector * EXIT_OFFSET + Vector3.new(0, 4, 0))
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
end

local function makeCar(): Model
	local model = Instance.new("Model")
	model.Name = Constants.Car.Name

	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = Vector3.new(4.4, 0.8, 8.4)
	body.Color = Color3.fromRGB(200, 24, 36)
	body.Material = Enum.Material.SmoothPlastic
	body.Anchored = true
	body.CanCollide = true
	body.Parent = model

	local cabin = Instance.new("Part")
	cabin.Name = "Cabin"
	cabin.Size = Vector3.new(2.6, 0.7, 2.4)
	cabin.Color = Color3.fromRGB(18, 20, 26)
	cabin.Material = Enum.Material.SmoothPlastic
	cabin.Massless = true
	cabin.CanCollide = false
	cabin.Anchored = true
	cabin.Parent = model

	local nose = Instance.new("Part")
	nose.Name = "Nose"
	nose.Size = Vector3.new(1.4, 0.4, 2.2)
	nose.Color = Color3.fromRGB(230, 230, 235)
	nose.Material = Enum.Material.SmoothPlastic
	nose.Massless = true
	nose.CanCollide = false
	nose.Anchored = true
	nose.Parent = model

	local seat = Instance.new("VehicleSeat")
	seat.Name = "Seat"
	seat.Size = Vector3.new(3.2, 0.7, 3.2)
	seat.Color = Color3.fromRGB(20, 20, 24)
	seat.HeadsUpDisplay = false
	seat.MaxSpeed = 500
	seat.Torque = 0
	seat.TurnSpeed = 0
	seat.Disabled = false
	seat.Anchored = true
	seat.Parent = model

	local wheelOffsets = {
		Vector3.new(-2.3, -0.45, 2.7),
		Vector3.new(2.3, -0.45, 2.7),
		Vector3.new(-2.3, -0.45, -2.8),
		Vector3.new(2.3, -0.45, -2.8),
	}
	for i, offset in wheelOffsets do
		local wheel = Instance.new("Part")
		wheel.Name = `Wheel{i}`
		wheel.Shape = Enum.PartType.Cylinder
		wheel.Size = Vector3.new(1.05, 1.7, 1.7)
		wheel.Color = Color3.fromRGB(24, 24, 24)
		wheel.Material = Enum.Material.Rubber
		wheel.Massless = true
		wheel.CanCollide = false
		wheel.Anchored = true
		wheel.CFrame = body.CFrame * CFrame.new(offset) * CFrame.Angles(0, 0, math.rad(90))
		wheel.Parent = model
		weld(body, wheel)
	end

	cabin.CFrame = body.CFrame * CFrame.new(0, 0.7, 0.4)
	nose.CFrame = body.CFrame * CFrame.new(0, 0.1, -4.6)
	seat.CFrame = body.CFrame * CFrame.new(0, 1.15, 0.2)
	weld(body, cabin)
	weld(body, nose)
	weld(body, seat)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "EnterCar"
	prompt.ActionText = "Drive"
	prompt.ObjectText = "Mini Racer"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 16
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.Parent = seat

	model.PrimaryPart = body
	return model
end

local function ensureDriveLoop()
	if driveConnection then
		return
	end

	-- Keep the car Anchored. Client DriveSim PivotTo's it every render frame.
	-- Writing CFrame on the server would replicate as forward hitching.
	driveConnection = RunService.Heartbeat:Connect(function()
		for _, model in cars do
			local seat = model:FindFirstChild("Seat") :: VehicleSeat
			if seat == nil then
				continue
			end
			local prompt = seat:FindFirstChild("EnterCar")
			if prompt and prompt:IsA("ProximityPrompt") then
				prompt.Enabled = seat.Occupant == nil
			end
		end
	end)
end

local function bindCar(player: Player, model: Model)
	if occupantConns[player] then
		occupantConns[player]:Disconnect()
	end
	if promptConns[player] then
		promptConns[player]:Disconnect()
	end

	local seat = model:FindFirstChild("Seat") :: VehicleSeat
	local body = model.PrimaryPart
	local prompt = seat and seat:FindFirstChild("EnterCar")

	occupantConns[player] = seat:GetPropertyChangedSignal("Occupant"):Connect(function()
		local occupant = seat.Occupant
		if occupant then
			occupant.AutoRotate = false
			if body then
				setCarAnchored(model, true)
			end
			return
		end
		if body then
			setCarAnchored(model, true)
		end
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			restoreHumanoid(humanoid)
			humanoid.Sit = false
			pcall(function()
				humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
			end)
		end
		if character and body then
			placeBesideCar(character, body)
		end
	end)

	if prompt and prompt:IsA("ProximityPrompt") then
		promptConns[player] = prompt.Triggered:Connect(function(who)
			if who ~= player then
				return
			end
			local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			if humanoid == nil or seat.Occupant ~= nil then
				return
			end
			restoreHumanoid(humanoid)
			seat:Sit(humanoid)
		end)
	end
end

function VehicleService.start()
	if inputConnection then
		return
	end
	inputConnection = Remotes.get("DriveInput").OnServerEvent:Connect(function() end)
end

function VehicleService.spawnFor(player: Player): Model
	VehicleService.despawn(player)

	local model = makeCar()
	model:PivotTo(TrackService.getSpawnCFrame())
	model.Parent = Workspace
	cars[player] = model
	canDrive[player] = false
	model:SetAttribute("CanDrive", false)
	bindCar(player, model)
	ensureDriveLoop()

	local seat = model:FindFirstChild("Seat") :: VehicleSeat
	task.spawn(function()
		for _ = 1, 25 do
			local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			if humanoid and seat then
				seat:Sit(humanoid)
				if seat.Occupant == humanoid then
					humanoid.AutoRotate = false
					break
				end
			end
			task.wait(0.12)
		end
	end)

	return model
end

function VehicleService.despawn(player: Player)
	if occupantConns[player] then
		occupantConns[player]:Disconnect()
		occupantConns[player] = nil
	end
	if promptConns[player] then
		promptConns[player]:Disconnect()
		promptConns[player] = nil
	end
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		restoreHumanoid(humanoid)
	end
	local existing = cars[player]
	if existing then
		existing:Destroy()
		cars[player] = nil
	end
	canDrive[player] = nil
end

function VehicleService.setDrivingEnabled(player: Player, enabled: boolean)
	canDrive[player] = enabled
	local model = cars[player]
	if model then
		model:SetAttribute("CanDrive", enabled)
	end
end

function VehicleService.getCar(player: Player): Model?
	return cars[player]
end

return VehicleService
