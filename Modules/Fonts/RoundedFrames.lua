local _, SUI = ...
local M = SUI:GetModule("fontCompatibility")
if not M then return end

local dandersThinBorders = setmetatable({}, { __mode = "k" })
local hookOwners = setmetatable({}, { __mode = "k" })
local seamLayers = setmetatable({}, { __mode = "k" })
local experienceRounding = setmetatable({}, { __mode = "k" })

local function IsOnePixelBorder(eui, border, allowTint)
    local pp = eui.PP
    local edges = border and border:IsShown() and pp.GetBorders(border)
    local top = edges and edges._top
    if not (top and edges:IsShown() and top:IsShown() and edges._snapEdge and pp.perfect) then return false end
    local pixels = edges._snapEdge * edges:GetEffectiveScale() / pp.perfect
    if math.abs(pixels - 1) > .1 then return false end
    local r, g, b, a = top:GetVertexColor()
    if allowTint then
        return type(a) == "number" and not (issecretvalue and issecretvalue(a)) and a >= .99
    end
    if issecretvalue and (issecretvalue(r) or issecretvalue(g) or issecretvalue(b) or issecretvalue(a)) then return false end
    return r <= .05 and g <= .05 and b <= .05 and a >= .99
end

local function EnemyHealthBar(owner)
    local ns = EllesmereUI and EllesmereUI._ModuleNS and EllesmereUI._ModuleNS.EllesmereUINameplates
    if ns and ns.plates and owner.unit and ns.plates[owner.unit] == owner then return owner.health end
end

local function IsUnlockedVisual(frame)
    return frame and not (frame.IsForbidden and frame:IsForbidden())
        and not (frame.IsProtected and frame:IsProtected())
end

function M:SyncRoundedSeam(owner, radius, opts)
    local thin = dandersThinBorders[owner]
    local unitBorder = owner._euiBaseUnit and owner.unifiedBorder
    local border = opts and opts.border
    local state = seamLayers[owner]
    local health = owner._npRounded and EnemyHealthBar(owner)
    local plateBorder = health and (border == health or border == owner._customBorder)
    local supported = border and (border == unitBorder or (thin and border == thin.layer) or plateBorder)
    if not state and not supported then return end
    local plateHealth = health or (state and state.plateHealth)
    if plateHealth and ((owner.IsForbidden and owner:IsForbidden())
        or (plateHealth.IsForbidden and plateHealth:IsForbidden())
        or (border and border.IsForbidden and border:IsForbidden())) then return end
    if InCombatLockdown and InCombatLockdown() then
        -- Nameplates belong to addon-created, non-protected visual frames.
        -- Avoid touching even the backing when that guarantee is absent.
        if not (plateHealth and IsUnlockedVisual(owner) and IsUnlockedVisual(plateHealth)
            and (not border or IsUnlockedVisual(border))) then
            self.pendingRoundedFrames = true
            if unitBorder then self.pendingEUISeams = true end
            if plateHealth then self.pendingNameplateSeams = true end
            return
        end
    end
    local eui = _G.EllesmereUI
    if not (type(radius) == "number" and radius > 0 and supported and opts.style == "solid"
        and IsOnePixelBorder(eui, border, plateBorder)) then
        if state and state.layer:IsShown() then
            eui.RoundCorners(state.layer, 0)
            state.layer:Hide()
        end
        return
    end
    if not state then
        local layer = CreateFrame("Frame", nil, owner)
        layer:EnableMouse(false)
        state = { layer = layer, options = { border = layer, style = "solid", roots = {} } }
        seamLayers[owner] = state
    end
    local layer = state.layer
    state.plateHealth = health
    local rect = opts.rect or owner
    local level = math.max(0, owner:GetFrameLevel() - 2)
    local thickness = 2
    if thin and border == thin.layer then
        -- DandersFrames draws its missing-health background on the owner,
        -- and its padded health bars three frame levels above it. Draw this
        -- ring between them so the empty padding stays black at full health.
        local paddingPx = thin.padding * owner:GetEffectiveScale() / eui.PP.perfect
        thickness = math.max(thickness, math.ceil(paddingPx - .001) + 1)
        level = owner:GetFrameLevel()
    elseif plateBorder then
        local strata = health:GetFrameStrata()
        if layer:GetFrameStrata() ~= strata then layer:SetFrameStrata(strata) end
        level = math.max(0, health:GetFrameLevel() - 2)
    end
    if state.rect ~= rect then
        layer:ClearAllPoints()
        layer:SetAllPoints(rect)
        state.rect = rect
    end
    if layer:GetFrameLevel() ~= level then layer:SetFrameLevel(level) end
    if layer:IsShown() and state.radius == radius and state.corners == opts.corners and state.thickness == thickness then return end
    -- The body mask and the inverse hole in the border are separately
    -- antialiased. A narrow ring behind both covers the subpixel gap.
    state.radius, state.corners, state.thickness = radius, opts.corners, thickness
    state.options.corners = opts.corners
    eui.ApplyBorderStyle(layer, thickness, 0, 0, 0, 1, "solid")
    if plateBorder and eui.PP.CreateBorder then
        -- Use the same scale guard as the native nameplate border.
        eui.PP.CreateBorder(layer, nil, nil, nil, nil, nil, nil, nil, true)
    end
    eui.RoundCorners(layer, radius, state.options)
end

function M:SyncNameplateSeamCorners(owner, corners)
    local state = seamLayers[owner]
    if not (state and state.plateHealth and state.layer:IsShown() and state.corners ~= corners) then return end
    if InCombatLockdown and InCombatLockdown() and not (IsUnlockedVisual(owner) and IsUnlockedVisual(state.plateHealth)) then
        self.pendingNameplateSeams = true
        return
    end
    if EllesmereUI.RoundedSetCorners(state.layer, corners) then state.corners = corners end
end

local function RestoreDandersArtwork(state)
    for region, shown in pairs(state.artwork) do
        region:SetShown(shown)
        state.artwork[region] = nil
    end
end

local function SuppressDandersArtwork(state, native, repainted)
    local function Hide(region)
        if not region or (region.IsForbidden and region:IsForbidden())
            or (region.IsProtected and region:IsProtected() and InCombatLockdown and InCombatLockdown()) then return end
        if repainted or state.artwork[region] == nil then state.artwork[region] = region:IsShown() end
        if region:IsShown() then region:Hide() end
    end
    Hide(native.top)
    Hide(native.bottom)
    Hide(native.left)
    Hide(native.right)
    Hide(native.bd)
    for _, piece in pairs(native.texPieces or {}) do Hide(piece) end
end

local function ReleaseThinDandersBorder(frame, state, repainted)
    if not state or not state.round then return end
    state.layer:Hide()
    if repainted and state.native == frame.border then wipe(state.artwork)
    else RestoreDandersArtwork(state) end
    pcall(state.round, frame, 0)
    if state.power then pcall(state.round, state.power, 0) end
    state.round, state.native, state.power, state.radius = nil, nil, nil, nil
    SUI:SafeModuleCall(M, "clear Danders dispel shape", M.SyncDandersDispelShape, frame, 0)
    M:SyncDandersAggroGlow(frame)
end

local function StatusTexture(bar)
    return bar and bar.GetStatusBarTexture and bar:GetStatusBarTexture()
end

function M:IsThinDandersBorderActive(frame)
    local state = dandersThinBorders[frame]
    return state and state.round ~= nil and state.native ~= nil or false
end

function M:GetDandersShapeRadius(frame)
    local state = dandersThinBorders[frame]
    return state and state.native and state.radius or 0
end

local function ApplyThinDandersBorder(frame, state, db, thinPreset, repainted, key)
    local native = frame.border
    if not native or not frame.healthBar or not frame.background then
        ReleaseThinDandersBorder(frame, state)
        return
    end
    local eui = _G.EllesmereUI
    if not state then
        local layer = CreateFrame("Frame", nil, native)
        layer:SetAllPoints(frame)
        layer:EnableMouse(false)
        state = { layer = layer, artwork = {}, options = { border = layer, style = "solid", roots = {}, textures = {} } }
        dandersThinBorders[frame] = state
    end
    local layer, opts = state.layer, state.options
    -- The native host receives the range alpha, including secret alpha.
    -- Keep that host visible and replace only its own square artwork.
    if state.native ~= native then
        RestoreDandersArtwork(state)
        if layer:GetParent() ~= native then layer:SetParent(native) end
        state.native = native
    end
    layer:SetFrameLevel(native:GetFrameLevel())
    local showBorder = db.frameShowBorder ~= false and (thinPreset or (tonumber(db.frameBorderSize) or 1) > 0)
    local size, r, g, b, a = 1, 0, 0, 0, 1
    local danders = M:GetDanders()
    local provider = danders and danders.Border
    if not thinPreset and showBorder and provider and provider.BuildSpec then
        local spec = provider:BuildSpec(db, "frame", { unit = frame.unit, frame = frame })
        local color = spec.color
        if color then r, g, b, a = color.r or color[1] or 0, color.g or color[2] or 0,
            color.b or color[3] or 0, color.a or color[4] or 1 end
        size = spec.size
    end
    eui.ApplyBorderStyle(layer, showBorder and size or 0, r, g, b, a, "solid")
    if showBorder and not eui.PP.GetBorders(layer) then
        ReleaseThinDandersBorder(frame, state)
        layer:Hide()
        return
    end
    -- Full-width power bars on the frame share its silhouette. Bars moved
    -- away from the frame still get their own small rounded ends.
    local power = frame.dfPowerBar
    local attachedPower = power and db.resourceBarMatchWidth
        and (db.resourceBarX or 0) == 0 and (db.resourceBarY or 0) == 0
    opts.roots[1] = attachedPower and power or nil
    opts.roots[2] = frame.healthBar
    opts.roots[3] = frame.missingHealthBar
    opts.roots[4] = frame.dfAbsorbBar
    opts.roots[5] = frame.dfHealAbsorbBar
    local textures = opts.textures
    textures[1] = frame.background
    textures[2] = StatusTexture(frame.healthBar)
    textures[3] = StatusTexture(frame.missingHealthBar)
    textures[4] = StatusTexture(frame.dfAbsorbBar)
    textures[5] = StatusTexture(frame.dfHealAbsorbBar)
    textures[6] = StatusTexture(frame.dfHealPredictionBar)
    textures[7] = StatusTexture(frame.dfHealPredictionBar2)
    textures[8] = StatusTexture(frame.dfReducedMaxHealthBar)
    state.padding = math.max(0, tonumber(db.framePadding) or 0)
    state.round = eui.RoundCorners
    local radius = M:ResolveFrameShape(8, nil, 8, key)
    state.radius = radius
    local ok = pcall(state.round, frame, radius, opts)
    if not ok then ReleaseThinDandersBorder(frame, state); return end
    local detachedPower = not attachedPower and power or nil
    if state.power and state.power ~= detachedPower then pcall(state.round, state.power, 0) end
    if detachedPower then
        pcall(state.round, detachedPower, radius > 0 and math.min(3, radius) or 0, { roots = { detachedPower }, style = "solid" })
    end
    state.power = detachedPower
    SuppressDandersArtwork(state, native, repainted)
    SUI:SafeModuleCall(M, "Danders dispel shape", M.SyncDandersDispelShape, frame, radius)
    M:SyncDandersAggroGlow(frame)
end

function M:ApplyDandersRoundedFrame(frame, db, repainted)
    if not SUI:IntegrationEnabled("danders") then return end
    if not frame then return end
    db = frame.dfPinnedBorderDB or db
    if not db then
        local danders = self:GetDanders()
        db = danders and danders.GetFrameDB and danders:GetFrameDB(frame)
    end
    local preset = type(db) == "table" and db.frameShowBorder ~= false
        and db.frameBorderStyle == "TEXTURE" and db.frameBorderTexture
    local danders = self:GetDanders()
    local raid = frame.isRaidFrame or (danders and danders.IsRaidFrame and danders:IsRaidFrame(frame))
    local key = raid and "dandersRaid" or "dandersParty"
    local mode = self:GetFrameShapeMode(false, key)
    local thinPreset = preset == self.ThinRoundedBorderKey
    local forceSolid = mode == "ROUND" and db and (db.frameShowBorder == false
        or (not db.frameBorderGradientEnabled and (not db.frameBorderStyle or db.frameBorderStyle == "SOLID")))
    local thin = (thinPreset or forceSolid) and self:CanDrawThinRoundedBorder()
    local thinState = dandersThinBorders[frame]
    if not (thin or (thinState and thinState.round)) then return end
    if InCombatLockdown and InCombatLockdown() then
        if repainted and thin and thinState and thinState.native == frame.border then
            SuppressDandersArtwork(thinState, frame.border, true)
        end
        self.pendingRoundedFrames = true
        return
    end
    if thin then
        ApplyThinDandersBorder(frame, thinState, db, thinPreset, repainted, key)
        return
    end
    ReleaseThinDandersBorder(frame, thinState, repainted)
end

function M:RefreshDandersRounded()
    if not SUI:IntegrationEnabled("danders") then return end
    local danders = self:GetDanders()
    if not danders then return end
    local function Apply(mode, frame)
        local db = danders.GetFrameDB and danders:GetFrameDB(frame)
        self:ApplyDandersRoundedFrame(frame, db or self:GetBorderDB(mode))
    end
    if type(danders.IteratePartyFrames) == "function" then
        pcall(danders.IteratePartyFrames, danders, function(frame) Apply("party", frame) end)
    end
    if type(danders.IterateArenaFrames) == "function" then
        pcall(danders.IterateArenaFrames, danders, function(frame) Apply("party", frame) end)
    end
    if type(danders.IterateRaidFrames) == "function" then
        pcall(danders.IterateRaidFrames, danders, function(frame) Apply("raid", frame) end)
    end
    for _, frame in pairs(danders.testPartyFrames or {}) do Apply("party", frame) end
    for _, frame in pairs(danders.testRaidFrames or {}) do Apply("raid", frame) end
end

local function ManaAppearance()
    local db = _G._ERB_AceDB
    local profile = db and db.profile
    if not profile then return end
    local resolve = _G._ERB_ResolvePowerCfg
    return (type(resolve) == "function" and resolve(profile)) or profile.primary
end

function M:RoundExperienceBar(frame, settings)
    if not SUI:IntegrationEnabled("frames") then return end
    local eui = _G.EllesmereUI
    if not (frame and frame._isXP and frame._bar and settings and eui and eui.RoundCorners) then return end
    if InCombatLockdown and InCombatLockdown() then self.pendingRoundedFrames = true; return end
    local mana = ManaAppearance()
    local radius, corners = self:ResolveFrameShape(mana and mana.cornerRadius or (not mana and 4), mana and mana.cornerMask, 4, "experience")
    local style = settings.customBorder and settings.borderTexture or "solid"
    if frame._xpArtOn or radius <= 0 or (eui.RoundedStyleOK and not eui.RoundedStyleOK(style)) then
        if experienceRounding[frame] then
            eui.RoundCorners(frame, 0)
            experienceRounding[frame] = nil
        end
        return
    end
    local opts = experienceRounding[frame]
    if not opts then
        opts = { roots = {}, textures = {} }
        experienceRounding[frame] = opts
    end
    opts.border = settings.customBorder and frame._cbHost or (frame._border and frame._border._frame)
    opts.style, opts.corners = style, corners
    opts.roots[1] = frame._fvFlipOn and frame._bar or nil
    opts.roots[2] = frame._divHost
    opts.textures[1] = frame._bg
    opts.textures[2] = StatusTexture(frame._bar)
    opts.textures[3] = StatusTexture(frame._restedBar)
    opts.textures[4] = StatusTexture(frame._questBar)
    opts.textures[5] = StatusTexture(frame._questDoneBar)
    eui.RoundCorners(frame, radius, opts)
end

function M:RefreshExperienceRounding()
    if not SUI:IntegrationEnabled("frames") then return end
    local ns = EllesmereUI and EllesmereUI._ModuleNS
    local bars = ns and ns.EllesmereUIActionBars
    local frame = bars and bars.dataBarFrames and bars.dataBarFrames.XPBar
    local db = bars and bars.EAB and bars.EAB.db
    local settings = db and db.profile and db.profile.bars and db.profile.bars.XPBar
    self:RoundExperienceBar(frame, settings)
end

function M:InstallRoundedHooks()
    local eui = SUI:IntegrationEnabled("frames") and _G.EllesmereUI
    local modules = eui and eui._ModuleNS
    local xp = modules and modules.EllesmereUIActionBars
    if hooksecurefunc and xp and type(xp.StyleDataBarFrame) == "function" and not hookOwners[xp] then
        hookOwners[xp] = true
        hooksecurefunc(xp, "StyleDataBarFrame", function(frame, settings)
            if frame and frame._isXP then
                SUI:SafeModuleCall(M, "rounded experience bar", M.RoundExperienceBar, frame, settings)
            end
        end)
    end
    local resource = modules and modules.EllesmereUIResourceBars
    if hooksecurefunc and resource and type(resource.ERB_RoundBar) == "function" and not hookOwners[resource] then
        hookOwners[resource] = true
        hooksecurefunc(resource, "ERB_RoundBar", function(_, settings)
            if settings and settings == ManaAppearance() then
                SUI:SafeModuleCall(M, "sync experience bar with mana", M.RefreshExperienceRounding)
            end
        end)
    end
    if hooksecurefunc and eui and self:CanDrawThinRoundedBorder() and not hookOwners[eui] then
        hookOwners[eui] = true
        hooksecurefunc(eui, "RoundCorners", function(owner, radius, opts)
            if owner and (owner._euiBaseUnit or owner._npRounded or dandersThinBorders[owner] or seamLayers[owner]) then
                SUI:SafeModuleCall(M, "rounded border seam", M.SyncRoundedSeam, owner, radius, opts)
            end
        end)
        if type(eui.RoundedSetCorners) == "function" then
            hooksecurefunc(eui, "RoundedSetCorners", function(owner, corners)
                if seamLayers[owner] and seamLayers[owner].plateHealth then
                    SUI:SafeModuleCall(M, "rounded nameplate seam corners", M.SyncNameplateSeamCorners, owner, corners)
                end
            end)
        end
        self.pendingEUISeams = true
        self.pendingNameplateSeams = true
    end
    local danders = SUI:IntegrationEnabled("danders") and self:GetDanders()
    if danders and not hookOwners[danders] then
        hookOwners[danders] = true
        self:InstallDandersDispelShape(danders)
        if type(danders.ApplyFrameBorder) == "function" then
            hooksecurefunc(danders, "ApplyFrameBorder", function(_, frame, db)
                SUI:SafeModuleCall(M, "DandersFrames border shape", M.ApplyDandersRoundedFrame, frame, db, true)
            end)
        end
        if type(danders.CreateFrameElementsExtended) == "function" then
            hooksecurefunc(danders, "CreateFrameElementsExtended", function(_, frame, db) M:ApplyDandersRoundedFrame(frame, db) end)
        end
        if type(danders.ApplyFrameLayout) == "function" then
            hooksecurefunc(danders, "ApplyFrameLayout", function(_, frame)
                if frame and dandersThinBorders[frame] then
                    SUI:SafeModuleCall(M, "DandersFrames settled shape", M.ApplyDandersRoundedFrame, frame)
                end
            end)
        end
        if type(danders.LayoutResourceBar) == "function" then
            hooksecurefunc(danders, "LayoutResourceBar", function(_, frame, db)
                if M:IsThinDandersBorderActive(frame) then M:ApplyDandersRoundedFrame(frame, db) end
            end)
        end
    end
end

function M:RefreshRoundedFrames()
    if InCombatLockdown and InCombatLockdown() then self.pendingRoundedFrames = true; return false end
    self.pendingRoundedFrames = nil
    local changed = self:UpdateFrameShapeMode()
    self:InstallDandersAggroGlow()
    self:InstallRoundedHooks()
    local hooked = self:InstallFrameShapeHooks()
    if changed or (hooked and self:GetFrameShapeMode() ~= "AUTO") or self.pendingNativeFrameShapes then
        self.pendingNativeFrameShapes = nil
        self:RefreshNativeFrameShapes()
    end
    self:RefreshShapeOverlays()
    self:RefreshExperienceRounding()
    self:RefreshDandersRounded()
    return true
end

function M:ScheduleRoundedRefresh()
    if self.roundedRefreshScheduled then return end
    self.roundedRefreshScheduled = true
    SUI:After(0, self, "rounded frames refresh", function()
        M.roundedRefreshScheduled = nil
        M:RefreshRoundedFrames()
    end)
end

local PreviousInitialize = M.Initialize
function M:Initialize()
    if PreviousInitialize then PreviousInitialize(self) end
    self:InstallMeterNumbers()
    SUI:RegisterModuleEvent(self, "PLAYER_ENTERING_WORLD")
    SUI:RegisterModuleEvent(self, "ADDON_LOADED")
    SUI:RegisterModuleEvent(self, "NAME_PLATE_UNIT_ADDED")
    SUI:RegisterModuleEvent(self, "UNIT_AURA")
    self:RefreshRoundedFrames()
end

local PreviousOnEvent = M.OnEvent
function M:OnEvent(event, ...)
    if PreviousOnEvent then PreviousOnEvent(self, event, ...) end
    if event == "NAME_PLATE_UNIT_ADDED" or event == "UNIT_AURA" then
        if event == "NAME_PLATE_UNIT_ADDED" then self:QueueNameplateRoundingCheck(...) end
        self:QueueNameplateDamageMarker(...)
        return
    end
    if event == "PLAYER_REGEN_ENABLED" then
        if self.pendingFrameAppearance then self:ApplyFrameAppearanceEdits() end
        if self.pendingDispelShape then self:RefreshPendingDispelShapes() end
    end
    if event == "ADDON_LOADED" then
        local name = ...
        if name == "EllesmereUIDamageMeters" then self:InstallMeterNumbers() end
        if name == "DoesItDieAdvanced" or name == "EllesmereUIAuraBuffReminders"
            or name == "EllesmereUIUnitFrames" or name == "EllesmereUIResourceBars"
            or name == "EllesmereUINameplates" or name == "DandersFrames" or name == "EllesmereUIRaidFrames"
            or name == "EllesmereUICooldownManager" then
            self.pendingNativeFrameShapes = true
            self:ScheduleRoundedRefresh()
        end
    end
    if event == "PLAYER_ENTERING_WORLD" or (event == "PLAYER_REGEN_ENABLED" and self.pendingRoundedFrames) then
        self:RefreshRoundedFrames()
    end
    if self.pendingEUISeams and (event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_REGEN_ENABLED")
        and not (InCombatLockdown and InCombatLockdown()) then
        self.pendingEUISeams = nil
        local unitNS = EllesmereUI and EllesmereUI._ModuleNS and EllesmereUI._ModuleNS.EllesmereUIUnitFrames
        if unitNS and type(unitNS.ReloadFrames) == "function" then
            SUI:After(0, self, "rounded unit frame seams", function() unitNS.ReloadFrames() end)
        end
    end
    if self.pendingNameplateSeams and (event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_REGEN_ENABLED")
        and not (InCombatLockdown and InCombatLockdown()) then
        self.pendingNameplateSeams = nil
        local ns = EllesmereUI and EllesmereUI._ModuleNS and EllesmereUI._ModuleNS.EllesmereUINameplates
        if ns and type(ns.RefreshBorder) == "function" then
            SUI:After(0, self, "rounded nameplate seams", function() ns.RefreshBorder() end)
        end
    end
end

local PreviousProfileChanged = M.OnProfileChanged
function M:OnProfileChanged()
    if PreviousProfileChanged then PreviousProfileChanged(self) end
    self.frameShapeChanged = true
    self:RefreshRoundedFrames()
end
