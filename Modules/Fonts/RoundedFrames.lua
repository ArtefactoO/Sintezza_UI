local _, SUI = ...
local M = SUI:GetModule("fontCompatibility")
if not M then return end

local dandersThinBorders = setmetatable({}, { __mode = "k" })
local hookOwners = setmetatable({}, { __mode = "k" })
local seamLayers = setmetatable({}, { __mode = "k" })
local experienceRounding = setmetatable({}, { __mode = "k" })
local petFramePools = { "petFrames", "partyPetFrames", "raidPetFrames", "arenaPetFrames", "testPetFrames", "testRaidPetFrames" }
local prayerRanks = { [401877] = true, [1240848] = true, [1240849] = true }
local petByOwner = setmetatable({}, { __mode = "kv" })
local petPrayerBorders = setmetatable({}, { __mode = "k" })
local queuedPetPrayerBorders = setmetatable({}, { __mode = "k" })
local auraGlowHosts = setmetatable({}, { __mode = "kv" })
local auraGlows = setmetatable({}, { __mode = "k" })

local function Public(value)
    return (not issecretvalue or not issecretvalue(value)) and (not canaccessvalue or canaccessvalue(value))
end

local function PublicNumber(value)
    return Public(value) and type(value) == "number" and value == value
end

local function Accessible(frame)
    if not Public(frame) or (type(frame) ~= "table" and type(frame) ~= "userdata") then return false end
    local ok, allowed = pcall(function()
        local forbidden = frame.IsForbidden and frame:IsForbidden()
        if not Public(forbidden) or forbidden then return false end
        if not frame.CanBeAccessedInContext then return true end
        local permitted = frame:CanBeAccessedInContext()
        return Public(permitted) and permitted == true
    end)
    return ok and allowed
end

local function ColorChannel(color, name, index, fallback)
    local value = color[name]
    if not Public(value) then return end
    if value == nil then value = color[index] end
    if value == nil then value = fallback end
    if PublicNumber(value) then return value end
end

local function BorderBlend(frame, mode)
    for _, region in ipairs({ frame:GetRegions() }) do
        if region:GetObjectType() == "Texture" then region:SetBlendMode(mode) end
    end
    for _, child in ipairs({ frame:GetChildren() }) do BorderBlend(child, mode) end
end

function M:ApplyDandersSolidBorder(layer, native, spec, thinPreset)
    if InCombatLockdown and InCombatLockdown() then return false end
    if not Accessible(layer) or not Accessible(native) or not Public(spec) or type(spec) ~= "table"
        or (canaccesstable and not canaccesstable(spec)) then return false end
    local eui, danders = _G.EllesmereUI, self:GetDanders()
    local provider = danders and danders.Border
    if not (eui and eui.PP and eui.PP.GetBorders and eui.ApplyBorderStyle) then return false end
    local size, inset = spec.size, spec.inset
    local offsetX, offsetY = spec.offsetX, spec.offsetY
    if not Public(size) or not Public(inset) or not Public(offsetX) or not Public(offsetY)
        or not Public(spec.pixelPerfect) or not Public(spec.renderScale) or not Public(spec.enabled) then return false end
    size, inset, offsetX, offsetY = size or 1, inset or 0, offsetX or 0, offsetY or 0
    if not PublicNumber(size) or not PublicNumber(inset) or not PublicNumber(offsetX) or not PublicNumber(offsetY) then return false end
    local color = spec.color
    if not Public(color) or type(color) ~= "table" or (canaccesstable and not canaccesstable(color)) then return false end
    local r, g, b, a = ColorChannel(color, "r", 1, 0), ColorChannel(color, "g", 2, 0),
        ColorChannel(color, "b", 3, 0), ColorChannel(color, "a", 4, 1)
    if r == nil or g == nil or b == nil or a == nil then return false end
    local blend = spec.blendMode
    if not Public(blend) then return false end
    blend = blend or "BLEND"
    if type(blend) ~= "string" then return false end
    if spec.pixelPerfect and not thinPreset then
        local scale = tonumber(spec.renderScale) or 1
        if not provider or not provider.SnapThickness or not danders.PixelPerfect then return false end
        local readable, snapped = pcall(provider.SnapThickness, provider, size, true, scale)
        if not readable or not PublicNumber(snapped) then return false end
        size = snapped
        if inset ~= 0 then
            local factor = scale > 0 and scale or 1
            readable, snapped = pcall(danders.PixelPerfect, danders, inset * factor)
            if not readable or not PublicNumber(snapped) then return false end
            inset = snapped / factor
        end
    end
    local pixel = eui.PP.perfect
    local readable, scale = pcall(layer.GetEffectiveScale, layer)
    if not readable then return false end
    if not PublicNumber(pixel) or pixel <= 0 or not PublicNumber(scale) or scale <= 0 then return false end
    local pixels = size * scale / pixel
    if thinPreset then pixels, inset, r, g, b, a, blend = 1, 0, 0, 0, 0, 1, "BLEND" end
    layer:ClearAllPoints()
    -- Danders has already placed this host with offsetX/Y. Apply only the
    -- inner/outer inset so offsets are inherited once.
    layer:SetPoint("TOPLEFT", native, "TOPLEFT", inset, -inset)
    layer:SetPoint("BOTTOMRIGHT", native, "BOTTOMRIGHT", -inset, inset)
    eui.ApplyBorderStyle(layer, spec.enabled ~= false and math.max(0, pixels) or 0, r, g, b, a, "solid")
    if spec.enabled ~= false and pixels > 0 and not eui.PP.GetBorders(layer) then return false end
    return true, blend, inset == 0 and offsetX == 0 and offsetY == 0
end

function M:ApplyDandersBorderBlend(layer, blend)
    if not Accessible(layer) or (InCombatLockdown and InCombatLockdown()) then return end
    BorderBlend(layer, blend)
end

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
        and (not thin or (thin.blendMode == "BLEND" and thin.seamAligned))
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
    for region, mask in pairs(state.artwork) do
        if Accessible(region) then pcall(region.RemoveMaskTexture, region, mask) end
        state.artwork[region] = nil
    end
end

local function SuppressDandersArtwork(state, native)
    if InCombatLockdown and InCombatLockdown() then return false end
    local mask = state.hideMask
    if state.maskParent ~= native then
        if type(native.CreateMaskTexture) ~= "function" then return false end
        local ok, created = pcall(native.CreateMaskTexture, native)
        if not ok or not Accessible(created) then return false end
        mask = created
        local path = "Interface\\AddOns\\EllesmereUI\\media\\rounded\\hide.tga"
        if mask:SetTexture(path, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE") == false then return false end
        mask:SetAllPoints(native)
        state.hideMask, state.maskParent = mask, native
    end
    local function MaskRegion(region)
        if not Public(region) then return false end
        if region == nil then return true end
        if not Accessible(region) then return false end
        local kind = region:GetObjectType()
        if kind == "Texture" then
            if state.artwork[region] == mask then return true end
            local ok, attached = pcall(region.AddMaskTexture, region, mask)
            if not ok or attached == false then return false end
            state.artwork[region] = mask
            return true
        end
        if kind ~= "Frame" then return true end
        for _, texture in ipairs({ region:GetRegions() }) do
            if not MaskRegion(texture) then return false end
        end
        for _, child in ipairs({ region:GetChildren() }) do
            if not MaskRegion(child) then return false end
        end
        return true
    end
    -- The mask is installed outside combat. Native Show/SetColor calls can
    -- then update the border without reviving its square artwork.
    for _, key in ipairs({ "top", "bottom", "left", "right", "bd" }) do
        if not MaskRegion(native[key]) then return false end
    end
    local pieces = native.texPieces
    if not Public(pieces) or (pieces and canaccesstable and not canaccesstable(pieces)) then return false end
    for _, piece in pairs(pieces or {}) do
        if not MaskRegion(piece) then return false end
    end
    return true
end

local function RestoreAuraGlow(state)
    if not state then return end
    RestoreDandersArtwork(state)
    pcall(state.round, state.layer, 0)
    local eui = _G.EllesmereUI
    if eui and eui.HideBorderStyle then eui.HideBorderStyle(state.layer) end
    state.layer:Hide()
end

local function IsSoftAuraGlow(spec)
    return Public(spec) and type(spec) == "table" and (not canaccesstable or canaccesstable(spec))
        and Public(spec.enabled) and Public(spec.style) and Public(spec.texture)
        and spec.enabled ~= false and spec.style == "TEXTURE" and spec.texture == M.SoftRoundedBorderKey
end

function M:ApplyDandersAuraGlow(frame, native, spec)
    if InCombatLockdown and InCombatLockdown() then self.pendingRoundedFrames = true; return end
    if not Accessible(native) then return end
    local state = auraGlows[native]
    local radius = self:GetDandersShapeRadius(frame)
    local eui = _G.EllesmereUI
    if not (radius > 0 and SUI:IntegrationEnabled("danders") and IsSoftAuraGlow(spec)
        and not spec.animation
        and eui and eui._bdBorderData and eui.PP and eui.RoundCorners and eui.ApplyBorderStyle) then
        RestoreAuraGlow(state)
        return
    end
    local size, inset, x, y = spec.size, spec.inset, spec.offsetX, spec.offsetY
    local mult, level = eui.PP.mult, native:GetFrameLevel()
    local color = spec.color
    if not (PublicNumber(size) and size > 0 and PublicNumber(inset) and PublicNumber(x) and PublicNumber(y)
        and PublicNumber(mult) and mult > 0 and PublicNumber(level) and Public(color) and type(color) == "table"
        and (not canaccesstable or canaccesstable(color))) then
        RestoreAuraGlow(state)
        return
    end
    local r, g, b, a = ColorChannel(color, "r", 1, 0), ColorChannel(color, "g", 2, 0),
        ColorChannel(color, "b", 3, 0), ColorChannel(color, "a", 4, 1)
    local w, h = frame:GetSize()
    if not (r and g and b and a and PublicNumber(w) and PublicNumber(h) and math.min(w, h) > 2) then
        RestoreAuraGlow(state)
        return
    end
    -- The native texture puts the center of its glow halfway into each edge.
    local center = inset + size / 2
    local base = math.min(radius, math.floor((math.min(w, h) - 1) / 2))
    local curve = math.max(1, base - center)
    if not state then
        local layer = CreateFrame("Frame", nil, native)
        layer:EnableMouse(false)
        state = { layer = layer, artwork = {}, options = { border = layer, style = "glow", roots = {} } }
        auraGlows[native] = state
    end
    local layer = state.layer
    layer:ClearAllPoints()
    layer:SetPoint("TOPLEFT", frame, "TOPLEFT", x + center, y - center)
    layer:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", x - center, y + center)
    layer:SetFrameLevel(level)
    state.round = eui.RoundCorners
    local ok = pcall(function()
        eui.ApplyBorderStyle(layer, 1, r, g, b, a, "glow", 0, 0, 0, 0, nil, nil, false, size / mult)
        state.round(layer, curve, state.options)
        local bd = eui._bdBorderData[layer]
        if not (bd and bd:IsShown() and bd:GetAlpha() == 0 and SuppressDandersArtwork(state, native)) then
            error("rounded aura glow unavailable")
        end
        self:ApplyDandersBorderBlend(layer, spec.blendMode or "BLEND")
    end)
    if not ok then RestoreAuraGlow(state) end
end

function M:SyncDandersAuraGlowHandle(frame, handle)
    if InCombatLockdown and InCombatLockdown() then self.pendingRoundedFrames = true; return end
    if not handle or handle._destroyed or not handle.GetAlphaHost or not handle.GetOverlaySlots then return end
    local cfg = handle.config
    local border = cfg and cfg.mode == "overlay" and cfg.style and cfg.style.border
    if not border then return end
    local host = handle:GetAlphaHost()
    if not Accessible(host) then return end
    if not (auraGlowHosts[host] or IsSoftAuraGlow(border.spec) or IsSoftAuraGlow(border.pandemicSpec)) then return end
    auraGlowHosts[host] = frame
    for _, slot in pairs(handle:GetOverlaySlots() or {}) do
        if Accessible(slot) then
            self:ApplyDandersAuraGlow(frame, slot.dfBorder, border.spec)
            self:ApplyDandersAuraGlow(frame, slot.dfBorderPandemic, border.pandemicSpec)
        end
    end
end

function M:RefreshDandersAuraGlows(frame)
    if not Accessible(frame) then return end
    local store = frame.dfADFactory
    for _, effect in pairs(store and store.border or {}) do
        self:SyncDandersAuraGlowHandle(frame, effect.handle)
    end
end

local function OnAuraBorderApplied(self, native, spec)
    if InCombatLockdown and InCombatLockdown() then self.pendingRoundedFrames = true; return end
    -- A paced build can create the slot after the factory has returned its handle.
    local parent = native
    for _ = 1, 10 do
        if not Accessible(parent) then break end
        local frame = auraGlowHosts[parent]
        if Accessible(frame) then
            self:ApplyDandersAuraGlow(frame, native, spec)
            return
        end
        parent = parent:GetParent()
    end
    RestoreAuraGlow(auraGlows[native])
end

local function ReleaseThinDandersBorder(frame, state, repainted)
    if not state or not state.round then return end
    state.layer:Hide()
    RestoreDandersArtwork(state)
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
    local readable, level = pcall(native.GetFrameLevel, native)
    if not readable or not PublicNumber(level) then
        ReleaseThinDandersBorder(frame, state, repainted)
        return
    end
    layer:SetFrameLevel(level)
    local danders = M:GetDanders()
    local provider = danders and danders.Border
    if not provider or not provider.BuildSpec then
        ReleaseThinDandersBorder(frame, state, repainted)
        return
    end
    local pet = frame.isPetFrame
    local spec
    if pet then
        spec = provider:BuildSpec(db, "pet")
    else
        local unit = frame.unit
        if not Public(unit) then ReleaseThinDandersBorder(frame, state, repainted); return end
        spec = provider:BuildSpec(db, "frame", { unit = unit, frame = frame })
    end
    local ok, blend, aligned = M:ApplyDandersSolidBorder(layer, native, spec, thinPreset)
    if not ok then ReleaseThinDandersBorder(frame, state, repainted); return end
    state.blendMode, state.seamAligned = blend, aligned
    opts.rect = layer
    -- Full-width power bars on the frame share its silhouette. Bars moved
    -- away from the frame still get their own small rounded ends.
    local power = pet and frame.powerBar or frame.dfPowerBar
    local attachedPower = power and (pet or (db.resourceBarMatchWidth
        and (db.resourceBarX or 0) == 0 and (db.resourceBarY or 0) == 0))
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
    M:ApplyDandersBorderBlend(layer, blend)
    if not SuppressDandersArtwork(state, native) then
        ReleaseThinDandersBorder(frame, state)
        return
    end
    SUI:SafeModuleCall(M, "Danders dispel shape", M.SyncDandersDispelShape, frame, radius)
    M:SyncDandersAggroGlow(frame)
end

function M:ApplyDandersRoundedFrame(frame, db, repainted)
    if not SUI:IntegrationEnabled("danders") then return end
    if InCombatLockdown and InCombatLockdown() then self.pendingRoundedFrames = true; return end
    if not Accessible(frame) then self.pendingRoundedFrames = true; return end
    local native = frame.border
    if not Public(native) or (native and not Accessible(native)) then self.pendingRoundedFrames = true; return end
    db = frame.dfPinnedBorderDB or db
    if not db then
        local danders = self:GetDanders()
        db = danders and danders.GetFrameDB and danders:GetFrameDB(frame)
    end
    local preset = type(db) == "table" and db.frameShowBorder ~= false and not db.frameBorderGradientEnabled
        and db.frameBorderStyle == "TEXTURE" and db.frameBorderTexture
    local danders = self:GetDanders()
    local raid = frame.isRaidFrame or (danders and danders.IsRaidFrame and danders:IsRaidFrame(frame))
    local key = raid and "dandersRaid" or "dandersParty"
    local mode = self:GetFrameShapeMode(false, key)
    local thinPreset = preset == self.ThinRoundedBorderKey
    local pet = frame.isPetFrame
    local rounded
    if pet then
        rounded = mode ~= "SQUARE" and (thinPreset or mode == "ROUND") and db
            and (db.petShowBorder == false or (not db.petBorderGradientEnabled
                and (db.petBorderStyle or "SOLID") == "SOLID"))
    else
        local forceSolid = mode == "ROUND" and db and (db.frameShowBorder == false
            or (not db.frameBorderGradientEnabled and (not db.frameBorderStyle or db.frameBorderStyle == "SOLID")))
        rounded = thinPreset or forceSolid
    end
    local thin = rounded and self:CanDrawThinRoundedBorder()
    local thinState = dandersThinBorders[frame]
    if not (thin or (thinState and thinState.round)) then return end
    if thin then
        ApplyThinDandersBorder(frame, thinState, db, thinPreset and not pet, repainted, key)
    else
        ReleaseThinDandersBorder(frame, thinState, repainted)
    end
    self:RefreshDandersAuraGlows(frame)
end

local function IsPrayerFilter(ids)
    if not Public(ids) or type(ids) ~= "table" or (canaccesstable and not canaccesstable(ids)) then return false end
    local prayer
    for spellID, included in pairs(ids) do
        if included then
            if not prayerRanks[spellID] then return false end
            prayer = true
        end
    end
    return prayer == true
end

local function FindPrayerBorder(owner)
    local store = owner.dfADFactory
    for _, effect in pairs(store and store.border or {}) do
        local handle = effect.handle
        local cfg = handle and not handle._destroyed and handle.config
        local filters = cfg and cfg.candidateFilters
        if cfg and cfg.mode == "overlay" and cfg.enabled ~= false and not cfg.parentDrivenVisibility and not cfg.dfGate
            and cfg.style and cfg.style.border and cfg.style.border.spec and filters
            and IsPrayerFilter(filters.includeSpellIDs) then
            return cfg
        end
    end
end

function M:SyncDandersPetPrayerBorder(frame)
    if InCombatLockdown and InCombatLockdown() then self.pendingRoundedFrames = true; return end
    if not Accessible(frame) or not frame.isPetFrame then return end
    local owner = frame.ownerFrame
    if Accessible(owner) then petByOwner[owner] = frame end
    local danders = self:GetDanders()
    local auraContainer = danders and danders.IS_FOREVER and danders.AuraContainer
    local state = petPrayerBorders[frame]
    local unit = frame.unit
    local source = SUI:IntegrationEnabled("danders") and auraContainer and auraContainer.Create
        and Public(unit) and type(unit) == "string" and Accessible(owner) and FindPrayerBorder(owner)
    if not source then
        if state then
            state.handle:Destroy()
            petPrayerBorders[frame] = nil
        end
        return
    end
    if frame.dfPetHidden == true and not state then return end

    local width, height = frame:GetSize()
    if not (PublicNumber(width) and PublicNumber(height) and width > 0 and height > 0) then return end
    local filter, candidates = source.filter, source.candidateFilters
    -- The native pet border sits 14 levels above the pet frame.
    local level = source.frameLevelOffset and source.frameLevelOffset >= 11 and 15 or 9
    local rebuild = not state or state.filter ~= filter or state.candidates ~= candidates or state.level ~= level
    local restyle = rebuild or state.style ~= source.style or state.width ~= width or state.height ~= height
    if restyle then
        local style = { border = SUI.DeepCopy(source.style.border) }
        for _, spec in ipairs({ style.border.spec, style.border.pandemicSpec }) do
            spec.knownWidth, spec.knownHeight = width, height
        end
        if rebuild then
            local config = {
                unit = unit, mode = "overlay", filter = filter, candidateFilters = SUI.DeepCopy(candidates),
                enabled = true, frameLevelOffset = level, adBorderAnim = source.adBorderAnim, style = style,
            }
            if state then
                state.handle:Rebuild(config)
            else
                local handle = auraContainer:Create(frame, config)
                if not handle then return end
                state = { handle = handle }
                petPrayerBorders[frame] = state
            end
        else
            state.handle:ApplyStyle(style)
        end
        state.filter, state.candidates, state.level, state.style = filter, candidates, level, source.style
        state.width, state.height = width, height
    end
    if not rebuild and state.unit ~= unit then state.handle:SetUnit(unit) end
    state.unit = unit
    self:SyncDandersAuraGlowHandle(frame, state.handle)
end

function M:QueueDandersPetPrayerBorder(frame)
    if not frame or queuedPetPrayerBorders[frame] then return end
    if InCombatLockdown and InCombatLockdown() then self.pendingRoundedFrames = true; return end
    queuedPetPrayerBorders[frame] = true
    SUI:After(0, self, "DandersFrames pet Prayer of Mending", function()
        queuedPetPrayerBorders[frame] = nil
        M:SyncDandersPetPrayerBorder(frame)
    end)
end

function M:RefreshDandersRounded()
    local danders = self:GetDanders()
    if not danders then return end
    local function Apply(mode, frame)
        local db = danders.GetFrameDB and danders:GetFrameDB(frame)
        self:ApplyDandersRoundedFrame(frame, db or self:GetBorderDB(mode))
    end
    if SUI:IntegrationEnabled("danders") then
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
    else
        for _, state in pairs(auraGlows) do
            if Accessible(state.layer) then RestoreAuraGlow(state) end
        end
    end
    for _, pool in ipairs(petFramePools) do
        for _, frame in pairs(danders[pool] or {}) do
            SUI:SafeModuleCall(self, "DandersFrames pet shape", self.ApplyDandersRoundedFrame, frame)
            SUI:SafeModuleCall(self, "DandersFrames pet Prayer of Mending", self.SyncDandersPetPrayerBorder, frame)
        end
    end
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
        if type(danders.ApplyPetFrameStyle) == "function" then
            hooksecurefunc(danders, "ApplyPetFrameStyle", function(_, frame)
                if frame then
                    SUI:SafeModuleCall(M, "DandersFrames pet shape", M.ApplyDandersRoundedFrame, frame, nil, true)
                end
            end)
        end
        local factory = danders.AuraDesigner and danders.AuraDesigner.Factory
        if hooksecurefunc and danders.Border and type(danders.Border.Apply) == "function" then
            hooksecurefunc(danders.Border, "Apply", function(_, native, spec)
                if Public(native) and (auraGlows[native] or IsSoftAuraGlow(spec)) then
                    SUI:SafeModuleCall(M, "DandersFrames aura glow shape", OnAuraBorderApplied, native, spec)
                end
            end)
        end
        if danders.IS_FOREVER and factory and type(factory.SyncFrame) == "function" and type(factory.ClearFrame) == "function"
            and type(danders.UpdatePetFrame) == "function" then
            hooksecurefunc(danders, "UpdatePetFrame", function(_, frame) M:QueueDandersPetPrayerBorder(frame) end)
            local function RefreshOwnerPet(_, owner)
                M:QueueDandersPetPrayerBorder(petByOwner[owner])
            end
            hooksecurefunc(factory, "SyncFrame", function(_, frame)
                SUI:SafeModuleCall(M, "DandersFrames aura glow shape", M.RefreshDandersAuraGlows, frame)
                RefreshOwnerPet(nil, frame)
            end)
            hooksecurefunc(factory, "ClearFrame", RefreshOwnerPet)
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
