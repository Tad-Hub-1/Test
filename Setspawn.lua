local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local FORCED_SPAWN_LOCATION_NAME = "SpawnLocation" 

local targetSpawn = Workspace:FindFirstChild(FORCED_SPAWN_LOCATION_NAME)

if not targetSpawn then
	warn("!!! สคริปต์บังคับเกิด: ไม่พบ SpawnLocation ที่ชื่อ '" .. FORCED_SPAWN_LOCATION_NAME .. "' !!!")
	return
end

local function forceSpawn(character)
	local rootPart = character:WaitForChild("HumanoidRootPart")
	
	task.wait(0.1) 
	
	rootPart.CFrame = targetSpawn.CFrame + Vector3.new(0, 3, 0)
end

local function onPlayerAdded(player)
	player.CharacterAdded:Connect(forceSpawn)
end

Players.PlayerAdded:Connect(onPlayerAdded)
