-- ================================================================
--  Ernte 20/20 — Full Local Script (Fixed Port)
--  Place in StarterPlayerScripts as a LocalScript
--  Fully client-side: ONLY you see the tool, model, and animations
-- ================================================================

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")

local LP   = Players.LocalPlayer
local Char = LP.Character or LP.CharacterAdded:Wait()
if Char:FindFirstChild("Accessory (Lollipop)") then
	Char["Accessory (Lollipop)"]:Destroy()
end
repeat task.wait() until Char:FindFirstChild("Torso")

-- ── Character refs ────────────────────────────────────────────────────
local Torso = Char:WaitForChild("Torso")
local rArm  = Char:WaitForChild("Right Arm")
local lArm  = Char:WaitForChild("Left Arm")
local Head  = Char:WaitForChild("Head")

local rShoulder = Torso:FindFirstChild("Right Shoulder")
local lShoulder = Torso:FindFirstChild("Left Shoulder")

-- Save default C0/C1 BEFORE anything is removed
local defLS_C0 = lShoulder.C0
local defLS_C1 = lShoulder.C1
local defRS_C0 = rShoulder.C0
local defRS_C1 = rShoulder.C1

-- Clones for restoration on unequip
local rShoulderStorage = rShoulder:Clone()
local lShoulderStorage = lShoulder:Clone()

-- ── Math shortcuts ────────────────────────────────────────────────────
local CF   = CFrame.new
local CFAN = CFrame.Angles
local RAD  = math.rad
local VEC3 = Vector3.new

-- RunService.Stepped alias (exact match for original TweenJoint)
local RS = RunService.Stepped

-- ── State ─────────────────────────────────────────────────────────────
local Selected   = false
local pulling    = false
local hasZig     = false
local drawing    = false
local ready      = false

local numberLeft = 20
local heat       = 0
local size       = 100
local minSize    = 25

local lWeld, rWeld
local packClone, currentZig, currentWeld, zigWeld, zigAnchor
local activatedConn  -- guard: one connection per equip

-- ── TweenJoint — exact port ───────────────────────────────────────────
local function TweenJoint(Joint, NewC0, NewC1, Alpha, Duration)
	coroutine.resume(coroutine.create(function()
		local TweenIndicator
		local NewCode = math.random(-1e9, 1e9)
		if not Joint:FindFirstChild("TweenCode") then
			TweenIndicator = Instance.new("IntValue")
			TweenIndicator.Name  = "TweenCode"
			TweenIndicator.Value = NewCode
			TweenIndicator.Parent = Joint
		else
			TweenIndicator = Joint.TweenCode
			TweenIndicator.Value = NewCode
		end
		local function MatrixCFrame(CFPos, CFTop, CFBack)
			local CFRight = CFTop:Cross(CFBack)
			return CF(
				CFPos.x, CFPos.y, CFPos.z,
				CFRight.x, CFTop.x, CFBack.x,
				CFRight.y, CFTop.y, CFBack.y,
				CFRight.z, CFTop.z, CFBack.z
			)
		end
		local function LerpCF(StartCF, EndCF, Al)
			local StartTop  = (StartCF * CFAN(RAD(90), 0, 0)).lookVector
			local StartBack = -StartCF.lookVector
			local EndTop    = (EndCF   * CFAN(RAD(90), 0, 0)).lookVector
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

-- ── Arm pose CFrames (EXACT values from LeftValues.pdf) ───────────────
-- These are the direct C0 values used for the weld joints, exactly as
-- they were stored in the original Tool's CFrameValue instances.
-- Format: CFrame.new(posX, posY, posZ) * CFrame.Angles(radX, radY, radZ)

local LeftValue  = CF(-0.9,   0,    -0.8 ) * CFAN(RAD( 8.593), RAD(-79.106), RAD(40.895))
local LeftValue2 = CF(-1.33, -0.14,  0.3 ) * CFAN(RAD( 7.261), RAD(-54.019), RAD( 14.367))
local LeftValue3 = CF(-1,  0.58, -0.61) * CFAN(RAD( -77.331), RAD(-163.091),RAD(-98.349))

local RightValue  = CF( 0.9,  0.2,  -1.0 ) * CFAN(RAD( 70.628), RAD( 92.469), RAD( -49.376))
local RightValue2 = CF( 1.1, 0.74, -0.81) * CFAN(RAD( -75.651), RAD(-158.195), RAD(115.249))
local RightValue3 = CF( 0.92, 0.63, -0.81) * CFAN(RAD( -54.518), RAD(-109.642), RAD(-143.491))
local RightValue4 = CF( 1.45,-0.04, -0.13) * CFAN(RAD( -10.373), RAD(  -6.056), RAD(  0.231))

-- ZigFrame (cigarette resting position on right arm, for reference)
local ZigFrame    = CF( 0.234, 1.265, -0.15) * CFAN(RAD(-5.284), RAD(-160.36), RAD(-171.2))

-- ── Model builders ────────────────────────────────────────────────────

local function buildZigareten()
	local zig = Instance.new("Model")
	zig.Name = "Zigareten"

	local function part(name, sz, col, mat, transp)
		local p = Instance.new("Part")
		p.Name         = name
		p.Size         = sz
		p.BrickColor   = BrickColor.new(col)
		p.Material     = Enum.Material[mat] or Enum.Material.SmoothPlastic
		p.Transparency = transp or 0
		p.CanCollide   = false
		p.CastShadow   = false
		p.Anchored     = false
		p.Parent       = zig
		return p
	end

	local function weld(child, root, c0)
		local w = Instance.new("Weld")
		w.Name   = "Weld"
		w.Part0  = child
		w.Part1  = root
		w.C0     = c0
		w.Parent = child
	end

	-- Paper — main white body (root; everything welds to this)
	local Paper          = part("Paper", VEC3(0.1, 0.4, 0.1), "White", "SmoothPlastic")
	local PaperMesh      = Instance.new("CylinderMesh", Paper)
	PaperMesh.Name       = "Mesh"
	-- Crackle sound — correct asset + equalizer matching original
	local Crackle              = Instance.new("Sound")
	Crackle.Name               = "Crackle"
	Crackle.SoundId            = "rbxassetid://150367028"   -- ← correct ID from PDF
	Crackle.Volume             = 0.1
	Crackle.Looped             = true
	Crackle.PlaybackSpeed      = 1.7
	Crackle.Parent             = Paper

	-- EqualizerSoundEffect on Crackle (values from PDF)
	local eq            = Instance.new("EqualizerSoundEffect")
	eq.HighGain         = -27.8
	eq.LowGain          = -44.9
	eq.MidGain          = -80
	eq.Priority         = 0
	eq.Parent           = Crackle

	-- Stub / extinguish sound
	local ExtSound       = Instance.new("Sound")
	ExtSound.Name        = "Sound"
	ExtSound.SoundId     = "rbxassetid://229579267"         -- ← correct ID from PDF
	ExtSound.Volume      = 0.6
	ExtSound.Parent      = Paper

	-- Filter (orange held end)
	local Filter         = part("Filter", VEC3(0.1, 0.135, 0.1), "Bright orange", "SmoothPlastic")
	local FilterMesh     = Instance.new("CylinderMesh", Filter)
	FilterMesh.Name      = "Mesh"
	weld(Filter, Paper, CF(0, -0.27, 0))

	-- End (very tip of filter)
	local End            = part("End", VEC3(0.101, 0.02, 0.8), "Tan", "SmoothPlastic")
	local EndMesh        = Instance.new("CylinderMesh", End)
	EndMesh.Name         = "Mesh"
	weld(End, Paper, CF(0, -0.21, 0))

	-- Band (branding ring)
	local Band           = part("Band", VEC3(0.08, 0.1, 0.09), "Cool yellow", "SmoothPlastic")
	local BandMesh       = Instance.new("CylinderMesh", Band)
	BandMesh.Name        = "Mesh"
	weld(Band, Paper, CF(0, -0.288, 0))

	-- Tobaccy (tobacco end — scales as it burns)
	local Tobaccy        = part("Tobaccy", VEC3(0.0985, 0.01, 0.8), "Reddish brown", "SmoothPlastic")
	local TobaccyMesh    = Instance.new("CylinderMesh", Tobaccy)
	TobaccyMesh.Name     = "Mesh"
	local tobaccyWeld = Instance.new("Weld")
	tobaccyWeld.Name = "TobaccyWeld"
	tobaccyWeld.Part0 = Tobaccy
	tobaccyWeld.Part1 = Paper
	tobaccyWeld.C0 = CF(0, 0.205, 0)
	tobaccyWeld.Parent = Tobaccy

	-- Cherry (glowing ember — starts invisible, turns on when lit)
	local Cherry         = part("Cherry", VEC3(0.1, 0.03, 0.1), "Bright orange", "Neon", 1)
	local CherryMesh     = Instance.new("CylinderMesh", Cherry)
	CherryMesh.Name      = "Mesh"
	local cherryWeld = Instance.new("Weld")
	cherryWeld.Name = "CherryWeld"
	cherryWeld.Part0 = Cherry
	cherryWeld.Part1 = Paper
	cherryWeld.C0 = CF(0, 0.205, 0)
	cherryWeld.Parent = Cherry
	zig:SetAttribute("CherryWeldName", "CherryWeld")

	-- Smack (invisible part holding the smoke ParticleEmitter)
	local SmkEmit        = Instance.new("ParticleEmitter")
	SmkEmit.Texture      = "rbxasset://textures/particles/smoke_main.dds"
	SmkEmit.Color        = ColorSequence.new(Color3.fromRGB(200,200,200), Color3.fromRGB(165,165,165))
	SmkEmit.LightEmission  = 0
	SmkEmit.LightInfluence = 1
	SmkEmit.EmissionDirection = Enum.NormalId.Back
	SmkEmit.Size = NumberSequence.new{
		NumberSequenceKeypoint.new(0,   0.08),
		NumberSequenceKeypoint.new(0.5, 0.2),
		NumberSequenceKeypoint.new(1,   0.45),
	}
	SmkEmit.Transparency = NumberSequence.new{
		NumberSequenceKeypoint.new(0,   0.3),
		NumberSequenceKeypoint.new(0.7, 0.75),
		NumberSequenceKeypoint.new(1,   1),
	}
	SmkEmit.Lifetime     = NumberRange.new(1, 2.2)
	SmkEmit.Rate         = 8
	SmkEmit.Speed        = NumberRange.new(1, 2.5)
	SmkEmit.SpreadAngle  = Vector2.new(15, 15)
	SmkEmit.RotSpeed     = NumberRange.new(-40, 40)
	SmkEmit.Enabled      = false
	SmkEmit.Parent       = Tobaccy

	local Fizzled        = Instance.new("BoolValue")
	Fizzled.Name         = "Fizzled"
	Fizzled.Value        = false
	Fizzled.Parent       = zig

	return zig
end

local function buildPack()
	local p       = Instance.new("Part")
	p.Name        = "Pack"
	p.Size        = VEC3(0.45, 0.7, 0.22)
	p.BrickColor  = BrickColor.new("White")
	p.Material    = Enum.Material.SmoothPlastic
	p.CanCollide  = false
	local d       = Instance.new("Decal")
	d.Texture     = "rbxassetid://1688752118"
	d.Face        = Enum.NormalId.Front
	d.Parent      = p
	local d2 = d:Clone()
	d2.Face = Enum.NormalId.Back
	d2.Parent = p
	d2 = d:Clone()
	d2.Face = Enum.NormalId.Right
	d2.Parent = p
	d2 = d:Clone()
	d2.Face = Enum.NormalId.Left
	d2.Parent = p
	d2 = d:Clone()
	d2.Face = Enum.NormalId.Top
	d2.Parent = p
	d2 = d:Clone()
	d2.Face = Enum.NormalId.Bottom
	d2.Parent = p
	return p
end

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

local function buildPuff()
	local puff           = Instance.new("ParticleEmitter")
	puff.Texture         = "rbxasset://textures/particles/smoke_main.dds"
	puff.Color           = ColorSequence.new(Color3.fromRGB(225,225,225), Color3.fromRGB(185,185,185))
	puff.LightEmission   = 0
	puff.LightInfluence  = 1
	puff.EmissionDirection = Enum.NormalId.Front
	puff.Size = NumberSequence.new{
		NumberSequenceKeypoint.new(0,   0.3),
		NumberSequenceKeypoint.new(0.5, 0.7),
		NumberSequenceKeypoint.new(1,   1.3),
	}
	puff.Transparency = NumberSequence.new{
		NumberSequenceKeypoint.new(0,   0.2),
		NumberSequenceKeypoint.new(0.6, 0.65),
		NumberSequenceKeypoint.new(1,   1),
	}
	puff.Lifetime    = NumberRange.new(2, 4)
	puff.Rate        = 22
	puff.Speed       = NumberRange.new(1, 3)
	puff.SpreadAngle = Vector2.new(30, 30)
	puff.RotSpeed    = NumberRange.new(-30, 30)
	puff.Enabled     = false
	return puff
end

-- ── Shoulder helpers ──────────────────────────────────────────────────
local function removeShoulderMotors()
	for _, m in ipairs(Torso:GetChildren()) do
		if m:IsA("Motor6D") and (m.Name == "Left Shoulder" or m.Name == "Right Shoulder") then
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

-- ── GetPack ───────────────────────────────────────────────────────────
local function GetPack(lW, packC, dLA_C0, dLA_C1)
	TweenJoint(lW, dLA_C0 * CF(0,-0.05,0), dLA_C1 * CFAN(RAD(-8), RAD(25), RAD(-15)), Linear, 0.5*0.5)

	local pw     = Instance.new("Weld")
	pw.Name      = "packWeld"
	pw.Part0     = packC
	pw.Part1     = lArm
	pw.C0        = CF(0,-0.7,-0.9) * CFAN(RAD(75), RAD(-8), RAD(180))
	pw.C1        = CF(0,0,0)
	pw.Parent    = packC

	task.wait(0.5*0.5)
	packC.Parent = lArm

	TweenJoint(lW, dLA_C0 * CF(0,-0.05,0), dLA_C1 * CFAN(RAD(-8), RAD(8), RAD(8)), Linear, 0.5*0.7)

	ready = true
end

-- ── Fizzle / touch helpers ────────────────────────────────────────────
local function fizzleZig(oldZig, delaySecs)
	task.delay(delaySecs, function()
		if not oldZig or not oldZig.Parent then return end
		oldZig.Fizzled.Value     = true
		oldZig.Cherry.Material   = Enum.Material.Slate
		oldZig.Cherry.BrickColor = BrickColor.new("Fossil")
		local pe = oldZig.Tobaccy:FindFirstChildOfClass("ParticleEmitter")
		if pe then pe.Enabled = false end
	end)
end

local function setupTouchStub(oldZig)
	oldZig.Paper.Touched:Connect(function(hit)
		if (hit.Name == "Left Leg" or hit.Name == "Right Leg") and not oldZig.Fizzled.Value then
			oldZig.Fizzled.Value     = true
			local s = oldZig.Paper:FindFirstChild("Sound")
			if s then s:Play() end
			oldZig.Cherry.Material   = Enum.Material.Slate
			oldZig.Cherry.BrickColor = BrickColor.new("Fossil")
			local pe = oldZig.Tobaccy:FindFirstChildOfClass("ParticleEmitter")
			if pe then pe.Enabled = false end
		end
	end)
end

-- ═════════════════════════════════════════════════════════════════════
--  BUILD TOOL
-- ═════════════════════════════════════════════════════════════════════
local Tool          = Instance.new("Tool")
Tool.Name           = "Cig Pack - 20/20"
Tool.ToolTip        = "Just Smoke it."
Tool.RequiresHandle = true
Tool.CanBeDropped   = false

local Handle            = Instance.new("Part")
Handle.Name             = "Handle"
Handle.Size             = VEC3(0.1, 0.1, 0.1)
Handle.Transparency     = 1
Handle.CanCollide       = false
Handle.Parent           = Tool

local reloadVal         = Instance.new("BoolValue")
reloadVal.Name          = "reload"
reloadVal.Value         = false
reloadVal.Parent        = Tool

Tool.Parent = LP.Backpack

-- ═════════════════════════════════════════════════════════════════════
--  EQUIP
-- ═════════════════════════════════════════════════════════════════════
Tool.Equipped:Connect(function()
	Selected  = true
	packClone = buildPack()

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

	local dLA_C0 = defLS_C0
	local dLA_C1 = defLS_C1

	-- Replace Motor6Ds with local Welds (server never replicates this)
	removeShoulderMotors()
	lWeld.Parent = Torso
	rWeld.Parent = Torso

	GetPack(lWeld, packClone, dLA_C0, dLA_C1)

	-- Single Activated connection per equip
	if activatedConn then activatedConn:Disconnect() end
	activatedConn = Tool.Activated:Connect(function()

		-- ────────────────────────────────────────────────────────────
		--  FIRST CLICK — pull zig from pack, light it
		-- ────────────────────────────────────────────────────────────
		if not hasZig and ready and not pulling then
			pulling = true

			-- Arms reach toward the pack (LeftValue / RightValue from PDF)
			TweenJoint(lWeld, LeftValue,  CF(0,0,0), Linear, 0.5*0.7)
			TweenJoint(rWeld, RightValue, CF(0,0,0), Linear, 0.5*0.7)
			task.wait(0.5*0.72)

			hasZig     = true
			numberLeft = numberLeft - 1
			Tool.Name  = "Cigarette"
			print("Zigareten left: "..numberLeft)

			heat    = 0
			size    = 2000
			minSize = 500

			-- Invisible pivot on right arm (replicates original zigAnchor)
			zigAnchor              = Instance.new("Part")
			zigAnchor.Name         = "Paper"
			zigAnchor.Size         = VEC3(0.1, 0.1, 0.1)
			zigAnchor.Transparency = 1
			zigAnchor.CanCollide   = false
			zigAnchor.Parent       = rArm

			local anchorWeld       = Instance.new("Weld")
			anchorWeld.Name        = "anchorWeld"
			anchorWeld.Part0       = zigAnchor
			anchorWeld.Part1       = rArm
			anchorWeld.C0          = CF(0.1, 1.1, 0.05) * CFAN(RAD(0),RAD(-30),RAD(25))
			anchorWeld.C1          = CF(-0.5,0,0.5) * CFAN(RAD(13), RAD(170), 0)
			anchorWeld.Parent      = zigAnchor

			local zigClone = buildZigareten()
			local cherryWeld = zigClone.Cherry:FindFirstChild("CherryWeld")
			local tobaccyWeld = zigClone.Tobaccy:FindFirstChild("TobaccyWeld")

			zigWeld        = Instance.new("Weld")
			zigWeld.Name   = "zigWeld"
			zigWeld.Part0  = zigClone.Paper
			zigWeld.Part1  = zigAnchor
			zigWeld.C0     = CF(-0.3, -0.26, -0.4) * CFAN(RAD(-27), 0, RAD(34))
			zigWeld.C1     = CF(0,0,0)
			zigWeld.Parent = zigClone
			zigClone.Parent = rArm

			currentZig  = zigClone
			currentWeld = zigWeld

			local PaperMesh   = zigClone.Paper.Mesh
			local TobaccyMesh = zigClone.Tobaccy.Mesh
			local CherryMesh  = zigClone.Cherry.Mesh

			local PaperOffAmt   = PaperMesh.Scale.y   / size * (zigClone.Paper.Size.y   / 2)
			local TobaccyOffAmt = TobaccyMesh.Scale.y / size * (zigClone.Tobaccy.Size.y / 2)
			local CherryOffAmt  = CherryMesh.Scale.y  / size * (zigClone.Cherry.Size.y  / 2)
			local PaperOrigSc   = PaperMesh.Scale.y
			local TobaccyOrigSc = TobaccyMesh.Scale.y
			local CherryOrigSc  = CherryMesh.Scale.y

			-- Bring zig up toward mouth; both arms move to lighting pose
			-- (LeftValue2 / RightValue2 from PDF)
			TweenJoint(zigWeld, CF(-0.3, -0.26, -0.4) * CFAN(RAD(-27), 0, RAD(34)), CF(0,0,0), Linear, 0.5*1)
			TweenJoint(lWeld,   LeftValue2,  CF(0,0,0), Linear, 0.5*1)
			TweenJoint(rWeld,   RightValue2, CF(0,0,0), Linear, 0.5*1)
			task.wait(0.5*1)

			packClone.Parent = nil

			-- Lighter appears in left hand
			local lighterClone  = buildLighter()
			local lighterBody   = lighterClone:FindFirstChildWhichIsA("Part")

			local lw            = Instance.new("Weld")
			lw.Name             = "lighterWeld"
			lw.Part0            = lighterBody
			lw.Part1            = lArm
			lw.C0               = CF(-0.34,-0.15,-1.11) * CFAN(RAD(95), RAD(0), RAD(-170))
			lw.C1               = CF(0,0,0)
			lw.Parent           = lighterClone
			lighterClone.Parent = lArm

			-- Left arm extends lighter toward cherry (LeftValue3 from PDF)
			TweenJoint(lWeld, LeftValue3, CF(0,0,0), Linear, 0.5*1)
			task.wait(0.5*1.2)

			-- Lighter ignites
			local lSnd = lighterBody:FindFirstChild("Sound")
			if lSnd then lSnd:Play() end
			task.wait(0.1)

			local lGUI = lighterClone.rope.BillboardGui
			if lGUI then lGUI.Enabled = true end

			heat = 1
			task.wait(0.5)

			-- Cherry lights up, smoke starts
			zigClone.Tobaccy:FindFirstChildOfClass("ParticleEmitter").Enabled = true
			zigClone.Cherry.Transparency = 0.1
			zigClone.Paper.Crackle:Play()

			task.wait(0.7)
			if lGUI then lGUI.Enabled = false end
			task.wait(0.2)

			-- Left arm pulls back to LeftValue2, then lighter disappears
			TweenJoint(lWeld, LeftValue2, CF(0,0,0), Linear, 0.5*1)
			task.wait(0.5*1)
			lighterClone:Destroy()

			-- Restore left arm Motor6D so default animations can play again
			lShoulderStorage:Clone().Parent = Torso
			if lWeld then lWeld:Destroy(); lWeld = nil end

			-- Right arm settles into resting hold (RightValue4 from PDF)
			TweenJoint(rWeld,   RightValue4, CF(0,0,0), Linear, 0.5*1)
			TweenJoint(zigWeld, CF(-0.3, -0.26, -0.4) * CFAN(RAD(-27), 0, RAD(34)), CF(0,0,0) * CFAN(0,0,RAD(20)), Linear, 0.5*1)

			pulling = false
			heat    = 0.3

			-- ── Burn loop ────────────────────────────────────────────
			task.spawn(function()
				while hasZig and size > minSize and Selected do
					task.wait(0.1)
					size = size - (1 * heat)

					PaperMesh.Scale  = VEC3(PaperMesh.Scale.x, PaperOrigSc * size/2000, PaperMesh.Scale.z)
					PaperMesh.Offset = VEC3(PaperMesh.Offset.x, PaperMesh.Offset.y + (PaperOffAmt * heat), PaperMesh.Offset.z)
					-- Welds track the paper tip exactly
					if cherryWeld then
						local burnPercent = size / 2000
						cherryWeld.C0 = CF(0, (2 * burnPercent - 1) * 0.205, 0)
					end
					if tobaccyWeld then
						local burnPercent = size / 2000
						tobaccyWeld.C0 = CF(0, (2 * burnPercent - 1) * 0.205, 0)
					end

					if size <= minSize then
						-- Burned to the filter
						zigWeld:Destroy()
						zigClone.Parent = workspace
						hasZig = false
						ready  = false
						zigClone.Paper.Crackle:Stop()
						zigAnchor:Destroy()

						TweenJoint(rWeld, RightValue4, CF(0,0,0), Linear, 0.5*1)

						local oldZig = zigClone
						fizzleZig(oldZig, 5)
						task.delay(25, function() if oldZig and oldZig.Parent then oldZig:Destroy() end end)
						setupTouchStub(oldZig)

						-- Reload pack if smokes remain
						task.wait(0.1)
						if numberLeft > 0 and Selected then
							-- Re-create lWeld and get a fresh pack
							removeShoulderMotors()
							lWeld        = Instance.new("Weld")
							lWeld.Name   = "lWeld"
							lWeld.C0     = defLS_C0
							lWeld.C1     = defLS_C1
							lWeld.Part0  = Torso
							lWeld.Part1  = lArm
							lWeld.Parent = Torso
							packClone    = buildPack()
							GetPack(lWeld, packClone, dLA_C0, dLA_C1)
						end
					end

					if numberLeft <= 0 then
						-- Pack empty — clean up everything
						Selected = false
						if currentWeld and currentWeld.Parent then currentWeld:Destroy() end
						zigClone.Parent = workspace
						if packClone then packClone.Parent = nil end
						hasZig = false; ready = false; pulling = false; drawing = false
						zigClone.Paper.Crackle:Stop()
						local oldZig = zigClone
						oldZig.Paper.CanCollide = true
						restoreShoulders()
						local pa = rArm:FindFirstChild("Paper")
						if pa then pa:Destroy() end
						fizzleZig(oldZig, 30)
						task.delay(90, function() if oldZig and oldZig.Parent then oldZig:Destroy() end end)
						setupTouchStub(oldZig)
						Tool:Destroy()
					end
				end
			end)

			-- ────────────────────────────────────────────────────────────
			--  SUBSEQUENT CLICKS — take a drag
			-- ────────────────────────────────────────────────────────────
		elseif hasZig and ready and not pulling and not drawing then
			drawing = true

			-- Right arm lifts zig back to mouth (RightValue2 from PDF)
			TweenJoint(rWeld,   RightValue2, CF(0,0,0), Linear, 0.5*1)
			TweenJoint(zigWeld, CF(-0.3, -0.26, -0.4) * CFAN(RAD(-27), 0, RAD(34)), CF(0,0,0), Linear, 0.5*1)
			task.wait(0.5*1)

			if drawing then
				heat = 2.5
				currentZig.Paper.Crackle.PlaybackSpeed = 3
				currentZig.Paper.Crackle.Volume        = 0.4
			end

			-- Release click to exhale
			local deactConn
			deactConn = Tool.Deactivated:Connect(function()
				deactConn:Disconnect()
				if not (hasZig and ready and not pulling) then return end

				-- Exhale puff
				if not reloadVal.Value then
					reloadVal.Value = true
					local puff = buildPuff()
					local at   = Instance.new("Attachment")
					at.CFrame  = CF(0,-0.25,0)
					at.Parent  = Head
					puff.Enabled = true
					puff.Parent  = at
					task.spawn(function()
						task.wait(2)
						puff.Enabled = false
						task.wait(6)
						at:Destroy()
						reloadVal.Value = false
					end)
				end

				drawing = false
				-- Right arm lowers back to resting hold (RightValue4 from PDF)
				TweenJoint(rWeld,   RightValue4, CF(0,0,0), Linear, 0.5*1)
				TweenJoint(zigWeld, CF(0,0.5,-0.22) * CFAN(RAD(75), 0, RAD(20)), CF(0,0,0) * CFAN(0,0,RAD(20)), Linear, 0.5*1)
				currentZig.Paper.Crackle.PlaybackSpeed = 1.7
				currentZig.Paper.Crackle.Volume        = 0.1
				heat = 0.3
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

	if hasZig then
		currentZig.Parent = workspace
		hasZig = false; ready = false; pulling = false; drawing = false
		currentZig.Paper.Crackle:Stop()
		local oldZig = currentZig
		oldZig.Paper.CanCollide = true
		restoreShoulders()
		Tool.Name  = "Cig Pack - "..numberLeft.."/20"
		local pa = rArm:FindFirstChild("Paper")
		if pa then pa:Destroy() end
		fizzleZig(oldZig, 5)
		task.delay(10, function() if oldZig and oldZig.Parent then oldZig:Destroy() end end)
		setupTouchStub(oldZig)
	else
		if packClone then packClone.Parent = nil end
		restoreShoulders()
	end
end)
