local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Remotes = require(game:GetService("ReplicatedStorage"):WaitForChild("Remotes"))

local CameraController = {}

local FOLLOW_BEHIND = 16
local FOLLOW_HEIGHT = 7
local LOOK_AHEAD = 12
local LOOK_HEIGHT = 2
local ORIGIN_HEIGHT = 5
local DIST_RATE = 16

local function expAlpha(rate: number, dt: number): number
	return 1 - math.exp(-rate * math.clamp(dt, 1 / 240, 1 / 20))
end

function CameraController.start()
	local player = Players.LocalPlayer
	local camera = Workspace.CurrentCamera
	local chasing = false
	local selecting = false
	local camDist = FOLLOW_BEHIND

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude

	Remotes.get("RaceStateChanged").OnClientEvent:Connect(function(payload)
		selecting = payload.state == "Selecting" or payload.state == "Lobby"
		if selecting then
			chasing = false
			camera.CameraType = Enum.CameraType.Custom
		end
	end)

	RunService:BindToRenderStep("MiniRacerCamera", Enum.RenderPriority.Camera.Value, function(dt)
		if selecting then
			if camera.CameraType ~= Enum.CameraType.Custom then
				camera.CameraType = Enum.CameraType.Custom
			end
			chasing = false
			return
		end

		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local seated = humanoid ~= nil and humanoid.SeatPart ~= nil
		if seated == false then
			if chasing then
				camera.CameraType = Enum.CameraType.Custom
				chasing = false
				camDist = FOLLOW_BEHIND
			end
			return
		end

		local car = humanoid.SeatPart.Parent
		if car == nil or not car:IsA("Model") or car.PrimaryPart == nil then
			if chasing then
				camera.CameraType = Enum.CameraType.Custom
				chasing = false
				camDist = FOLLOW_BEHIND
			end
			return
		end

		local root = car.PrimaryPart
		local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
		if look.Magnitude < 0.05 then
			return
		end
		look = look.Unit

		if chasing == false then
			camera.CameraType = Enum.CameraType.Scriptable
			chasing = true
			camDist = FOLLOW_BEHIND
		end

		local origin = root.Position + Vector3.new(0, ORIGIN_HEIGHT, 0)
		local desired = origin - look * FOLLOW_BEHIND + Vector3.new(0, FOLLOW_HEIGHT, 0)
		local exclude: { Instance } = { car }
		if character then
			table.insert(exclude, character)
		end
		params.FilterDescendantsInstances = exclude
		local hit = Workspace:Raycast(origin, desired - origin, params)
		local targetDist = FOLLOW_BEHIND
		if hit then
			targetDist = math.clamp((hit.Position - origin).Magnitude - 1.4, 7, FOLLOW_BEHIND)
		end
		camDist += (targetDist - camDist) * expAlpha(DIST_RATE, dt)

		local height = FOLLOW_HEIGHT * (0.55 + 0.45 * (camDist / FOLLOW_BEHIND))
		local camPos = origin - look * camDist + Vector3.new(0, height, 0)
		local focus = root.Position + look * LOOK_AHEAD + Vector3.new(0, LOOK_HEIGHT, 0)
		camera.CameraType = Enum.CameraType.Scriptable
		camera.CFrame = CFrame.lookAt(camPos, focus)
	end)
end

return CameraController
