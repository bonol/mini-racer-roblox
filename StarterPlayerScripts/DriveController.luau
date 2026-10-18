local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local Remotes = require(game:GetService("ReplicatedStorage"):WaitForChild("Remotes"))
local DriveSim = require(game:GetService("ReplicatedStorage"):WaitForChild("DriveSim"))

local DriveController = {}

local held: { [Enum.KeyCode]: boolean } = {}

local THROTTLE_POS = { Enum.KeyCode.W, Enum.KeyCode.Up }
local THROTTLE_NEG = { Enum.KeyCode.S, Enum.KeyCode.Down }
local STEER_POS = { Enum.KeyCode.D, Enum.KeyCode.Right }
local STEER_NEG = { Enum.KeyCode.A, Enum.KeyCode.Left }

local function isHeld(keys: { Enum.KeyCode }): boolean
	for _, key in keys do
		if held[key] or UserInputService:IsKeyDown(key) then
			return true
		end
	end
	return false
end

local function axis(positive: { Enum.KeyCode }, negative: { Enum.KeyCode }): number
	local value = 0
	if isHeld(positive) then
		value += 1
	end
	if isHeld(negative) then
		value -= 1
	end
	return value
end

function DriveController.start()
	local player = Players.LocalPlayer
	local sim = DriveSim.newState()
	local racing = false
	local seatedCar: Model? = nil
	local replicateAccum = 0

	UserInputService.InputBegan:Connect(function(input, processed)
		if input.UserInputType == Enum.UserInputType.Keyboard then
			held[input.KeyCode] = true
		end
		if processed or UserInputService:GetFocusedTextBox() ~= nil then
			return
		end
		if not racing then
			return
		end
		if input.KeyCode == Enum.KeyCode.E then
			Remotes.get("UseItem"):FireServer("Booster")
		elseif input.KeyCode == Enum.KeyCode.Q then
			Remotes.get("UseItem"):FireServer("Bomb")
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Keyboard then
			held[input.KeyCode] = nil
		end
	end)

	Remotes.get("RaceStateChanged").OnClientEvent:Connect(function(payload)
		racing = payload.state == "Racing"
	end)

	Remotes.get("RecoverCar").OnClientEvent:Connect(function(cf)
		if typeof(cf) ~= "CFrame" then
			return
		end
		if seatedCar and seatedCar.PrimaryPart then
			sim = DriveSim.newState(cf)
			seatedCar:PivotTo(cf)
		end
	end)

	-- Integrate before the chase cam so both use the same CFrame this frame.
	RunService:BindToRenderStep("MiniRacerDrive", Enum.RenderPriority.Input.Value, function(dt)
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local seat = humanoid and humanoid.SeatPart
		local car = seat and seat.Parent
		if car == nil or not car:IsA("Model") or car.PrimaryPart == nil then
			if seatedCar then
				sim = DriveSim.newState()
				seatedCar = nil
			end
			return
		end

		if seatedCar ~= car then
			seatedCar = car
			sim = DriveSim.newState(car.PrimaryPart.CFrame)
		end

		local throttle = 0
		local steer = 0
		if racing and UserInputService:GetFocusedTextBox() == nil then
			throttle = axis(THROTTLE_POS, THROTTLE_NEG)
			steer = axis(STEER_POS, STEER_NEG)
		end
		if car:GetAttribute("CanDrive") == false then
			throttle = 0
			steer = 0
		end

		DriveSim.step(sim, car, character, throttle, steer, dt)

		replicateAccum += dt
		if replicateAccum >= 1 / 15 and car.PrimaryPart then
			replicateAccum = 0
			Remotes.get("DriveInput"):FireServer(car.PrimaryPart.CFrame)
		end
	end)
end

return DriveController
