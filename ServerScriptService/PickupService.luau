local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Constants = require(ReplicatedStorage:WaitForChild("Constants"))
local InventoryService = require(script.Parent:WaitForChild("InventoryService"))
local TrackService = require(script.Parent:WaitForChild("TrackService"))

local function matchService()
	return require(script.Parent:WaitForChild("MatchService"))
end

local TAG = "ItemPickup"
local COLORS = {
	Booster = Color3.fromRGB(255, 186, 48),
	Bomb = Color3.fromRGB(220, 70, 80),
}

type Pad = {
	part: BasePart,
	checkpoint: BasePart,
	live: boolean,
	touching: { [Player]: boolean },
}

local PickupService = {}

local pads: { Pad } = {}
local started = false

local function randomItem(): string
	return if math.random() < 0.5 then "Booster" else "Bomb"
end

local function stylePad(part: BasePart, itemId: string)
	part:SetAttribute("ItemId", itemId)
	part.Color = COLORS[itemId] or Color3.fromRGB(180, 180, 190)
	part.Name = "Pickup_" .. itemId
	local label = part:FindFirstChild("Label")
	if label and label:IsA("BillboardGui") then
		local title = label:FindFirstChild("Title")
		if title and title:IsA("TextLabel") then
			title.Text = itemId
		end
	end
end

local function pointInPad(part: BasePart, pos: Vector3): boolean
	local rel = part.CFrame:PointToObjectSpace(pos)
	local half = part.Size * 0.5
	return math.abs(rel.X) <= half.X + 2
		and math.abs(rel.Y) <= half.Y + 6
		and math.abs(rel.Z) <= half.Z + 2
end

local function restock(pad: Pad)
	stylePad(pad.part, randomItem())
	pad.part.Transparency = 0.15
	pad.live = true
	table.clear(pad.touching)
end

local function collect(pad: Pad, player: Player)
	if not pad.live then
		return
	end
	if pad.touching[player] then
		return
	end
	pad.touching[player] = true
	if not matchService().isRacing(player) then
		return
	end
	local itemId = pad.part:GetAttribute("ItemId")
	if typeof(itemId) ~= "string" then
		return
	end
	pad.live = false
	pad.part.Transparency = 1
	InventoryService.add(player, itemId, 1, "pickup")
	task.delay(Constants.Items.PickupRespawnSeconds, function()
		if pad.part.Parent then
			restock(pad)
		end
	end)
end

local function makePad(checkpoint: BasePart, folder: Folder): Pad
	local part = Instance.new("Part")
	part.Size = Vector3.new(7, 3.2, 7)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.Material = Enum.Material.Neon
	part.CFrame = checkpoint.CFrame * CFrame.new(0, 1.2, -10)
	part.Parent = folder
	CollectionService:AddTag(part, TAG)

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Label"
	billboard.Size = UDim2.fromOffset(140, 36)
	billboard.StudsOffset = Vector3.new(0, 3.2, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = part
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Size = UDim2.fromScale(1, 1)
	title.Font = Enum.Font.GothamBold
	title.TextSize = 18
	title.TextColor3 = Color3.new(1, 1, 1)
	title.TextStrokeTransparency = 0.4
	title.Text = "Booster"
	title.Parent = billboard

	local pad: Pad = {
		part = part,
		checkpoint = checkpoint,
		live = true,
		touching = {},
	}
	restock(pad)
	return pad
end

function PickupService.consider(player: Player, prev: Vector3, pos: Vector3)
	local dist = (pos - prev).Magnitude
	local steps = math.max(1, math.ceil(dist / 2))
	for _, pad in pads do
		local hit = false
		for s = 1, steps do
			if pointInPad(pad.part, prev:Lerp(pos, s / steps)) then
				hit = true
				break
			end
		end
		if hit then
			collect(pad, player)
		else
			pad.touching[player] = nil
		end
	end
end

function PickupService.build()
	local existing = Workspace:FindFirstChild("KartPickups")
	if existing then
		existing:Destroy()
	end
	table.clear(pads)
	local folder = Instance.new("Folder")
	folder.Name = "KartPickups"
	for _, checkpoint in TrackService.getCheckpoints() do
		table.insert(pads, makePad(checkpoint, folder))
	end
	folder.Parent = Workspace
end

function PickupService.start()
	if started then
		return
	end
	started = true
	PickupService.build()
end

return PickupService
