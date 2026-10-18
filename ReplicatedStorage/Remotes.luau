local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FOLDER_NAME = "Remotes"

local NAMES = {
	RaceStateChanged = "RaceStateChanged",
	CheckpointPassed = "CheckpointPassed",
	RaceFinished = "RaceFinished",
	RequestRestart = "RequestRestart",
	DriveInput = "DriveInput",
	SelectKart = "SelectKart",
	CreditsChanged = "CreditsChanged",
	BuyItem = "BuyItem",
	InventoryChanged = "InventoryChanged",
	UseItem = "UseItem",
	ItemStateChanged = "ItemStateChanged",
	RecoverCar = "RecoverCar",
}

local Remotes = {
	Names = NAMES,
}

function Remotes.getFolder(): Instance
	return ReplicatedStorage:WaitForChild(FOLDER_NAME)
end

function Remotes.get(name: string): RemoteEvent
	return Remotes.getFolder():WaitForChild(name) :: RemoteEvent
end

function Remotes.ensure(): Instance
	local folder = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
	if folder == nil then
		folder = Instance.new("Folder")
		folder.Name = FOLDER_NAME
		folder.Parent = ReplicatedStorage
	end

	for _, name in NAMES do
		if folder:FindFirstChild(name) == nil then
			local remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = folder
		end
	end

	return folder
end

return Remotes
