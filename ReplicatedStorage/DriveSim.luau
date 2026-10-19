local Workspace = game:GetService("Workspace")

local Constants = require(script.Parent:WaitForChild("Constants"))

local DriveSim = {}

local BODY_HOVER = Constants.Car.BodyHover
local WALL_SKIN = 0.35
local MAX_STEP_SLACK = 0.75
local GRAVITY = 168
local LAND_BOUNCE = 0.26
local BOUNCE_MIN = 22
local STICK_UP = 8
local STICK_DOWN = 10
local GROUND_RAY = 240
local REVERSE_MAX = Constants.Car.MaxSpeed * 0.55

export type State = {
	speed: number,
	lastSafe: CFrame?,
	vy: number,
	lastMul: number,
	slowCap: number?,
	airborne: boolean,
}

function DriveSim.newState(at: CFrame?): State
	return {
		speed = 0,
		lastSafe = at,
		vy = 0,
		lastMul = 1,
		slowCap = nil,
		airborne = false,
	}
end

local function isWall(instance: Instance?): boolean
	return instance ~= nil and (instance.Name == "Barrier" or instance.Name == "BarrierWall")
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

local function groundY(model: Model, character: Model?, from: Vector3): number?
	local ray = select(1, excludeParams(model, character))
	local origin = from + Vector3.new(0, 12, 0)
	local remaining = GROUND_RAY
	for _ = 1, 16 do
		if remaining < 2 then
			return nil
		end
		local hit = Workspace:Raycast(origin, Vector3.new(0, -remaining, 0), ray)
		if hit == nil then
			return nil
		end
		local name = hit.Instance.Name
		if name == "Road" or name == "Grass" then
			return hit.Position.Y + BODY_HOVER
		end
		origin = hit.Position + Vector3.new(0, -0.15, 0)
		remaining -= math.max(hit.Distance, 0.15) + 0.15
	end
	return nil
end

function DriveSim.followGround(y: number, vy: number, ground: number?, dt: number, airborne: boolean?): (number, number, boolean)
	dt = math.max(dt, 1 / 240)
	local inAir = airborne == true
	if ground ~= nil and not inAir then
		local above = y - ground
		if above <= STICK_DOWN and -above <= STICK_UP then
			return ground, 0, false
		end
		inAir = true
	end
	vy -= GRAVITY * dt
	y += vy * dt
	if ground ~= nil and y <= ground then
		y = ground
		if vy < -BOUNCE_MIN then
			vy = -vy * LAND_BOUNCE
			return y, vy, vy > 6
		end
		return y, 0, false
	end
	if ground == nil and y < BODY_HOVER then
		return BODY_HOVER, 0, false
	end
	return y, vy, true
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

local function sweepSize(body: BasePart, airborne: boolean): Vector3
	local y = if airborne then math.max(10, body.Size.Y + 6) else math.max(0.35, body.Size.Y * 0.4)
	return Vector3.new(body.Size.X * 0.72, y, body.Size.Z * 0.72)
end

local function overlapsWall(at: CFrame, size: Vector3, overlap: OverlapParams): boolean
	for _, part in Workspace:GetPartBoundsInBox(at, size, overlap) do
		if isWall(part) then
			return true
		end
	end
	return false
end

local function closestWallHit(startCf: CFrame, body: BasePart, movement: Vector3, ray: RaycastParams, airborne: boolean): RaycastResult?
	if movement.Magnitude < 0.001 then
		return nil
	end
	local size = sweepSize(body, airborne)
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
	dt: number,
	maxFwd: number,
	maxRev: number
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

	local maxStep = maxFwd * dt + MAX_STEP_SLACK
	local signedStep = speed * dt
	if math.abs(signedStep) > maxStep then
		signedStep = math.sign(signedStep) * maxStep
	end
	local movement = flatLook * signedStep
	local startCf = CFrame.lookAt(startPos, startPos + flatLook)
	local pos = startPos + movement
	local hit = closestWallHit(startCf, body, movement, ray, state.airborne)
	if hit then
		local n = inwardNormal(startPos, hit.Position, hit.Normal)
		if movement.Magnitude > 0.001 then
			local travel = math.max(0, hit.Distance - WALL_SKIN)
			pos = startPos + movement.Unit * travel + n * WALL_SKIN
		else
			pos = startPos + n * WALL_SKIN
		end
		local vel = reflectVelocity(flatLook * speed, n)
		speed = math.clamp(vel:Dot(flatLook), -maxRev, maxFwd)
		if math.abs(speed) <= 1 then
			speed = 0
		end
	end

	local proposed = CFrame.lookAt(pos, pos + flatLook)
	if overlapsWall(proposed, sweepSize(body, state.airborne), overlap) then
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
	local y, vy, inAir = DriveSim.followGround(startPos.Y, state.vy, ground, dt, state.airborne)
	state.vy = vy
	state.airborne = inAir
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

function DriveSim.step(state: State, model: Model, character: Model?, throttle: number, steer: number, dt: number, jumpWanted: boolean?)
	local body = model.PrimaryPart
	if body == nil then
		return
	end
	dt = math.clamp(dt, 1 / 240, 1 / 30)

	local mul = model:GetAttribute("SpeedMul")
	if typeof(mul) ~= "number" or mul <= 0 then
		mul = 1
	end
	local lastMul = state.lastMul or 1
	local speed = state.speed
	if mul < lastMul - 0.05 then
		speed *= Constants.Items.SlowMul
		state.slowCap = math.abs(speed)
	elseif mul >= 0.99 then
		state.slowCap = nil
	end
	state.lastMul = mul

	local lookHint = Vector3.new(body.CFrame.LookVector.X, 0, body.CFrame.LookVector.Z)
	if lookHint.Magnitude < 0.05 then
		lookHint = Vector3.new(1, 0, 0)
	else
		lookHint = lookHint.Unit
	end
	local yAhead = groundY(model, character, body.Position + lookHint * 5)
	local yBehind = groundY(model, character, body.Position - lookHint * 5)
	local pitch = math.atan2(yAhead - yBehind, 10)
	local travelClimb = if speed >= 0 then pitch else -pitch
	local gradeMul = 1
	if not state.airborne and travelClimb > 0.02 then
		gradeMul = math.clamp(1 - math.sin(travelClimb), Constants.Track.ClimbMinMul, 1)
	end

	local maxFwd = Constants.Car.MaxSpeed * mul * gradeMul
	local maxRev = REVERSE_MAX * mul * gradeMul
	if state.slowCap then
		maxFwd = math.min(maxFwd, state.slowCap * gradeMul)
		maxRev = math.min(maxRev, state.slowCap * gradeMul)
	end
	if throttle > 0.05 then
		if speed < 0 then
			speed += Constants.Car.Brake * dt
		else
			speed += Constants.Car.Acceleration * mul * gradeMul * dt
		end
	elseif throttle < -0.05 then
		if speed > 0 then
			speed -= Constants.Car.Brake * dt
		else
			speed -= Constants.Car.Acceleration * mul * gradeMul * dt
		end
	else
		local coast = Constants.Car.Brake * 0.45 * dt
		if speed > 0 then
			speed = math.max(0, speed - coast)
		elseif speed < 0 then
			speed = math.min(0, speed + coast)
		end
	end
	speed = math.clamp(speed, -maxRev, maxFwd)

	local look = body.CFrame.LookVector
	local flatLook = Vector3.new(look.X, 0, look.Z)
	if flatLook.Magnitude < 0.05 then
		flatLook = Vector3.new(1, 0, 0)
	else
		flatLook = flatLook.Unit
	end

	local yaw = -steer
		* Constants.Car.TurnSpeed
		* math.clamp((math.abs(speed) + 10) / 28, 0.4, 1)
		* (if state.airborne then Constants.Car.AirSteerMul else 1)
	flatLook = (CFrame.lookAt(Vector3.zero, flatLook) * CFrame.Angles(0, yaw * dt, 0)).LookVector
	flatLook = Vector3.new(flatLook.X, 0, flatLook.Z)
	if flatLook.Magnitude < 0.05 then
		state.speed = speed
		model:SetAttribute("HudSpeed", math.abs(speed))
		return
	end
	flatLook = flatLook.Unit

	if jumpWanted == true and not state.airborne then
		local takeoff = groundY(model, character, body.Position)
		if takeoff and (body.Position.Y - takeoff) <= STICK_DOWN then
			local height = Constants.Car.Height * Constants.Car.JumpHeightFrac
			height *= math.sqrt(math.clamp(mul, Constants.Items.SlowMul, Constants.Items.BoostMul))
			state.vy = math.sqrt(2 * GRAVITY * height)
			state.airborne = true
		end
	end

	local pos
	pos, flatLook, speed = bounceMove(state, body, model, character, flatLook, speed, dt, maxFwd, maxRev)
	state.speed = speed
	model:SetAttribute("HudSpeed", math.abs(speed))
	local look3d = Vector3.new(flatLook.X, math.tan(pitch), flatLook.Z)
	if look3d.Magnitude < 0.05 then
		look3d = flatLook
	end
	model:PivotTo(CFrame.lookAt(pos, pos + look3d))
	zeroVelocities(model)
end

return DriveSim
