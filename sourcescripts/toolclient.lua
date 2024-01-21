--//Misenthropic

--//SERVICES

local PLAYERS = game:GetService("Players")
local REPLICATED_STORAGE = game:GetService("ReplicatedStorage")

--//OBJECTS

local player = PLAYERS.LocalPlayer
local storage = REPLICATED_STORAGE:WaitForChild("UEStorage")

--//SETUP

local tool_client = {}
local gun = require(script:WaitForChild("Gun"))

tool_client.setup = function()
	for _, tool in player.Backpack:GetChildren() do
		local config = tool:FindFirstChild("UEConfig")
		if config then
			print(tool)
			gun.setup(tool, require(config))
		end
	end
end

tool_client.setup()

return {}
