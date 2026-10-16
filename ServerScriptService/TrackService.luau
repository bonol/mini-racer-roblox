local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local Constants = require(game:GetService("ReplicatedStorage"):WaitForChild("Constants"))

local TrackService = {}

-- Clockwise GP: pit start/finish, T1, south esses (clear of the pit), west hairpin,
-- then a right-hander onto the pit before the start/finish stripe.
local CONTROL = {
	Vector3.new(-900, 0, 140),
	Vector3.new(-620, 0, 140),
	Vector3.new(-240, 0, 140),
	Vector3.new(120, 0, 140),
	Vector3.new(360, 0, 140),
	Vector3.new(500, 0, 110),
	Vector3.new(580, 0, 20),
	Vector3.new(560, 0, -90),
	Vector3.new(460, 0, -180),
	Vector3.new(280, 0, -240),
	Vector3.new(40, 0, -250),
	Vector3.new(-180, 0, -210),
	Vector3.new(-380, 0, -90),
	Vector3.new(-560, 0, -50),
	Vector3.new(-740, 0, -130),
	Vector3.new(-920, 0, -210),
	Vector3.new(-1120, 0, -220),
	Vector3.new(-1280, 0, -210),
	Vector3.new(-1420, 0, -190),
	Vector3.new(-1540, 0, -120),
	Vector3.new(-1640, 0, 30),
	Vector3.new(-1540, 0, 160),
	Vector3.new(-1420, 0, 250),
	Vector3.new(-1320, 0, 248),
	Vector3.new(-1200, 0, 230),
	Vector3.new(-1100, 0, 195),
	Vector3.new(-1020, 0, 160),
	Vector3.new(-960, 0, 144),
}

local function wrap(points: { Vector3 }, index: number): Vector3
	local n = #points
	return points[((index - 1) % n) + 1]
end

local function heading(from: Vector3, to: Vector3): Vector3
	local delta = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
	if delta.Magnitude < 0.05 then
		return Vector3.new(1, 0, 0)
	end
	return delta.Unit
end

local function leftNormal(look: Vector3): Vector3
	return Vector3.new(-look.Z, 0, look.X)
end

local function pitStraightSpawn(centerline: { Vector3 }): CFrame
	local ref = heading(centerline[1], centerline[2])
	local run: { { mid: Vector3, look: Vector3 } } = {}
	for i = 1, #centerline do
		local a = centerline[i]
		local b = wrap(centerline, i + 1)
		local look = heading(a, b)
		local ang = math.deg(math.acos(math.clamp(look:Dot(ref), -1, 1)))
		if ang < 8 and math.abs(a.Z - centerline[1].Z) < 20 then
			table.insert(run, {
				mid = Vector3.new((a.X + b.X) * 0.5, 1.2, (a.Z + b.Z) * 0.5),
				look = look,
			})
		elseif #run > 6 then
			break
		end
	end
	if #run == 0 then
		local a = centerline[1]
		return CFrame.lookAt(Vector3.new(a.X, 1.2, a.Z), Vector3.new(a.X, 1.2, a.Z) + ref)
	end
	local mid = run[math.clamp(math.floor(#run * 0.5), 1, #run)]
	return CFrame.lookAt(mid.mid, mid.mid + mid.look)
end

local function catmull(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: number): Vector3
	local t2 = t * t
	local t3 = t2 * t
	return 0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3)
end

local function sampleCenterline(): { Vector3 }
	local points = {}
	local spacing = 8
	for i = 1, #CONTROL do
		local p0 = wrap(CONTROL, i - 1)
		local p1 = wrap(CONTROL, i)
		local p2 = wrap(CONTROL, i + 1)
		local p3 = wrap(CONTROL, i + 2)
		local chord = (p2 - p1).Magnitude
		local steps = math.max(4, math.ceil(chord / spacing))
		for s = 0, steps - 1 do
			table.insert(points, catmull(p0, p1, p2, p3, s / steps))
		end
	end
	return points
end

local function part(props: { [string]: any }): Part
	local instance = Instance.new("Part")
	instance.Anchored = true
	instance.CanCollide = true
	instance.TopSurface = Enum.SurfaceType.Smooth
	instance.BottomSurface = Enum.SurfaceType.Smooth
	instance.Material = Enum.Material.Concrete
	for key, value in props do
		(instance :: any)[key] = value
	end
	return instance
end

-- Constant-width offset of a closed centerline. Miters joints so rails stay continuous.
local function offsetLoop(centerline: { Vector3 }, dist: number): { Vector3 }
	local pts = {}
	for i = 1, #centerline do
		local p = centerline[i]
		local tin = heading(wrap(centerline, i - 1), p)
		local tout = heading(p, wrap(centerline, i + 1))
		local nIn = leftNormal(tin)
		local nOut = leftNormal(tout)
		local bis = nIn + nOut
		local offset: Vector3
		if bis.Magnitude < 0.2 then
			offset = nOut * dist
		else
			bis = bis.Unit
			local denom = bis:Dot(nOut)
			local scale = if math.abs(denom) > 0.22 then dist / denom else dist
			local limit = math.abs(dist) * 2.4
			scale = math.clamp(scale, -limit, limit)
			offset = bis * scale
		end
		table.insert(pts, Vector3.new(p.X + offset.X, 0, p.Z + offset.Z))
	end
	return pts
end

local function placeStrip(
	points: { Vector3 },
	name: string,
	sizeX: number,
	sizeY: number,
	y: number,
	colorFor: (number) -> Color3,
	material: Enum.Material,
	canCollide: boolean,
	extra: number,
	parent: Instance
)
	local created = 0
	for i = 1, #points do
		local a = points[i]
		local b = wrap(points, i + 1)
		local dx, dz = b.X - a.X, b.Z - a.Z
		local len = math.sqrt(dx * dx + dz * dz)
		if len < 0.45 then
			continue
		end
		local mid = Vector3.new((a.X + b.X) * 0.5, y, (a.Z + b.Z) * 0.5)
		part({
			Name = name,
			Size = Vector3.new(sizeX, sizeY, len + extra),
			CFrame = CFrame.lookAt(mid, Vector3.new(b.X, y, b.Z)),
			Color = colorFor(i),
			Material = material,
			CanCollide = canCollide,
			Parent = parent,
		})
		created += 1
		if created % 40 == 0 then
			task.wait()
		end
	end
end

local function hideDefaultSpawn(spawnCFrame: CFrame)
	local spawn = Workspace:FindFirstChild("SpawnLocation")
	if spawn and spawn:IsA("SpawnLocation") then
		spawn.Enabled = true
		spawn.Duration = 0
		spawn.CanCollide = false
		spawn.Transparency = 1
		spawn.Size = Vector3.new(6, 1, 6)
		spawn.CFrame = spawnCFrame + Vector3.new(0, 2, 0)
		local decal = spawn:FindFirstChildOfClass("Decal")
		if decal then
			decal.Transparency = 1
		end
	end
end

local function hideBaseplate()
	local baseplate = Workspace:FindFirstChild("Baseplate")
	if baseplate and baseplate:IsA("BasePart") then
		baseplate.Transparency = 1
		baseplate.CanCollide = false
	end
end

local function checkpoint(index: number, at: CFrame, width: number): Part
	local isFinish = index == Constants.Race.CheckpointCount
	local marker = part({
		Name = if isFinish then "Finish" else `Checkpoint{index}`,
		Size = Vector3.new(width + 6, 14, 4),
		CFrame = at + Vector3.new(0, 7, 0),
		Color = if isFinish then Color3.fromRGB(240, 240, 240) else Color3.fromRGB(80, 200, 120),
		-- Sector gates stay in the world for later pickups; only start/finish is drawn.
		Transparency = if isFinish then 0.72 else 1,
		CastShadow = isFinish,
		CanCollide = false,
		CanQuery = false,
		Material = Enum.Material.Neon,
	})
	marker:SetAttribute("Index", index)
	CollectionService:AddTag(marker, Constants.Track.CheckpointTag)
	return marker
end

local function build()
	local existing = Workspace:FindFirstChild("MiniRacerTrack")
	if existing then
		existing:Destroy()
	end

	local model = Instance.new("Model")
	model.Name = "MiniRacerTrack"

	local centerline = sampleCenterline()
	local width = Constants.Track.RoadWidth
	local railHeight = Constants.Track.BarrierHeight
	local created = 0

	local minX, maxX, minZ, maxZ = CONTROL[1].X, CONTROL[1].X, CONTROL[1].Z, CONTROL[1].Z
	for _, p in CONTROL do
		minX = math.min(minX, p.X)
		maxX = math.max(maxX, p.X)
		minZ = math.min(minZ, p.Z)
		maxZ = math.max(maxZ, p.Z)
	end
	-- Roblox parts cap at 2048; overlap tiles so seams do not drop the car.
	local pad = 220
	local tile = 2000
	local seam = 6
	local x0, x1 = minX - pad, maxX + pad
	local z0, z1 = minZ - pad, maxZ + pad
	local gx = x0
	while gx < x1 do
		local gz = z0
		local w = math.min(tile, x1 - gx)
		while gz < z1 do
			local d = math.min(tile, z1 - gz)
			if w > 8 and d > 8 then
				part({
					Name = "Grass",
					Size = Vector3.new(w, 1, d),
					Position = Vector3.new(gx + w * 0.5, 0.4, gz + d * 0.5),
					Color = Color3.fromRGB(46, 112, 52),
					Material = Enum.Material.Grass,
					Parent = model,
				})
			end
			gz += math.max(d - seam, d)
			if d <= seam then
				break
			end
		end
		gx += math.max(w - seam, w)
		if w <= seam then
			break
		end
	end

	local lengths = {}
	local total = 0
	for i = 1, #centerline do
		local a = centerline[i]
		local b = wrap(centerline, i + 1)
		local len = (Vector3.new(b.X, 0, b.Z) - Vector3.new(a.X, 0, a.Z)).Magnitude
		table.insert(lengths, len)
		total += len
	end

	local acc = 0
	local spawnCFrame = pitStraightSpawn(centerline)
	local checkpointAt = {
		[1] = total * 0.25,
		[2] = total * 0.5,
		[3] = total * 0.75,
	}
	local placed = {}

	for i = 1, #centerline do
		local a = centerline[i]
		local b = wrap(centerline, i + 1)
		local p0 = Vector3.new(a.X, 1.2, a.Z)
		local p1 = Vector3.new(b.X, 1.2, b.Z)
		local delta = p1 - p0
		local length = delta.Magnitude
		if length < 1 then
			continue
		end

		local mid = (p0 + p1) * 0.5
		local look = CFrame.lookAt(mid, p1)
		local prevLook = heading(wrap(centerline, i - 1), a)
		local thisLook = heading(a, b)
		local turnAng = math.deg(math.acos(math.clamp(prevLook:Dot(thisLook), -1, 1)))
		-- Overlap wide planks on turns so end-caps do not fan into a broken floor.
		local overlap = math.clamp(width * math.tan(math.rad(math.max(turnAng, 1.5)) * 0.5), 2, width * 0.42)

		part({
			Name = "Road",
			Size = Vector3.new(width, 1.2, length + overlap),
			CFrame = look,
			Color = Color3.fromRGB(36, 38, 42),
			Material = Enum.Material.Asphalt,
			Parent = model,
		})

		acc += lengths[i]
		for index, along in checkpointAt do
			if placed[index] == nil and acc >= along then
				local gate = checkpoint(index, look, width)
				gate.Parent = model
				placed[index] = true
			end
		end

		created += 1
		if created % 40 == 0 then
			task.wait()
		end
	end

	local half = width * 0.5
	local kerbColor = function(i: number): Color3
		return if i % 2 == 0 then Color3.fromRGB(230, 230, 230) else Color3.fromRGB(200, 40, 40)
	end
	local railColor = function(_: number): Color3
		return Color3.fromRGB(196, 200, 210)
	end

	placeStrip(offsetLoop(centerline, half - 1.1), "Kerb", 2.2, 0.35, 1.9, kerbColor, Enum.Material.SmoothPlastic, false, 0.9, model)
	placeStrip(offsetLoop(centerline, -(half - 1.1)), "Kerb", 2.2, 0.35, 1.9, kerbColor, Enum.Material.SmoothPlastic, false, 0.9, model)
	placeStrip(offsetLoop(centerline, half + 1.6), "Barrier", 1.6, railHeight, railHeight / 2 - 0.2, railColor, Enum.Material.Metal, true, 1.35, model)
	placeStrip(offsetLoop(centerline, -(half + 1.6)), "Barrier", 1.6, railHeight, railHeight / 2 - 0.2, railColor, Enum.Material.Metal, true, 1.35, model)

	local spawn = part({
		Name = "StartSpawn",
		Size = Vector3.new(width - 6, 0.28, 5),
		CFrame = spawnCFrame + Vector3.new(0, 0.85, 0),
		Color = Color3.fromRGB(255, 220, 70),
		CanCollide = false,
		CanQuery = false,
		Material = Enum.Material.SmoothPlastic,
		Parent = model,
	})
	CollectionService:AddTag(spawn, Constants.Track.SpawnTag)

	local finish = checkpoint(Constants.Race.CheckpointCount, spawnCFrame, width)
	finish.Size = Vector3.new(width + 2, 8, 1.6)
	finish.Transparency = 0.82
	finish.Parent = model

	hideDefaultSpawn(spawn.CFrame)
	hideBaseplate()

	model.Parent = Workspace
end

function TrackService.buildIfNeeded()
	if Workspace:FindFirstChild("MiniRacerTrack") then
		return
	end
	build()
end

function TrackService.rebuild()
	build()
end

function TrackService.getSpawnCFrame(): CFrame
	local tagged = CollectionService:GetTagged(Constants.Track.SpawnTag)
	if #tagged > 0 then
		local spawn = tagged[1] :: BasePart
		return spawn.CFrame + Vector3.new(0, Constants.Car.SpawnHeight, 0)
	end
	return CFrame.new(-300, Constants.Car.SpawnHeight, 140)
end

function TrackService.getCheckpoints(): { BasePart }
	local parts = {}
	for _, instance in CollectionService:GetTagged(Constants.Track.CheckpointTag) do
		if instance:IsA("BasePart") then
			table.insert(parts, instance)
		end
	end
	table.sort(parts, function(a, b)
		return (a:GetAttribute("Index") :: number) < (b:GetAttribute("Index") :: number)
	end)
	return parts
end

return TrackService
