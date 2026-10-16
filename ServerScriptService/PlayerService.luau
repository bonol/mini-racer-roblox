local Players = game:GetService("Players")

local Remotes = require(game:GetService("ReplicatedStorage"):WaitForChild("Remotes"))
local RaceService = require(script.Parent:WaitForChild("RaceService"))

local PlayerService = {}

function PlayerService.start()
	local function hook(player: Player)
		player.CharacterAdded:Connect(function()
			task.wait(0.4)
			RaceService.start(player)
		end)
		if player.Character then
			task.defer(function()
				RaceService.start(player)
			end)
		end
	end

	Players.PlayerAdded:Connect(hook)
	Players.PlayerRemoving:Connect(function(player)
		RaceService.forget(player)
	end)

	Remotes.get("RequestRestart").OnServerEvent:Connect(function(player)
		RaceService.start(player)
	end)

	for _, player in Players:GetPlayers() do
		hook(player)
	end
end

return PlayerService
