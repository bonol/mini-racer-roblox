local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(script.Parent:WaitForChild("Constants"))

export type Palette = {
	Id: string,
	Name: string,
	Body: Color3,
	Cabin: Color3,
	Stripe: Color3,
	Accent: Color3,
	Rear: Color3,
	Emblem: Color3,
	Mark: Color3,
	Exhaust: Color3,
	Tip: Color3,
	Tire: Color3,
	Rim: Color3,
	Seat: Color3,
	Cockpit: Color3,
}

local KartPrototype = {}

KartPrototype.Palettes = {
	{
		Id = "Default",
		Name = "Azure",
		Body = Color3.fromRGB(36, 98, 222),
		Cabin = Color3.fromRGB(248, 250, 252),
		Stripe = Color3.fromRGB(224, 86, 42),
		Accent = Color3.fromRGB(248, 250, 252),
		Rear = Color3.fromRGB(204, 42, 48),
		Emblem = Color3.fromRGB(248, 250, 252),
		Mark = Color3.fromRGB(210, 36, 46),
		Exhaust = Color3.fromRGB(28, 28, 32),
		Tip = Color3.fromRGB(186, 224, 42),
		Tire = Color3.fromRGB(24, 24, 24),
		Rim = Color3.fromRGB(236, 192, 42),
		Seat = Color3.fromRGB(22, 22, 26),
		Cockpit = Color3.fromRGB(18, 20, 26),
	},
	{
		Id = "Forest",
		Name = "Forest",
		Body = Color3.fromRGB(46, 168, 78),
		Cabin = Color3.fromRGB(248, 246, 232),
		Stripe = Color3.fromRGB(28, 92, 48),
		Accent = Color3.fromRGB(248, 250, 252),
		Rear = Color3.fromRGB(32, 110, 58),
		Emblem = Color3.fromRGB(248, 250, 252),
		Mark = Color3.fromRGB(36, 140, 64),
		Exhaust = Color3.fromRGB(28, 28, 32),
		Tip = Color3.fromRGB(186, 224, 42),
		Tire = Color3.fromRGB(24, 24, 24),
		Rim = Color3.fromRGB(232, 188, 48),
		Seat = Color3.fromRGB(22, 22, 26),
		Cockpit = Color3.fromRGB(18, 20, 26),
	},
	{
		Id = "Blush",
		Name = "Blush",
		Body = Color3.fromRGB(240, 142, 178),
		Cabin = Color3.fromRGB(255, 250, 246),
		Stripe = Color3.fromRGB(232, 176, 72),
		Accent = Color3.fromRGB(255, 244, 230),
		Rear = Color3.fromRGB(214, 86, 128),
		Emblem = Color3.fromRGB(255, 250, 246),
		Mark = Color3.fromRGB(228, 96, 140),
		Exhaust = Color3.fromRGB(28, 28, 32),
		Tip = Color3.fromRGB(236, 196, 86),
		Tire = Color3.fromRGB(24, 24, 24),
		Rim = Color3.fromRGB(236, 196, 86),
		Seat = Color3.fromRGB(22, 22, 26),
		Cockpit = Color3.fromRGB(18, 20, 26),
	},
	{
		Id = "Ember",
		Name = "Ember",
		Body = Color3.fromRGB(214, 102, 36),
		Cabin = Color3.fromRGB(58, 38, 28),
		Stripe = Color3.fromRGB(242, 196, 48),
		Accent = Color3.fromRGB(28, 28, 32),
		Rear = Color3.fromRGB(148, 36, 28),
		Emblem = Color3.fromRGB(28, 28, 32),
		Mark = Color3.fromRGB(242, 196, 48),
		Exhaust = Color3.fromRGB(28, 28, 32),
		Tip = Color3.fromRGB(232, 118, 36),
		Tire = Color3.fromRGB(24, 24, 24),
		Rim = Color3.fromRGB(242, 196, 48),
		Seat = Color3.fromRGB(22, 22, 26),
		Cockpit = Color3.fromRGB(16, 14, 12),
	},
	{
		Id = "Midnight",
		Name = "Midnight",
		Body = Color3.fromRGB(28, 40, 86),
		Cabin = Color3.fromRGB(214, 220, 230),
		Stripe = Color3.fromRGB(42, 214, 224),
		Accent = Color3.fromRGB(248, 250, 252),
		Rear = Color3.fromRGB(36, 168, 178),
		Emblem = Color3.fromRGB(248, 250, 252),
		Mark = Color3.fromRGB(42, 214, 224),
		Exhaust = Color3.fromRGB(20, 22, 28),
		Tip = Color3.fromRGB(42, 214, 224),
		Tire = Color3.fromRGB(24, 24, 24),
		Rim = Color3.fromRGB(188, 198, 210),
		Seat = Color3.fromRGB(22, 22, 26),
		Cockpit = Color3.fromRGB(14, 16, 22),
	},
	{
		Id = "Voltage",
		Name = "Voltage",
		Body = Color3.fromRGB(244, 206, 46),
		Cabin = Color3.fromRGB(248, 250, 252),
		Stripe = Color3.fromRGB(126, 68, 196),
		Accent = Color3.fromRGB(28, 28, 32),
		Rear = Color3.fromRGB(98, 48, 168),
		Emblem = Color3.fromRGB(28, 28, 32),
		Mark = Color3.fromRGB(186, 120, 255),
		Exhaust = Color3.fromRGB(28, 28, 32),
		Tip = Color3.fromRGB(232, 86, 196),
		Tire = Color3.fromRGB(24, 24, 24),
		Rim = Color3.fromRGB(126, 68, 196),
		Seat = Color3.fromRGB(22, 22, 26),
		Cockpit = Color3.fromRGB(18, 20, 26),
	},
} :: { Palette }

local TEMPLATE_NAME = "KartPrototype"

local function weld(a: BasePart, b: BasePart)
	local w = Instance.new("WeldConstraint")
	w.Part0 = a
	w.Part1 = b
	w.Parent = a
end

local function paint(instance: Instance, role: string)
	instance:SetAttribute("ColorRole", role)
end

local function makePart(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	role: string,
	opts: { Shape: Enum.PartType?, Material: Enum.Material?, CanCollide: boolean? }?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Anchored = true
	p.Massless = true
	p.CanCollide = if opts and opts.CanCollide then true else false
	p.CanQuery = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = (opts and opts.Material) or Enum.Material.SmoothPlastic
	if opts and opts.Shape then
		p.Shape = opts.Shape
	end
	paint(p, role)
	p.Parent = parent
	return p
end

local function addMark(plate: BasePart, face: Enum.NormalId)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "EmblemGui"
	gui.Face = face
	gui.LightInfluence = 0
	gui.Brightness = 2
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 50
	gui.Parent = plate

	local label = Instance.new("TextLabel")
	label.Name = "Mark"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBlack
	label.Text = "M"
	label.TextScaled = true
	paint(label, "Mark")
	label.Parent = gui
end

local function addNameplate(model: Model, title: string)
	local body = model.PrimaryPart
	if body == nil then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "LiveryName"
	gui.Size = UDim2.fromOffset(150, 34)
	gui.StudsOffset = Vector3.new(0, 4.4, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 80
	gui.Parent = body

	local label = Instance.new("TextLabel")
	label.BackgroundColor3 = Color3.fromRGB(12, 16, 24)
	label.BackgroundTransparency = 0.25
	label.BorderSizePixel = 0
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBold
	label.Text = title
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextScaled = true
	label.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = label
end

function KartPrototype.getPalette(id: string): Palette
	for _, palette in KartPrototype.Palettes do
		if palette.Id == id then
			return palette
		end
	end
	return KartPrototype.Palettes[1]
end

function KartPrototype.variants(): { Palette }
	local list = {}
	for _, palette in KartPrototype.Palettes do
		if palette.Id ~= "Default" then
			table.insert(list, palette)
		end
	end
	return list
end

function KartPrototype.applyPalette(model: Model, palette: Palette)
	model:SetAttribute("PaletteId", palette.Id)
	model:SetAttribute("PaletteName", palette.Name)
	for _, inst in model:GetDescendants() do
		local role = inst:GetAttribute("ColorRole")
		if typeof(role) ~= "string" then
			continue
		end
		local color = (palette :: any)[role]
		if typeof(color) ~= "Color3" then
			continue
		end
		if inst:IsA("BasePart") then
			inst.Color = color
		elseif inst:IsA("TextLabel") then
			inst.TextColor3 = color
		end
	end
end

function KartPrototype.build(): Model
	local model = Instance.new("Model")
	model.Name = TEMPLATE_NAME

	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = Vector3.new(4.15, 0.72, 7.15)
	body.CFrame = CFrame.new()
	body.Anchored = true
	body.CanCollide = true
	body.Material = Enum.Material.SmoothPlastic
	body.TopSurface = Enum.SurfaceType.Smooth
	body.BottomSurface = Enum.SurfaceType.Smooth
	paint(body, "Body")
	body.Parent = model
	model.PrimaryPart = body

	local cf = body.CFrame
	local visuals: { BasePart } = {}

	local function add(...: BasePart): BasePart
		local p = select(1, ...)
		table.insert(visuals, p)
		return p
	end

	add(makePart(model, "Hood", Vector3.new(3.05, 0.4, 1.85), cf * CFrame.new(0, 0.26, -2.45), "Body"))
	add(makePart(model, "FrontBumper", Vector3.new(3.35, 0.36, 0.95), cf * CFrame.new(0, -0.16, -3.82), "Accent"))
	add(makePart(model, "RearBumper", Vector3.new(4.15, 0.78, 0.95), cf * CFrame.new(0, 0.12, 3.58), "Rear"))
	add(makePart(model, "Cabin", Vector3.new(2.65, 1.18, 2.35), cf * CFrame.new(0, 0.92, 0.18), "Cabin"))
	add(makePart(model, "Cockpit", Vector3.new(1.95, 0.78, 1.45), cf * CFrame.new(0, 1.18, -0.08), "Cockpit"))
	add(makePart(model, "StripeL", Vector3.new(0.18, 0.62, 2.55), cf * CFrame.new(-2.1, 0.14, 0.22), "Stripe"))
	add(makePart(model, "StripeR", Vector3.new(0.18, 0.62, 2.55), cf * CFrame.new(2.1, 0.14, 0.22), "Stripe"))
	add(makePart(model, "SideAccentL", Vector3.new(0.16, 0.4, 0.72), cf * CFrame.new(-2.1, 0.06, 1.62), "Accent"))
	add(makePart(model, "SideAccentR", Vector3.new(0.16, 0.4, 0.72), cf * CFrame.new(2.1, 0.06, 1.62), "Accent"))

	add(makePart(
		model,
		"EmblemDisc",
		Vector3.new(0.24, 1.62, 1.62),
		cf * CFrame.new(0, 0.4, -4.48) * CFrame.Angles(0, math.rad(90), 0),
		"Emblem",
		{ Shape = Enum.PartType.Cylinder }
	))
	local plate = add(makePart(model, "EmblemFace", Vector3.new(0.95, 0.95, 0.05), cf * CFrame.new(0, 0.4, -4.62), "Emblem"))
	addMark(plate, Enum.NormalId.Front)

	local pipeTilt = CFrame.Angles(math.rad(-40), 0, 0) * CFrame.Angles(0, 0, math.rad(90))
	local pipeSize = Vector3.new(1.7, 0.78, 0.78)
	local tipSize = Vector3.new(0.52, 0.68, 0.68)
	for _, x in { -0.52, 0.52 } do
		local pipe = add(makePart(
			model,
			if x < 0 then "ExhaustL" else "ExhaustR",
			pipeSize,
			cf * CFrame.new(x, 1.02, 2.42) * pipeTilt,
			"Exhaust",
			{ Shape = Enum.PartType.Cylinder }
		))
		add(makePart(
			model,
			if x < 0 then "ExhaustTipL" else "ExhaustTipR",
			tipSize,
			pipe.CFrame * CFrame.new(pipeSize.X * 0.5 + tipSize.X * 0.22, 0, 0),
			"Tip",
			{ Shape = Enum.PartType.Cylinder }
		))
	end

	local wheelY = -0.58
	local wheelX = 2.38
	local tireSize = Vector3.new(0.95, 2.02, 2.02)
	local rimSize = Vector3.new(0.28, 1.28, 1.28)
	local corners = {
		{ "FL", -wheelX, -2.38 },
		{ "FR", wheelX, -2.38 },
		{ "RL", -wheelX, 2.22 },
		{ "RR", wheelX, 2.22 },
	}
	for _, corner in corners do
		local name, x, z = corner[1], corner[2], corner[3]
		local wheelCf = cf * CFrame.new(x, wheelY, z)
		local outward = if x < 0 then -0.48 else 0.48
		add(makePart(model, "Tire" .. name, tireSize, wheelCf, "Tire", {
			Shape = Enum.PartType.Cylinder,
			Material = Enum.Material.Rubber,
		}))
		add(makePart(
			model,
			"Rim" .. name,
			rimSize,
			cf * CFrame.new(x + outward, wheelY, z),
			"Rim",
			{ Shape = Enum.PartType.Cylinder }
		))
	end

	local seat = Instance.new("VehicleSeat")
	seat.Name = "Seat"
	seat.Size = Vector3.new(2.15, 0.48, 2.15)
	seat.CFrame = cf * CFrame.new(0, 0.95, 0.18)
	seat.HeadsUpDisplay = false
	seat.MaxSpeed = 500
	seat.Torque = 0
	seat.TurnSpeed = 0
	seat.Disabled = false
	seat.Anchored = true
	seat.Massless = true
	seat.CanCollide = false
	seat.Material = Enum.Material.SmoothPlastic
	paint(seat, "Seat")
	seat.Parent = model

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "EnterCar"
	prompt.ActionText = "Drive"
	prompt.ObjectText = "Mini Racer"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 16
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.Parent = seat

	for _, part in visuals do
		weld(body, part)
	end
	weld(body, seat)

	KartPrototype.applyPalette(model, KartPrototype.getPalette("Default"))
	return model
end

function KartPrototype.ensureTemplate(): Model
	local existing = ReplicatedStorage:FindFirstChild(TEMPLATE_NAME)
	if existing and existing:IsA("Model") then
		return existing
	end
	local model = KartPrototype.build()
	model.Parent = ReplicatedStorage
	return model
end

function KartPrototype.spawn(palette: Palette): Model
	local model = KartPrototype.ensureTemplate():Clone()
	model.Name = Constants.Car.Name
	KartPrototype.applyPalette(model, palette)
	return model
end

function KartPrototype.makeDisplay(model: Model)
	model:SetAttribute("Showcase", true)
	local seat = model:FindFirstChild("Seat")
	if seat and seat:IsA("VehicleSeat") then
		seat.Disabled = true
		local prompt = seat:FindFirstChild("EnterCar")
		if prompt then
			prompt:Destroy()
		end
	end
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
		end
	end
	addNameplate(model, model:GetAttribute("PaletteName") :: string or "Kart")
end

return KartPrototype
