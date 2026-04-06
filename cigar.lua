-- ================================================================
--  Cigar — Full Local Script
--  Place in StarterPlayerScripts as a LocalScript
--  Fully client-side: ONLY you see the model and animations
--  One cigar, no pack.  Cherry glows gradually via TweenService.
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

-- ── Cherry colour states ──────────────────────────────────────────────
-- Unlit  : very dark grey  (completely cold)
-- Idle   : dim warm orange  (lit, resting between drags)
-- Drag   : bright neon orange (actively inhaling)
local CHERRY_UNLIT = Color3.fromRGB(40,  40,  40)
local CHERRY_IDLE  = Color3.fromRGB(200, 80,  0)
local CHERRY_DRAG  = Color3.fromRGB(255, 140, 20)

-- ── State ─────────────────────────────────────────────────────────────
local Selected  = false
local pulling   = false
local hasCigar  = false
local drawing   = false
local ready     = false
local isLit     = false

local heat    = 0
local size    = 5000
local minSize = 1050

local lWeld, rWeld
local currentCigar, currentWeld, cigarWeld, cigarAnchor
local activatedConn

-- ── TweenJoint (exact port from original) ────────────────────────────
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

-- ── Arm pose CFrames (same values as original cigarette script) ───────
local LeftValue2 = CF(-1.33,-0.14, 0.3 ) * CFAN(RAD(  7.261), RAD(-54.019), RAD( 14.367))
local LeftValue3 = CF(-0.84, 0.58,-1) * CFAN(RAD(-77.331), RAD(-163.091),RAD(-123.349))
local RightValue2 = CF( 1.1, 0.74,-0.81) * CFAN(RAD(-75.651), RAD(-158.195), RAD(115.249))
local RightValue4 = CF( 1.45,-0.04,-0.13)* CFAN(RAD(-10.373), RAD(  -6.056), RAD(  0.231))

-- ── Cherry tween helper ───────────────────────────────────────────────
-- Smoothly transitions colour + transparency of the cherry Part,
-- and the brightness/colour of its PointLight (if provided).
local function tweenCherry(cherry, light, targetColour, targetTransp, targetBright, duration)
	if not cherry or not cherry.Parent then return end
	local info = TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
	TweenService:Create(cherry, info, {
		Color        = targetColour,
		Transparency = targetTransp,
	}):Play()
	if light then
		TweenService:Create(light, info, {
			Brightness = targetBright,
			Color      = targetColour,
		}):Play()
	end
end

-- ── Build cigar model ─────────────────────────────────────────────────
--  Structure matching the reference image:
--   • Brown cylinder body (thick, wide)
--   • Orange cap on the mouth end (bottom)
--   • Red band ring near the cherry/burn end (top)
--   • Dark-grey Neon cherry that tweens orange when smoking
local function buildCigar()
	local cig = Instance.new("Model")
	cig.Name  = "Cigar"

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
		p.Parent       = cig
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

	-- Body (root — everything welds to this)
	-- Dark brown cylinder, ~1 stud tall and 0.22 wide
	local Body     = makePart("Paper", VEC3(0.22, 1.0, 0.22), "Burnt Sienna", "SmoothPlastic")
	local BodyMesh = Instance.new("CylinderMesh", Body)
	BodyMesh.Name  = "Mesh"

	-- Crackle burn sound (lower pitch than cigarette = deeper / manlier)
	local Crackle         = Instance.new("Sound")
	Crackle.Name          = "Crackle"
	Crackle.SoundId       = "rbxassetid://150367028"
	Crackle.Volume        = 0.18
	Crackle.Looped        = true
	Crackle.PlaybackSpeed = 1.0
	Crackle.Parent        = Body
	local eq      = Instance.new("EqualizerSoundEffect")
	eq.HighGain   = -22
	eq.LowGain    = -35
	eq.MidGain    = -70
	eq.Priority   = 0
	eq.Parent     = Crackle

	-- Extinguish / stub-out sound
	local ExtSound      = Instance.new("Sound")
	ExtSound.Name       = "Sound"
	ExtSound.SoundId    = "rbxassetid://229579267"
	ExtSound.Volume     = 0.6
	ExtSound.Parent     = Body

	-- Cap — tobacco-coloured sphere at the mouth end (real cigar cap shape)
	local Cap     = makePart("Filter", VEC3(0.22, 0.22, 0.22), "Burnt Sienna", "SmoothPlastic")
	local CapMesh = Instance.new("SpecialMesh", Cap)
	CapMesh.MeshType = Enum.MeshType.Sphere
	CapMesh.Name  = "Mesh"
	attachWeld(Cap, Body, CF(0, -0.5, 0))

	-- Band — red ring sitting near the cherry/burn end
	local Band     = makePart("Band", VEC3(0.225, 0.055, 0.225), "Bright red", "SmoothPlastic")
	local BandMesh = Instance.new("CylinderMesh", Band)
	BandMesh.Name  = "Mesh"
	attachWeld(Band, Body, CF(0, -0.35, 0))

	-- Tobaccy — tobacco face visible at the top; slides as it burns
	local Tobaccy     = makePart("Tobaccy", VEC3(0.215, 0.012, 0.215), "Reddish brown", "SmoothPlastic")
	local TobaccyMesh = Instance.new("CylinderMesh", Tobaccy)
	TobaccyMesh.Name  = "Mesh"
	local tobaccyWeld       = Instance.new("Weld")
	tobaccyWeld.Name        = "TobaccyWeld"
	tobaccyWeld.Part0       = Tobaccy
	tobaccyWeld.Part1       = Body
	tobaccyWeld.C0          = CF(0, 0.506, 0)
	tobaccyWeld.Parent      = Tobaccy

	-- Cherry — Neon ember; starts dark grey, tweens orange when smoking
	local Cherry     = makePart("Cherry", VEC3(0.22, 0.035, 0.22), "Fossil", "Neon", 1)
	Cherry.Color     = CHERRY_UNLIT
	local CherryMesh = Instance.new("CylinderMesh", Cherry)
	CherryMesh.Name  = "Mesh"
	local cherryWeld       = Instance.new("Weld")
	cherryWeld.Name        = "CherryWeld"
	cherryWeld.Part0       = Cherry
	cherryWeld.Part1       = Body
	cherryWeld.C0          = CF(0, 0.518, 0)
	cherryWeld.Parent      = Cherry
	cig:SetAttribute("CherryWeldName", "CherryWeld")

	-- PointLight on the cherry — world glow that intensifies while dragging
	local CherryLight           = Instance.new("PointLight")
	CherryLight.Name            = "CherryLight"
	CherryLight.Brightness      = 0
	CherryLight.Range           = 10
	CherryLight.Color           = Color3.fromRGB(255, 100, 0)
	CherryLight.Parent          = Cherry

	-- Smoke emitter on the tobacco face
	local SmkEmit                 = Instance.new("ParticleEmitter")
	SmkEmit.Texture               = "rbxasset://textures/particles/smoke_main.dds"
	SmkEmit.Color                 = ColorSequence.new(
		Color3.fromRGB(175,175,175), Color3.fromRGB(130,130,130))
	SmkEmit.LightEmission         = 0
	SmkEmit.LightInfluence        = 1
	SmkEmit.EmissionDirection     = Enum.NormalId.Back
	SmkEmit.Size = NumberSequence.new{
		NumberSequenceKeypoint.new(0,   0.14),
		NumberSequenceKeypoint.new(0.5, 0.35),
		NumberSequenceKeypoint.new(1,   0.65),
	}
	SmkEmit.Transparency = NumberSequence.new{
		NumberSequenceKeypoint.new(0,   0.25),
		NumberSequenceKeypoint.new(0.7, 0.72),
		NumberSequenceKeypoint.new(1,   1),
	}
	SmkEmit.Lifetime      = NumberRange.new(1.5, 3.0)
	SmkEmit.Rate          = 7
	SmkEmit.Speed         = NumberRange.new(0.8, 2.2)
	SmkEmit.SpreadAngle   = Vector2.new(12, 12)
	SmkEmit.RotSpeed      = NumberRange.new(-35, 35)
	SmkEmit.Enabled       = false
	SmkEmit.Parent        = Tobaccy

	-- Fizzled flag (read by the touch-stub and fizzle helpers)
	local Fizzled       = Instance.new("BoolValue")
	Fizzled.Name        = "Fizzled"
	Fizzled.Value       = false
	Fizzled.Parent      = cig

	return cig
end

-- ── Lighter model (identical to original) ────────────────────────────
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

-- ── Fizzle: dim the cherry gradually after a delay ────────────────────
local function fizzleCigar(oldCig, delaySecs)
	task.delay(delaySecs, function()
		if not oldCig or not oldCig.Parent then return end
		if oldCig.Fizzled.Value then return end
		oldCig.Fizzled.Value = true
		local cherry = oldCig:FindFirstChild("Cherry")
		if cherry then
			tweenCherry(cherry, cherry:FindFirstChild("CherryLight"),
				CHERRY_UNLIT, 0.65, 0, 1.0)
		end
		local pe = oldCig.Tobaccy:FindFirstChildOfClass("ParticleEmitter")
		if pe then pe.Enabled = false end
	end)
end

-- ── Touch stub: walking over it stamps it out ─────────────────────────
local function setupTouchStub(oldCig)
	local paper = oldCig:FindFirstChild("Paper")
	if not paper then return end
	paper.Touched:Connect(function(hit)
		if (hit.Name == "Left Leg" or hit.Name == "Right Leg") then
			paper.Anchored = true
			and not oldCig.Fizzled.Value then
			oldCig.Fizzled.Value = true
			local s = paper:FindFirstChild("Sound")
			if s then s:Play() end
			local cherry = oldCig:FindFirstChild("Cherry")
			if cherry then
				tweenCherry(cherry, cherry:FindFirstChild("CherryLight"),
					CHERRY_UNLIT, 0.65, 0, 0.35)   -- quick stamp-out
			end
			local pe = oldCig.Tobaccy:FindFirstChildOfClass("ParticleEmitter")
			if pe then pe.Enabled = false end
		end
	end)
end

-- ═════════════════════════════════════════════════════════════════════
--  BUILD TOOL
-- ═════════════════════════════════════════════════════════════════════
local Tool          = Instance.new("Tool")
Tool.Name           = "Cigar"
Tool.ToolTip        = "Cigar"
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
--  EQUIP — cigar appears directly in the right hand, cold and unlit
-- ═════════════════════════════════════════════════════════════════════
Tool.Equipped:Connect(function()
	Selected = true
	isLit    = false
	size     = 5000

	-- Replace Motor6Ds with local Welds for full arm control
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

	-- Invisible pivot anchored to the right arm (same pattern as original)
	cigarAnchor              = Instance.new("Part")
	cigarAnchor.Name         = "Paper"
	cigarAnchor.Size         = VEC3(0.1, 0.1, 0.1)
	cigarAnchor.Transparency = 1
	cigarAnchor.CanCollide   = false
	cigarAnchor.Parent       = rArm

	local anchorWeld      = Instance.new("Weld")
	anchorWeld.Name       = "anchorWeld"
	anchorWeld.Part0      = cigarAnchor
	anchorWeld.Part1      = rArm
	anchorWeld.C0         = CF(0.1, 1.1, 0.05) * CFAN(RAD(0), RAD(-30), RAD(25))
	anchorWeld.C1         = CF(-0.5, 0, 0.5)   * CFAN(RAD(13), RAD(170), 0)
	anchorWeld.Parent     = cigarAnchor

	-- Spawn and attach cigar
	local cigClone = buildCigar()

	cigarWeld        = Instance.new("Weld")
	cigarWeld.Name   = "cigarWeld"
	cigarWeld.Part0  = cigClone.Paper
	cigarWeld.Part1  = cigarAnchor
	cigarWeld.C0     = CF(-0.3, -0.05, -0.4) * CFAN(RAD(-27), 0, RAD(34))
	cigarWeld.C1     = CF(0, 0, 0)
	cigarWeld.Parent = cigClone
	cigClone.Parent  = rArm

	currentCigar = cigClone
	currentWeld  = cigarWeld
	hasCigar     = true
	heat         = 0

	-- Settle right arm into relaxed hold
	TweenJoint(rWeld, RightValue4, CF(0,0,0), Linear, 0.5)
	task.wait(0.55)
	ready = true

	-- ── Activated connection (one per equip) ──────────────────────────
	if activatedConn then activatedConn:Disconnect() end
	activatedConn = Tool.Activated:Connect(function()

		-- ════════════════════════════════════════════════════════════
		--  FIRST CLICK — light the cigar
		-- ════════════════════════════════════════════════════════════
		if hasCigar and ready and not pulling and not isLit then
			pulling = true

			local cigRef      = currentCigar
			local cherryRef   = cigRef:FindFirstChild("Cherry")
			local cherryLight = cherryRef and cherryRef:FindFirstChild("CherryLight")
			local cherryWeld  = cherryRef and cherryRef:FindFirstChild("CherryWeld")
			local tobaccyWeld = cigRef.Tobaccy:FindFirstChild("TobaccyWeld")

			-- Both arms swing to bring the cigar up toward the mouth
			TweenJoint(lWeld,     LeftValue2,  CF(0,0,0), Linear, 0.5)
			TweenJoint(rWeld,     RightValue2, CF(0,0,0), Linear, 0.5)
			TweenJoint(cigarWeld,
				CF(-0.3,-0.05,-0.4)*CFAN(RAD(-27),0,RAD(34)),
				CF(0,0,0), Linear, 0.5)
			task.wait(0.5)

			-- Lighter appears in the left hand
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

			-- Left arm extends the lighter toward the cherry end
			TweenJoint(lWeld, LeftValue3, CF(0,0,0), Linear, 0.5)
			task.wait(0.6)

			-- Lighter ignites
			local lSnd = lighterBody:FindFirstChild("Sound")
			if lSnd then lSnd:Play() end
			task.wait(0.1)

			local lGUI = lighterClone.rope.BillboardGui
			if lGUI then lGUI.Enabled = true end

			-- ── Cherry warms up: dark grey → dim orange (slow tween) ──
			tweenCherry(cherryRef, cherryLight, CHERRY_IDLE, 0.05, 0.9, 1.4)

			task.wait(0.9)

			-- Smoke begins trailing from the tobacco face
			cigRef.Tobaccy:FindFirstChildOfClass("ParticleEmitter").Enabled = true
			cigRef.Paper.Crackle:Play()

			task.wait(0.5)
			if lGUI then lGUI.Enabled = false end
			task.wait(0.2)

			-- Left arm pulls back; lighter vanishes
			TweenJoint(lWeld, LeftValue2, CF(0,0,0), Linear, 0.5)
			task.wait(0.5)
			lighterClone:Destroy()

			-- Restore the left shoulder Motor6D so default walk anims can play
			lShoulderStorage:Clone().Parent = Torso
			if lWeld then lWeld:Destroy(); lWeld = nil end

			-- Right arm settles back to relaxed hold
			TweenJoint(rWeld, RightValue4, CF(0,0,0), Linear, 0.5)
			TweenJoint(cigarWeld,
				CF(-0.3,-0.26,-0.4)*CFAN(RAD(-27),0,RAD(34)),
				CF(0,0,0)*CFAN(0,0,RAD(20)), Linear, 0.5)

			pulling = false
			isLit   = true
			heat    = 0.5   -- slow ambient burn between drags

			-- ── Burn loop ─────────────────────────────────────────────
			local PaperMesh   = cigRef.Paper.Mesh
			local PaperOrigSc = PaperMesh.Scale.y

			task.spawn(function()
				while hasCigar and size > minSize and Selected do
					task.wait(0.1)
					size = size - heat   -- burn faster while drawing (heat rises to 6)

					-- Shrink the body mesh as tobacco is consumed
					local currentSc = math.max(0.01, PaperOrigSc * (size / 5000))
					PaperMesh.Scale = VEC3(
						PaperMesh.Scale.x,
						currentSc,
						PaperMesh.Scale.z
					)

					-- Offset the mesh downward to keep the cap end stationary
					-- while the cherry/top end burns away
					PaperMesh.Offset = VEC3(
						PaperMesh.Offset.x,
						(PaperOrigSc - currentSc) * (cigRef.Paper.Size.y / 2),
						PaperMesh.Offset.z
					)

					-- Slide the tobaccy face and cherry weld with the receding tip
					local burnPct = size / 5000
					if cherryWeld then
						cherryWeld.C0  = CF(0, (2*burnPct - 1) * 0.518, 0)
					end
					if tobaccyWeld then
						tobaccyWeld.C0 = CF(0, (2*burnPct - 1) * 0.506, 0)
					end

					-- ── Cigar is finished — throw it ─────────────────
					-- ── Cigar is finished — throw it ─────────────────
					if size <= minSize then
						ready = false; isLit = false

						TweenJoint(rWeld,
							CF(1.3, 0.6, -0.7) * CFAN(RAD(75), RAD(10), RAD(-15)),
							CF(0, 0, 0), Linear, 0.15)

						task.wait(0.15) -- full tween plays, cigar still attached

						hasCigar = false

						cigarWeld:Destroy()
						cigRef.Parent = workspace
						cigRef.Paper.CanCollide = true

						local root = Char:FindFirstChild("HumanoidRootPart") or Torso
						local throwDir = (
							root.CFrame.LookVector +
								root.CFrame.RightVector * 0.45 +
								Vector3.new(0, 0.25, 0)
						).Unit
						cigRef.Paper.AssemblyLinearVelocity  = throwDir * 30
						cigRef.Paper.AssemblyAngularVelocity = Vector3.new(
							math.random(-22, 22),
							math.random(-22, 22),
							math.random(-22, 22)
						)

						cigRef.Paper.Crackle:Stop()
						cigarAnchor:Destroy()

						task.wait(0.22)
						TweenJoint(rWeld, RightValue4, CF(0,0,0), Linear, 0.5)
						fizzleCigar(cigRef, 5)
						-- ... rest unchanged
						-- ... rest unchanged
						task.delay(25, function()
							if cigRef and cigRef.Parent then cigRef:Destroy() end
						end)
						setupTouchStub(cigRef)

						-- No more cigars — clean up and destroy the tool
						task.wait(0.6)
						Selected = false
						restoreShoulders()
						Tool:Destroy()
						return
					end
				end
			end)

			-- ════════════════════════════════════════════════════════════
			--  SUBSEQUENT CLICKS — take a drag
			-- ════════════════════════════════════════════════════════════
		elseif hasCigar and ready and isLit and not pulling and not drawing then
			drawing = true

			local cigRef      = currentCigar
			local cherryRef   = cigRef:FindFirstChild("Cherry")
			local cherryLight = cherryRef and cherryRef:FindFirstChild("CherryLight")

			-- Lift cigar to mouth
			TweenJoint(rWeld, RightValue2, CF(0,0,0), Linear, 0.5)
			TweenJoint(cigarWeld,
				CF(-0.3,-0.05,-0.4)*CFAN(RAD(-27),0,RAD(34)),
				CF(0,0,0), Linear, 0.5)
			task.wait(0.5)

			if drawing then
				heat = 6   -- burns noticeably faster while inhaling
				cigRef.Paper.Crackle.PlaybackSpeed = 2.2
				cigRef.Paper.Crackle.Volume        = 0.38

				-- ── Cherry brightens to full neon orange on the inhale ─
				tweenCherry(cherryRef, cherryLight, CHERRY_DRAG, 0, 1.3, 0.4)
			end

			-- Release click = stop inhaling
			local deactConn
			deactConn = Tool.Deactivated:Connect(function()
				deactConn:Disconnect()
				if not (hasCigar and ready and not pulling) then return end

				-- Exhale puff of smoke from the face
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
						task.wait(1)
						at:Destroy()
						reloadVal.Value = false
					end)
				end

				drawing = false
				heat    = 0.5   -- back to ambient burn

				-- ── Cherry dims back down to idle glow after the drag ──
				local cr = currentCigar
				if cr then
					local cCherry = cr:FindFirstChild("Cherry")
					local cLight  = cCherry and cCherry:FindFirstChild("CherryLight")
					tweenCherry(cCherry, cLight, CHERRY_IDLE, 0.05, 0.9, 0.9)
				end

				-- Lower arm to resting hold
				TweenJoint(rWeld, RightValue4, CF(0,0,0), Linear, 0.5)
				TweenJoint(cigarWeld,
					CF(0,0.5,-0.22)*CFAN(RAD(75),0,RAD(20)),
					CF(0,0,0)*CFAN(0,0,RAD(20)), Linear, 0.5)
				cigRef.Paper.Crackle.PlaybackSpeed = 1.0
				cigRef.Paper.Crackle.Volume        = 0.18
			end)
		end
	end)
end)

-- ═════════════════════════════════════════════════════════════════════
--  UNEQUIP — drop the cigar if unequipped while still smoking
-- ═════════════════════════════════════════════════════════════════════
Tool.Unequipped:Connect(function()
	if activatedConn then activatedConn:Disconnect(); activatedConn = nil end

	if hasCigar then
		hasCigar = false; ready = false; pulling = false; drawing = false; isLit = false
		currentCigar.Paper.Crackle:Stop()
		local oldCig = currentCigar

		TweenJoint(rWeld,
			CF(1.3, 0.6, -0.7) * CFAN(RAD(75), RAD(10), RAD(-35)),
			CF(0, 0, 0), Linear, 0.15)

		task.wait(0.15) -- full animation before releasing

		if currentWeld then currentWeld:Destroy(); currentWeld = nil end
		oldCig.Parent = workspace
		oldCig.Paper.CanCollide = true

		local root = Char:FindFirstChild("HumanoidRootPart") or Torso
		local throwDir = (
			root.CFrame.LookVector +
				root.CFrame.RightVector * 0.45 +
				Vector3.new(0, 0.25, 0)
		).Unit
		oldCig.Paper.AssemblyLinearVelocity  = throwDir * 30
		oldCig.Paper.AssemblyAngularVelocity = Vector3.new(
			math.random(-22, 22),
			math.random(-22, 22),
			math.random(-22, 22)
		)

		Selected = false

		local pa = rArm:FindFirstChild("Paper")
		if pa then pa:Destroy() end

		fizzleCigar(oldCig, 5)
		setupTouchStub(oldCig)
		Tool:Destroy()
		task.delay(10, function()
			if oldCig and oldCig.Parent then oldCig:Destroy() end
		end)

		task.wait(0.22)
		restoreShoulders()
	else
		Selected = false
		restoreShoulders()
	end
end)
