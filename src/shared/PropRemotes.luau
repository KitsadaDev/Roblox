--!strict
-- ReplicatedStorage/Shared/PropRemotes.luau
-- Ensures the PropRemotes folder and all required RemoteEvents exist in ReplicatedStorage.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FOLDER_NAME = "PropRemotes"
local REMOTE_NAMES = {
	"MorphRequest",
	"ToggleLockRequest",
	"RotatePropRequest",
	"SeekerAttackRequest",
	"TauntRequest",
	"AbilityRequest",
	"RadarFeedback",
	"VoteMapRequest",
	"RoundEventNotice",
}

local remotesFolder: Folder

if RunService:IsServer() then
	local existing = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
	if existing and existing:IsA("Folder") then
		remotesFolder = existing
	else
		remotesFolder = Instance.new("Folder")
		remotesFolder.Name = FOLDER_NAME
		remotesFolder.Parent = ReplicatedStorage
	end

	for _, name in REMOTE_NAMES do
		if not remotesFolder:FindFirstChild(name) then
			local remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = remotesFolder
		end
	end
else
	remotesFolder = ReplicatedStorage:WaitForChild(FOLDER_NAME) :: Folder
end

return {
	Folder = remotesFolder,
	MorphRequest = remotesFolder:WaitForChild("MorphRequest") :: RemoteEvent,
	ToggleLockRequest = remotesFolder:WaitForChild("ToggleLockRequest") :: RemoteEvent,
	RotatePropRequest = remotesFolder:WaitForChild("RotatePropRequest") :: RemoteEvent,
	SeekerAttackRequest = remotesFolder:WaitForChild("SeekerAttackRequest") :: RemoteEvent,
	TauntRequest = remotesFolder:WaitForChild("TauntRequest") :: RemoteEvent,
	AbilityRequest = remotesFolder:WaitForChild("AbilityRequest") :: RemoteEvent,
	RadarFeedback = remotesFolder:WaitForChild("RadarFeedback") :: RemoteEvent,
	VoteMapRequest = remotesFolder:WaitForChild("VoteMapRequest") :: RemoteEvent,
	RoundEventNotice = remotesFolder:WaitForChild("RoundEventNotice") :: RemoteEvent,
}
