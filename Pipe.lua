-- ================================================================
--  Pipe — Full Local Script
--  Place in StarterPlayerScripts as a LocalScript
--  Fully client-side: ONLY you see the model and animations.
--  One pipe, never destroyed. Tobacco stays full always.
--  Bowl glows via TweenService on drag. No light emission.
--  Bowl is built from 8 wall segments + a cap (no GeometryService).
-- ================================================================

local Players      = game:GetService("Players")
local RunService   = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local LP   = Players.LocalPlayer
local Char = LP.Character or LP.CharacterAdded:Wait()
repeat task.wait() until Char:FindFirstChild("Torso")

-- ── Character refs ────────────────────────────────────────────────────
local Torso = Char:WaitForChild("Torso")
local rArm  = Char:WaitForChild("Right Arm")
local lArm  = Char:WaitForChild("Left Arm")
local Head  = Char:WaitForChild("Head")

local rShoulder = Torso:FindFirstChild("Right Shoulder")
local lShoulder = Torso:FindFirstChild("Left Shoulder")

local defLS_C0 = lShoulder.C0
local defLS_C1 = lShoulder.C1
local defRS_C0 = rShoulder.C0
local defRS_C1 = rShoulder.C1

local rShoulderStorage = rShoulder:Clone()
local lShoulderStorage = lShoulder:Clone()

-- ── Math shortcuts ────────────────────────────────────────────────────
local CF   = CFrame.new
local CFAN = CFrame.Angles
local RAD  = math.rad
local VEC3 = Vector3.new
local RS   = RunService.Stepped

-- ── Bowl ember colour states ──────────────────────────────────────────
local CHERRY_UNLIT = Color3.fromRGB(40,  40,  40)
local CHERRY_IDLE  = Color3.fromRGB(200, 80,  0)
local CHERRY_DRAG  = Color3.fromRGB(255, 140, 20)

-- ── State ─────────────────────────────────────────────────────────────
local Selected  = false
local pulling   = false
local hasPipe   = false
local drawing   = false
local ready     = false
local isLit     = false

local lWeld, rWeld
local currentPipe, currentWeld, pipeWeld, pipeAnchor
local activatedConn

-- ── TweenJoint ────────────────────────────────────────────────────────
local function TweenJoint(Joint, NewC0, NewC1, Alpha, Duration)
	coroutine.resume(coroutine.create(function()
		local TweenIndicator
		local NewCode = math.random(-1e9, 1e9)
		if not Joint:FindFirstChild("TweenCode") then
			TweenIndicator        = Instance.new("IntValue")
			TweenIndicator.Name   = "TweenCode"
			TweenIndicator.Value  = NewCode
			TweenIndicator.Parent = Joint
		else
			TweenIndicator        = Joint.TweenCode
			TweenIndicator.Value  = NewCode
		end
		local function MatrixCFrame(CFPos, CFTop, CFBack)
			local CFRight = CFTop:Cross(CFBack)
			return CF(
				CFPos.x,   CFPos.y,   CFPos.z,
				CFRight.x, CFTop.x,   CFBack.x,
				CFRight.y, CFTop.y,   CFBack.y,
				CFRight.z, CFTop.z,   CFBack.z
			)
		end
		local function LerpCF(StartCF, EndCF, Al)
			local StartTop  = (StartCF * CFAN(RAD(90),0,0)).lookVector
			local StartBack = -StartCF.lookVector
			local EndTop    = (EndCF   * CFAN(RAD(90),0,0)).lookVector
			local EndBack   = -EndCF.lookVector
			return MatrixCFrame(
				StartCF.p:lerp(EndCF.p, Al),
				StartTop:lerp(EndTop, Al),
				StartBack:lerp(EndBack, Al)
			)
		end
		local StartC0 = Joint.C0
		local StartC1 = Joint.C1
		local X = 0
		while true do
			local NewX = X + math.min(1.5 / math.max(Duration, 0), 90)
			X = (NewX > 90 and 90 or NewX)
			if TweenIndicator.Value ~= NewCode then break end
			if not Selected then break end
			if NewC0 then Joint.C0 = LerpCF(StartC0, NewC0, Alpha(X)) end
			if NewC1 then Joint.C1 = LerpCF(StartC1, NewC1, Alpha(X)) end
			if X == 90 then break end
			RS:wait()
		end
		if TweenIndicator.Value == NewCode then
			TweenIndicator:Destroy()
		end
	end))
end

local function Linear(X) return X / 90 end

-- ── Arm pose CFrames ──────────────────────────────────────────────────
local LeftValue2  = CF(-1.33,-0.14, 0.3 ) * CFAN(RAD(  7.261), RAD(-54.019), RAD( 14.367))
local LeftValue3  = CF(-0.84, 0.58,-0.71) * CFAN(RAD(-77.331), RAD(-163.091),RAD(-108.349))
local RightValue2 = CF( 1.1,  0.74,-0.81) * CFAN(RAD(-75.651), RAD(-158.195), RAD(115.249))
local RightValue4 = CF( 1.45,-0.04,-0.13) * CFAN(RAD(-10.373), RAD(  -6.056), RAD(  0.231))

-- ── Pipe weld CFrames ─────────────────────────────────────────────────
local PIPE_REST  = CF(0.18, 0.3, 0.2) * CFAN(RAD(-30.954), RAD(130.889), RAD(18.939))
local PIPE_MOUTH = CF(0.18, 0.3, 0.2) * CFAN(RAD(-30.954), RAD(130.889), RAD(18.939))

-- ── Bowl ember tween helper ───────────────────────────────────────────
local function tweenEmber(cherry, targetColour, targetTransp, duration)
	if not cherry or not cherry.Parent then return end
	local info = TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
	TweenService:Create(cherry, info, {
		Color        = targetColour,
		Transparency = targetTransp,
	}):Play()
end

-- ── Build pipe model ──────────────────────────────────────────────────
--  Structure:
--   Bowl      — invisible anchor part, root of the whole pipe.
--               Sounds live here so pipeClone.Bowl.Crackle still works.
--   BowlWall  — 8 thin rectangular parts arranged in a ring to fake a
--               hollow cylinder. All welded to Bowl.
--   BowlCap   — flat cylinder disc closing the bottom of the bowl.
--   Stem      — long thin cylinder welded to Bowl, runs horizontally.
--   Tobaccy   — reddish-brown disc inside the bowl near the rim.
--               Carries the smoke ParticleEmitter.
--   Cherry    — thin Neon disc on top of the tobacco.
--               Starts dark grey, tweens orange when smoking.
local function buildPipe()
	local pipe = Instance.new("Model")
	pipe.Name  = "Pipe"

	local function makePart(name, sz, col, mat, transp)
		local p = Instance.new("Part")
		p.Name         = name
		p.Size         = sz
		p.BrickColor   = BrickColor.new(col)
		p.Material     = Enum.Material[mat] or Enum.Material.SmoothPlastic
		p.Transparency = transp or 0
		p.CanCollide   = false
		p.CastShadow   = false
		p.Anchored     = false
		p.Parent       = pipe
		return p
	end

	local function attachWeld(child, root, c0)
		local w = Instance.new("Weld")
		w.Name   = "Weld"
		w.Part0  = child
		w.Part1  = root
		w.C0     = c0
		w.Parent = child
	end

	-- ── Bowl anchor (invisible root — all parts weld to this) ─────────
	-- Kept transparent so it contributes nothing visual, but it hosts
	-- the sounds so all existing Bowl.Crackle / Bowl.Sound refs work.
	local Bowl = makePart("Bowl", VEC3(0.05, 0.05, 0.05), "Really black", "SmoothPlastic", 1)

	-- ── Bowl walls — 8 thin segments arranged in a ring ───────────────
	-- Together they read as a hollow open-top cylinder at pipe scale.
	local wallCount = 16
	local wallRadius    = 0.125   -- distance from center to wall face
	local wallHeight    = 0.20    -- how tall the bowl is
	local wallThickness = 0.05    -- thickness of each segment
	-- Width of each segment = arc chord length so segments touch at the rim
	local wallWidth = 2 * wallRadius * math.sin(math.pi / wallCount) + 0.01

	for i = 1, wallCount do
		local angle = (i / wallCount) * math.pi * 2
		local x = math.cos(angle) * wallRadius
		local z = math.sin(angle) * wallRadius
		local seg = makePart("BowlWall", VEC3(wallWidth, wallHeight, wallThickness), "Burnt Sienna", "SmoothPlastic")
		-- Slight top offset so walls sit above the cap
		attachWeld(seg, Bowl, CFAN(0, -angle, 0) * CF(z, 0.06, x))

	end

	-- ── Bowl cap — flat disc sealing the bottom ────────────────────────
	local BowlCap     = makePart("BowlCap", VEC3(0.28, 0.03, 0.28), "Burnt Sienna", "SmoothPlastic")
	local BowlCapMesh = Instance.new("CylinderMesh", BowlCap)
	BowlCapMesh.Name  = "Mesh"
	attachWeld(BowlCap, Bowl, CF(0, -0.04, 0))

	-- ── Sounds on the Bowl anchor ─────────────────────────────────────
	local Crackle         = Instance.new("Sound")
	Crackle.Name          = "Crackle"
	Crackle.SoundId       = "rbxassetid://150367028"
	Crackle.Volume        = 0.22
	Crackle.Looped        = true
	Crackle.PlaybackSpeed = 0.85
	Crackle.Parent        = Bowl
	local eq      = Instance.new("EqualizerSoundEffect")
	eq.HighGain   = -22
	eq.LowGain    = -35
	eq.MidGain    = -70
	eq.Priority   = 0
	eq.Parent     = Crackle

	local ExtSound      = Instance.new("Sound")
	ExtSound.Name       = "Sound"
	ExtSound.SoundId    = "rbxassetid://229579267"
	ExtSound.Volume     = 0.5
	ExtSound.Parent     = Bowl

	-- ── Stem ──────────────────────────────────────────────────────────
	local Stem     = makePart("Stem", VEC3(0.10, 0.68, 0.10), "Burnt Sienna", "SmoothPlastic")
	local StemMesh = Instance.new("CylinderMesh", Stem)
	StemMesh.Name  = "Mesh"
	attachWeld(Stem, Bowl, CF(0, -0.45, 0) * CFAN(RAD(90), 0, 0))

	-- ── Tobaccy ───────────────────────────────────────────────────────
	local Tobaccy     = makePart("Tobaccy", VEC3(0.20, 0.015, 0.20), "Reddish brown", "SmoothPlastic")
	local TobaccyMesh = Instance.new("CylinderMesh", Tobaccy)
	TobaccyMesh.Name  = "Mesh"
	attachWeld(Tobaccy, Bowl, CF(0, 0.10, 0))

	-- ── Cherry (Neon ember) ───────────────────────────────────────────
	local Cherry     = makePart("Cherry", VEC3(0.20, 0.008, 0.20), "Fossil", "Neon", 1)
	Cherry.Color     = CHERRY_UNLIT
	local CherryMesh = Instance.new("CylinderMesh", Cherry)
	CherryMesh.Name  = "Mesh"
	attachWeld(Cherry, Bowl, CF(0, 0.115, 0))

	-- ── Smoke emitter on the tobacco surface ──────────────────────────
	local SmkEmit                 = Instance.new("ParticleEmitter")
	SmkEmit.Texture               = "rbxasset://textures/particles/smoke_main.dds"
	SmkEmit.Color                 = ColorSequence.new(
		Color3.fromRGB(175,175,175), Color3.fromRGB(115,115,115))
	SmkEmit.LightEmission         = 0
	SmkEmit.LightInfluence        = 1
	SmkEmit.EmissionDirection     = Enum.NormalId.Top
	SmkEmit.Size = NumberSequence.new{
		NumberSequenceKeypoint.new(0,   0.09),
		NumberSequenceKeypoint.new(0.5, 0.26),
		NumberSequenceKeypoint.new(1,   0.52),
	}
	SmkEmit.Transparency = NumberSequence.new{
		NumberSequenceKeypoint.new(0,   0.20),
		NumberSequenceKeypoint.new(0.7, 0.70),
		NumberSequenceKeypoint.new(1,   1),
	}
	SmkEmit.Lifetime      = NumberRange.new(1.5, 3.0)
	SmkEmit.Rate          = 6
	SmkEmit.Speed         = NumberRange.new(0.5, 1.6)
	SmkEmit.SpreadAngle   = Vector2.new(12, 12)
	SmkEmit.RotSpeed      = NumberRange.new(-25, 25)
	SmkEmit.Enabled       = false
	SmkEmit.Parent        = Tobaccy

	local Fizzled       = Instance.new("BoolValue")
	Fizzled.Name        = "Fizzled"
	Fizzled.Value       = false
	Fizzled.Parent      = pipe

	return pipe
end

-- ── Lighter model ─────────────────────────────────────────────────────

local function buildLighter()
	local function makePart(name, sz, col, mat, transp)
		local p = Instance.new("Part")
		p.Name         = name
		p.Size         = sz
		p.BrickColor   = BrickColor.new(col)
		p.Material     = Enum.Material[mat] or Enum.Material.SmoothPlastic
		p.Transparency = transp or 0
		p.CanCollide   = false
		p.CastShadow   = false
		p.Anchored     = false
		return p
	end

	local function attachWeld(child, root, c0)
		local w = Instance.new("Weld")
		w.Name   = "Weld"
		w.Part0  = child
		w.Part1  = root
		w.C0     = c0
		w.Parent = child
	end

	local lighter   = Instance.new("Model")
	lighter.Name    = "Lighter"
	local body      = Instance.new("Part")
	body.Name       = "Union"
	body.Size       = VEC3(0.167, 0.361, 0.381)
	body.BrickColor = BrickColor.new("Medium stone grey")
	body.Material = Enum.Material.Metal
	body.CanCollide = false
	body.Parent = lighter

	local lid = makePart("lid", VEC3(0.167, 0.214, 0.381), "Medium stone grey", "Metal", 0)
	lid.Parent = lighter
	attachWeld(lid, body, CF(0, 0.11, -0.45)*CFAN(RAD(45),0,0))

	local cage = makePart("cage", VEC3(0.184, 0.098, 0.084), "Really black", "Plastic", 1)
	local t = Instance.new("Decal")
	t.Texture  = "rbxassetid://95858094726954"
	t.Face = Enum.NormalId.Front
	t.Color3 = Color3.fromRGB(34, 34, 34)
	t.Parent = cage
	local t2 = t:Clone()
	t2.Face = Enum.NormalId.Back
	t2.Parent = cage
	t2 = t:Clone()
	t2.Face = Enum.NormalId.Right
	t2.Parent = cage
	t2 = t:Clone()
	t2.Face = Enum.NormalId.Left
	t2.Parent = cage
	cage.Parent = lighter
	attachWeld(cage, body, CF(0, -0.22, 0)*CFAN(0,RAD(90),0))

	local rock = makePart("rock", VEC3(0.084, 0.084, 0.084), "Black", "Basalt", 0)
	local rockMesh = Instance.new("CylinderMesh",rock)
	rockMesh.Name = "Mesh"
	rock.Parent = lighter
	attachWeld(rock, body, CF(0.25, 0, 0.14)*CFAN(0,0,RAD(90)))

	local rope = makePart("rope", VEC3(0.084, 0.084, 0.021), "Medium brown", "Sand", 0)
	local ropeMesh = Instance.new("CylinderMesh",rope)
	ropeMesh.Name = "Mesh"
	local Bill = Instance.new("BillboardGui")
	Bill.Enabled = false
	Bill.Parent = rope
	Bill.Size = UDim2.new(0.209, 0, 0.293, 0)
	Bill.StudsOffset = Vector3.new(0, 0.146, 0)
	local im = Instance.new("ImageLabel")
	im.Image = "rbxassetid://91181651318006"
	im.BackgroundTransparency = 1
	im.Size = UDim2.new(1, 0, 1, 0)
	im.Parent = Bill
	rope.Parent = lighter
	attachWeld(rope, body, CF(0, -0.22, 0))
	return lighter
end

-- ── Exhale puff emitter ───────────────────────────────────────────────
local function buildPuff()
	local puff             = Instance.new("ParticleEmitter")
	puff.Texture           = "rbxasset://textures/particles/smoke_main.dds"
	puff.Color             = ColorSequence.new(
		Color3.fromRGB(215,215,215), Color3.fromRGB(175,175,175))
	puff.LightEmission     = 0
	puff.LightInfluence    = 1
	puff.EmissionDirection = Enum.NormalId.Front
	puff.Size = NumberSequence.new{
		NumberSequenceKeypoint.new(0,   0.40),
		NumberSequenceKeypoint.new(0.5, 0.90),
		NumberSequenceKeypoint.new(1,   1.60),
	}
	puff.Transparency = NumberSequence.new{
		NumberSequenceKeypoint.new(0,   0.20),
		NumberSequenceKeypoint.new(0.6, 0.65),
		NumberSequenceKeypoint.new(1,   1),
	}
	puff.Lifetime    = NumberRange.new(3, 5)
	puff.Rate        = 20
	puff.Speed       = NumberRange.new(1, 3)
	puff.SpreadAngle = Vector2.new(35, 35)
	puff.RotSpeed    = NumberRange.new(-30, 30)
	puff.Enabled     = false
	return puff
end

-- ── Shoulder helpers ──────────────────────────────────────────────────
local function removeShoulderMotors()
	for _, m in ipairs(Torso:GetChildren()) do
		if m:IsA("Motor6D") and
			(m.Name == "Left Shoulder" or m.Name == "Right Shoulder") then
			m:Destroy()
		end
	end
end

local function restoreShoulders()
	if lWeld then lWeld:Destroy(); lWeld = nil end
	if rWeld then rWeld:Destroy(); rWeld = nil end
	removeShoulderMotors()
	lShoulderStorage:Clone().Parent = Torso
	rShoulderStorage:Clone().Parent = Torso
end

-- ═════════════════════════════════════════════════════════════════════
--  BUILD TOOL  (never destroyed — lives as long as the LocalScript)
-- ═════════════════════════════════════════════════════════════════════
local Tool          = Instance.new("Tool")
Tool.Name           = "Pipe"
Tool.ToolTip        = "Pipe"
Tool.RequiresHandle = true
Tool.CanBeDropped   = false

local Handle        = Instance.new("Part")
Handle.Name         = "Handle"
Handle.Size         = VEC3(0.1, 0.1, 0.1)
Handle.Transparency = 1
Handle.CanCollide   = false
Handle.Parent       = Tool

local reloadVal     = Instance.new("BoolValue")
reloadVal.Name      = "reload"
reloadVal.Value     = false
reloadVal.Parent    = Tool

Tool.Parent = LP.Backpack

-- ═════════════════════════════════════════════════════════════════════
--  EQUIP
-- ═════════════════════════════════════════════════════════════════════
Tool.Equipped:Connect(function()
	Selected = true

	lWeld        = Instance.new("Weld")
	lWeld.Name   = "lWeld"
	lWeld.C0     = defLS_C0
	lWeld.C1     = defLS_C1
	lWeld.Part0  = Torso
	lWeld.Part1  = lArm

	rWeld        = Instance.new("Weld")
	rWeld.Name   = "rWeld"
	rWeld.C0     = defRS_C0
	rWeld.C1     = defRS_C1
	rWeld.Part0  = Torso
	rWeld.Part1  = rArm

	removeShoulderMotors()
	lWeld.Parent = Torso
	rWeld.Parent = Torso

	-- Invisible pivot anchored to the right arm
	pipeAnchor              = Instance.new("Part")
	pipeAnchor.Name         = "PipeAnchor"
	pipeAnchor.Size         = VEC3(0.1, 0.1, 0.1)
	pipeAnchor.Transparency = 1
	pipeAnchor.CanCollide   = false
	pipeAnchor.Parent       = rArm

	local anchorWeld      = Instance.new("Weld")
	anchorWeld.Name       = "anchorWeld"
	anchorWeld.Part0      = pipeAnchor
	anchorWeld.Part1      = rArm
	anchorWeld.C0         = CF(0.2, 0.9, 0.5) * CFAN(RAD(20), RAD(0), RAD(30))
	anchorWeld.C1         = CF(-0.5, 0, 0.5)   * CFAN(RAD(13), RAD(170), 0)
	anchorWeld.Parent     = pipeAnchor

	local pipeClone = buildPipe()

	pipeWeld        = Instance.new("Weld")
	pipeWeld.Name   = "pipeWeld"
	pipeWeld.Part0  = pipeClone.Bowl      -- invisible anchor is the root
	pipeWeld.Part1  = pipeAnchor
	pipeWeld.C1     = CF(0, 0, 0) * CFAN(RAD(90),0,0)
	pipeWeld.C0     = PIPE_REST
	pipeWeld.Parent = pipeClone
	pipeClone.Parent = rArm

	currentPipe = pipeClone
	currentWeld = pipeWeld
	hasPipe     = true

	if isLit then
		local cherry = pipeClone:FindFirstChild("Cherry")
		if cherry then
			cherry.Color        = CHERRY_IDLE
			cherry.Transparency = 0.05
		end
		pipeClone.Bowl.Crackle:Play()
		local pe = pipeClone.Tobaccy:FindFirstChildOfClass("ParticleEmitter")
		if pe then pe.Enabled = true end
	end

	TweenJoint(rWeld, RightValue4, CF(0,0,0), Linear, 0.5)
	task.wait(0.55)
	ready = true

	-- ── Activated connection (one per equip) ──────────────────────────
	if activatedConn then activatedConn:Disconnect() end
	activatedConn = Tool.Activated:Connect(function()

		-- ════════════════════════════════════════════════════════════
		--  FIRST CLICK — light the pipe with a lighter
		-- ════════════════════════════════════════════════════════════
		if hasPipe and ready and not pulling and not isLit then
			pulling = true

			local pipeRef   = currentPipe
			local cherryRef = pipeRef:FindFirstChild("Cherry")

			TweenJoint(lWeld,    LeftValue2,  CF(0,0,0), Linear, 0.5)
			TweenJoint(rWeld,    RightValue2, CF(0,0,0), Linear, 0.5)
			TweenJoint(pipeWeld, PIPE_MOUTH,  CF(0,0,0), Linear, 0.5)
			task.wait(0.5)

			local lighterClone = buildLighter()
			local lighterBody  = lighterClone:FindFirstChildWhichIsA("Part")
			local lw           = Instance.new("Weld")
			lw.Name            = "lighterWeld"
			lw.Part0           = lighterBody
			lw.Part1           = lArm
			lw.C0              = CF(-0.34,-0.15,-1.11)*CFAN(RAD(95),RAD(0),RAD(-170))
			lw.C1              = CF(0,0,0)
			lw.Parent          = lighterClone
			lighterClone.Parent = lArm

			TweenJoint(lWeld, LeftValue3, CF(0,0,0), Linear, 0.5)
			task.wait(0.6)
			task.wait(math.huge)
			local lSnd = lighterBody:FindFirstChild("Sound")
			if lSnd then lSnd:Play() end
			task.wait(0.1)

			local lGUI = lighterClone.rope.BillboardGui
			if lGUI then lGUI.Enabled = true end

			tweenEmber(cherryRef, CHERRY_IDLE, 0.05, 1.4)
			task.wait(0.9)

			pipeRef.Tobaccy:FindFirstChildOfClass("ParticleEmitter").Enabled = true
			pipeRef.Bowl.Crackle:Play()

			task.wait(0.5)
			if lGUI then lGUI.Enabled = false end
			task.wait(0.2)

			TweenJoint(lWeld, LeftValue2, CF(0,0,0), Linear, 0.5)
			task.wait(0.5)
			lighterClone:Destroy()

			lShoulderStorage:Clone().Parent = Torso
			if lWeld then lWeld:Destroy(); lWeld = nil end

			TweenJoint(rWeld,    RightValue4, CF(0,0,0), Linear, 0.5)
			TweenJoint(pipeWeld, PIPE_REST,   CF(0,0,0), Linear, 0.5)

			pulling = false
			isLit   = true

			-- ════════════════════════════════════════════════════════════
			--  SUBSEQUENT CLICKS — take a drag
			-- ════════════════════════════════════════════════════════════
		elseif hasPipe and ready and isLit and not pulling and not drawing then
			drawing = true

			local pipeRef   = currentPipe
			local cherryRef = pipeRef:FindFirstChild("Cherry")

			TweenJoint(rWeld,    RightValue2, CF(0,0,0), Linear, 0.5)
			TweenJoint(pipeWeld, PIPE_MOUTH,  CF(0,0,0), Linear, 0.5)
			task.wait(0.5)

			if drawing then
				pipeRef.Bowl.Crackle.PlaybackSpeed = 1.9
				pipeRef.Bowl.Crackle.Volume        = 0.42
				tweenEmber(cherryRef, CHERRY_DRAG, 0, 0.4)
			end

			local deactConn
			deactConn = Tool.Deactivated:Connect(function()
				deactConn:Disconnect()
				if not (hasPipe and ready and not pulling) then return end

				if not reloadVal.Value then
					reloadVal.Value = true
					local puff = buildPuff()
					local at   = Instance.new("Attachment")
					at.CFrame  = CF(0, -0.25, 0)
					at.Parent  = Head
					puff.Enabled = true
					puff.Parent  = at
					task.spawn(function()
						task.wait(2.5)
						puff.Enabled = false
						task.wait(6)
						at:Destroy()
						reloadVal.Value = false
					end)
				end

				drawing = false

				local cr = currentPipe
				if cr then
					local cCherry = cr:FindFirstChild("Cherry")
					tweenEmber(cCherry, CHERRY_IDLE, 0.05, 0.9)
				end

				TweenJoint(rWeld,    RightValue4, CF(0,0,0), Linear, 0.5)
				TweenJoint(pipeWeld, PIPE_REST,   CF(0,0,0), Linear, 0.5)
				pipeRef.Bowl.Crackle.PlaybackSpeed = 0.85
				pipeRef.Bowl.Crackle.Volume        = 0.22
			end)
		end
	end)
end)

-- ═════════════════════════════════════════════════════════════════════
--  UNEQUIP
-- ═════════════════════════════════════════════════════════════════════
Tool.Unequipped:Connect(function()
	Selected = false
	if activatedConn then activatedConn:Disconnect(); activatedConn = nil end
	isLit = false
	if hasPipe then
		hasPipe  = false
		ready    = false
		pulling  = false
		drawing  = false
		if currentPipe and currentPipe.Parent then
			currentPipe.Bowl.Crackle:Stop()
			local pe = currentPipe.Tobaccy:FindFirstChildOfClass("ParticleEmitter")
			if pe then pe.Enabled = false end
			currentPipe:Destroy()
			currentPipe = nil
		end
	end

	if pipeAnchor then
		pipeAnchor:Destroy()
		pipeAnchor = nil
	end

	restoreShoulders()
	-- NOTE: isLit is intentionally NOT reset here.
	-- The pipe stays lit between equip/unequip sessions.
end)