-- ===========================================================================
-- BULLET-DROP LASER + GUI + ESP OUTLINE + SILENT AIM  (standalone, paste & run)
-- Draggable panel: toggle on/off + live sliders for thickness, speed,
-- gravity (drop) and range. Auto-detects guns (re-equip safe).
-- ESP outline highlights enemy characters with team-based colors.
-- Silent aim with FOV circle for smooth targeting.
-- Toggle with T key, show/hide GUI with Enum code.
-- ===========================================================================

local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local Players = game:GetService("Players")
local plr = Players.LocalPlayer
local mouse = plr:GetMouse()

-- Live settings (sliders write into this table; the laser reads it each frame).
local cfg = {
	enabled  = true,
	width    = 0.08,
	color    = Color3.fromRGB(255, 0, 0),
	targetColor = Color3.fromRGB(0, 255, 0),  -- color when aimed at an enemy
	enemyColorEnabled = true,                 -- recolor beam when aimed at an enemy
	speed    = 500,                 -- projectile speed (studs/sec)
	gravity  = workspace.Gravity,   -- drop strength
	range    = 3000,                -- total beam length
	segments = 60,                  -- curve smoothness (fixed)
	espEnabled = true,              -- ESP outline toggle
	useTeamColors = true,           -- Use team-based colors for ESP
	silentAimEnabled = false,       -- Silent aim toggle
	silentAimFOV = 100,             -- Silent aim field of view (pixels)
	silentAimSmoothing = 0.1,       -- Aiming smoothing factor
}

-- Team-based ESP colors
local teamColors = {
	Yoromoto = Color3.fromRGB(0, 0, 0),        -- Black
	Renetti = Color3.fromRGB(0, 255, 0),       -- Green
	Alamont = Color3.fromRGB(128, 128, 128),   -- Grey
	Bergman = Color3.fromRGB(139, 69, 19),     -- Brown
	Halfwell = Color3.fromRGB(0, 0, 255),      -- Blue
}

-- Guns to attach a laser to.
local gunNames = {
	Pistol = true, Snub = true, DB = true, AK47 = true, ToolboxMAC10 = true,
	PitchGun = true, Sniper = true, AceCarbine = true, MAGNUM = true,
	Strikeout = true, TheFix = true, Liquidator = true, Forte = true, Deagle = true,
}

local function getCF(x)
	return x:IsA("Attachment") and x.WorldCFrame or x.CFrame
end

-- True if the part belongs to another player's / NPC character.
local function isEnemyCharacter(inst)
	local model = inst and inst:FindFirstAncestorWhichIsA("Model")
	while model do
		if model:FindFirstChildOfClass("Humanoid") then
			return model ~= plr.Character
		end
		model = model:FindFirstAncestorWhichIsA("Model")
	end
	return false
end

-- Get team color for a player
local function getTeamColor(player)
	if not cfg.useTeamColors then
		return Color3.fromRGB(255, 0, 255)  -- Default magenta
	end
	
	if player.Team then
		local teamName = player.Team.Name
		return teamColors[teamName] or Color3.fromRGB(255, 0, 255)
	end
	
	return Color3.fromRGB(255, 0, 255)  -- Default magenta if no team
end

-- ====================== SILENT AIM LOGIC ==================================
local silentAimTarget = nil
local fovCircle = Drawing.new("Circle")
fovCircle.Thickness = 2
fovCircle.NumSides = 50
fovCircle.Color = Color3.fromRGB(0, 255, 0)
fovCircle.Filled = false
fovCircle.Visible = false

local function getClosestPlayerInFOV()
	local closestPlayer = nil
	local closestDistance = cfg.silentAimFOV
	
	for _, player in pairs(Players:GetPlayers()) do
		if player ~= plr and player.Character then
			local character = player.Character
			local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			
			if humanoidRootPart and humanoid and humanoid.Health > 0 then
				-- Get screen position of target
				local camera = workspace.CurrentCamera
				local screenPos, onScreen = camera:WorldToScreenPoint(humanoidRootPart.Position)
				
				if onScreen then
					-- Calculate distance from mouse to target on screen
					local mouseX = mouse.X
					local mouseY = mouse.Y
					local distance = math.sqrt((screenPos.X - mouseX)^2 + (screenPos.Y - mouseY)^2)
					
					if distance < closestDistance then
						closestDistance = distance
						closestPlayer = player
					end
				end
			end
		end
	end
	
	return closestPlayer
end

local function updateSilentAim()
	if not cfg.silentAimEnabled then
		silentAimTarget = nil
		fovCircle.Visible = false
		return
	end
	
	-- Update FOV circle position and visibility
	fovCircle.Position = Vector2.new(mouse.X, mouse.Y)
	fovCircle.Radius = cfg.silentAimFOV
	fovCircle.Visible = true
	
	-- Get closest player in FOV
	silentAimTarget = getClosestPlayerInFOV()
end

-- ====================== ESP OUTLINE LOGIC ==================================
local espOutlines = {}  -- [character] = highlight object

local function addESPOutline(character, player)
	if espOutlines[character] then return end
	
	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	if not humanoidRootPart then return end
	
	local espColor = getTeamColor(player)
	
	-- Use Highlight if available
	local highlight = Instance.new("Highlight")
	highlight.Adornee = character
	highlight.FillColor = espColor
	highlight.OutlineColor = espColor
	highlight.FillTransparency = 0.5
	highlight.OutlineTransparency = 0
	highlight.Parent = character
	
	espOutlines[character] = highlight
end

local function removeESPOutline(character)
	if espOutlines[character] then
		espOutlines[character]:Destroy()
		espOutlines[character] = nil
	end
end

local function updateESPOutlines()
	if not cfg.espEnabled then
		for character, _ in pairs(espOutlines) do
			removeESPOutline(character)
		end
		return
	end
	
	-- Scan for enemy characters
	for _, player in pairs(Players:GetPlayers()) do
		if player ~= plr and player.Character then
			local character = player.Character
			if not espOutlines[character] then
				addESPOutline(character, player)
			else
				-- Update color in case team changed
				local newColor = getTeamColor(player)
				espOutlines[character].FillColor = newColor
				espOutlines[character].OutlineColor = newColor
			end
		end
	end
	
	-- Remove outlines for deleted characters
	for character, _ in pairs(espOutlines) do
		if not character.Parent then
			removeESPOutline(character)
		end
	end
end

-- Monitor character death/respawn
Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		if player ~= plr then
			task.wait(0.1)
			addESPOutline(character, player)
		end
	end)
	if player.Character then
		addESPOutline(player.Character, player)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	if player.Character then
		removeESPOutline(player.Character)
	end
end)

-- Monitor team changes
Players.PlayerAdded:Connect(function(player)
	player:GetPropertyChangedSignal("Team"):Connect(function()
		if player.Character and player ~= plr then
			removeESPOutline(player.Character)
			task.wait(0.1)
			addESPOutline(player.Character, player)
		end
	end)
end)

-- ====================== LASER LOGIC ========================================
local attached = {}   -- [muzzle] = true

local function makeArc(muzzle)
	local segs = {}
	for i = 1, cfg.segments do
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Locked = true
		p.Material = Enum.Material.Neon
		p.Color = cfg.color
		p.Transparency = 1
		p.Parent = workspace
		segs[i] = p
	end

	-- Laser parts have CanQuery=false so raycasts already ignore them.
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.IgnoreWater = true

	local conn
	conn = RunService.Heartbeat:Connect(function()
		-- Muzzle gone (unequipped) -> clean up so it can re-attach later.
		if not muzzle.Parent then
			for _, p in segs do p:Destroy() end
			attached[muzzle] = nil
			conn:Disconnect()
			return
		end

		if not cfg.enabled then
			for _, p in segs do p.Transparency = 1 end
			return
		end

		local origin = getCF(muzzle)
		local startPos = origin.Position
		local velocity = origin.LookVector * cfg.speed
		local gravity = Vector3.new(0, -cfg.gravity, 0)
		local dt = (cfg.range / math.max(cfg.speed, 1)) / cfg.segments

		rayParams.FilterDescendantsInstances = { plr.Character }

		local prev = startPos
		local detected = false
		local onTarget = false
		for s = 1, cfg.segments do
			local t = s * dt
			local nextPos = startPos + velocity * t + 0.5 * gravity * (t * t)
			local len = (nextPos - prev).Magnitude

			-- Detect what the path first hits (enemy humanoid -> recolor).
			if not detected and len > 0 then
				local hit = workspace:Raycast(prev, nextPos - prev, rayParams)
				if hit then
					detected = true
					onTarget = isEnemyCharacter(hit.Instance)
				end
			end

			local p = segs[s]
			if len < 0.01 then
				p.Transparency = 1
			else
				p.Size = Vector3.new(cfg.width, cfg.width, len)
				p.CFrame = CFrame.new((prev + nextPos) / 2, nextPos)
				p.Transparency = 0
			end
			prev = nextPos
		end

		local col = (cfg.enemyColorEnabled and onTarget) and cfg.targetColor or cfg.color
		for s = 1, cfg.segments do
			segs[s].Color = col
		end
	end)
end

local function scan()
	for _, g in workspace:GetChildren() do
		if gunNames[g.Name] then
			local root = g:FindFirstChild("Root")
			local muzzle = root and root:FindFirstChild("Muzzle")
			if muzzle and not attached[muzzle] then
				attached[muzzle] = true
				makeArc(muzzle)
			end
		end
	end
end

scan()
task.spawn(function()
	while true do
		task.wait(1)
		scan()
	end
end)

-- Update ESP outlines every frame
task.spawn(function()
	while true do
		updateESPOutlines()
		task.wait(0.1)
	end
end)

-- Update silent aim every frame
task.spawn(function()
	while true do
		updateSilentAim()
		task.wait(0.01)
	end
end)

-- ====================== GUI ================================================
local parent = (gethui and gethui()) or game:GetService("CoreGui")

-- Remove an old copy if you re-run the script.
local old = parent:FindFirstChild("LaserGui")
if old then old:Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name = "LaserGui"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = parent

local main = Instance.new("Frame")
main.Name = "Main"
main.Size = UDim2.new(0, 250, 0, 470)
main.Position = UDim2.new(0, 40, 0, 120)
main.BackgroundColor3 = Color3.fromRGB(28, 28, 32)
main.BorderSizePixel = 0
main.Active = true
main.Parent = gui
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 8)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 32)
title.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
title.BorderSizePixel = 0
title.Text = "Bullet-Drop Laser + ESP + Aim"
title.Font = Enum.Font.GothamBold
title.TextSize = 15
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.Parent = main
Instance.new("UICorner", title).CornerRadius = UDim.new(0, 8)

-- Drag the panel by its title bar.
do
	local dragging, dragStart, startPos
	title.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = main.Position
		end
	end)
	UIS.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local d = input.Position - dragStart
			main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
		end
	end)
	UIS.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)
end

-- Scrollable content area (auto-grows with the controls).
local content = Instance.new("ScrollingFrame")
content.Size = UDim2.new(1, 0, 1, -32)
content.Position = UDim2.new(0, 0, 0, 32)
content.BackgroundTransparency = 1
content.BorderSizePixel = 0
content.ScrollBarThickness = 4
content.CanvasSize = UDim2.new(0, 0, 0, 0)
content.AutomaticCanvasSize = Enum.AutomaticSize.Y
content.Parent = main

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 6)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = content

local pad = Instance.new("UIPadding")
pad.PaddingTop = UDim.new(0, 8)
pad.PaddingBottom = UDim.new(0, 8)
pad.PaddingLeft = UDim.new(0, 10)
pad.PaddingRight = UDim.new(0, 10)
pad.Parent = content

local order = 0
local function nextOrder()
	order += 1
	return order
end

-- Section header.
local function addHeader(text)
	local h = Instance.new("TextLabel")
	h.Size = UDim2.new(1, 0, 0, 18)
	h.BackgroundTransparency = 1
	h.Text = text
	h.Font = Enum.Font.GothamBold
	h.TextSize = 12
	h.TextColor3 = Color3.fromRGB(150, 150, 160)
	h.TextXAlignment = Enum.TextXAlignment.Left
	h.LayoutOrder = nextOrder()
	h.Parent = content
end

-- Toggle helper. onChange(state) gets the new boolean.
local function addToggle(labelOn, labelOff, initial, onChange)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(1, 0, 0, 30)
	btn.BorderSizePixel = 0
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 14
	btn.TextColor3 = Color3.fromRGB(255, 255, 255)
	btn.AutoButtonColor = true
	btn.LayoutOrder = nextOrder()
	btn.Parent = content
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
	local state = initial
	local function refresh()
		btn.Text = state and labelOn or labelOff
		btn.BackgroundColor3 = state and Color3.fromRGB(40, 160, 70) or Color3.fromRGB(160, 50, 50)
	end
	btn.MouseButton1Click:Connect(function()
		state = not state
		refresh()
		onChange(state)
	end)
	refresh()
end

-- Main lasers on/off.
addToggle("Lasers: ON", "Lasers: OFF", cfg.enabled, function(state)
	cfg.enabled = state
end)

-- Slider factory.
local function createSlider(name, minV, maxV, default, decimals, onChange)
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.new(1, 0, 0, 38)
	holder.LayoutOrder = nextOrder()
	holder.Parent = content

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, 0, 0, 16)
	label.Font = Enum.Font.Gotham
	label.TextSize = 13
	label.TextColor3 = Color3.fromRGB(230, 230, 230)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = holder

	local bar = Instance.new("Frame")
	bar.Size = UDim2.new(1, 0, 0, 6)
	bar.Position = UDim2.new(0, 0, 0, 26)
	bar.BackgroundColor3 = Color3.fromRGB(60, 60, 66)
	bar.BorderSizePixel = 0
	bar.Parent = holder
	Instance.new("UICorner", bar).CornerRadius = UDim.new(1, 0)

	local fill = Instance.new("Frame")
	fill.BackgroundColor3 = Color3.fromRGB(255, 70, 70)
	fill.BorderSizePixel = 0
	fill.Parent = bar
	Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)

	local knob = Instance.new("Frame")
	knob.Size = UDim2.new(0, 12, 0, 12)
	knob.AnchorPoint = Vector2.new(0.5, 0.5)
	knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	knob.BorderSizePixel = 0
	knob.ZIndex = 2
	knob.Parent = bar
	Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

	local function round(v)
		local m = 10 ^ decimals
		return math.floor(v * m + 0.5) / m
	end

	local function setValue(v)
		v = round(math.clamp(v, minV, maxV))
		local alpha = (v - minV) / (maxV - minV)
		fill.Size = UDim2.new(alpha, 0, 1, 0)
		knob.Position = UDim2.new(alpha, 0, 0.5, 0)
		label.Text = name .. ": " .. tostring(v)
		onChange(v)
	end

	local dragging = false
	local function update(input)
		local rel = (input.Position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X
		setValue(minV + rel * (maxV - minV))
	end
	bar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			update(input)
		end
	end)
	knob.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
		end
	end)
	UIS.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			update(input)
		end
	end)
	UIS.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)

	setValue(default)
end

addHeader("BEAM")
createSlider("Thickness", 0.02, 0.50, cfg.width,   2, function(v) cfg.width = v end)
createSlider("Speed",     50,   2000, cfg.speed,   0, function(v) cfg.speed = v end)
createSlider("Gravity",   0,    600,  cfg.gravity, 0, function(v) cfg.gravity = v end)
createSlider("Range",     200,  6000, cfg.range,   0, function(v) cfg.range = v end)

addHeader("NORMAL COLOR")
local normalRGB = { math.floor(cfg.color.R * 255 + 0.5), math.floor(cfg.color.G * 255 + 0.5), math.floor(cfg.color.B * 255 + 0.5) }
local function applyNormal()
	cfg.color = Color3.fromRGB(normalRGB[1], normalRGB[2], normalRGB[3])
end
createSlider("Red",   0, 255, normalRGB[1], 0, function(v) normalRGB[1] = v applyNormal() end)
createSlider("Green", 0, 255, normalRGB[2], 0, function(v) normalRGB[2] = v applyNormal() end)
createSlider("Blue",  0, 255, normalRGB[3], 0, function(v) normalRGB[3] = v applyNormal() end)

addHeader("ENEMY COLOR")
addToggle("Enemy Color: ON", "Enemy Color: OFF", cfg.enemyColorEnabled, function(state)
	cfg.enemyColorEnabled = state
end)
local enemyRGB = { math.floor(cfg.targetColor.R * 255 + 0.5), math.floor(cfg.targetColor.G * 255 + 0.5), math.floor(cfg.targetColor.B * 255 + 0.5) }
local function applyEnemy()
	cfg.targetColor = Color3.fromRGB(enemyRGB[1], enemyRGB[2], enemyRGB[3])
end
createSlider("Red",   0, 255, enemyRGB[1], 0, function(v) enemyRGB[1] = v applyEnemy() end)
createSlider("Green", 0, 255, enemyRGB[2], 0, function(v) enemyRGB[2] = v applyEnemy() end)
createSlider("Blue",  0, 255, enemyRGB[3], 0, function(v) enemyRGB[3] = v applyEnemy() end)

addHeader("ESP OUTLINE")
addToggle("ESP: ON", "ESP: OFF", cfg.espEnabled, function(state)
	cfg.espEnabled = state
end)
addToggle("Team Colors: ON", "Team Colors: OFF", cfg.useTeamColors, function(state)
	cfg.useTeamColors = state
end)

-- Display team color reference
local teamInfo = Instance.new("TextLabel")
teamInfo.Size = UDim2.new(1, 0, 0, 90)
teamInfo.BackgroundTransparency = 1
teamInfo.Text = "Teams:\n• Yoromoto: Black\n• Renetti: Green\n• Alamont: Grey\n• Bergman: Brown\n• Halfwell: Blue"
teamInfo.Font = Enum.Font.Gotham
teamInfo.TextSize = 11
teamInfo.TextColor3 = Color3.fromRGB(180, 180, 190)
teamInfo.TextXAlignment = Enum.TextXAlignment.Left
teamInfo.TextYAlignment = Enum.TextYAlignment.Top
teamInfo.LayoutOrder = nextOrder()
teamInfo.Parent = content

addHeader("SILENT AIM")
addToggle("Silent Aim: ON", "Silent Aim: OFF", cfg.silentAimEnabled, function(state)
	cfg.silentAimEnabled = state
end)
createSlider("FOV", 25, 500, cfg.silentAimFOV, 0, function(v) cfg.silentAimFOV = v end)

-- ====================== KEYBOARD CONTROLS ====================================
UIS.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	
	-- T key: Toggle all features on/off
	if input.KeyCode == Enum.KeyCode.T then
		cfg.enabled = not cfg.enabled
		cfg.espEnabled = not cfg.espEnabled
		cfg.silentAimEnabled = not cfg.silentAimEnabled
		print("All features toggled: " .. (cfg.enabled and "ON" or "OFF"))
	end
	
	-- Delete key: Toggle GUI visibility
	if input.KeyCode == Enum.KeyCode.Delete then
		main.Visible = not main.Visible
	end
end)

print("Laser GUI with Team-Based ESP, Silent Aim, and Controls loaded.")
print("Press T to toggle all features | Press Delete to toggle GUI visibility")
