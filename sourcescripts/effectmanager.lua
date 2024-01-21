--//Misenthropic

local GORE = false

--//SERVICES

local PLAYERS = game:GetService("Players")
local REPLICATED_STORAGE = game:GetService("ReplicatedStorage")
local DEBRIS = game:GetService("Debris")

--//OBJECTS

local storage = REPLICATED_STORAGE:WaitForChild("UEStorage")

local network_function = storage.NetworkFunction
local network_event = storage.NetworkEvent

local projectile_manager = require(storage.Modules.ProjectileManager)
local projectile = projectile_manager.new()

local function weld_part(part0, part1, rel_part)
	local weld = Instance.new("Weld")
	weld.Part0 = part0
	weld.Part1 = part1
	weld.C0 = CFrame.new()
	weld.C1 = part1.CFrame:toObjectSpace(rel_part.CFrame)
	weld.Parent = part0
end

local effect_manager = {}
effect_manager.__index = effect_manager

effect_manager.effect = function(self, ...)
	local shit = {...}
	local call = shit[1]

	if call == "projectile" then
		local projectile_info = shit[2]

		projectile:cast(projectile_info)
	elseif call == "sound" then
		local sound = shit[2]
		local distance

		if sound then
			if sound.Parent:IsA("Attachment") then
				distance = (workspace.CurrentCamera.CFrame.Position - sound.Parent.WorldPosition).Magnitude
			else
				distance = (workspace.CurrentCamera.CFrame.Position - sound.Parent.Position).Magnitude
			end

			local muffle_distance = 500

			local sound_clone = sound:Clone()
			local random = Random.new(6969 * math.random())
			sound_clone.PlaybackSpeed = sound.PlaybackSpeed * random:NextNumber(0.9, 1.1)

			local equalizer = Instance.new("EqualizerSoundEffect")
			equalizer.HighGain = 0 - (distance/muffle_distance) * 80
			equalizer.LowGain = 0 + (distance/muffle_distance) * 10
			equalizer.MidGain = 0 - (distance/muffle_distance) * 80

			local equalizer2 = Instance.new("EqualizerSoundEffect")
			equalizer2.HighGain = 0 - (distance/muffle_distance) * 80
			equalizer2.LowGain = 0 - (distance/muffle_distance) * 80
			equalizer2.MidGain = 0 + (distance/muffle_distance) * 10

			local compressor = Instance.new("CompressorSoundEffect")
			compressor.Attack = 1
			compressor.Ratio = 50
			compressor.Release = 0.15

			equalizer.Parent = sound_clone
			equalizer2.Parent = sound_clone
			compressor.Parent = sound_clone

			sound_clone.Parent = sound.Parent
			sound_clone:Play()

			DEBRIS:AddItem(sound_clone, sound_clone.TimeLength/sound_clone.PlaybackSpeed)
		end
	elseif call == "hit" then
		local hit_info = shit[2]
		if hit_info == nil then return end
		local humanoid = hit_info.instance.Parent:FindFirstChildOfClass("Humanoid") or hit_info.instance.Parent.Parent:FindFirstChildOfClass("Humanoid")

		local hit_part = Instance.new("Part")
		hit_part.Transparency = 1
		hit_part.CanCollide = false
		hit_part.Anchored = true
		hit_part.CanQuery = false
		hit_part.CanTouch = false
		hit_part.Size = Vector3.new(0.1, 0.1, 0.01)
		hit_part.Position = hit_info.position
		hit_part.CFrame = CFrame.lookAt(hit_part.Position, hit_part.Position + hit_info.normal)
		hit_part.Parent = workspace.UEWorkspace

		local weld = Instance.new("WeldConstraint")
		weld.Parent = hit_part
		weld.Part0 = hit_info.instance
		weld.Part1 = hit_part
		hit_part.Anchored = false

		local bullet_holes = storage.Assets.BulletHoles
		local sounds = storage.Assets.Sounds
		local particles = storage.Assets.Particles

		local hit_image = bullet_holes.Concrete:GetChildren()[math.random(1, #bullet_holes.Concrete:GetChildren())]:Clone()
		local hit_sound = sounds.Concrete:GetChildren()[math.random(1, #sounds.Concrete:GetChildren())]:Clone()
		local hit_particles = storage.Assets.Particles.Concrete:GetChildren()

		if hit_info.material == (Enum.Material.Metal or Enum.Material.DiamondPlate or Enum.Material.CorrodedMetal) then
			hit_image = bullet_holes.Humanoid:GetChildren()[math.random(1, #bullet_holes.Humanoid:GetChildren())]:Clone()
			hit_sound = sounds.Metal:GetChildren()[math.random(1, #sounds.Metal:GetChildren())]:Clone()
			hit_particles = particles.Metal:GetChildren()
		end

		if humanoid then
			hit_image = bullet_holes.Humanoid:GetChildren()[math.random(1, #bullet_holes.Humanoid:GetChildren())]:Clone()
			hit_sound = sounds.Humanoid.Hit:GetChildren()[math.random(1, #sounds.Humanoid.Hit:GetChildren())]:Clone()
			hit_particles = particles.Humanoid.Hit:GetChildren()
			
			if GORE then
				if hit_info.lethality >= 2 then
					local limb = hit_info.instance.Name
					if limb == "HumanoidRootPart" then
						limb = "Torso"
					end
					if storage.Assets.Gore[limb] == nil then return end
					if humanoid.Parent:FindFirstChild("GoreModels") == nil then
						local gore_folder = Instance.new("Folder")
						gore_folder.Name = "GoreModels"
						gore_folder.Parent = humanoid.Parent
					end
					local gore_model = storage.Assets.Gore[limb]:GetChildren()[math.random(1, #storage.Assets.Gore[limb]:GetChildren())]:Clone()
					if humanoid.Parent.GoreModels:FindFirstChild(limb) == nil then
						for _, base_part in gore_model:GetChildren() do
							if base_part:IsA("BasePart") then
								base_part.Anchored = false
								base_part.CanCollide = false
								base_part.CanQuery = false
								weld_part(humanoid.Parent[limb], base_part, storage.Assets.Gore.GoreDummy[limb])
							end
						end
						hit_sound = sounds.Humanoid.Gore:GetChildren()[math.random(1, #sounds.Humanoid.Gore:GetChildren())]:Clone()
						gore_model.Name = limb
						gore_model.Parent = humanoid.Parent.GoreModels
						hit_info.instance.Transparency = 1
					end
				end
			end
		else
			if hit_info.lethality >= 2 then
				local crack_sound = sounds.Crack:GetChildren()[math.random(1, #sounds.Crack:GetChildren())]:Clone()
				crack_sound.Volume *= hit_info.lethality
				crack_sound.Parent = hit_part
				self:effect("sound", crack_sound)
			end
		end

		hit_sound.RollOffMode = Enum.RollOffMode.InverseTapered
		hit_sound.Parent = hit_part
		self:effect("sound", hit_sound)

		hit_image.ImageLabel.Rotation = math.random(-180, 180)
		hit_image.ImageLabel.Size = UDim2.new(
			0, 
			hit_image.ImageLabel.Size.X.Offset * hit_info.lethality,
			0,
			hit_image.ImageLabel.Size.Y.Offset * hit_info.lethality
		)
		hit_image.Parent = hit_part

		for _, particle in pairs(hit_particles) do
			local clone = particle:Clone()
			clone.Parent = hit_part
			task.delay(0.01, function()
				clone:Emit(clone.Rate)
			end)
		end

		DEBRIS:AddItem(hit_part, 30)
	end
end

network_event.OnClientEvent:Connect(function(...)
	print(...)
	effect_manager:effect(...)
end)

return effect_manager
