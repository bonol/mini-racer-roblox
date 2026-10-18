local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Constants = require(ReplicatedStorage:WaitForChild("Constants"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))
local KartPrototype = require(ReplicatedStorage:WaitForChild("KartPrototype"))
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
local paddockHandler: ((Player, string) -> ())? = nil

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

local function spawnPaddock()
	local existing = Workspace:FindFirstChild("KartPaddock")
	if existing then
		existing:Destroy()
	end

	local folder = Instance.new("Folder")
	folder.Name = "KartPaddock"

	local palettes = KartPrototype.Palettes
	for i, palette in palettes do
		local car = KartPrototype.spawn(palette)
		KartPrototype.makeDisplay(car)
		car.Name = "Kart_" .. palette.Id
		local at = TrackService.getPaddockCFrame(i, #palettes)
		car:PivotTo(at)

		local body = car.PrimaryPart
		if body then
			body.CanQuery = true
			local click = Instance.new("ClickDetector")
			click.Name = "ChooseKart"
			click.MaxActivationDistance = 36
			click.Parent = body
			click.MouseClick:Connect(function(who)
				if paddockHandler then
					paddockHandler(who, palette.Id)
				end
			end)
		end

		car.Parent = folder
	end

	folder.Parent = Workspace
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
	KartPrototype.ensureTemplate()
	spawnPaddock()
	inputConnection = Remotes.get("DriveInput").OnServerEvent:Connect(function() end)
end

function VehicleService.setPaddockHandler(handler: (Player, string) -> ())
	paddockHandler = handler
end

function VehicleService.sendToPlaza(player: Player)
	local character = player.Character
	if character == nil then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		restoreHumanoid(humanoid)
		humanoid.Sit = false
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		root.CFrame = TrackService.getPlazaSpawnCFrame()
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
	end
end

function VehicleService.freezeForSelect(player: Player)
	VehicleService.sendToPlaza(player)
end

function VehicleService.spawnFor(player: Player, paletteId: string?, slotIndex: number?, slotCount: number?): Model
	VehicleService.despawn(player)

	local model = KartPrototype.spawn(KartPrototype.getPalette(paletteId or Constants.Car.DefaultPalette))
	model.Name = "MiniRacer_" .. player.Name
	local at = if slotIndex ~= nil
		then TrackService.getGridCFrame(slotIndex, slotCount or 1)
		else TrackService.getSpawnCFrame()
	model:PivotTo(at)
	model.Parent = Workspace
	cars[player] = model
	canDrive[player] = false
	model:SetAttribute("CanDrive", false)
	model:SetAttribute("SpeedMul", 1)
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
