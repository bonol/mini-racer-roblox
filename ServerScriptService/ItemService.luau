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

type Mine = {
	part: BasePart,
	owner: Player,
	armedAt: number,
}

local ItemService = {}

local boostUntil: { [Player]: number } = {}
local slowUntil: { [Player]: number } = {}
local lastCf: { [Player]: CFrame } = {}
local mines: { Mine } = {}
local started = false
local mineFolder: Folder? = nil

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

local function ensureMineFolder(): Folder
	local folder = Workspace:FindFirstChild("KartMines")
	if folder and folder:IsA("Folder") then
		mineFolder = folder
		return folder
	end
	local created = Instance.new("Folder")
	created.Name = "KartMines"
	created.Parent = Workspace
	mineFolder = created
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

function ItemService.dropMine(player: Player)
	if not matchService().isRacing(player) then
		return
	end
	if not InventoryService.tryConsume(player, "Landmine") then
		InventoryService.reject(player, "no landmine")
		return
	end
	local cf = lastCf[player]
	local car = VehicleService.getCar(player)
	if cf == nil and car and car.PrimaryPart then
		cf = car.PrimaryPart.CFrame
	end
	if cf == nil then
		InventoryService.add(player, "Landmine", 1)
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
	part.Name = "Landmine"
	part.Size = Vector3.new(4.2, 0.7, 4.2)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.Material = Enum.Material.SmoothPlastic
	part.Color = Color3.fromRGB(40, 28, 32)
	part.CFrame = CFrame.new(pos.X, 1.55, pos.Z)
	part.Parent = ensureMineFolder()
	table.insert(mines, {
		part = part,
		owner = player,
		armedAt = now() + Constants.Items.MineArmSeconds,
	})
end

function ItemService.clearRound()
	for _, mine in mines do
		if mine.part then
			mine.part:Destroy()
		end
	end
	table.clear(mines)
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
	ensureMineFolder()

	Remotes.get("UseItem").OnServerEvent:Connect(function(player, itemId)
		if itemId == "Booster" then
			ItemService.useBooster(player)
		elseif itemId == "Landmine" then
			ItemService.dropMine(player)
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
		while i <= #mines do
			local mine = mines[i]
			if mine.part == nil or mine.part.Parent == nil then
				table.remove(mines, i)
				continue
			end
			if clock < mine.armedAt then
				i += 1
				continue
			end
			local hitPlayer: Player? = nil
			for player, cf in lastCf do
				if player == mine.owner then
					continue
				end
				if not matchService().isRacing(player) then
					continue
				end
				local p = cf.Position
				local m = mine.part.Position
				if (Vector3.new(p.X, 0, p.Z) - Vector3.new(m.X, 0, m.Z)).Magnitude <= 7 then
					hitPlayer = player
					break
				end
			end
			if hitPlayer then
				slowUntil[hitPlayer] = clock + Constants.Items.SlowSeconds
				applyMul(hitPlayer)
				fireState(hitPlayer)
				mine.part:Destroy()
				table.remove(mines, i)
			else
				i += 1
			end
		end
	end)
end

return ItemService
