local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Constants = require(ReplicatedStorage:WaitForChild("Constants"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))
local InventoryService = require(script.Parent:WaitForChild("InventoryService"))
local VehicleService = require(script.Parent:WaitForChild("VehicleService"))

local function matchService()
	return require(script.Parent:WaitForChild("MatchService"))
end

type Bomb = {
	part: BasePart,
}

local ItemService = {}

local boostUntil: { [Player]: number } = {}
local slowUntil: { [Player]: number } = {}
local lastCf: { [Player]: CFrame } = {}
local bombs: { Bomb } = {}
local started = false
local bombFolder: Folder? = nil

local function now(): number
	return os.clock()
end

local function remaining(untilTime: number?): number
	if untilTime == nil then
		return 0
	end
	return math.max(0, untilTime - now())
end

local function speedMulFor(player: Player): number
	if remaining(slowUntil[player]) > 0 then
		return Constants.Items.SlowMul
	end
	if remaining(boostUntil[player]) > 0 then
		return Constants.Items.BoostMul
	end
	return 1
end

local function applyMul(player: Player)
	local car = VehicleService.getCar(player)
	if car then
		car:SetAttribute("SpeedMul", speedMulFor(player))
	end
end

local function fireState(player: Player)
	Remotes.get("ItemStateChanged"):FireClient(player, {
		boostRemaining = remaining(boostUntil[player]),
		slowRemaining = remaining(slowUntil[player]),
		speedMul = speedMulFor(player),
	})
end

local function surfaceY(from: Vector3): number?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude: { Instance } = {}
	if bombFolder then
		table.insert(exclude, bombFolder)
	end
	params.FilterDescendantsInstances = exclude
	local origin = from + Vector3.new(0, 12, 0)
	local hit = Workspace:Raycast(origin, Vector3.new(0, -240, 0), params)
	if hit and (hit.Instance.Name == "Road" or hit.Instance.Name == "Grass") then
		return hit.Position.Y
	end
	return nil
end

local function kartLift(pos: Vector3): number
	local ground = surfaceY(pos)
	if ground == nil then
		return 0
	end
	return math.max(0, pos.Y - ground - Constants.Car.BodyHover)
end

local function ensureBombFolder(): Folder
	local leftover = Workspace:FindFirstChild("KartMines")
	if leftover then
		leftover:Destroy()
	end
	local folder = Workspace:FindFirstChild("KartBombs")
	if folder and folder:IsA("Folder") then
		bombFolder = folder
		return folder
	end
	local created = Instance.new("Folder")
	created.Name = "KartBombs"
	created.Parent = Workspace
	bombFolder = created
	return created
end

function ItemService.notePosition(player: Player, cf: CFrame)
	lastCf[player] = cf
end

function ItemService.useBooster(player: Player)
	if not matchService().isRacing(player) then
		return
	end
	if not InventoryService.tryConsume(player, "Booster") then
		InventoryService.reject(player, "no booster")
		return
	end
	boostUntil[player] = now() + Constants.Items.BoostSeconds
	applyMul(player)
	fireState(player)
end

function ItemService.dropBomb(player: Player)
	if not matchService().isRacing(player) then
		return
	end
	if not InventoryService.tryConsume(player, "Bomb") then
		InventoryService.reject(player, "no bomb")
		return
	end
	local cf = lastCf[player]
	local car = VehicleService.getCar(player)
	if cf == nil and car and car.PrimaryPart then
		cf = car.PrimaryPart.CFrame
	end
	if cf == nil then
		InventoryService.add(player, "Bomb", 1)
		return
	end
	local look = Vector3.new(cf.LookVector.X, 0, cf.LookVector.Z)
	if look.Magnitude < 0.05 then
		look = Vector3.new(0, 0, -1)
	else
		look = look.Unit
	end
	local pos = cf.Position - look * 9
	local part = Instance.new("Part")
	part.Name = "Bomb"
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.new(5.4, 5.4, 5.4)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Material = Enum.Material.Neon
	part.Color = Color3.fromRGB(220, 40, 48)
	local groundY = surfaceY(pos) or (pos.Y - Constants.Car.BodyHover)
	part.CFrame = CFrame.new(pos.X, groundY + part.Size.Y * 0.5, pos.Z)
	part.Parent = ensureBombFolder()

	local light = Instance.new("PointLight")
	light.Brightness = 4
	light.Range = 18
	light.Color = Color3.fromRGB(255, 80, 60)
	light.Parent = part

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Label"
	billboard.Size = UDim2.fromOffset(80, 28)
	billboard.StudsOffset = Vector3.new(0, 3.4, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = part
	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.fromScale(1, 1)
	title.Font = Enum.Font.GothamBlack
	title.TextSize = 18
	title.TextColor3 = Color3.fromRGB(255, 220, 80)
	title.TextStrokeTransparency = 0.3
	title.Text = "BOMB"
	title.Parent = billboard

	table.insert(bombs, {
		part = part,
	})
end

function ItemService.clearRound()
	for _, bomb in bombs do
		if bomb.part then
			bomb.part:Destroy()
		end
	end
	table.clear(bombs)
	table.clear(boostUntil)
	table.clear(slowUntil)
	for player, _ in lastCf do
		applyMul(player)
		fireState(player)
	end
end

function ItemService.start()
	if started then
		return
	end
	started = true
	ensureBombFolder()

	Remotes.get("UseItem").OnServerEvent:Connect(function(player, itemId)
		if itemId == "Booster" then
			ItemService.useBooster(player)
		elseif itemId == "Bomb" then
			ItemService.dropBomb(player)
		end
	end)

	Remotes.get("DriveInput").OnServerEvent:Connect(function(player, cf)
		if typeof(cf) ~= "CFrame" then
			return
		end
		ItemService.notePosition(player, cf)
	end)

	RunService.Heartbeat:Connect(function()
		local clock = now()
		for player, untilTime in boostUntil do
			if clock >= untilTime then
				boostUntil[player] = nil
				applyMul(player)
				fireState(player)
			end
		end
		for player, untilTime in slowUntil do
			if clock >= untilTime then
				slowUntil[player] = nil
				applyMul(player)
				fireState(player)
			end
		end

		local i = 1
		while i <= #bombs do
			local bomb = bombs[i]
			if bomb.part == nil or bomb.part.Parent == nil then
				table.remove(bombs, i)
				continue
			end
			local hitPlayer: Player? = nil
			for player, cf in lastCf do
				if not matchService().isRacing(player) then
					continue
				end
				local p = cf.Position
				local m = bomb.part.Position
				local xz = (Vector3.new(p.X, 0, p.Z) - Vector3.new(m.X, 0, m.Z)).Magnitude
				if xz <= Constants.Items.BombRadius and kartLift(p) < Constants.Car.Height * Constants.Items.BombHeightFrac then
					hitPlayer = player
					break
				end
			end
			if hitPlayer then
				slowUntil[hitPlayer] = clock + Constants.Items.SlowSeconds
				applyMul(hitPlayer)
				fireState(hitPlayer)
				bomb.part:Destroy()
				table.remove(bombs, i)
			else
				i += 1
			end
		end
	end)
end

return ItemService
