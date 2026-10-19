local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
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

local function applyLighting(theme)
	local spec = theme.Lighting
	Lighting.ClockTime = spec.ClockTime
	Lighting.Brightness = spec.Brightness
	Lighting.Ambient = spec.Ambient
	Lighting.OutdoorAmbient = spec.OutdoorAmbient
	Lighting.FogColor = spec.FogColor
	Lighting.FogStart = spec.FogStart
	Lighting.FogEnd = spec.FogEnd
	Lighting.EnvironmentDiffuseScale = spec.EnvironmentDiffuseScale or 0.5
	Lighting.EnvironmentSpecularScale = spec.EnvironmentSpecularScale or 0.5
	Lighting.ExposureCompensation = spec.ExposureCompensation or 0
	if theme.World.Gate == "Portal" then
		Lighting.ColorShift_Top = Color3.fromRGB(90, 190, 255)
		Lighting.ColorShift_Bottom = Color3.fromRGB(50, 20, 90)
	else
		Lighting.ColorShift_Top = Color3.fromRGB(196, 214, 235)
		Lighting.ColorShift_Bottom = Color3.fromRGB(78, 110, 64)
	end

	local atmos = Lighting:FindFirstChildOfClass("Atmosphere")
	if spec.Atmosphere then
		if atmos == nil then
			atmos = Instance.new("Atmosphere")
			atmos.Name = "MiniRacerAtmosphere"
			atmos.Parent = Lighting
		end
		atmos.Density = spec.Atmosphere.Density
		atmos.Offset = spec.Atmosphere.Offset or 0
		atmos.Color = spec.Atmosphere.Color
		atmos.Decay = spec.Atmosphere.Decay
		atmos.Haze = spec.Atmosphere.Haze
		atmos.Glare = spec.Atmosphere.Glare
	elseif atmos then
		atmos:Destroy()
	end

	local sky = Lighting:FindFirstChildOfClass("Sky")
	if sky == nil then
		sky = Instance.new("Sky")
		sky.Name = "MiniRacerSky"
		sky.Parent = Lighting
	end
	local portal = theme.World.Gate == "Portal"
	sky.CelestialBodiesShown = true
	sky.StarCount = if portal then 3000 else 0
	sky.SunAngularSize = if portal then 0 else 12
	sky.MoonAngularSize = if portal then 0 else 0
	local faces = theme.Sky
	if faces then
		if faces.Bk ~= "" then
			sky.SkyboxBk = faces.Bk
		end
		if faces.Dn ~= "" then
			sky.SkyboxDn = faces.Dn
		end
		if faces.Ft ~= "" then
			sky.SkyboxFt = faces.Ft
		end
		if faces.Lf ~= "" then
			sky.SkyboxLf = faces.Lf
		end
		if faces.Rt ~= "" then
			sky.SkyboxRt = faces.Rt
		end
		if faces.Up ~= "" then
			sky.SkyboxUp = faces.Up
		end
	end
end

local function paintFolders(theme)
	for _, folderName in { "MiniRacerTrack", "KartPlaza", "KartGrid" } do
		local folder = Workspace:FindFirstChild(folderName)
		if folder then
			for _, instance in folder:GetDescendants() do
				if instance:IsA("BasePart") then
					local role = colorRole(instance)
					local color = theme.Colors[role]
					if color then
						instance.Color = color
					end
					local material = theme.Materials[role]
					if material then
						instance.Material = material
					end
				end
			end
		end
	end
	for _, instance in CollectionService:GetTagged(IMAGE_TAG) do
		applyImage(instance, theme)
	end
end

local function apply(theme)
	Workspace:SetAttribute("MiniRacerThemeId", theme.Id)
	applyLighting(theme)
	paintFolders(theme)
	local TrackService = require(script.Parent:WaitForChild("TrackService"))
	TrackService.applyThemeWorld(theme.Id)
	paintFolders(theme)
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
