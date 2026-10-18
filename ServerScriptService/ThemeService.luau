local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local TrackThemes = require(ReplicatedStorage:WaitForChild("TrackThemes"))

local ThemeService = {}

local IMAGE_TAG = "MiniRacerThemeImage"
local currentIndex = 1
local started = false

local function colorRole(part: BasePart): string
	local role = part:GetAttribute("ThemeColorRole")
	if typeof(role) == "string" then
		return role
	end
	if part.Name == "Kerb" then
		local index = part:GetAttribute("ThemeIndex")
		return if typeof(index) == "number" and index % 2 == 0 then "KerbB" else "KerbA"
	end
	if string.sub(part.Name, 1, 10) == "Checkpoint" then
		return "Checkpoint"
	end
	return part.Name
end

local function imageId(theme, slot: string, sponsorId: string?): string
	if slot == "Sponsor" then
		return theme.Sponsors[sponsorId or ""] or ""
	end
	return theme.Images[slot] or ""
end

local function applyImage(instance: Instance, theme)
	local slot = instance:GetAttribute("ThemeImageSlot")
	if typeof(slot) ~= "string" then
		return
	end
	local sponsorId = instance:GetAttribute("SponsorId")
	local id = imageId(theme, slot, if typeof(sponsorId) == "string" then sponsorId else nil)
	if instance:IsA("Decal") or instance:IsA("Texture") then
		instance.Texture = id
		instance.Transparency = if id == "" then 1 else 0
	elseif instance:IsA("ImageLabel") then
		instance.Image = id
		instance.ImageTransparency = if id == "" then 1 else 0
	end
end

local function apply(theme)
	for _, folderName in { "MiniRacerTrack", "KartPlaza", "KartGrid" } do
		local folder = Workspace:FindFirstChild(folderName)
		if folder then
			for _, instance in folder:GetDescendants() do
				if instance:IsA("BasePart") then
					local color = theme.Colors[colorRole(instance)]
					if color then
						instance.Color = color
					end
				end
			end
		end
	end
	for _, instance in CollectionService:GetTagged(IMAGE_TAG) do
		applyImage(instance, theme)
	end
	Workspace:SetAttribute("MiniRacerThemeId", theme.Id)
end

function ThemeService.start()
	if started then
		return
	end
	started = true
	apply(TrackThemes.get(TrackThemes.Order[currentIndex]))
	CollectionService:GetInstanceAddedSignal(IMAGE_TAG):Connect(function(instance)
		applyImage(instance, TrackThemes.get(TrackThemes.Order[currentIndex]))
	end)
	Workspace.ChildAdded:Connect(function(instance)
		if instance.Name == "MiniRacerTrack" or instance.Name == "KartPlaza" or instance.Name == "KartGrid" then
			task.defer(function()
				apply(TrackThemes.get(TrackThemes.Order[currentIndex]))
			end)
		end
	end)
end

function ThemeService.nextRound()
	currentIndex = (currentIndex % #TrackThemes.Order) + 1
	apply(TrackThemes.get(TrackThemes.Order[currentIndex]))
end

function ThemeService.getCurrentId(): string
	return TrackThemes.Order[currentIndex]
end

return ThemeService
