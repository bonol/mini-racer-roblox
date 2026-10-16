local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local Constants = require(game:GetService("ReplicatedStorage"):WaitForChild("Constants"))

local TrackService = {}

-- Clockwise: pit straight, sharp T1 hairpin, flowing S into a sharp south
-- hairpin, then a longer west U back onto the start/finish stripe.
local CONTROL = {
	Vector3.new(-720, 0, -165),
	Vector3.new(-420, 0, -165),
	Vector3.new(-80, 0, -165),
	Vector3.new(280, 0, -165),
	Vector3.new(640, 0, -165),
	Vector3.new(980, 0, -165),
	Vector3.new(1200, 0, -165),
	Vector3.new(1330, 0, -165),
	-- Sharp T1 hairpin
	Vector3.new(1410, 0, -185),
	Vector3.new(1445, 0, -250),
	Vector3.new(1410, 0, -315),
	Vector3.new(1330, 0, -335),
	Vector3.new(1200, 0, -340),
	Vector3.new(980, 0, -360),
	Vector3.new(740, 0, -470),
	Vector3.new(500, 0, -555),
	Vector3.new(280, 0, -545),
	Vector3.new(80, 0, -470),
	-- First S, then sharp south hairpin
	Vector3.new(-40, 0, -385),
	Vector3.new(-160, 0, -345),
	Vector3.new(-250, 0, -410),
	Vector3.new(-280, 0, -540),
	Vector3.new(-295, 0, -670),
	Vector3.new(-370, 0, -745),
	Vector3.new(-490, 0, -745),
	Vector3.new(-565, 0, -670),
	Vector3.new(-585, 0, -540),
	Vector3.new(-620, 0, -500),
	Vector3.new(-760, 0, -495),
	Vector3.new(-940, 0, -520),
	Vector3.new(-1060, 0, -515),
	Vector3.new(-1260, 0, -430),
	-- Slightly longer west U, flattening onto the pit
	Vector3.new(-1380, 0, -300),
	Vector3.new(-1400, 0, -160),
	Vector3.new(-1320, 0, -50),
	Vector3.new(-1160, 0, -20),
	Vector3.new(-980, 0, -70),
	Vector3.new(-900, 0, -140),
	Vector3.new(-840, 0, -165),
	Vector3.new(-780, 0, -165),
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

-- Pit whoops sit after the last corner, well clear of the grid / S/F stripe.
local PIT_WHOOP_NEAR = 420
local PIT_WHOOP_SPAN = 556
local T1_WHOOP_DELAY = 48
local T1_WHOOP_SPAN = PIT_WHOOP_SPAN * 2
local WHOOP_MAX = 12.8

local function whoopHeight(s: number, span: number, waveScale: number): number
	if s <= 0 or s >= span then
		return 0
	end
	local env = math.sin((s / span) * math.pi)
	local y = env * (5.2 + 4.4 * math.sin(s / (9.2 * waveScale)) + 2.8 * math.sin(s / (5.8 * waveScale) + 0.9))
	return math.clamp(y, 0, WHOOP_MAX)
end

local function applyBumps(centerline: { Vector3 }, spawnCFrame: CFrame)
	local n = #centerline
	local cum = table.create(n)
	local total = 0
	for i = 1, n do
		cum[i] = total
		local a = centerline[i]
		local b = wrap(centerline, i + 1)
		total += (Vector3.new(b.X, 0, b.Z) - Vector3.new(a.X, 0, a.Z)).Magnitude
	end

	local spawnIdx = 1
	local best = math.huge
	local spawn = spawnCFrame.Position
	for i, p in centerline do
		local dx, dz = p.X - spawn.X, p.Z - spawn.Z
		local d = dx * dx + dz * dz
		if d < best then
			best = d
			spawnIdx = i
		end
	end
	local spawnAlong = cum[spawnIdx]

	-- Eastmost point is the T1 hairpin apex; exit once we are heading back west.
	local t1Idx = 1
	local maxX = -math.huge
	for i, p in centerline do
		if p.X > maxX then
			maxX = p.X
			t1Idx = i
		end
	end
	local t1ExitAlong = cum[t1Idx]
	for step = 1, n do
		local idx = ((t1Idx + step - 1) % n) + 1
		local look = heading(centerline[idx], wrap(centerline, idx + 1))
		local along = (cum[idx] - cum[t1Idx]) % total
		if along > 90 and look.X < -0.7 then
			t1ExitAlong = cum[idx]
			break
		end
	end

	for i, p in centerline do
		local beforeFinish = (spawnAlong - cum[i]) % total
		local afterT1 = (cum[i] - t1ExitAlong) % total
		local y = 0
		if beforeFinish > PIT_WHOOP_NEAR and beforeFinish < PIT_WHOOP_NEAR + PIT_WHOOP_SPAN then
			y = math.max(y, whoopHeight(beforeFinish - PIT_WHOOP_NEAR, PIT_WHOOP_SPAN, 1))
		end
		if afterT1 > T1_WHOOP_DELAY and afterT1 < T1_WHOOP_DELAY + T1_WHOOP_SPAN then
			y = math.max(y, whoopHeight(afterT1 - T1_WHOOP_DELAY, T1_WHOOP_SPAN, 2))
		end
		centerline[i] = Vector3.new(p.X, y, p.Z)
	end
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
		table.insert(pts, Vector3.new(p.X + offset.X, p.Y, p.Z + offset.Z))
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
		local yA = a.Y + y
		local yB = b.Y + y
		local dx, dy, dz = b.X - a.X, yB - yA, b.Z - a.Z
		local len = math.sqrt(dx * dx + dy * dy + dz * dz)
		if len < 0.45 then
			continue
		end
		local mid = Vector3.new((a.X + b.X) * 0.5, (yA + yB) * 0.5, (a.Z + b.Z) * 0.5)
		part({
			Name = name,
			Size = Vector3.new(sizeX, sizeY, len + extra),
			CFrame = CFrame.lookAt(mid, Vector3.new(b.X, yB, b.Z)),
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
	applyBumps(centerline, spawnCFrame)
	local checkpointAt = {
		[1] = total * 0.25,
		[2] = total * 0.5,
		[3] = total * 0.75,
	}
	local placed = {}

	for i = 1, #centerline do
		local a = centerline[i]
		local b = wrap(centerline, i + 1)
		local p0 = Vector3.new(a.X, 1.2 + a.Y, a.Z)
		local p1 = Vector3.new(b.X, 1.2 + b.Y, b.Z)
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
	return CFrame.new(250, Constants.Car.SpawnHeight, -165)
end

local GRID_COLS = 4
local GRID_COL_SPACING = 16
local GRID_ROW_SPACING = 20
local GRID_BACK = 16

function TrackService.getGridCFrame(slotIndex: number, slotCount: number): CFrame
	local spawn = TrackService.getSpawnCFrame()
	local count = math.max(slotCount, 1)
	local index = math.clamp(math.floor(slotIndex), 1, count) - 1
	local col = index % GRID_COLS
	local row = math.floor(index / GRID_COLS)
	local colsThisRow = math.min(GRID_COLS, count - row * GRID_COLS)
	local x = (col - (colsThisRow - 1) / 2) * GRID_COL_SPACING
	local z = GRID_BACK + row * GRID_ROW_SPACING
	return spawn * CFrame.new(x, 0, z)
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
