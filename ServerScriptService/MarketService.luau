local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage:WaitForChild("Constants"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))
local TrackService = require(script.Parent:WaitForChild("TrackService"))
local CreditService = require(script.Parent:WaitForChild("CreditService"))
local InventoryService = require(script.Parent:WaitForChild("InventoryService"))
local MatchService = require(script.Parent:WaitForChild("MatchService"))

local MarketService = {}

local COLORS = {
	Booster = Color3.fromRGB(255, 186, 48),
	Landmine = Color3.fromRGB(220, 70, 80),
}

local function catalogItem(itemId: string): { Id: string, Name: string, Cost: number }?
	for _, item in Constants.Shop.Items do
		if item.Id == itemId then
			return item
		end
	end
	return nil
end

function MarketService.tryBuy(player: Player, itemId: any)
	if typeof(itemId) ~= "string" then
		return
	end
	local item = catalogItem(itemId)
	if item == nil then
		InventoryService.reject(player, "unknown item")
		return
	end
	local state = MatchService.getState()
	if Constants.Shop.OpenStates[state] ~= true then
		InventoryService.reject(player, "shop closed")
		return
	end
	if CreditService.get(player) < item.Cost then
		InventoryService.reject(player, `need {item.Cost}`)
		return
	end
	if not CreditService.trySpend(player, item.Cost) then
		InventoryService.reject(player, `need {item.Cost}`)
		return
	end
	InventoryService.add(player, item.Id, 1)
end

local function makeStall(folder: Folder, item: { Id: string, Name: string, Cost: number }, at: CFrame)
	local part = Instance.new("Part")
	part.Name = "Stall_" .. item.Id
	part.Size = Vector3.new(7, 5, 7)
	part.Anchored = true
	part.CanCollide = false
	part.Material = Enum.Material.SmoothPlastic
	part.Color = COLORS[item.Id] or Color3.fromRGB(180, 180, 190)
	part.CFrame = at
	part.Parent = folder

	local click = Instance.new("ClickDetector")
	click.Name = "Buy"
	click.MaxActivationDistance = 160
	click.Parent = part
	click.MouseClick:Connect(function(who)
		MarketService.tryBuy(who, item.Id)
	end)

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Label"
	billboard.Size = UDim2.fromOffset(180, 64)
	billboard.StudsOffset = Vector3.new(0, 4.6, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = part

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, 0, 0.55, 0)
	title.Font = Enum.Font.GothamBold
	title.TextSize = 22
	title.TextColor3 = Color3.new(1, 1, 1)
	title.TextStrokeTransparency = 0.4
	title.Text = item.Name
	title.Parent = billboard

	local cost = Instance.new("TextLabel")
	cost.BackgroundTransparency = 1
	cost.Position = UDim2.fromScale(0, 0.5)
	cost.Size = UDim2.new(1, 0, 0.5, 0)
	cost.Font = Enum.Font.Gotham
	cost.TextSize = 18
	cost.TextColor3 = Color3.fromRGB(255, 236, 140)
	cost.TextStrokeTransparency = 0.45
	cost.Text = `{item.Cost} cr`
	cost.Parent = billboard
end

local function spawnStalls()
	local existing = Workspace:FindFirstChild("KartMarket")
	if existing then
		existing:Destroy()
	end

	local folder = Instance.new("Folder")
	folder.Name = "KartMarket"
	local origin = TrackService.getSpawnCFrame()
	for i, item in Constants.Shop.Items do
		local along = (i - 1) * 12
		local at = origin * CFrame.new(-48, 2.6, 8 + along)
		makeStall(folder, item, at)
	end
	folder.Parent = Workspace
end

function MarketService.start()
	spawnStalls()
	Remotes.get("BuyItem").OnServerEvent:Connect(function(player, itemId)
		MarketService.tryBuy(player, itemId)
	end)
end

return MarketService
