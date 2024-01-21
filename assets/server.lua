--//Misenthropic sbrgkuhrbsdgiuyrdbiuysgris7yurgidyurfgidrtyu

--//SERVICES

local PLAYERS = game:GetService("Players")
local REPLICATED_STORAGE = game:GetService("ReplicatedStorage")
local DEBRIS = game:GetService("Debris")

--//OBJECTS

local storage = REPLICATED_STORAGE:WaitForChild("UEStorage")

local network_function = storage.NetworkFunction
local network_event = storage.NetworkEvent

--//EVENT LISTENERS

network_function.OnServerInvoke = function(player, ...)
	local shit = {...}
	local call = shit[1]

	if call == "setup" then
		local config = shit[2]
		local gun_model = storage.Guns[config.gun_model]:Clone()

		local main_weld = Instance.new("Motor6D")
		main_weld.Parent = player.Character.Torso
		main_weld.Part0 = player.Character.Torso
		main_weld.Part1 = gun_model.Handle
		main_weld.Name = gun_model.Name

		for _, part in gun_model:GetDescendants() do
			if part:IsA("BasePart") then
				part.CanCollide = false
			end
		end

		gun_model.Parent = player.Character

		return gun_model
	end
end

network_event.OnServerEvent:Connect(function(player, ...)
	local shit = {...}
	local call = shit[1]

	if call == "fire" then
		local sound = shit[2]
		for _, target_player in PLAYERS:GetChildren() do
			if target_player ~= player then
				network_event:FireClient(target_player, "sound", sound)
			end
		end
	elseif call == "hit" then
		local hit_info = shit[2]
		local humanoid = hit_info.instance.Parent:FindFirstChildOfClass("Humanoid") or hit_info.instance.Parent.Parent:FindFirstChildOfClass("Humanoid")

		for _, target_player in PLAYERS:GetChildren() do
			if target_player ~= player then
				network_event:FireClient(target_player, "hit", hit_info)
			end
		end

		if humanoid then
			if humanoid.Health > 0 and hit_info.damage then
				humanoid:TakeDamage(hit_info.damage)
			end
		end
	elseif call == "projectile" then
		local projectile_info = shit[2]
		for _, target_player in PLAYERS:GetChildren() do
			if target_player ~= player then
				projectile_info.origin = player.Character.Head.Position
				network_event:FireClient(target_player, "projectile", projectile_info)
			end
		end
	elseif call == "showmodel" then
		local model = shit[2]
		for _, base_part in model:GetDescendants() do
			if base_part:IsA("BasePart") then
				base_part.Transparency = 0
			end
		end
	elseif call == "hidemodel" then
		local model = shit[2]
		for _, base_part in model:GetDescendants() do
			if base_part:IsA("BasePart") then
				base_part.Transparency = 1
			end
		end
	end
end)

PLAYERS.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		local character_script = script.UECharacter:Clone()
		character_script.Parent = character

		local player_script = script.UEClient:Clone()
		player_script.Parent = player

		delay(0.1, function()
			character_script.Enabled = true
			player_script.Enabled = true
		end)
	end)
end)
