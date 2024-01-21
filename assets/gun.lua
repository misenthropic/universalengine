--//Misenthropic

--//PREACH

local gun = {}
gun.__index = gun

--//SERVICES

local PLAYERS = game:GetService("Players")
local REPLICATED_STORAGE = game:GetService("ReplicatedStorage")
local USER_INPUT_SERVICE = game:GetService("UserInputService")
local DEBRIS = game:GetService("Debris")
local RUN_SERVICE = game:GetService("RunService")
local TWEEN_SERVICE = game:GetService("TweenService")
local REPLICATED_FIRST = game:GetService("ReplicatedFirst")

--//OBJECTS

local player = PLAYERS.LocalPlayer
local mouse = player:GetMouse()
local storage = REPLICATED_STORAGE:WaitForChild("UEStorage")

local network_function = storage.NetworkFunction
local network_event = storage.NetworkEvent

local projectile = require(storage.Modules.ProjectileManager)
local effect_manager = require(player.UEClient.EffectManager)

--//GUN

gun.setup = function(tool, config)
	local self = setmetatable({}, gun)
	self.tool = tool
	self.equipped = false

	self.animations = {}
	self.config = {}

	for setting, value in config do
		self.config[setting] = value
	end

	self.ammo = self.tool.UEConfig.Ammo
	self.reserve = self.tool.UEConfig.Reserve

	for animation_name, animation_info in self.config.animations do
		if animation_info[1] == nil then return end
		local animation_object = Instance.new("Animation")
		animation_object.AnimationId = animation_info[1]

		self.animations[animation_name] = player.Character.Humanoid:LoadAnimation(animation_object)
		self.animations[animation_name].Priority = animation_info[2]
	end

	self.tool.Equipped:Connect(function() self:equip() end)
	self.tool.Unequipped:Connect(function() self:unequip() end)
	self.gun_model = network_function:InvokeServer("setup", self.config)
	self.projectile = projectile.new()
	self.projectile.hit = function(ray_result) self:hit(ray_result) end

	if self.network_connection then
		self.network_connection:Disconnect()
	end

	task.delay(0.01, function()
		if self.animations["Unequipped"] == nil then
			network_event:FireServer("hidemodel", self.gun_model)
		else
			self.animations["Unequipped"]:Play()
		end
	end)
end

gun.equip = function(self)
	self.equipped_connections = {}
	self.viewmodel_cframes = {
		idle_offset = Instance.new("CFrameValue"),
		aim_offset = Instance.new("CFrameValue"),
		sway_offset = Instance.new("CFrameValue"),
		bob_offset = Instance.new("CFrameValue"),
	}
	self.equipped = true
	self.reloading = false
	self.mouse_down = false
	self.aiming = false
	self.firing = false
	self.first_person = false
	self.camera_offsets = {}
	self.camera_offsets.fire = Vector3.new(0, 0, 0)
	self.animations["Equip"]:Play()
	if self.animations.Unequipped then
		self.animations["Unequipped"]:Stop()
	end
	task.delay(self.animations["Equip"].Length - 0.2, function()
		self.animations["Equipped"]:Play()
	end)

	self.gui = storage.Assets.UI.UEGunGui:Clone()
	self.gui.Info.Container.NameLabel.Text = self.tool.Name
	self.gui.Info.Container.AmmoLabel.Text = tostring(self.ammo.Value) .. "/" .. tostring(self.reserve.Value)

	--//INPUT

	for _, connection in self.equipped_connections do
		connection:Disconnect()
	end

	self.equipped_connections.input_began = USER_INPUT_SERVICE.InputBegan:Connect(function(input, gp)
		if not gp then
			if input.KeyCode == Enum.KeyCode.R then
				self:reload()
			elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
				self.mouse_down = true
				self:fire()
			elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
				self.aiming = true
			end
		end
	end)

	self.equipped_connections.input_ended = USER_INPUT_SERVICE.InputEnded:Connect(function(input, gp)
		if not gp then
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				self.mouse_down = false
			elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
				self.aiming = false
			end
		end
	end)

	self.equipped_connections.stepped_connection = RUN_SERVICE.PreRender:Connect(function()
		local main_cframe = CFrame.new(0, 0, 0)
		if self.aiming then
			TWEEN_SERVICE:Create(
				self.viewmodel_cframes.aim_offset,
				TweenInfo.new(0.1, Enum.EasingStyle.Linear, Enum.EasingDirection.Out),
				{Value = workspace.CurrentCamera.CFrame:ToObjectSpace(self.gun_model.Handle.ADS.WorldCFrame)}
			):Play()
			if self.first_person then
				self.gui.Crosshair.Visible = false
			end
		else
			TWEEN_SERVICE:Create(
				self.viewmodel_cframes.aim_offset,
				TweenInfo.new(0.1, Enum.EasingStyle.Linear, Enum.EasingDirection.Out),
				{Value = CFrame.new(0, 0 ,0)}
			):Play()
			self.gui.Crosshair.Visible = true
		end
		
		local distance = ((player.Character.HumanoidRootPart.Position + Vector3.new(0, 1, 0)) - workspace.CurrentCamera.CFrame.Position).Magnitude
		local root_joint = player.Character:WaitForChild("HumanoidRootPart"):WaitForChild("RootJoint")
		if distance <= 2 then
			for _, cframe_value in self.viewmodel_cframes do
				main_cframe *= cframe_value.Value
			end
			
			TWEEN_SERVICE:Create(
				self.viewmodel_cframes.idle_offset,
				TweenInfo.new(1, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
				{Value = workspace.CurrentCamera.CFrame:toObjectSpace(player.Character:WaitForChild("HumanoidRootPart").CFrame):inverse() * CFrame.Angles(-math.pi/2, -math.pi, 0) * CFrame.new(0, 0, 1.5)}
			):Play()
			self.first_person = true
			root_joint.C0 = main_cframe
		else
			root_joint.C0 = CFrame.new(0, 0, 0) * CFrame.Angles(-math.pi/2, -math.pi, 0)
			root_joint.C1 = CFrame.new(0, 0, 0) * CFrame.Angles(-math.pi/2, -math.pi, 0)
			self.first_person = false
		end
		
		--print(self.viewmodel_cframes.idle_offset.Value)
		
		for _, model in player.Character:GetChildren() do
			if model:IsA("Model") then
				for _, base_part in model:GetDescendants() do
					if base_part:IsA("BasePart") then
						base_part.LocalTransparencyModifier = base_part.Transparency
					end
				end
			end
		end
		
		player.Character["Right Arm"].LocalTransparencyModifier = 0
		player.Character["Left Arm"].LocalTransparencyModifier = 0
		
		self.gui.Info.Container.NameLabel.Text = self.tool.Name
		self.gui.Info.Container.AmmoLabel.Text = tostring(self.ammo.Value) .. "/" .. tostring(self.reserve.Value)

		local ammo_factor = (self.ammo.Value / self.ammo:GetAttribute("Capacity")) - 0.5
		TWEEN_SERVICE:Create(
			self.gui.Info.AmmoGradient,
			TweenInfo.new(
				0.2,
				Enum.EasingStyle.Quint,
				Enum.EasingDirection.Out
			),
			{Offset = Vector2.new(ammo_factor, 0)}
		):Play()
		TWEEN_SERVICE:Create(
			self.gui.Crosshair.Container,
			TweenInfo.new(
				self.config.recoil_speed,
				Enum.EasingStyle.Quint,
				Enum.EasingDirection.Out
			),
			{Size = UDim2.new(1, 0, 1, 0), Position = UDim2.new(0.5, 0, 0.5, 0), Rotation = 0}
		):Play()
		TWEEN_SERVICE:Create(
			self.gui.Crosshair,
			TweenInfo.new(
				0,
				Enum.EasingStyle.Quint,
				Enum.EasingDirection.Out
			),
			{Position = UDim2.new(0, mouse.X, 0, mouse.Y + 37)}
		):Play()
		TWEEN_SERVICE:Create(
			self.gui.CrosshairCircle,
			TweenInfo.new(
				0.05,
				Enum.EasingStyle.Quint,
				Enum.EasingDirection.Out
			),
			{Position = UDim2.new(0, mouse.X, 0, mouse.Y + 37)}
		):Play()
		TWEEN_SERVICE:Create(
			self.gui.Crosshair.Container.Crosshair,
			TweenInfo.new(
				self.config.recoil_speed,
				Enum.EasingStyle.Quint,
				Enum.EasingDirection.Out
			),
			{ImageTransparency = 0.2}
		):Play()
		TWEEN_SERVICE:Create(
			player.Character.Humanoid,
			TweenInfo.new(
				self.config.recoil_speed,
				Enum.EasingStyle.Quint,
				Enum.EasingDirection.Out
			),
			{CameraOffset = Vector3.new(0, 0, 0)}
		):Play()
		
		self.gui.CrosshairCircle.Container.Position = UDim2.new(0.5, USER_INPUT_SERVICE:GetMouseDelta().X, 0.5, USER_INPUT_SERVICE:GetMouseDelta().Y)
		
		if math.abs(math.abs(self.gui.Crosshair.Position.X.Offset) - math.abs(mouse.X)) <= 2 then
			self.gui.Crosshair.Position = UDim2.new(0, mouse.X, 0, mouse.Y + 37)
		end
	end)

	for event, sound_id in self.config.sfx do
		for name, animation in self.animations do
			self.equipped_connections[animation.Name..event] = animation:GetMarkerReachedSignal(event):Connect(function()
				local sound = Instance.new("Sound")
				sound.SoundId = sound_id
				sound.Parent = self.gun_model.Handle
				sound.RollOffMode = Enum.RollOffMode.InverseTapered
				sound.RollOffMinDistance = 10
				sound.RollOffMaxDistance = 500
				sound.Name = event
				effect_manager:effect("sound", sound)

				if event == "MagOut" and self.gun_model:FindFirstChild("Mag") then
					print("hi")
					local clone = self.gun_model.Mag:Clone()
					clone.Parent = workspace.UEWorkspace
					clone.CFrame = self.gun_model.Mag.CFrame
					clone.Anchored = false
					clone.CanCollide = false
					delay(0.1, function()
						clone.CanCollide = true
					end)
					self.gun_model.Mag.Transparency = 1
					DEBRIS:AddItem(clone, 60)
				elseif event == "MagIn" and self.gun_model:FindFirstChild("Mag") then
					self.gun_model.Mag.Transparency = 0
				end
			end)
		end
	end

	if self.animations.Unequipped == nil then
		network_event:FireServer("showmodel", self.gun_model)
	end

	self.gui.Parent = player.PlayerGui
	USER_INPUT_SERVICE.MouseIconEnabled = false
end

gun.unequip = function(self)
	self.equipped = false
	for _, animation in self.animations do
		animation:Stop()
		delay(0.5, function()
			if self.equipped == false then
				animation:Stop()
			end
		end)
	end
	if self.animations.Unequipped then
		self.animations["Unequipped"]:Play()
	end
	for _, connection in self.equipped_connections do
		connection:Disconnect()
	end

	if self.animations.Unequipped == nil then
		network_event:FireServer("hidemodel", self.gun_model)
	end
	
	local root_joint = player.Character:WaitForChild("HumanoidRootPart"):WaitForChild("RootJoint")
	
	root_joint.C0 = CFrame.new(0, 0, 0) * CFrame.Angles(-math.pi/2, -math.pi, 0)
	root_joint.C1 = CFrame.new(0, 0, 0) * CFrame.Angles(-math.pi/2, -math.pi, 0)

	self.gui:Destroy()
	USER_INPUT_SERVICE.MouseIconEnabled = true
end

gun.reload = function(self)
	if self.equipped == false then return end

	local ammo_needed = self.ammo:GetAttribute("Capacity") - self.ammo.Value

	if self.reserve.Value > 0 and ammo_needed > 0 then
		if self.reserve.Value - ammo_needed >= 0 then
			self.reserve.Value -= ammo_needed
			self.ammo.Value += ammo_needed
		else
			self.ammo.Value = self.reserve.Value
			self.reserve.Value = 0
		end

		self.animations["Reload"]:Play()
		self.reloading = true
		task.delay(self.config.reload_time, function()
			self.reloading = false
		end)
	end
end

gun.fire = function(self)
	if self.equipped == false then return end

	repeat 
		task.spawn(function()
			if self.ammo.Value > 0 and self.reloading == false and self.firing == false and self.equipped == true then
				self.animations["Fire"]:Play()
				self.gun_model.Handle.Ejection.ParticleEffect:Emit(1)
				self.ammo.Value -= 1
				effect_manager:effect("sound", self.gun_model.Handle.Muzzle.Fire)
				network_event:FireServer("fire", self.gun_model.Handle.Muzzle.Fire)
				self.firing = true
				local projectile_info = {
					origin = self.gun_model.Handle.Muzzle.WorldPosition, 
					destination = mouse.Hit.Position, 
					force = self.config.muzzle_velocity, 
					origin_velocity = player.Character.HumanoidRootPart.AssemblyLinearVelocity,
					gravity = self.config.gravity, 
					visual_instance = self.config.visual, 
					blacklist = {player.Character, workspace.UEWorkspace}, 
					lifetime = 5,
					debug_mode = false
				}

				if self.ammo.Value % self.config.visual_interval ~= 0 then
					projectile_info.visual_instance = storage.Assets.Projectiles.TracerSilenced
				end 

				self.projectile:cast(projectile_info)
				network_event:FireServer("projectile", projectile_info)
				
				self.gui.Crosshair.Container.Size += UDim2.new(0, 300, 0, 300)
				self.gui.Crosshair.Container.Rotation += Random.new():NextNumber(-90, 90)
				self.gui.Crosshair.Container.Position += UDim2.new(0, 0, 0, -10)
				self.gui.Crosshair.Container.Crosshair.ImageTransparency += 4
				
				player.Character.Humanoid.CameraOffset += self.config.recoil_offset
				
				task.delay(60/self.config.rpm, function()
					self.firing = false
				end)
			end
		end)
		task.wait(60/self.config.rpm)
	until 
	self.config.automatic == false
		or self.ammo.Value <= 0 
		or self.reloading == true
		or self.mouse_down == false
		or self.equipped == false
end

gun.hit = function(self, ray_result)
	if ray_result == nil then return end
	local humanoid = ray_result.Instance.Parent:FindFirstChildOfClass("Humanoid") or ray_result.Instance.Parent.Parent:FindFirstChildOfClass("Humanoid")

	local damage = self.config.damage
	for limb, multiplier in self.config.limb_multipliers do
		if ray_result.Instance.Name == limb then
			damage *= multiplier
		end
	end

	local hit_info = {
		instance = ray_result.Instance,
		position = ray_result.Position,
		material = ray_result.Material,
		normal = ray_result.Normal,
		damage = damage,
		lethality = self.config.lethality
	}

	effect_manager:effect("hit", hit_info)
	network_event:FireServer("hit", hit_info)
end

return gun
