local Zigarette = {
    ["PluginName"] = "Smoke that",
    ["PluginDescription"] = "Smoke this.",
    ["Commands"] = {
        ["cig"] = {
            ["ListName"] = "cig / givecig / cigarette (CLIENT R6)",
            ["Description"] = "Gives a Cigarette pack. (CLIENT R6)",
            ["Aliases"] = {"givecig","cigarette"},
            ["Function"] = function(args, speaker)
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
                Tool.Name           = "Ernte - 20/20"
                Tool.ToolTip        = "Ernte 20/20"
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
                            Tool.Name  = "Izzurba - "..numberLeft.."/20"
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
            end
        },
        ["cigar"] = {
            ["ListName"] = "cigar / givecigar (CLIENT R6)",
            ["Description"] = "Gives a Cigar. (CLIENT R6)",
            ["Aliases"] = {"givecigar"},
            ["Function"] = function(args, speaker)

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
                        if (hit.Name == "Left Leg" or hit.Name == "Right Leg")
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
                                    if size <= minSize then
                                        cigarWeld:Destroy()
                                        cigRef.Parent = workspace
                                        hasCigar = false; ready = false; isLit = false
                                        cigRef.Paper.Crackle:Stop()
                                        cigarAnchor:Destroy()

                                        TweenJoint(rWeld, RightValue4, CF(0,0,0), Linear, 0.5)

                                        -- Cherry fizzles out naturally after hitting the ground
                                        fizzleCigar(cigRef, 5)
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
                                        task.wait(6)
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
                    Selected = false
                    if activatedConn then activatedConn:Disconnect(); activatedConn = nil end

                    if hasCigar then
                        currentCigar.Parent = workspace
                        hasCigar = false; ready = false; pulling = false; drawing = false; isLit = false
                        currentCigar.Paper.Crackle:Stop()
                        local oldCig = currentCigar
                        oldCig.Paper.CanCollide = true
                        restoreShoulders()
                        local pa = rArm:FindFirstChild("Paper")
                        if pa then pa:Destroy() end
                        fizzleCigar(oldCig, 5)
                        Tool:Destroy()
                        task.delay(10, function()
                            if oldCig and oldCig.Parent then oldCig:Destroy() end
                        end)
                        setupTouchStub(oldCig)
                    else
                        restoreShoulders()
                    end
                end)
            end
        },
        ["pipe"] = {
            ["ListName"] = "pipe / givepipe (CLIENT R6)",
            ["Description"] = "Gives a smoking pipe. (CLIENT R6)",
            ["Aliases"] = {"givepipe"},
            ["Function"] = function(args, speaker)

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
            end
        }
    }
}

return Zigarette