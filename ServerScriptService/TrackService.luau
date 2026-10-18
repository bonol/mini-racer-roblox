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

local function applyCurveClimbs(centerline: { Vector3 })
	local n = #centerline
	if n < 16 then
		return
	end
	local grade = math.tan(math.rad(Constants.Track.ClimbDegrees))
	local peakMax = Constants.Track.ClimbPeakMax
	local cum = table.create(n)
	local total = 0
	for i = 1, n do
		cum[i] = total
		local a = centerline[i]
		local b = wrap(centerline, i + 1)
		total += (Vector3.new(b.X, 0, b.Z) - Vector3.new(a.X, 0, a.Z)).Magnitude
	end

	local marked = table.create(n, false)
	for i = 1, n do
		local prev = heading(wrap(centerline, i - 1), centerline[i])
		local this = heading(centerline[i], wrap(centerline, i + 1))
		local ang = math.deg(math.acos(math.clamp(prev:Dot(this), -1, 1)))
		if ang >= 7 then
			marked[i] = true
		end
	end
	local dilated = table.create(n, false)
	for i = 1, n do
		if marked[i] then
			for d = -6, 6 do
				dilated[((i + d - 1) % n) + 1] = true
			end
		end
	end

	local extra = table.create(n, 0)
	local i = 1
	while i <= n do
		if not dilated[i] then
			i += 1
			continue
		end
		local j = i
		while j <= n and dilated[j] do
			j += 1
		end
		local first, last = i, j - 1
		i = j
		if last - first < 8 then
			continue
		end
		first = math.max(1, first - 14)
		last = math.min(n, last + 14)
		local apex = math.floor((first + last) * 0.5)
		local function horiz(from: number, to: number): number
			return math.abs(cum[to] - cum[from])
		end
		local climbRun = horiz(first, apex)
		local dropRun = horiz(apex, last)
		local peak = math.min(climbRun, dropRun) * grade
		peak = math.min(peak, peakMax)
		if peak < 5 then
			continue
		end
		for k = first, apex do
			extra[k] = math.max(extra[k], math.min(horiz(first, k) * grade, peak))
		end
		for k = apex, last do
			extra[k] = math.max(extra[k], math.max(peak - horiz(apex, k) * grade, 0))
		end
	end

	for idx, p in centerline do
		local add = extra[idx] or 0
		if add > 0.05 then
			centerline[idx] = Vector3.new(p.X, p.Y + add, p.Z)
		end
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

local function themeDecal(host: BasePart, face: Enum.NormalId, slot: string, sponsorId: string?)
	local decal = Instance.new("Decal")
	decal.Name = slot .. "Art"
	decal.Face = face
	decal.Transparency = 1
	decal:SetAttribute("ThemeImageSlot", slot)
	if sponsorId then
		decal:SetAttribute("SponsorId", sponsorId)
	end
	decal.Parent = host
	CollectionService:AddTag(decal, "MiniRacerThemeImage")
end

local function themeTexture(host: BasePart, face: Enum.NormalId, slot: string, tileU: number, tileV: number)
	local texture = Instance.new("Texture")
	texture.Name = slot .. "Art"
	texture.Face = face
	texture.StudsPerTileU = tileU
	texture.StudsPerTileV = tileV
	texture.Transparency = 1
	texture:SetAttribute("ThemeImageSlot", slot)
	texture.Parent = host
	CollectionService:AddTag(texture, "MiniRacerThemeImage")
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
	parent: Instance,
	imageFace: Enum.NormalId?
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
		local segment = part({
			Name = name,
			Size = Vector3.new(sizeX, sizeY, len + extra),
			CFrame = CFrame.lookAt(mid, Vector3.new(b.X, yB, b.Z)),
			Color = colorFor(i),
			Material = material,
			CanCollide = canCollide,
			Parent = parent,
		})
		segment:SetAttribute("ThemeIndex", i)
		if imageFace then
			themeTexture(segment, imageFace, "Barrier", 15, 6)
		end
		created += 1
		if created % 40 == 0 then
			task.wait()
		end
	end
end

local SPONSOR_IDS = {
	"MiniRacerCup",
	"KoalaRacing",
	"BoltBoost",
	"TurboTires",
	"PlazaPitstop",
	"BombBox",
}

local BANNER_COPIES = 3
local BOARD_LENGTH = 28 * 6
local BOARD_HEIGHT = 10 * 3
local ARCH_BANNER_HEIGHT = 30 * 3
local ARCH_POST_HEIGHT = 42 * 3

local function placeTrackBoard(
	parent: Instance,
	centerline: { Vector3 },
	width: number,
	index: number,
	side: number,
	slot: string,
	sponsorId: string?
)
	local n = #centerline
	local idx = ((index - 1) % n) + 1
	local p = centerline[idx]
	local direction = heading(p, wrap(centerline, idx + 1))
	local outward = leftNormal(direction) * side
	local boardPos = p + outward * (width * 0.5 + 28) + Vector3.new(0, BOARD_HEIGHT * 0.5 + 4, 0)
	local faceAt = Vector3.new(p.X, boardPos.Y, p.Z)
	local board = part({
		Name = if sponsorId then "SponsorBoard" else "FinishTrackBanner",
		Size = Vector3.new(BOARD_LENGTH, BOARD_HEIGHT, 1.2),
		CFrame = CFrame.lookAt(boardPos, faceAt),
		Color = Color3.fromRGB(36, 98, 222),
		Material = Enum.Material.SmoothPlastic,
		CanCollide = false,
		CanQuery = false,
		Parent = parent,
	})
	board:SetAttribute("ThemeColorRole", if sponsorId then "SponsorFrame" else "Arch")
	themeDecal(board, Enum.NormalId.Front, slot, sponsorId)
	themeDecal(board, Enum.NormalId.Back, slot, sponsorId)
	for _, xOff in { -BOARD_LENGTH * 0.38, BOARD_LENGTH * 0.38 } do
		local leg = part({
			Name = "BannerLeg",
			Size = Vector3.new(2.2, boardPos.Y - 1, 2.2),
			CFrame = board.CFrame * CFrame.new(xOff, -boardPos.Y * 0.5 + 0.5, 0),
			Color = Color3.fromRGB(36, 98, 222),
			Material = Enum.Material.SmoothPlastic,
			CanCollide = false,
			CanQuery = false,
			Parent = parent,
		})
		leg:SetAttribute("ThemeColorRole", board:GetAttribute("ThemeColorRole"))
	end
end

local function buildThemeDecor(model: Model, centerline: { Vector3 }, stripe: CFrame, width: number)
	local existing = model:FindFirstChild("ThemeDecor")
	if existing then
		existing:Destroy()
	end
	local decor = Instance.new("Folder")
	decor.Name = "ThemeDecor"
	decor.Parent = model

	local postOffset = width * 0.5 + 4
	local postY = ARCH_POST_HEIGHT * 0.5
	for _, side in { -1, 1 } do
		local post = part({
			Name = "FinishArchPost",
			Size = Vector3.new(3.2, ARCH_POST_HEIGHT, 3.2),
			CFrame = stripe * CFrame.new(side * postOffset, postY, 0),
			Color = Color3.fromRGB(36, 98, 222),
			Material = Enum.Material.SmoothPlastic,
			CanCollide = false,
			CanQuery = false,
			Parent = decor,
		})
		post:SetAttribute("ThemeColorRole", "Arch")
	end
	local arch = part({
		Name = "FinishArchBanner",
		Size = Vector3.new(width + 11, ARCH_BANNER_HEIGHT, 2.2),
		CFrame = stripe * CFrame.new(0, ARCH_POST_HEIGHT - ARCH_BANNER_HEIGHT * 0.5, 0),
		Color = Color3.fromRGB(36, 98, 222),
		Material = Enum.Material.SmoothPlastic,
		CanCollide = false,
		CanQuery = false,
		Parent = decor,
	})
	arch:SetAttribute("ThemeColorRole", "Arch")
	themeDecal(arch, Enum.NormalId.Front, "FinishBanner")
	themeDecal(arch, Enum.NormalId.Back, "FinishBanner")

	-- Finish art also rides the circuit twice more (gantry + 2 = 3). Sponsors × 3.
	local n = #centerline
	local sponsorCount = #SPONSOR_IDS * BANNER_COPIES
	for k = 1, sponsorCount do
		local sponsorId = SPONSOR_IDS[((k - 1) % #SPONSOR_IDS) + 1]
		local idx = math.floor((k - 0.5) / sponsorCount * n) + 1
		local side = if k % 2 == 0 then -1 else 1
		placeTrackBoard(decor, centerline, width, idx, side, "Sponsor", sponsorId)
	end
	for copy = 1, BANNER_COPIES - 1 do
		local idx = math.floor(copy / BANNER_COPIES * n) + 1
		placeTrackBoard(decor, centerline, width, idx, if copy == 1 then 1 else -1, "FinishBanner")
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
	applyCurveClimbs(centerline)
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
	placeStrip(offsetLoop(centerline, half + 1.6), "Barrier", 1.6, railHeight, railHeight / 2 - 0.2, railColor, Enum.Material.Metal, true, 1.35, model, Enum.NormalId.Right)
	placeStrip(offsetLoop(centerline, -(half + 1.6)), "Barrier", 1.6, railHeight, railHeight / 2 - 0.2, railColor, Enum.Material.Metal, true, 1.35, model, Enum.NormalId.Left)

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
	themeTexture(spawn, Enum.NormalId.Top, "StartLine", 12, 12)
	buildThemeDecor(model, centerline, spawnCFrame, width)

	local finish = checkpoint(Constants.Race.CheckpointCount, spawnCFrame, width)
	finish.Size = Vector3.new(width + 2, 16, 12)
	finish.Transparency = 0.82
	finish.Parent = model

	hideDefaultSpawn(spawn.CFrame)
	hideBaseplate()

	model.Parent = Workspace
	TrackService.ensurePlaza()
end

function TrackService.buildIfNeeded()
	local existing = Workspace:FindFirstChild("MiniRacerTrack")
	if existing == nil then
		build()
		return
	end
	-- Rebuild banners from current TrackService without replacing the course.
	-- Barrier/start-line textures are only added the first time ThemeDecor appears.
	if existing:IsA("Model") then
		local stripe = TrackService.getStripeCFrame()
		local centerline = sampleCenterline()
		applyBumps(centerline, stripe)
		applyCurveClimbs(centerline)
		local hadDecor = existing:FindFirstChild("ThemeDecor") ~= nil
		buildThemeDecor(existing, centerline, stripe, Constants.Track.RoadWidth)
		if not hadDecor then
			local decorated = 0
			for _, instance in existing:GetDescendants() do
				if instance:IsA("BasePart") and instance.Name == "Barrier" then
					themeTexture(instance, Enum.NormalId.Left, "Barrier", 15, 6)
					themeTexture(instance, Enum.NormalId.Right, "Barrier", 15, 6)
					decorated += 1
					if decorated % 40 == 0 then
						task.wait()
					end
				end
			end
			local spawn = existing:FindFirstChild("StartSpawn")
			if spawn and spawn:IsA("BasePart") then
				themeTexture(spawn, Enum.NormalId.Top, "StartLine", 12, 12)
			end
		end
	end
	TrackService.ensurePlaza()
end

function TrackService.rebuild()
	build()
end

function TrackService.getStripeCFrame(): CFrame
	local tagged = CollectionService:GetTagged(Constants.Track.SpawnTag)
	if #tagged > 0 then
		local spawn = tagged[1] :: BasePart
		return spawn.CFrame
	end
	return CFrame.new(250, 1.2, -165)
end

function TrackService.getSpawnCFrame(): CFrame
	return TrackService.getStripeCFrame() + Vector3.new(0, Constants.Car.SpawnHeight, 0)
end

local GRID_COLS = 4
local GRID_COL_SPACING = 16
local GRID_ROW_SPACING = 20
local GRID_BACK = 16

-- Infield is local -X (south of the eastbound pit). Road half-width is 40.
local PLAZA_X = -92
local PLAZA_Z = 18
local PADDOCK_X = -110
local STALL_X = -74

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

function TrackService.getPlazaSpawnCFrame(): CFrame
	local stripe = TrackService.getStripeCFrame()
	return stripe * CFrame.new(PLAZA_X, 4.2, PLAZA_Z)
end

function TrackService.getPaddockCFrame(index: number, count: number): CFrame
	local stripe = TrackService.getStripeCFrame()
	local n = math.max(count, 1)
	local i = math.clamp(math.floor(index), 1, n)
	local along = (i - (n + 1) / 2) * 9.5
	local at = stripe * CFrame.new(PADDOCK_X, 3.4, PLAZA_Z + along)
	local lookAt = Vector3.new(stripe.Position.X, at.Position.Y, stripe.Position.Z)
	return CFrame.lookAt(at.Position, lookAt)
end

function TrackService.getStallCFrame(index: number, count: number): CFrame
	local stripe = TrackService.getStripeCFrame()
	local n = math.max(count, 1)
	local i = math.clamp(math.floor(index), 1, n)
	local along = (i - (n + 1) / 2) * 14
	return stripe * CFrame.new(STALL_X, 3.6, PLAZA_Z + along)
end

function TrackService.getRecoverCFrame(checkpointIndex: number): CFrame
	local checkpoints = TrackService.getCheckpoints()
	local index = math.clamp(math.floor(checkpointIndex), 1, math.max(#checkpoints, 1))
	local gate = checkpoints[index]
	if gate then
		return gate.CFrame * CFrame.new(0, 3.4, 8)
	end
	return TrackService.getSpawnCFrame()
end

function TrackService.isOffTrack(pos: Vector3): boolean
	if pos.Y < -20 or pos.Y > 180 then
		return true
	end
	return pos.X < -1600 or pos.X > 1700 or pos.Z < -980 or pos.Z > 220
end

function TrackService.ensurePlaza()
	local stripe = TrackService.getStripeCFrame()

	local plaza = Workspace:FindFirstChild("KartPlaza")
	if plaza then
		plaza:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "KartPlaza"

	local pad = part({
		Name = "PlazaFloor",
		Size = Vector3.new(56, 1.2, 92),
		CFrame = stripe * CFrame.new(PLAZA_X, 0.9, PLAZA_Z),
		Color = Color3.fromRGB(52, 56, 64),
		Material = Enum.Material.Asphalt,
		Parent = folder,
	})
	pad.TopSurface = Enum.SurfaceType.Smooth

	local paddockPad = part({
		Name = "PaddockPad",
		Size = Vector3.new(22, 0.6, 64),
		CFrame = stripe * CFrame.new(PADDOCK_X, 1.35, PLAZA_Z),
		Color = Color3.fromRGB(38, 42, 50),
		Material = Enum.Material.Asphalt,
		Parent = folder,
	})
	paddockPad.CanCollide = false

	local stallPad = part({
		Name = "MarketPad",
		Size = Vector3.new(22, 0.6, 40),
		CFrame = stripe * CFrame.new(STALL_X, 1.35, PLAZA_Z),
		Color = Color3.fromRGB(64, 48, 36),
		Material = Enum.Material.Asphalt,
		Parent = folder,
	})
	stallPad.CanCollide = false

	part({
		Name = "PlazaCurb",
		Size = Vector3.new(2.2, 3.4, 96),
		CFrame = stripe * CFrame.new(-46, 2.2, PLAZA_Z),
		Color = Color3.fromRGB(210, 210, 216),
		Material = Enum.Material.Concrete,
		Parent = folder,
	})

	folder.Parent = Workspace

	local grid = Workspace:FindFirstChild("KartGrid")
	if grid then
		grid:Destroy()
	end
	local gridFolder = Instance.new("Folder")
	gridFolder.Name = "KartGrid"
	local paints = {
		Color3.fromRGB(36, 98, 222),
		Color3.fromRGB(46, 168, 78),
		Color3.fromRGB(240, 142, 178),
		Color3.fromRGB(214, 102, 36),
		Color3.fromRGB(48, 56, 96),
		Color3.fromRGB(236, 196, 48),
		Color3.fromRGB(180, 180, 190),
		Color3.fromRGB(160, 80, 200),
	}
	for i = 1, 8 do
		local at = TrackService.getGridCFrame(i, 8)
		part({
			Name = "GridSlot_" .. i,
			Size = Vector3.new(10, 0.22, 16),
			CFrame = at * CFrame.new(0, -Constants.Car.SpawnHeight + 0.2, 0),
			Color = paints[i],
			Material = Enum.Material.SmoothPlastic,
			CanCollide = false,
			CanQuery = false,
			Parent = gridFolder,
		})
	end
	gridFolder.Parent = Workspace

	hideDefaultSpawn(TrackService.getPlazaSpawnCFrame())
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
