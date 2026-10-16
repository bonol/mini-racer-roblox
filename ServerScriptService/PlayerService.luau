local Players = game:GetService("Players")

local Remotes = require(game:GetService("ReplicatedStorage"):WaitForChild("Remotes"))
local MatchService = require(script.Parent:WaitForChild("MatchService"))

local PlayerService = {}

function PlayerService.start()
	local function hook(player: Player)
		player.CharacterAdded:Connect(function()
			task.wait(0.4)
			MatchService.addPlayer(player)
		end)
		if player.Character then
			task.defer(function()
				MatchService.addPlayer(player)
			end)
		end
	end

	Players.PlayerAdded:Connect(hook)
	Players.PlayerRemoving:Connect(function(player)
		MatchService.removePlayer(player)
	end)

	Remotes.get("RequestRestart").OnServerEvent:Connect(function(player)
		MatchService.requestRestart(player)
	end)

	for _, player in Players:GetPlayers() do
		hook(player)
	end
end

return PlayerService
