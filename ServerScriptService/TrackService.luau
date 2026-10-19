local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local Constants = require(game:GetService("ReplicatedStorage"):WaitForChild("Constants"))
local TrackThemes = require(game:GetService("ReplicatedStorage"):WaitForChild("TrackThemes"))

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
	imageFace: Enum.NormalId?,
	transparency: number?
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
		if transparency ~= nil then
			segment.Transparency = transparency
			segment.CastShadow = false
		end
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

local STONE = Color3.fromRGB(214, 190, 148)
local STONE_DARK = Color3.fromRGB(156, 134, 106)
local ROOF = Color3.fromRGB(196, 52, 48)
local GOLD = Color3.fromRGB(210, 162, 58)
local WINDOW = Color3.fromRGB(48, 36, 72)
local TREE_TRUNK = Color3.fromRGB(118, 82, 48)
local TREE_LEAF = Color3.fromRGB(46, 128, 52)
local TREE_LEAF_DARK = Color3.fromRGB(28, 92, 40)
local PICKET = Color3.fromRGB(248, 248, 242)

local GATE_CLEARANCE = 32
local TOWER_H = 108
local TOWER_D = 20
local ROOF_H = 36
local LINTEL_H = 36
local LINTEL_D = 32
local WING_H = 52
local WING_TURRET_H = 74
local SPIRE_H = 38

local function decorPart(props: { [string]: any }, role: string): Part
	props.CanCollide = false
	props.CanQuery = false
	if props.Material == nil then
		props.Material = Enum.Material.Slate
	end
	local instance = part(props)
	instance:SetAttribute("ThemeColorRole", role)
	return instance
end

local function addPointLight(host: BasePart, color: Color3, brightness: number, range: number)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Brightness = brightness
	light.Range = range
	light.Shadows = false
	light.Parent = host
end

local function uprightCylinder(
	parent: Instance,
	name: string,
	diameter: number,
	height: number,
	at: CFrame,
	color: Color3,
	role: string,
	material: Enum.Material?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = Enum.PartType.Cylinder
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.Material = material or Enum.Material.Slate
	p.Color = color
	p.Size = Vector3.new(height, diameter, diameter)
	p.CFrame = at * CFrame.Angles(0, 0, math.pi * 0.5)
	p:SetAttribute("ThemeColorRole", role)
	p.Parent = parent
	return p
end

local function turretRoof(parent: Instance, at: CFrame, base: number, height: number, withFlag: boolean)
	local steps = 7
	local stepH = height / steps
	for i = 1, steps do
		local t = (i - 1) / (steps - 1)
		local d = math.max(base * (1 - t * 0.9), 2)
		uprightCylinder(
			parent,
			"CastleRoof",
			d,
			stepH + 0.2,
			at * CFrame.new(0, stepH * (i - 0.5), 0),
			ROOF,
			"CastleRoof",
			Enum.Material.SmoothPlastic
		)
	end
	decorPart({
		Name = "CastleFinial",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(2.8, 2.8, 2.8),
		CFrame = at * CFrame.new(0, height + 1.1, 0),
		Color = GOLD,
		Material = Enum.Material.SmoothPlastic,
		Parent = parent,
	}, "Arch")
	if withFlag then
		decorPart({
			Name = "CastleFlagPole",
			Size = Vector3.new(0.45, 12, 0.45),
			CFrame = at * CFrame.new(0, height + 7, 0),
			Color = GOLD,
			Material = Enum.Material.SmoothPlastic,
			Parent = parent,
		}, "Arch")
		decorPart({
			Name = "CastleFlag",
			Size = Vector3.new(8, 3.6, 0.28),
			CFrame = at * CFrame.new(4.1, height + 10, 0),
			Color = ROOF,
			Material = Enum.Material.SmoothPlastic,
			Parent = parent,
		}, "CastleRoof")
	end
end

local function roundTower(
	parent: Instance,
	stripe: CFrame,
	x: number,
	z: number,
	yBase: number,
	height: number,
	diameter: number,
	roofH: number,
	name: string,
	withFlag: boolean
)
	uprightCylinder(
		parent,
		name,
		diameter,
		height,
		stripe * CFrame.new(x, yBase + height * 0.5, z),
		STONE,
		"CastleStone"
	)
	for _, t in { 0.28, 0.62 } do
		uprightCylinder(
			parent,
			"CastleBand",
			diameter + 1.6,
			1.6,
			stripe * CFrame.new(x, yBase + height * t, z),
			GOLD,
			"Arch",
			Enum.Material.SmoothPlastic
		)
	end
	for _, yOff in { yBase + height * 0.22, yBase + height * 0.48, yBase + height * 0.74 } do
		for _, zOff in { z - diameter * 0.51, z + diameter * 0.51 } do
			decorPart({
				Name = "CastleWindow",
				Size = Vector3.new(4.2, 7.2, 0.7),
				CFrame = stripe * CFrame.new(x, yOff, zOff),
				Color = WINDOW,
				Material = Enum.Material.SmoothPlastic,
				Parent = parent,
			}, "CastleWindow")
			decorPart({
				Name = "CastleWindowArch",
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(4.2, 4.2, 0.7),
				CFrame = stripe * CFrame.new(x, yOff + 3.4, zOff),
				Color = WINDOW,
				Material = Enum.Material.SmoothPlastic,
				Parent = parent,
			}, "CastleWindow")
		end
	end
	turretRoof(parent, stripe * CFrame.new(x, yBase + height, z), diameter + 6, roofH, withFlag)
end

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
	local look = CFrame.lookAt(boardPos, faceAt)
	decorPart({
		Name = if sponsorId then "SponsorFrame" else "FinishTrackFrame",
		Size = Vector3.new(BOARD_LENGTH + 2.6, BOARD_HEIGHT + 2.6, 1.1),
		CFrame = look * CFrame.new(0, 0, 0.7),
		Color = GOLD,
		Material = Enum.Material.SmoothPlastic,
		Parent = parent,
	}, "Arch")
	local board = decorPart({
		Name = if sponsorId then "SponsorBoard" else "FinishTrackBanner",
		Size = Vector3.new(BOARD_LENGTH, BOARD_HEIGHT, 1.2),
		CFrame = look,
		Color = STONE,
		Material = Enum.Material.SmoothPlastic,
		Parent = parent,
	}, "CastleStone")
	themeDecal(board, Enum.NormalId.Front, slot, sponsorId)
	themeDecal(board, Enum.NormalId.Back, slot, sponsorId)
	for _, xOff in { -BOARD_LENGTH * 0.38, BOARD_LENGTH * 0.38 } do
		local leg = decorPart({
			Name = "BannerLeg",
			Size = Vector3.new(3.2, boardPos.Y - 1, 3.2),
			CFrame = look * CFrame.new(xOff, -boardPos.Y * 0.5 + 0.5, 0),
			Color = STONE,
			Parent = parent,
		}, "CastleStone")
		decorPart({
			Name = "BannerLegCap",
			Size = Vector3.new(4, 1.4, 4),
			CFrame = leg.CFrame * CFrame.new(0, (boardPos.Y - 1) * 0.5 + 0.7, 0),
			Color = GOLD,
			Material = Enum.Material.SmoothPlastic,
			Parent = parent,
		}, "Arch")
	end
end

local function merlons(parent: Instance, stripe: CFrame, x0: number, x1: number, y: number, z: number, step: number)
	local a = math.min(x0, x1)
	local b = math.max(x0, x1)
	for x = a, b, math.abs(step) do
		decorPart({
			Name = "CastleMerlon",
			Size = Vector3.new(5, 8, 6),
			CFrame = stripe * CFrame.new(x, y, z),
			Color = STONE,
			Parent = parent,
		}, "CastleStone")
	end
end

local function buildCastleGate(parent: Instance, stripe: CFrame, width: number)
	local towerX = width * 0.5 + TOWER_D * 0.5 + 4
	local halfD = LINTEL_D * 0.5
	local frontZ = -halfD
	local backZ = halfD
	local lintelY = GATE_CLEARANCE + LINTEL_H * 0.5
	local keepH = 24
	local keepTop = GATE_CLEARANCE + LINTEL_H + keepH

	roundTower(parent, stripe, -towerX, frontZ, 0, TOWER_H, TOWER_D, ROOF_H, "FinishArchPost", true)
	roundTower(parent, stripe, towerX, frontZ, 0, TOWER_H, TOWER_D, ROOF_H, "CastleTower", true)
	roundTower(parent, stripe, -towerX, backZ, 0, TOWER_H - 12, TOWER_D, ROOF_H - 6, "CastleTower", false)
	roundTower(parent, stripe, towerX, backZ, 0, TOWER_H - 12, TOWER_D, ROOF_H - 6, "CastleTower", false)

	for _, side in { -1, 1 } do
		local wingX = towerX + 28
		roundTower(parent, stripe, side * wingX, frontZ, 0, WING_TURRET_H, 14, 24, "CastleWingTurret", true)
		decorPart({
			Name = "CastleCurtain",
			Size = Vector3.new(math.abs(wingX - towerX) - 10, WING_H, 9),
			CFrame = stripe * CFrame.new(side * (towerX + wingX) * 0.5, WING_H * 0.5, frontZ),
			Color = STONE,
			Parent = parent,
		}, "CastleStone")
		merlons(parent, stripe, side * (towerX + 8), side * (wingX - 8), WING_H + 4, frontZ, side * 9)
		decorPart({
			Name = "CastleSideWall",
			Size = Vector3.new(9, TOWER_H * 0.58, LINTEL_D - 6),
			CFrame = stripe * CFrame.new(side * towerX, TOWER_H * 0.29, 0),
			Color = STONE_DARK,
			Parent = parent,
		}, "CastleStoneDark")
		decorPart({
			Name = "CastleShoulder",
			Size = Vector3.new(16, 16, LINTEL_D - 4),
			CFrame = stripe * CFrame.new(side * (width * 0.5 - 5), GATE_CLEARANCE + 8, 0),
			Color = STONE_DARK,
			Parent = parent,
		}, "CastleStoneDark")
	end

	decorPart({
		Name = "CastleLintel",
		Size = Vector3.new(width + 10, LINTEL_H, LINTEL_D),
		CFrame = stripe * CFrame.new(0, lintelY, 0),
		Color = STONE,
		Parent = parent,
	}, "CastleStone")
	decorPart({
		Name = "CastleKeep",
		Size = Vector3.new(width * 0.5, keepH, LINTEL_D - 8),
		CFrame = stripe * CFrame.new(0, GATE_CLEARANCE + LINTEL_H + keepH * 0.5, 0),
		Color = STONE,
		Parent = parent,
	}, "CastleStone")
	roundTower(parent, stripe, 0, 0, keepTop, SPIRE_H, 15, 30, "CastleSpire", true)
	merlons(parent, stripe, -width * 0.42, width * 0.42, GATE_CLEARANCE + LINTEL_H + 4, frontZ, 10)
	merlons(parent, stripe, -width * 0.42, width * 0.42, GATE_CLEARANCE + LINTEL_H + 4, backZ, 10)

	-- Gold clock on the keep, facing racers as they approach.
	decorPart({
		Name = "CastleClockRing",
		Size = Vector3.new(12, 12, 1.2),
		CFrame = stripe * CFrame.new(0, keepTop - 6, frontZ - 4.6),
		Color = GOLD,
		Material = Enum.Material.SmoothPlastic,
		Parent = parent,
	}, "Arch")
	decorPart({
		Name = "CastleClockFace",
		Size = Vector3.new(9.4, 9.4, 1.3),
		CFrame = stripe * CFrame.new(0, keepTop - 6, frontZ - 5.1),
		Color = Color3.fromRGB(236, 220, 180),
		Material = Enum.Material.SmoothPlastic,
		Parent = parent,
	}, "CastleStone")
	decorPart({
		Name = "CastleClockHand",
		Size = Vector3.new(0.7, 3.4, 0.5),
		CFrame = stripe * CFrame.new(0, keepTop - 5.2, frontZ - 5.6),
		Color = GOLD,
		Material = Enum.Material.SmoothPlastic,
		Parent = parent,
	}, "Arch")

	for x = -width * 0.36, width * 0.36, 6 do
		decorPart({
			Name = "CastlePortcullis",
			Size = Vector3.new(0.7, 12, 0.7),
			CFrame = stripe * CFrame.new(x, GATE_CLEARANCE - 6, frontZ + 1),
			Color = GOLD,
			Material = Enum.Material.SmoothPlastic,
			Parent = parent,
		}, "Arch")
	end

	local tapestry = decorPart({
		Name = "FinishArchBanner",
		Size = Vector3.new(width - 14, LINTEL_H - 10, 1.4),
		CFrame = stripe * CFrame.new(0, lintelY - 1, frontZ - 1.2),
		Color = GOLD,
		Material = Enum.Material.SmoothPlastic,
		Parent = parent,
	}, "Arch")
	themeDecal(tapestry, Enum.NormalId.Front, "FinishBanner")
	themeDecal(tapestry, Enum.NormalId.Back, "FinishBanner")
	local backTapestry = decorPart({
		Name = "FinishArchBannerBack",
		Size = Vector3.new(width - 14, LINTEL_H - 10, 1.4),
		CFrame = stripe * CFrame.new(0, lintelY - 1, backZ + 1.2),
		Color = GOLD,
		Material = Enum.Material.SmoothPlastic,
		Parent = parent,
	}, "Arch")
	themeDecal(backTapestry, Enum.NormalId.Front, "FinishBanner")
	themeDecal(backTapestry, Enum.NormalId.Back, "FinishBanner")
end

local function buildPortalGate(parent: Instance, stripe: CFrame, width: number)
	local pylonX = width * 0.5 + 10
	local pylonH = 72
	local ringT = 6
	local glowH = GATE_CLEARANCE + 8

	for _, side in { -1, 1 } do
		decorPart({
			Name = "PortalPylon",
			Size = Vector3.new(12, pylonH, 16),
			CFrame = stripe * CFrame.new(side * pylonX, pylonH * 0.5, 0),
			Color = Color3.fromRGB(36, 44, 58),
			Material = Enum.Material.Metal,
			Parent = parent,
		}, "SciHull")
		decorPart({
			Name = "PortalTrim",
			Size = Vector3.new(2.2, pylonH, 18),
			CFrame = stripe * CFrame.new(side * (pylonX - 6), pylonH * 0.5, 0),
			Color = Color3.fromRGB(0, 230, 255),
			Material = Enum.Material.Neon,
			Parent = parent,
		}, "SciAccent")
		decorPart({
			Name = "PortalCap",
			Size = Vector3.new(16, 8, 20),
			CFrame = stripe * CFrame.new(side * pylonX, pylonH + 2, 0),
			Color = Color3.fromRGB(90, 40, 255),
			Material = Enum.Material.Neon,
			Parent = parent,
		}, "SciGlow")
	end

	decorPart({
		Name = "PortalLintel",
		Size = Vector3.new(width + 28, ringT, 18),
		CFrame = stripe * CFrame.new(0, GATE_CLEARANCE + ringT * 0.5, 0),
		Color = Color3.fromRGB(36, 44, 58),
		Material = Enum.Material.Metal,
		Parent = parent,
	}, "SciHull")
	decorPart({
		Name = "PortalLintelGlow",
		Size = Vector3.new(width + 8, 2.4, 20),
		CFrame = stripe * CFrame.new(0, GATE_CLEARANCE + 1.4, 0),
		Color = Color3.fromRGB(0, 230, 255),
		Material = Enum.Material.Neon,
		Parent = parent,
	}, "SciAccent")
	decorPart({
		Name = "PortalVeil",
		Size = Vector3.new(width - 4, glowH, 1.2),
		CFrame = stripe * CFrame.new(0, glowH * 0.5, 0),
		Color = Color3.fromRGB(90, 40, 255),
		Material = Enum.Material.Neon,
		Transparency = 0.72,
		Parent = parent,
	}, "SciGlow")
	local banner = decorPart({
		Name = "FinishArchBanner",
		Size = Vector3.new(width - 18, 14, 1.4),
		CFrame = stripe * CFrame.new(0, GATE_CLEARANCE + ringT + 8, -10),
		Color = Color3.fromRGB(0, 255, 220),
		Material = Enum.Material.SmoothPlastic,
		Parent = parent,
	}, "Arch")
	themeDecal(banner, Enum.NormalId.Front, "FinishBanner")
	themeDecal(banner, Enum.NormalId.Back, "FinishBanner")

	for _, side in { -1, 1 } do
		local lamp = decorPart({
			Name = "PortalLamp",
			Size = Vector3.new(4, 4, 4),
			CFrame = stripe * CFrame.new(side * (pylonX - 8), 18, 10),
			Color = Color3.fromRGB(0, 230, 255),
			Material = Enum.Material.Neon,
			Parent = parent,
		}, "SciAccent")
		addPointLight(lamp, Color3.fromRGB(0, 230, 255), 3.2, 48)
		local lampM = decorPart({
			Name = "PortalLamp",
			Size = Vector3.new(3.2, 3.2, 3.2),
			CFrame = stripe * CFrame.new(side * (pylonX - 8), 40, -8),
			Color = Color3.fromRGB(180, 60, 255),
			Material = Enum.Material.Neon,
			Parent = parent,
		}, "SciGlow")
		addPointLight(lampM, Color3.fromRGB(180, 60, 255), 2.4, 40)
	end
	local crown = decorPart({
		Name = "PortalCrown",
		Size = Vector3.new(width + 20, 3, 6),
		CFrame = stripe * CFrame.new(0, GATE_CLEARANCE + 22, 0),
		Color = Color3.fromRGB(0, 255, 220),
		Material = Enum.Material.Neon,
		Parent = parent,
	}, "SciAccent")
	addPointLight(crown, Color3.fromRGB(80, 220, 255), 2.8, 56)
end

local function placeWorldStrip(
	points: { Vector3 },
	sizeX: number,
	sizeY: number,
	y: number,
	color: Color3,
	material: Enum.Material,
	extra: number,
	parent: Instance,
	role: string,
	stripe: CFrame
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
		local localMid = stripe:PointToObjectSpace(mid)
		if math.abs(localMid.Z) < 52 then
			continue
		end
		local segment = decorPart({
			Name = "WorldShell",
			Size = Vector3.new(sizeX, sizeY, len + extra),
			CFrame = CFrame.lookAt(mid, Vector3.new(b.X, yB, b.Z)),
			Color = color,
			Material = material,
			Parent = parent,
		}, role)
		segment.CastShadow = true
		created += 1
		if created % 40 == 0 then
			task.wait()
		end
	end
end

local function dressShell(points: { Vector3 }, inwardSign: number, parent: Instance, stripe: CFrame, theme, height: number)
	local portal = theme.World.Gate == "Portal"
	local step = if portal then 6 else 8
	local cyan = Color3.fromRGB(0, 230, 255)
	local mag = Color3.fromRGB(180, 60, 255)
	local flame = Color3.fromRGB(255, 150, 60)
	for i = 1, #points, step do
		local a = points[i]
		local b = wrap(points, i + 1)
		local mid = Vector3.new((a.X + b.X) * 0.5, (a.Y + b.Y) * 0.5, (a.Z + b.Z) * 0.5)
		if math.abs(stripe:PointToObjectSpace(mid).Z) < 52 then
			continue
		end
		local look = heading(a, b)
		if look.Magnitude < 0.05 then
			continue
		end
		local inward = leftNormal(look) * inwardSign
		local at = mid + inward * 8
		local face = CFrame.lookAt(at, at + inward)
		if portal then
			local accent = math.floor(i / step) % 2 == 0
			local bar = decorPart({
				Name = "NeonTrim",
				Size = Vector3.new(1.4, 2.2, 14),
				CFrame = face * CFrame.new(0, 14, 0),
				Color = if accent then cyan else mag,
				Material = Enum.Material.Neon,
				Parent = parent,
			}, if accent then "SciAccent" else "SciGlow")
			addPointLight(bar, bar.Color, 2.6, 40)
			local high = decorPart({
				Name = "NeonTrim",
				Size = Vector3.new(1.2, 1.6, 12),
				CFrame = face * CFrame.new(0, 42, 0),
				Color = if accent then mag else cyan,
				Material = Enum.Material.Neon,
				Parent = parent,
			}, "SciGlow")
			addPointLight(high, high.Color, 1.8, 30)
			local pad = decorPart({
				Name = "RunwayLight",
				Size = Vector3.new(1.8, 0.45, 1.8),
				CFrame = face * CFrame.new(0, 1.15, 7),
				Color = cyan,
				Material = Enum.Material.Neon,
				Parent = parent,
			}, "SciAccent")
			addPointLight(pad, cyan, 1.4, 18)
		else
			decorPart({
				Name = "CastleMerlon",
				Size = Vector3.new(5.5, 8, 8),
				CFrame = CFrame.new(mid + Vector3.new(0, height + 3, 0)) * (face - face.Position),
				Color = Color3.fromRGB(214, 190, 148),
				Parent = parent,
			}, "CastleStone")
			decorPart({
				Name = "CastleTorch",
				Size = Vector3.new(0.7, 12, 0.7),
				CFrame = face * CFrame.new(0, 7, 0),
				Color = Color3.fromRGB(156, 134, 106),
				Parent = parent,
			}, "CastleStoneDark")
			local bowl = part({
				Name = "CastleFlame",
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(2.2, 2.2, 2.2),
				CFrame = face * CFrame.new(0, 14.2, 0),
				Color = flame,
				Material = Enum.Material.Neon,
				CanCollide = false,
				CanQuery = false,
				Parent = parent,
			})
			addPointLight(bowl, flame, 1.1, 20)
			if math.floor(i / step) % 2 == 0 then
				local tapestry = decorPart({
					Name = "CourtyardBanner",
					Size = Vector3.new(10, 18, 0.55),
					CFrame = face * CFrame.new(0, 22, 0),
					Color = ROOF,
					Material = Enum.Material.SmoothPlastic,
					Parent = parent,
				}, "CastleRoof")
				themeDecal(tapestry, Enum.NormalId.Front, "FinishBanner")
				themeDecal(tapestry, Enum.NormalId.Back, "FinishBanner")
			end
		end
		if i % (step * 4) == 1 then
			task.wait()
		end
	end
end

local function freePart(props: { [string]: any }): Part
	props.CanCollide = false
	props.CanQuery = false
	return part(props)
end

local function placeTree(parent: Instance, at: CFrame, scale: number)
	freePart({
		Name = "VillageTrunk",
		Size = Vector3.new(1.5 * scale, 7 * scale, 1.5 * scale),
		CFrame = at * CFrame.new(0, 3.5 * scale, 0),
		Color = TREE_TRUNK,
		Material = Enum.Material.Wood,
		Parent = parent,
	})
	freePart({
		Name = "VillageCanopy",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(9, 9, 9) * scale,
		CFrame = at * CFrame.new(0, 8.4 * scale, 0),
		Color = TREE_LEAF,
		Material = Enum.Material.Grass,
		Parent = parent,
	})
	freePart({
		Name = "VillageCanopy",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(6.4, 6.4, 6.4) * scale,
		CFrame = at * CFrame.new(2.1 * scale, 10.4 * scale, 1.2 * scale),
		Color = TREE_LEAF_DARK,
		Material = Enum.Material.Grass,
		Parent = parent,
	})
end

local function placeFlower(parent: Instance, at: CFrame, color: Color3)
	freePart({
		Name = "VillageStem",
		Size = Vector3.new(0.28, 1.5, 0.28),
		CFrame = at * CFrame.new(0, 0.95, 0),
		Color = Color3.fromRGB(40, 110, 48),
		Material = Enum.Material.Grass,
		Parent = parent,
	})
	freePart({
		Name = "VillageFlower",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(1.15, 1.15, 1.15),
		CFrame = at * CFrame.new(0, 1.75, 0),
		Color = color,
		Material = Enum.Material.SmoothPlastic,
		Parent = parent,
	})
end

local function placeLampPost(parent: Instance, at: CFrame)
	decorPart({
		Name = "VillageLampPole",
		Size = Vector3.new(0.55, 14, 0.55),
		CFrame = at * CFrame.new(0, 7, 0),
		Color = Color3.fromRGB(70, 70, 78),
		Material = Enum.Material.SmoothPlastic,
		Parent = parent,
	}, "CastleStoneDark")
	decorPart({
		Name = "VillageLampArm",
		Size = Vector3.new(3.2, 0.4, 0.4),
		CFrame = at * CFrame.new(1.4, 13.6, 0),
		Color = Color3.fromRGB(70, 70, 78),
		Material = Enum.Material.SmoothPlastic,
		Parent = parent,
	}, "CastleStoneDark")
	local globe = freePart({
		Name = "VillageLamp",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(1.6, 1.6, 1.6),
		CFrame = at * CFrame.new(2.6, 13.2, 0),
		Color = Color3.fromRGB(255, 226, 160),
		Material = Enum.Material.SmoothPlastic,
		Parent = parent,
	})
	addPointLight(globe, Color3.fromRGB(255, 220, 160), 0.55, 14)
end

local function placePicketRun(parent: Instance, origin: CFrame, x: number, z0: number, z1: number)
	local a = math.min(z0, z1)
	local b = math.max(z0, z1)
	for z = a, b, 3.4 do
		freePart({
			Name = "VillagePicket",
			Size = Vector3.new(0.38, 2.5, 0.38),
			CFrame = origin * CFrame.new(x, 1.45, z),
			Color = PICKET,
			Material = Enum.Material.SmoothPlastic,
			Parent = parent,
		})
	end
	freePart({
		Name = "VillageRail",
		Size = Vector3.new(0.26, 0.28, math.abs(z1 - z0) + 0.8),
		CFrame = origin * CFrame.new(x, 1.65, (z0 + z1) * 0.5),
		Color = PICKET,
		Material = Enum.Material.SmoothPlastic,
		Parent = parent,
	})
end

local function placeCottage(parent: Instance, origin: CFrame, x: number, z: number, facePositiveZ: boolean)
	local yaw = if facePositiveZ then 0 else math.pi
	local cf = origin * CFrame.new(x, 0, z) * CFrame.Angles(0, yaw, 0)
	decorPart({
		Name = "VillageHouse",
		Size = Vector3.new(16, 12, 12),
		CFrame = cf * CFrame.new(0, 7, 0),
		Color = Color3.fromRGB(232, 214, 176),
		Parent = parent,
	}, "CastleStone")
	decorPart({
		Name = "VillageRoof",
		Size = Vector3.new(18, 2.6, 14),
		CFrame = cf * CFrame.new(0, 14.1, 0),
		Color = ROOF,
		Material = Enum.Material.SmoothPlastic,
		Parent = parent,
	}, "CastleRoof")
	decorPart({
		Name = "VillageRoof",
		Size = Vector3.new(12, 3.4, 14),
		CFrame = cf * CFrame.new(0, 16.8, 0),
		Color = ROOF,
		Material = Enum.Material.SmoothPlastic,
		Parent = parent,
	}, "CastleRoof")
	decorPart({
		Name = "VillageChimney",
		Size = Vector3.new(2.4, 6, 2.4),
		CFrame = cf * CFrame.new(-5, 17.2, -2),
		Color = STONE_DARK,
		Parent = parent,
	}, "CastleStoneDark")
	decorPart({
		Name = "VillageDoor",
		Size = Vector3.new(3.2, 6.2, 0.5),
		CFrame = cf * CFrame.new(0, 4.1, 6.2),
		Color = Color3.fromRGB(120, 72, 42),
		Material = Enum.Material.Wood,
		Parent = parent,
	}, "CastleStoneDark")
	for _, xOff in { -4.2, 4.2 } do
		decorPart({
			Name = "VillageWindow",
			Size = Vector3.new(2.6, 3.2, 0.45),
			CFrame = cf * CFrame.new(xOff, 8.4, 6.2),
			Color = WINDOW,
			Material = Enum.Material.SmoothPlastic,
			Parent = parent,
		}, "CastleWindow")
	end
	decorPart({
		Name = "VillageFlagPole",
		Size = Vector3.new(0.35, 8, 0.35),
		CFrame = cf * CFrame.new(6.5, 20, 0),
		Color = GOLD,
		Material = Enum.Material.SmoothPlastic,
		Parent = parent,
	}, "Arch")
	decorPart({
		Name = "VillageFlag",
		Size = Vector3.new(4.4, 2.2, 0.22),
		CFrame = cf * CFrame.new(8.6, 22.4, 0),
		Color = ROOF,
		Material = Enum.Material.SmoothPlastic,
		Parent = parent,
	}, "CastleRoof")
end

local function placeKeepTower(parent: Instance, stripe: CFrame, x: number, z: number, height: number, width: number, withFlag: boolean)
	decorPart({
		Name = "PlazaKeepTower",
		Size = Vector3.new(width, height, width),
		CFrame = stripe * CFrame.new(x, height * 0.5, z),
		Color = STONE,
		Parent = parent,
	}, "CastleStone")
	for i = 1, 5 do
		local t = (i - 1) / 4
		local s = math.max((width + 6) * (1 - t * 0.88), 2.4)
		decorPart({
			Name = "PlazaKeepRoof",
			Size = Vector3.new(s, 4, s),
			CFrame = stripe * CFrame.new(x, height + 1.6 + (i - 1) * 3.5, z),
			Color = ROOF,
			Material = Enum.Material.SmoothPlastic,
			Parent = parent,
		}, "CastleRoof")
	end
	if withFlag then
		decorPart({
			Name = "PlazaKeepFlagPole",
			Size = Vector3.new(0.4, 12, 0.4),
			CFrame = stripe * CFrame.new(x, height + 24, z),
			Color = GOLD,
			Material = Enum.Material.SmoothPlastic,
			Parent = parent,
		}, "Arch")
		decorPart({
			Name = "PlazaKeepFlag",
			Size = Vector3.new(7.5, 3.4, 0.28),
			CFrame = stripe * CFrame.new(x + 3.8, height + 28, z),
			Color = ROOF,
			Material = Enum.Material.SmoothPlastic,
			Parent = parent,
		}, "CastleRoof")
	end
	for _, yOff in { height * 0.28, height * 0.55 } do
		decorPart({
			Name = "PlazaKeepWindow",
			Size = Vector3.new(0.5, 5, 3.2),
			CFrame = stripe * CFrame.new(x + width * 0.5, yOff, z),
			Color = WINDOW,
			Material = Enum.Material.SmoothPlastic,
			Parent = parent,
		}, "CastleWindow")
	end
end

local function placePlazaKeep(parent: Instance, stripe: CFrame)
	local x = -152
	local z = 18
	decorPart({
		Name = "PlazaKeep",
		Size = Vector3.new(24, 42, 36),
		CFrame = stripe * CFrame.new(x, 22, z),
		Color = STONE,
		Parent = parent,
	}, "CastleStone")
	decorPart({
		Name = "PlazaKeepDoor",
		Size = Vector3.new(0.7, 16, 10),
		CFrame = stripe * CFrame.new(x + 12.2, 9, z),
		Color = WINDOW,
		Material = Enum.Material.SmoothPlastic,
		Parent = parent,
	}, "CastleWindow")
	for _, zOff in { -10, 0, 10 } do
		for _, yOff in { 18, 30 } do
			decorPart({
				Name = "PlazaKeepWindow",
				Size = Vector3.new(0.55, 5.5, 3.6),
				CFrame = stripe * CFrame.new(x + 12.2, yOff, z + zOff),
				Color = WINDOW,
				Material = Enum.Material.SmoothPlastic,
				Parent = parent,
			}, "CastleWindow")
		end
	end
	for mx = -8, 8, 8 do
		decorPart({
			Name = "PlazaKeepMerlon",
			Size = Vector3.new(5, 7, 6),
			CFrame = stripe * CFrame.new(x + mx, 46, z + 16),
			Color = STONE,
			Parent = parent,
		}, "CastleStone")
		decorPart({
			Name = "PlazaKeepMerlon",
			Size = Vector3.new(5, 7, 6),
			CFrame = stripe * CFrame.new(x + mx, 46, z - 16),
			Color = STONE,
			Parent = parent,
		}, "CastleStone")
	end
	placeKeepTower(parent, stripe, x - 10, z - 20, 54, 14, true)
	placeKeepTower(parent, stripe, x - 10, z + 20, 54, 14, true)
	placeKeepTower(parent, stripe, x + 2, z, 70, 12, true)
	freePart({
		Name = "VillageHill",
		Size = Vector3.new(70, 20, 90),
		CFrame = stripe * CFrame.new(x - 36, 6, z),
		Color = Color3.fromRGB(86, 150, 62),
		Material = Enum.Material.Grass,
		Parent = parent,
	})
	freePart({
		Name = "VillageHill",
		Size = Vector3.new(40, 14, 36),
		CFrame = stripe * CFrame.new(x - 28, 10, z - 38),
		Color = Color3.fromRGB(64, 132, 52),
		Material = Enum.Material.Grass,
		Parent = parent,
	})
end

local function dressPlaza(parent: Instance, stripe: CFrame, theme)
	local origin = stripe * CFrame.new(-92, 0, 18)
	if theme.World.Gate == "Portal" then
		local spots = {
			Vector3.new(-18, 0, -22),
			Vector3.new(18, 0, -22),
			Vector3.new(-18, 0, 22),
			Vector3.new(18, 0, 22),
		}
		for i, off in spots do
			decorPart({
				Name = "PlazaPylon",
				Size = Vector3.new(3, 22, 3),
				CFrame = origin * CFrame.new(off.X, 12, off.Z),
				Color = Color3.fromRGB(36, 44, 58),
				Material = Enum.Material.Metal,
				Parent = parent,
			}, "SciHull")
			local cap = decorPart({
				Name = "PlazaPylonCap",
				Size = Vector3.new(4.2, 2.2, 4.2),
				CFrame = origin * CFrame.new(off.X, 24, off.Z),
				Color = if i % 2 == 0 then Color3.fromRGB(180, 60, 255) else Color3.fromRGB(0, 230, 255),
				Material = Enum.Material.Neon,
				Parent = parent,
			}, if i % 2 == 0 then "SciGlow" else "SciAccent")
			addPointLight(cap, cap.Color, 3.4, 44)
		end
		local ring = decorPart({
			Name = "HoloRing",
			Size = Vector3.new(16, 0.55, 16),
			CFrame = origin * CFrame.new(0, 1.55, 0),
			Color = Color3.fromRGB(90, 40, 255),
			Material = Enum.Material.Neon,
			Parent = parent,
		}, "SciGlow")
		addPointLight(ring, Color3.fromRGB(140, 80, 255), 2.2, 28)
		return
	end

	placePlazaKeep(parent, stripe)
	placeCottage(parent, origin, -36, -50, true)
	placeCottage(parent, origin, -14, -52, true)
	placeCottage(parent, origin, -36, 50, false)
	placeCottage(parent, origin, -12, 52, false)

	placeTree(parent, origin * CFrame.new(-48, 0, -36), 1.15)
	placeTree(parent, origin * CFrame.new(-50, 0, 34), 1.25)
	placeTree(parent, origin * CFrame.new(24, 0, -44), 1)
	placeTree(parent, origin * CFrame.new(26, 0, 44), 1.1)
	placeTree(parent, origin * CFrame.new(-8, 0, -48), 0.85)
	placeTree(parent, origin * CFrame.new(-6, 0, 48), 0.9)
	placeTree(parent, origin * CFrame.new(-58, 0, -8), 1.35)

	placePicketRun(parent, origin, -46, -40, 40)
	placePicketRun(parent, origin, 26, -44, -20)
	placePicketRun(parent, origin, 26, 20, 44)

	placeLampPost(parent, origin * CFrame.new(-26, 0, -42))
	placeLampPost(parent, origin * CFrame.new(-26, 0, 42))
	placeLampPost(parent, origin * CFrame.new(24, 0, -42))
	placeLampPost(parent, origin * CFrame.new(24, 0, 42))

	local flowerColors = {
		Color3.fromRGB(255, 214, 64),
		Color3.fromRGB(228, 64, 64),
		Color3.fromRGB(245, 245, 250),
		Color3.fromRGB(255, 150, 40),
	}
	for i = -8, 8 do
		local color = flowerColors[(i % #flowerColors) + 1]
		placeFlower(parent, origin * CFrame.new(-44, 0, i * 4.2), color)
		placeFlower(parent, origin * CFrame.new(-42 + (i % 2) * 1.6, 0, -44 + i * 0.2), color)
	end
	for _, z in { -46, 46 } do
		for i = -4, 2 do
			placeFlower(parent, origin * CFrame.new(-20 + i * 4, 0, z), flowerColors[(i % #flowerColors) + 1])
		end
	end

	decorPart({
		Name = "PlazaWell",
		Size = Vector3.new(8, 2.4, 8),
		CFrame = origin * CFrame.new(8, 1.4, -38),
		Color = STONE_DARK,
		Parent = parent,
	}, "CastleStoneDark")
	freePart({
		Name = "PlazaWellWater",
		Size = Vector3.new(5.5, 0.8, 5.5),
		CFrame = origin * CFrame.new(8, 2.3, -38),
		Color = Color3.fromRGB(70, 120, 160),
		Material = Enum.Material.Glass,
		Transparency = 0.3,
		Parent = parent,
	})
	for _, z in { -34, 34 } do
		decorPart({
			Name = "PlazaBench",
			Size = Vector3.new(10, 1.4, 2.4),
			CFrame = origin * CFrame.new(-30, 1.8, z),
			Color = STONE_DARK,
			Parent = parent,
		}, "CastleStoneDark")
		decorPart({
			Name = "PlazaBenchBack",
			Size = Vector3.new(10, 2.2, 0.55),
			CFrame = origin * CFrame.new(-31.2, 3.2, z),
			Color = STONE,
			Parent = parent,
		}, "CastleStone")
	end
end

local function buildThemeWorld(model: Model, centerline: { Vector3 }, stripe: CFrame, width: number, theme)
	local existing = model:FindFirstChild("ThemeWorld")
	if existing then
		existing:Destroy()
	end
	local world = Instance.new("Folder")
	world.Name = "ThemeWorld"
	world.Parent = model

	local half = width * 0.5
	local dist = half + theme.World.ShellOffset
	local height = theme.World.ShellHeight
	local role = theme.World.ShellRole
	local color = theme.Colors[role] or theme.Colors.CastleStone
	local material = theme.Materials.WorldShell or Enum.Material.Slate
	placeWorldStrip(
		offsetLoop(centerline, dist),
		10,
		height,
		height / 2 - 0.2,
		color,
		material,
		1.6,
		world,
		role,
		stripe
	)
	placeWorldStrip(
		offsetLoop(centerline, -dist),
		10,
		height,
		height / 2 - 0.2,
		color,
		material,
		1.6,
		world,
		role,
		stripe
	)
	dressShell(offsetLoop(centerline, dist), -1, world, stripe, theme, height)
	dressShell(offsetLoop(centerline, -dist), 1, world, stripe, theme, height)
	dressPlaza(world, stripe, theme)
end

local function currentTheme()
	local themeId = Workspace:GetAttribute("MiniRacerThemeId")
	if typeof(themeId) ~= "string" then
		themeId = TrackThemes.Order[1]
	end
	return TrackThemes.get(themeId)
end

local function buildThemeDecor(model: Model, centerline: { Vector3 }, stripe: CFrame, width: number, theme)
	local existing = model:FindFirstChild("ThemeDecor")
	if existing then
		existing:Destroy()
	end
	local decor = Instance.new("Folder")
	decor.Name = "ThemeDecor"
	decor.Parent = model

	if theme.World.Gate == "Portal" then
		buildPortalGate(decor, stripe, width)
	else
		buildCastleGate(decor, stripe, width)
	end

	-- Finish tapestries also ride the circuit twice more. Sponsors × 3.
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
	local wallHeight = Constants.Track.BarrierWallHeight or 28
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
		return Color3.fromRGB(214, 190, 148)
	end

	placeStrip(offsetLoop(centerline, half - 1.1), "Kerb", 2.2, 0.35, 1.9, kerbColor, Enum.Material.SmoothPlastic, false, 0.9, model)
	placeStrip(offsetLoop(centerline, -(half - 1.1)), "Kerb", 2.2, 0.35, 1.9, kerbColor, Enum.Material.SmoothPlastic, false, 0.9, model)
	placeStrip(offsetLoop(centerline, half + 1.6), "Barrier", 1.6, railHeight, railHeight / 2 - 0.2, railColor, Enum.Material.Metal, true, 1.35, model, Enum.NormalId.Right)
	placeStrip(offsetLoop(centerline, -(half + 1.6)), "Barrier", 1.6, railHeight, railHeight / 2 - 0.2, railColor, Enum.Material.Metal, true, 1.35, model, Enum.NormalId.Left)
	placeStrip(
		offsetLoop(centerline, half + 1.6),
		"BarrierWall",
		1.2,
		wallHeight,
		wallHeight / 2 - 0.2,
		railColor,
		Enum.Material.SmoothPlastic,
		true,
		1.35,
		model,
		nil,
		1
	)
	placeStrip(
		offsetLoop(centerline, -(half + 1.6)),
		"BarrierWall",
		1.2,
		wallHeight,
		wallHeight / 2 - 0.2,
		railColor,
		Enum.Material.SmoothPlastic,
		true,
		1.35,
		model,
		nil,
		1
	)

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

	local finish = checkpoint(Constants.Race.CheckpointCount, spawnCFrame, width)
	finish.Size = Vector3.new(width + 2, 16, 12)
	finish.Transparency = 0.82
	finish.Parent = model

	hideDefaultSpawn(spawn.CFrame)
	hideBaseplate()

	model.Parent = Workspace
	TrackService.ensurePlaza()
end

function TrackService.applyThemeWorld(themeId: string)
	local existing = Workspace:FindFirstChild("MiniRacerTrack")
	if existing == nil or not existing:IsA("Model") then
		return
	end
	local theme = TrackThemes.get(themeId)
	local stripe = TrackService.getStripeCFrame()
	local centerline = sampleCenterline()
	applyBumps(centerline, stripe)
	applyCurveClimbs(centerline)
	local width = Constants.Track.RoadWidth
	buildThemeDecor(existing, centerline, stripe, width, theme)
	buildThemeWorld(existing, centerline, stripe, width, theme)
end

function TrackService.buildIfNeeded()
	local existing = Workspace:FindFirstChild("MiniRacerTrack")
	if existing == nil then
		build()
		return
	end
	TrackService.applyThemeWorld(currentTheme().Id)
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
