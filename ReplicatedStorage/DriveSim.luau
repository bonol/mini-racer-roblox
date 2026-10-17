local Workspace = game:GetService("Workspace")

local Constants = require(script.Parent:WaitForChild("Constants"))

local DriveSim = {}

local BODY_HOVER = 1.7
local WALL_SKIN = 0.35
local MAX_STEP_SLACK = 0.75
local GRAVITY = 168
local MAX_LAUNCH = 52
local LAND_BOUNCE = 0.26
local BOUNCE_MIN = 22
local REVERSE_MAX = Constants.Car.MaxSpeed * 0.55

export type State = {
	speed: number,
	lastSafe: CFrame?,
	vy: number,
}

function DriveSim.newState(at: CFrame?): State
	return {
		speed = 0,
		lastSafe = at,
		vy = 0,
	}
end

local function isWall(instance: Instance?): boolean
	return instance ~= nil and instance.Name == "Barrier"
end

local function excludeParams(model: Model, character: Model?): (RaycastParams, OverlapParams)
	local exclude: { Instance } = { model }
	if character then
		table.insert(exclude, character)
	end
	local ray = RaycastParams.new()
	ray.FilterType = Enum.RaycastFilterType.Exclude
	ray.FilterDescendantsInstances = exclude
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Exclude
	overlap.FilterDescendantsInstances = exclude
	return ray, overlap
end

local function groundY(model: Model, character: Model?, from: Vector3): number
	local ray = select(1, excludeParams(model, character))
	local origin = from + Vector3.new(0, 8, 0)
	local remaining = 48
	for _ = 1, 8 do
		local hit = Workspace:Raycast(origin, Vector3.new(0, -remaining, 0), ray)
		if hit == nil then
			return from.Y
		end
		local name = hit.Instance.Name
		if name == "Road" or name == "Grass" then
			return hit.Position.Y + BODY_HOVER
		end
		origin = hit.Position + Vector3.new(0, -0.2, 0)
		remaining -= 0.2
		if remaining < 2 then
			break
		end
	end
	return from.Y
end

local function flatten(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function inwardNormal(startPos: Vector3, hitPos: Vector3, reported: Vector3): Vector3
	local n = flatten(reported)
	if n.Magnitude < 0.05 then
		n = flatten(startPos - hitPos)
	end
	if n.Magnitude < 0.05 then
		return Vector3.new(0, 0, 1)
	end
	n = n.Unit
	local towardStart = flatten(startPos - hitPos)
	if towardStart.Magnitude > 0.05 and n:Dot(towardStart) < 0 then
		n = -n
	end
	return n
end

local function reflectVelocity(vel: Vector3, normal: Vector3): Vector3
	local n = flatten(normal)
	if n.Magnitude < 0.05 then
		return flatten(vel)
	end
	n = n.Unit
	local into = vel:Dot(n)
	if into >= 0 then
		return flatten(vel)
	end
	return flatten(vel - (1 + Constants.Track.WallBounce) * into * n)
end

local function sweepSize(body: BasePart): Vector3
	return Vector3.new(body.Size.X * 0.72, math.max(0.35, body.Size.Y * 0.4), body.Size.Z * 0.72)
end

local function overlapsWall(at: CFrame, size: Vector3, overlap: OverlapParams): boolean
	for _, part in Workspace:GetPartBoundsInBox(at, size, overlap) do
		if isWall(part) then
			return true
		end
	end
	return false
end

local function closestWallHit(startCf: CFrame, body: BasePart, movement: Vector3, ray: RaycastParams): RaycastResult?
	if movement.Magnitude < 0.001 then
		return nil
	end
	local size = sweepSize(body)
	local maxDist = movement.Magnitude + 0.15
	local best: RaycastResult? = nil
	local localOffsets = {
		Vector3.zero,
		Vector3.new(body.Size.X * 0.32, 0, 0),
		Vector3.new(-body.Size.X * 0.32, 0, 0),
		Vector3.new(0, 0, body.Size.Z * 0.18),
		Vector3.new(0, 0, -body.Size.Z * 0.18),
	}
	for _, localOff in localOffsets do
		local origin = startCf * CFrame.new(localOff)
		local hit = Workspace:Blockcast(origin, size, movement, ray)
		if
			hit
			and isWall(hit.Instance)
			and hit.Distance <= maxDist
			and (best == nil or hit.Distance < best.Distance)
		then
			best = hit
		end
	end
	return best
end

local function bounceMove(
	state: State,
	body: BasePart,
	model: Model,
	character: Model?,
	flatLook: Vector3,
	speed: number,
	dt: number
): (Vector3, Vector3, number)
	local ray, overlap = excludeParams(model, character)
	local safe = state.lastSafe
	local startPos = body.Position
	if safe and (body.Position - safe.Position).Magnitude > 12 then
		startPos = safe.Position
		local safeLook = flatten(safe.LookVector)
		if safeLook.Magnitude > 0.05 then
			flatLook = safeLook.Unit
		end
	end

	local maxStep = Constants.Car.MaxSpeed * dt + MAX_STEP_SLACK
	local signedStep = speed * dt
	if math.abs(signedStep) > maxStep then
		signedStep = math.sign(signedStep) * maxStep
	end
	local movement = flatLook * signedStep
	local startCf = CFrame.lookAt(startPos, startPos + flatLook)
	local pos = startPos + movement
	local hit = closestWallHit(startCf, body, movement, ray)
	if hit then
		local n = inwardNormal(startPos, hit.Position, hit.Normal)
		if movement.Magnitude > 0.001 then
			local travel = math.max(0, hit.Distance - WALL_SKIN)
			pos = startPos + movement.Unit * travel + n * WALL_SKIN
		else
			pos = startPos + n * WALL_SKIN
		end
		local vel = reflectVelocity(flatLook * speed, n)
		speed = math.clamp(vel:Dot(flatLook), -REVERSE_MAX, Constants.Car.MaxSpeed)
		if math.abs(speed) <= 1 then
			speed = 0
		end
	end

	local proposed = CFrame.lookAt(pos, pos + flatLook)
	if overlapsWall(proposed, sweepSize(body), overlap) then
		if safe then
			pos = safe.Position
			local safeLook = flatten(safe.LookVector)
			if safeLook.Magnitude > 0.05 then
				flatLook = safeLook.Unit
			end
		else
			pos = startPos
		end
		speed *= 0.35
	else
		state.lastSafe = proposed
	end

	local delta = flatten(pos - startPos)
	local maxMove = math.abs(signedStep) + WALL_SKIN + 0.5
	if delta.Magnitude > maxMove then
		pos = startPos + delta.Unit * maxMove
	end

	local ground = groundY(model, character, pos)
	local y = startPos.Y
	local vy = state.vy
	if y <= ground + 0.4 then
		local rise = ground - y
		if rise > 0 then
			y = ground
			vy = math.min(MAX_LAUNCH, math.max(vy, rise / math.max(dt, 1 / 240)))
		end
	end
	vy -= GRAVITY * dt
	y += vy * dt
	if y < ground then
		y = ground
		if vy < -BOUNCE_MIN then
			vy = -vy * LAND_BOUNCE
		else
			vy = 0
		end
	end
	state.vy = vy
	pos = Vector3.new(pos.X, y, pos.Z)
	return pos, flatLook, speed
end

local function zeroVelocities(model: Model)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.AssemblyLinearVelocity = Vector3.zero
			part.AssemblyAngularVelocity = Vector3.zero
		end
	end
end

function DriveSim.step(state: State, model: Model, character: Model?, throttle: number, steer: number, dt: number)
	local body = model.PrimaryPart
	if body == nil then
		return
	end
	dt = math.clamp(dt, 1 / 240, 1 / 30)

	local speed = state.speed
	if throttle > 0.05 then
		if speed < 0 then
			speed += Constants.Car.Brake * dt
		else
			speed += Constants.Car.Acceleration * dt
		end
	elseif throttle < -0.05 then
		if speed > 0 then
			speed -= Constants.Car.Brake * dt
		else
			speed -= Constants.Car.Acceleration * dt
		end
	else
		local coast = Constants.Car.Brake * 0.45 * dt
		if speed > 0 then
			speed = math.max(0, speed - coast)
		elseif speed < 0 then
			speed = math.min(0, speed + coast)
		end
	end
	speed = math.clamp(speed, -REVERSE_MAX, Constants.Car.MaxSpeed)

	local look = body.CFrame.LookVector
	local flatLook = Vector3.new(look.X, 0, look.Z)
	if flatLook.Magnitude < 0.05 then
		flatLook = Vector3.new(1, 0, 0)
	else
		flatLook = flatLook.Unit
	end

	local yaw = -steer * Constants.Car.TurnSpeed * math.clamp((math.abs(speed) + 10) / 28, 0.4, 1)
	flatLook = (CFrame.lookAt(Vector3.zero, flatLook) * CFrame.Angles(0, yaw * dt, 0)).LookVector
	flatLook = Vector3.new(flatLook.X, 0, flatLook.Z)
	if flatLook.Magnitude < 0.05 then
		state.speed = speed
		return
	end
	flatLook = flatLook.Unit

	local pos
	pos, flatLook, speed = bounceMove(state, body, model, character, flatLook, speed, dt)
	state.speed = speed
	model:PivotTo(CFrame.lookAt(pos, pos + flatLook, Vector3.yAxis))
	zeroVelocities(model)
end

return DriveSim
