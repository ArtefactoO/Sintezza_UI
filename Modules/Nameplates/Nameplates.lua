local _, SUI = ...
local Text = SUI.Text

local M = SUI:RegisterModule("nameplates", {
    title = Text("Неймплейты", "Nameplates"),
    available = false,
    plates = {},
    activeUnits = {},
    pendingUnits = {},
})
SUI.Nameplates = M

local TARGET_TEXTURE_KEY = "sui-target-arrows-in"
local TARGET_TEXTURE_NAME = Text("SUI: Стрелки внутрь", "SUI: Inward arrows")
local TARGET_TEXTURE_PATH = "Interface\\AddOns\\Sintezza_UI\\Media\\Nameplates\\target-arrows-in.png"
local TARGET_PATTERN_TEXTURES = {
    arrowsIn = "Interface\\AddOns\\Sintezza_UI\\Media\\Nameplates\\target-arrows-in.png",
    diagonal = "Interface\\AddOns\\Sintezza_UI\\Media\\Nameplates\\target-pattern-diagonal.png",
    diagonalReverse = "Interface\\AddOns\\Sintezza_UI\\Media\\Nameplates\\target-pattern-diagonal-reverse.png",
    fine = "Interface\\AddOns\\Sintezza_UI\\Media\\Nameplates\\target-pattern-fine.png",
    crosshatch = "Interface\\AddOns\\Sintezza_UI\\Media\\Nameplates\\target-pattern-crosshatch.png",
    vertical = "Interface\\AddOns\\Sintezza_UI\\Media\\Nameplates\\target-pattern-vertical.png",
    chevrons = "Interface\\AddOns\\Sintezza_UI\\Media\\Nameplates\\target-pattern-chevrons.png",
    dots = "Interface\\AddOns\\Sintezza_UI\\Media\\Nameplates\\target-pattern-dots.png",
}
M.TargetPatternOptions = {
    { value = "arrowsIn", title = Text("Стрелки внутрь", "Inward arrows"), texture = TARGET_PATTERN_TEXTURES.arrowsIn },
    { value = "diagonal", title = Text("Диагональ /", "Diagonal /"), texture = TARGET_PATTERN_TEXTURES.diagonal },
    { value = "diagonalReverse", title = Text("Широкая диагональ \\", "Wide diagonal \\"), texture = TARGET_PATTERN_TEXTURES.diagonalReverse },
    { value = "fine", title = Text("Тонкая штриховка", "Fine hatching"), texture = TARGET_PATTERN_TEXTURES.fine },
    { value = "crosshatch", title = Text("Перекрестная штриховка", "Crosshatch"), texture = TARGET_PATTERN_TEXTURES.crosshatch },
    { value = "vertical", title = Text("Вертикальные полосы", "Vertical stripes"), texture = TARGET_PATTERN_TEXTURES.vertical },
    { value = "chevrons", title = Text("Шевроны", "Chevrons"), texture = TARGET_PATTERN_TEXTURES.chevrons },
    { value = "dots", title = Text("Точки", "Dots"), texture = TARGET_PATTERN_TEXTURES.dots },
}

local function IsSecret(value)
    return issecretvalue and issecretvalue(value)
end

-- 12.1 may return secret unit-derived values. They cannot be negated,
-- formatted or used as a table key; pcall alone is insufficient unless the
-- returned value is checked before Lua evaluates it.
local function SafePlainCall(func, ...)
    if type(func) ~= "function" then return nil, false end
    local ok, value = pcall(func, ...)
    if not ok or IsSecret(value) then return nil, false end
    return value, true
end

local ROUND_MEDIA = "Interface\\AddOns\\EllesmereUI\\media\\rounded\\"
local ringMasks = setmetatable({}, { __mode = "k" })

function M:GetNativePlateRounding(health, namespace)
    local eui = _G.EllesmereUI
    local ns = namespace or (self.adapterKey == "ellesmere" and self.adapterState and self.adapterState.namespace)
    local p = ns and ns.db and ns.db.profile
    if not (p and eui and Enum and Enum.UITextureSliceMode and Enum.UITextureSliceMode.Stretched
        and not (ns.NP_Blizz and ns.NP_Blizz())
        and not (ns.GetWrapBorderCastbar and ns.GetWrapBorderCastbar())) then return end
    local shapes = SUI:GetModule("fontCompatibility")
    local radius, corners = shapes:ResolveFrameShape(p.cornerRadius, p.cornerMask, 8, "plates")
    if radius < 1 then return end
    local style = ns.IsCustomBorderEnabled and ns.IsCustomBorderEnabled() and p.customBorderTexture or "solid"
    if eui.RoundedStyleOK and not eui.RoundedStyleOK(style) then return end
    local height = health and SafePlainCall(health.GetHeight, health) or tonumber(p.healthBarHeight)
    local width = health and SafePlainCall(health.GetWidth, health)
    if type(height) == "number" and height > 2 then
        if type(width) == "number" and width > 2 then height = math.min(height, width) end
        radius = math.min(radius, math.max(1, math.floor(height / 2 - .5)))
    end
    return math.min(16, math.floor(radius)), corners
end

function M:GetPlateEffectShape(plate, namespace)
    local ns = namespace or (self.adapterKey == "ellesmere" and self.adapterState and self.adapterState.namespace)
    local rect = plate.health
    local custom = plate._customBorder
    if ns and ns.IsCustomBorderEnabled and ns.IsCustomBorderEnabled() and custom and custom:IsShown() then rect = custom end
    local radius, corners = self:GetNativePlateRounding(rect, ns)
    local eui = _G.EllesmereUI
    if radius and plate._npJoinCast and plate.cast and plate.cast:IsShown() and eui and eui.RoundedJoinCorners then
        corners = eui.RoundedJoinCorners(corners)
    end
    return rect, radius, corners
end

local function SetRoundedArt(region, radius, corners, inverse)
    local base = inverse and "rounded-inv-" or "rounded-"
    local mask = corners == 15 and "" or ("-" .. corners)
    local wrap = inverse and "CLAMPTOWHITE" or "CLAMPTOBLACKADDITIVE"
    region:SetTexture(ROUND_MEDIA .. base .. radius .. mask .. ".tga", wrap, wrap)
    region:SetTextureSliceMargins(radius, radius, radius, radius)
    region:SetTextureSliceMode(Enum.UITextureSliceMode.Stretched)
end

local function ExpandAround(region, health, pad)
    region:ClearAllPoints()
    region:SetPoint("TOPLEFT", health, "TOPLEFT", -pad, pad)
    region:SetPoint("BOTTOMRIGHT", health, "BOTTOMRIGHT", pad, -pad)
end

-- Texture-only outline: its aura button still owns visibility. The inverse
-- mask cuts the middle out so the health and text remain visible.
function M:PlaceRoundedPlateRing(texture, parent, health, radius, corners, gap, width)
    local state = ringMasks[texture]
    if not state then
        state = { hole = parent:CreateMaskTexture() }
        ringMasks[texture] = state
    end
    if state.health == health and state.radius == radius and state.corners == corners
        and state.gap == gap and state.width == width then return end
    if state.attached then texture:RemoveMaskTexture(state.hole) end
    local outer = gap + width
    SetRoundedArt(texture, math.max(1, math.min(16, math.floor(radius + outer + .5))), corners, false)
    SetRoundedArt(state.hole, math.max(1, math.min(16, math.floor(radius + gap + .5))), corners, true)
    ExpandAround(texture, health, outer)
    ExpandAround(state.hole, health, gap)
    texture:AddMaskTexture(state.hole)
    state.attached = true
    state.health, state.radius, state.corners, state.gap, state.width = health, radius, corners, gap, width
end

function M:ColorPlateEffectTexture(texture, r, g, b, a)
    if ringMasks[texture] then texture:SetVertexColor(r, g, b, a)
    else texture:SetColorTexture(r, g, b, a) end
end

local function PlaceSquareEdges(frame, width)
    if not frame.edges then
        frame.edges = {}
        for index = 1, 4 do frame.edges[index] = frame:CreateTexture(nil, "OVERLAY", nil, 5) end
    end
    if frame.edgeWidth ~= width then
        local top, bottom, left, right = unpack(frame.edges)
        top:SetPoint("TOPLEFT", frame, "TOPLEFT", -width, width)
        top:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", width, 0)
        bottom:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", -width, 0)
        bottom:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", width, -width)
        left:SetPoint("TOPLEFT", frame, "TOPLEFT", -width, 0)
        left:SetPoint("BOTTOMRIGHT", frame, "BOTTOMLEFT", 0, 0)
        right:SetPoint("TOPLEFT", frame, "TOPRIGHT", 0, 0)
        right:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", width, 0)
        frame.edgeWidth = width
    end
    return frame.edges
end

local function UnitExistsPlain(unit)
    local value, readable = SafePlainCall(UnitExists, unit)
    return readable and value == true
end

function M:QueueLearnedDebuffScan(unit)
    local profile = self:Profile()
    if not profile or profile.enabled == false or profile.learnDebuffs ~= true or not self.AuraCatalog
        or IsSecret(unit) or type(unit) ~= "string" then return end
    if unit ~= "target" and unit ~= "focus" and not self.activeUnits[unit] then return end
    self.learnPendingUnits = self.learnPendingUnits or {}
    self.learnPendingUnits[unit] = true
    if self.learnScanScheduled then return end
    self.learnScanScheduled = true
    -- UNIT_AURA can burst for several plates in one event batch. Coalesce those
    -- units into one next-frame pass and reuse the pending table.
    SUI:After(0, self, "learn nameplate debuffs", function()
        M.learnScanScheduled = nil
        local pending = M.learnPendingUnits or {}
        local current = M:Profile()
        if not current or current.enabled == false or current.learnDebuffs ~= true then wipe(pending); return end
        local learned = 0
        for pendingUnit in pairs(pending) do
            pending[pendingUnit] = nil
            learned = learned + M.AuraCatalog:LearnFromUnit(pendingUnit)
        end
        M.learnedThisSession = (M.learnedThisSession or 0) + learned
    end)
end

function M:Profile()
    return SUI:GetModuleProfile("nameplates")
end

function M:IsTapColorPriority(unit)
    local profile = self:Profile()
    if IsSecret(unit) or not unit or not profile or not profile.enabled or profile.respectTapDenied == false then return false end
    local denied = SafePlainCall(UnitIsTapDenied, unit)
    return denied == true
end

function M:RegisterTargetTexture()
    local ns = self.namespace
    if not ns or type(ns.healthBarTextures) ~= "table"
        or type(ns.healthBarTextureNames) ~= "table"
        or type(ns.healthBarTextureOrder) ~= "table" then return false end

    ns.healthBarTextures[TARGET_TEXTURE_KEY] = TARGET_TEXTURE_PATH
    ns.healthBarTextureNames[TARGET_TEXTURE_KEY] = TARGET_TEXTURE_NAME
    for _, key in ipairs(ns.healthBarTextureOrder) do
        if key == TARGET_TEXTURE_KEY then return true end
    end
    ns.healthBarTextureOrder[#ns.healthBarTextureOrder + 1] = TARGET_TEXTURE_KEY
    return true
end

function M:TargetPatternProfile()
    local profile = self:Profile()
    return profile and profile.targetPattern
end

function M:IsTargetPlate(plate)
    local unit = plate and plate.unit
    if not unit then return false end
    local same, readable = SafePlainCall(UnitIsUnit, unit, "target")
    return readable and same == true
end

function M:TargetPatternLevel(plate)
    if not plate or not plate.health then return nil end
    local auraLevel = self.AuraRules and self.AuraRules:TopVisualLevel(plate.health)
    return (auraLevel or plate.health:GetFrameLevel()) + 1
end

local ARROW_POOL_SIZE = 6
local ARROW_SOURCE_WIDTH = 17 / 256
local ARROW_CELL_WIDTH = 18 / 256
local ARROW_GROUP_WIDTH = 54 / 256

local function PreparePatternTexture(parent, layer, subLevel)
    local texture = parent:CreateTexture(nil, layer or "OVERLAY", nil, subLevel or 7)
    texture:SetBlendMode("BLEND")
    if texture.SetSnapToPixelGrid then texture:SetSnapToPixelGrid(false) end
    if texture.SetTexelSnappingBias then texture:SetTexelSnappingBias(0) end
    return texture
end

local function EnsurePatternArrowPool(container)
    local pool = container.__suiPatternArrowPool
    if pool then return pool end
    pool = { left = {}, right = {} }
    local layer = container.__suiPatternLayer or "ARTWORK"
    local subLevel = container.__suiPatternSubLevel
    for index = 1, ARROW_POOL_SIZE do
        local left = PreparePatternTexture(container, layer, subLevel)
        local right = PreparePatternTexture(container, layer, subLevel)
        left:SetTexCoord(1 / 256, 18 / 256, 0, 1)
        right:SetTexCoord(238 / 256, 255 / 256, 0, 1)
        left:Hide()
        right:Hide()
        pool.left[index], pool.right[index] = left, right
    end
    container.__suiPatternArrowPool = pool
    return pool
end

local function HidePatternArrowPool(container)
    local pool = container.__suiPatternArrowPool
    if not pool then return end
    for index = 1, ARROW_POOL_SIZE do
        pool.left[index]:Hide()
        pool.right[index]:Hide()
    end
end

local function ApplyPatternArtwork(container, anchor, mainTexture, key, scale, alpha)
    local path = TARGET_PATTERN_TEXTURES[key]
    if not container or not anchor or not mainTexture or not path then return false end
    scale = math.max(.5, math.min(2, tonumber(scale) or 1))
    alpha = math.max(.05, math.min(1, tonumber(alpha) or .88))

    if key == "arrowsIn" then
        mainTexture:Hide()
        local pool = EnsurePatternArrowPool(container)
        if container.__suiPatternArrowPath ~= path then
            container.__suiPatternArrowPath = path
            for index = 1, ARROW_POOL_SIZE do
                pool.left[index]:SetTexture(path)
                pool.right[index]:SetTexture(path)
            end
        end

        local width = tonumber(anchor:GetWidth()) or 0
        if width < 2 then width = tonumber(container.__suiPatternFallbackWidth) or 1 end
        width = math.max(1, width)
        local arrowWidth = math.max(1, width * ARROW_SOURCE_WIDTH * scale)
        local cellWidth = math.max(1, width * ARROW_CELL_WIDTH * scale)
        local groupWidth = width * ARROW_GROUP_WIDTH
        local count = math.max(1, math.min(ARROW_POOL_SIZE, math.floor(groupWidth / cellWidth + .5)))
        for index = 1, ARROW_POOL_SIZE do
            local left, right = pool.left[index], pool.right[index]
            if index <= count then
                local offset = (index - 1) * cellWidth
                left:ClearAllPoints()
                left:SetPoint("TOPLEFT", anchor, "TOPLEFT", offset, 0)
                left:SetPoint("BOTTOMLEFT", anchor, "BOTTOMLEFT", offset, 0)
                left:SetWidth(arrowWidth)
                left:SetAlpha(alpha)
                left:Show()
                right:ClearAllPoints()
                right:SetPoint("TOPRIGHT", anchor, "TOPRIGHT", -offset, 0)
                right:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", -offset, 0)
                right:SetWidth(arrowWidth)
                right:SetAlpha(alpha)
                right:Show()
            else
                left:Hide()
                right:Hide()
            end
        end
    else
        HidePatternArrowPool(container)
        mainTexture:Show()
        if container.__suiPatternKey ~= key then
            local ok, applied = pcall(mainTexture.SetTexture, mainTexture, path, "REPEAT", "CLAMPTOBLACKADDITIVE")
            if not ok or applied == false then mainTexture:SetTexture(path) end
        end
        if container.__suiPatternKey ~= key or container.__suiPatternScale ~= scale then
            local span = 1 / scale
            local left = (1 - span) * .5
            mainTexture:SetTexCoord(left, left + span, 0, 1)
        end
        mainTexture:SetAlpha(alpha)
    end
    container.__suiPatternKey = key
    container.__suiPatternScale = scale
    return true
end

function M:EnsureTargetPattern(plate)
    if plate.__suiTargetPattern then return plate.__suiTargetPattern end
    local health = plate and plate.health
    if not health then return nil end
    local fill = health:GetStatusBarTexture()
    if not fill then return nil end

    local frame = CreateFrame("Frame", nil, health)
    frame:SetClipsChildren(true)
    frame:SetAllPoints(health)
    frame:EnableMouse(false)
    frame:Hide()
    frame.__suiPatternLayer = "OVERLAY"
    frame.__suiPatternSubLevel = 7

    local texture = PreparePatternTexture(frame, "OVERLAY", 7)
    -- The drawing spans the full bar while the frame clips it at the current
    -- fill edge. Pattern coordinates therefore remain stable as health changes.
    texture:SetPoint("TOPLEFT", health, "TOPLEFT", 0, 0)
    texture:SetPoint("BOTTOMRIGHT", health, "BOTTOMRIGHT", 0, 0)

    frame.texture = texture
    frame.fill = fill
    plate.__suiTargetPattern = frame
    return frame
end

function M:AnchorTargetPattern(frame, plate, coverBackground)
    local health = plate and plate.health
    local fill = health and health:GetStatusBarTexture()
    if not frame or not health or not fill then return false end
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", health, "TOPLEFT", 0, 0)
    frame:SetPoint("BOTTOMLEFT", health, "BOTTOMLEFT", 0, 0)
    frame:SetPoint("RIGHT", coverBackground and health or fill, "RIGHT", 0, 0)
    frame.fill = fill
    frame.coverBackground = coverBackground == true
    return true
end

function M:ApplyTargetPatternTexture(frame, plate, key, scale, alpha)
    local health = plate and plate.health
    return ApplyPatternArtwork(frame, health, frame and frame.texture, key, scale, alpha)
end

function M:MaskTargetPattern(frame, health)
    local radius, corners = self:GetNativePlateRounding(health)
    local mask = frame.__suiRoundMask
    if not radius and not mask then return end
    if not mask then
        if not frame.CreateMaskTexture then return end
        mask = frame:CreateMaskTexture()
        frame.__suiRoundMask = mask
        frame.__suiMaskedPattern = {}
    end
    local attached = frame.__suiMaskedPattern
    if frame.__suiMaskRadius ~= radius or frame.__suiMaskCorners ~= corners then
        for texture in pairs(attached) do
            texture:RemoveMaskTexture(mask)
            attached[texture] = nil
        end
        if radius then
            SetRoundedArt(mask, math.max(1, radius - 1), corners, false)
            local eui = _G.EllesmereUI
            local scale = SafePlainCall(health.GetEffectiveScale, health)
            local pixel = eui.PP and eui.PP.perfect
            local inset = type(scale) == "number" and scale > 0 and type(pixel) == "number" and pixel / scale or 0
            ExpandAround(mask, health, -inset)
        end
        frame.__suiMaskRadius, frame.__suiMaskCorners = radius, corners
    end
    if not radius then return end
    local function Seat(texture)
        if texture and not attached[texture] then texture:AddMaskTexture(mask); attached[texture] = true end
    end
    Seat(frame.texture)
    local arrows = frame.__suiPatternArrowPool
    for index, texture in ipairs(arrows and arrows.left or {}) do
        Seat(texture)
        Seat(arrows.right[index])
    end
end

function M:ApplyTargetPatternPreview(sample, texture, key, scale)
    key = TARGET_PATTERN_TEXTURES[key] and key or "diagonal"
    sample.__suiPatternFallbackWidth = 222
    -- The shared widget sets the plain texture before this callback, so force
    -- the preview to restore REPEAT wrapping even when only scale changed.
    sample.__suiPatternKey = nil
    return ApplyPatternArtwork(sample, sample, texture, key, scale, .88)
end

function M:UpdateTargetPattern(plate, isTarget)
    local moduleProfile = self:Profile()
    local profile = self:TargetPatternProfile()
    local frame = plate and plate.__suiTargetPattern
    if isTarget == nil then isTarget = self:IsTargetPlate(plate) end
    if not moduleProfile or moduleProfile.enabled == false or not profile
        or profile.enabled == false or not isTarget or self:IsTapColorPriority(plate and plate.unit) then
        if frame then frame:Hide() end
        return
    end
    frame = self:EnsureTargetPattern(plate)
    if not frame then return end

    local fill = plate.health:GetStatusBarTexture()
    local coverBackground = profile.coverBackground == true
    if fill and (frame.fill ~= fill or frame.coverBackground ~= coverBackground) then
        self:AnchorTargetPattern(frame, plate, coverBackground)
    end
    local key = TARGET_PATTERN_TEXTURES[profile.texture] and profile.texture or "diagonal"
    local scale = math.max(.5, math.min(2, tonumber(profile.scale) or 1))
    local alpha = math.max(.05, math.min(.70, tonumber(profile.opacity) or .28))
    if plate.__suiThreat and plate.__suiThreat:IsShown() then alpha = alpha * .55 end
    self:ApplyTargetPatternTexture(frame, plate, key, scale, alpha)
    pcall(self.MaskTargetPattern, self, frame, plate.health)
    pcall(frame.SetFrameLevel, frame, self:TargetPatternLevel(plate))
    frame:Show()
end

function M:RestoreNativeSelectionGlow(plate)
    local state = plate and plate.__suiRoundedSelectionGlow
    if not state then return end
    state.layer:Hide()
    if state.originalShown then
        for texture, shown in pairs(state.originalShown) do texture:SetShown(shown) end
    end
    state.originalShown = nil
end

local function PlateTextLevel(plate)
    local health = plate.healthTextFrame and SafePlainCall(plate.healthTextFrame.GetFrameLevel, plate.healthTextFrame)
    local top = plate.topTextFrame and SafePlainCall(plate.topTextFrame.GetFrameLevel, plate.topTextFrame)
    if type(health) == "number" and type(top) == "number" then return math.min(health, top) end
    if type(health) == "number" then return health end
    if type(top) == "number" then return top end
end

function M:UpdateNativeSelectionGlow(plate, isTarget, namespace)
    local ns = namespace or (self.adapterKey == "ellesmere" and self.adapterState and self.adapterState.namespace)
    local eui = _G.EllesmereUI
    local health, native = plate and plate.health, plate and plate.glow
    local preview = plate and plate.settingsPreview
    if not (health and (preview or (native and native:IsShown() and plate.glowTextures))
        and isTarget and ns and ns.GetTargetGlowEllesmereUI
        and ns.GetTargetGlowEllesmereUI() and not (ns.NP_Blizz and ns.NP_Blizz())
        and eui and eui.RoundCorners and eui.ApplyBorderStyle and eui.SetBorderStyleColor
        and ns.GetTargetGlowColor and ns.GetTargetGlowAlpha) then
        self:RestoreNativeSelectionGlow(plate)
        return
    end
    local radius, corners = self:GetNativePlateRounding(health, ns)
    radius = radius or 0
    local color, alpha = ns.GetTargetGlowColor(), ns.GetTargetGlowAlpha()
    local state = plate.__suiRoundedSelectionGlow
    if not state then
        -- The native glow is in BACKGROUND. Our glow shares the explicit
        -- MEDIUM tier with the threat edge and text on the flattened plate.
        local layer = CreateFrame("Frame", nil, preview and plate.frame or plate)
        if not preview then layer:SetFrameStrata("MEDIUM") end
        layer:EnableMouse(false)
        state = { layer = layer, opts = { border = layer, style = "glow", roots = {} } }
        plate.__suiRoundedSelectionGlow = state
        if native and native.HookScript then
            native:HookScript("OnHide", function()
                SUI:SafeModuleCall(M, "hide nameplate target glow", M.RestoreNativeSelectionGlow, plate)
            end)
        end
    end
    local layer = state.layer
    local base = self.AuraRules and self.AuraRules:TopVisualLevel(health)
        or SafePlainCall(health.GetFrameLevel, health) or 0
    local level = base + 4
    local threat = plate.__suiThreat
    local threatLevel = threat and threat:IsShown() and SafePlainCall(threat.GetFrameLevel, threat)
    if type(threatLevel) == "number" then level = math.max(level, threatLevel + 1) end
    local textLevel = PlateTextLevel(plate)
    if textLevel and textLevel > 1 then level = math.min(level, textLevel - 1) end
    if state.health ~= health then
        layer:ClearAllPoints()
        layer:SetAllPoints(health)
        state.health = health
    end
    if state.radius ~= radius or state.corners ~= corners or state.level ~= level then
        layer:SetFrameLevel(level)
        eui.ApplyBorderStyle(layer, 1, color.r, color.g, color.b, alpha, "glow", 0, 0, 0, 0, nil, nil, true, SUI:GetModule("fontCompatibility").SelectionGlowWidth)
        state.opts.corners = corners
        eui.RoundCorners(layer, radius, state.opts)
        state.radius, state.corners, state.level = radius, corners, level
    elseif state.r ~= color.r or state.g ~= color.g or state.b ~= color.b or state.a ~= alpha then
        eui.SetBorderStyleColor(layer, color.r, color.g, color.b, alpha)
    end
    state.r, state.g, state.b, state.a = color.r, color.g, color.b, alpha
    layer:Show()
    -- Only the artwork is replaced. ApplyTarget still controls when the
    -- native glow is active, including changes to the user's settings.
    if plate.glowTextures and not state.originalShown then
        state.originalShown = {}
        for _, texture in ipairs(plate.glowTextures) do
            state.originalShown[texture] = texture:IsShown()
            texture:Hide()
        end
    end
end

local SELECTION_CLIPS = { "targetClipFill", "targetClipBg", "focusClipFill", "focusClipBg", "hoverClipFill", "hoverClipBg" }

local function RestoreSelectionClipAlpha(plate)
    local saved = plate and plate.__suiTargetClipAlpha
    if not saved then return end
    for clip, alpha in pairs(saved) do clip:SetAlpha(alpha) end
    plate.__suiTargetClipAlpha = nil
end

function M:UpdateSelectionClipAlpha(plate, isTarget)
    if not plate or self.adapterKey ~= "ellesmere" then return end
    local tapped = self:IsTapColorPriority(plate.unit)
    local dimTarget = isTarget and plate.__suiThreat and plate.__suiThreat:IsShown()
    local saved = plate.__suiTargetClipAlpha
    if not tapped and not dimTarget then RestoreSelectionClipAlpha(plate); return end
    -- The owner still controls visibility and tint. Only the clip hosts'
    -- alpha changes; the selection glow and the bar's numbers keep drawing.
    for index, key in ipairs(SELECTION_CLIPS) do
        local clip = plate[key]
        local factor = tapped and 0 or (dimTarget and index <= 2 and .4 or 1)
        local original = clip and saved and saved[clip]
        if clip and factor ~= 1 then
            if original == nil then
                original = SafePlainCall(clip.GetAlpha, clip)
                if type(original) == "number" then
                    saved = saved or {}
                    saved[clip] = original
                end
            end
            if type(original) == "number" then clip:SetAlpha(original * factor) end
        elseif original ~= nil then
            clip:SetAlpha(original)
            saved[clip] = nil
        end
    end
    plate.__suiTargetClipAlpha = saved
end

function M:UpdateTargetAccents(plate, isTarget)
    self:UpdateTargetPattern(plate, isTarget)
    self:UpdateSelectionClipAlpha(plate, isTarget)
    SUI:SafeModuleCall(self, "nameplate target glow", self.UpdateNativeSelectionGlow, plate, isTarget)
end

function M:UpdateSelectionVisuals(plate)
    local hasTarget = UnitExistsPlain("target")
    local isTarget = hasTarget and self:IsTargetPlate(plate) or false
    self:UpdateTargetAccents(plate, isTarget)
    if plate and plate.health then
        local auraLevel = self.AuraRules and self.AuraRules:TopVisualLevel(plate.health)
        local overlayLevel = (auraLevel or plate.health:GetFrameLevel()) + 1
        for _, key in ipairs({ "targetClipFill", "targetClipBg", "focusClipFill", "focusClipBg" }) do
            local overlay = plate[key]
            if overlay then pcall(overlay.SetFrameLevel, overlay, overlayLevel) end
        end
    end
end

function M:RefreshSelectionVisuals()
    for _, plate in pairs(self.plates or {}) do self:UpdateSelectionVisuals(plate) end
end

M.RefreshTargetPatterns = M.RefreshSelectionVisuals

local styledText = setmetatable({}, { __mode = "k" })
local textHooks = setmetatable({}, { __mode = "k" })
local textModes = { outline = true, shadow = true, outlineShadow = true }
local textFields = {
    name = { "name" }, level = { "levelText" }, health = { "hpNumber", "hpText" },
    target = { "totText" }, quest = { "questText" },
    castName = { "castName" }, castTarget = { "castTarget" }, castTime = { "castTimer" },
}
local textRefreshHooks = {
    RefreshNamePosition = "name", ApplyHealthTextAppearance = false, UpdateQuestText = "quest",
}

local function HasTextStyle(styles)
    if type(styles) ~= "table" then return false end
    for key in pairs(textFields) do
        if textModes[styles[key]] then return true end
    end
    return false
end

local function ApplyNameplateTextStyle(fs, eui, path, mode, enabled, preview)
    if not (fs and fs.GetFont) or (fs.IsForbidden and fs:IsForbidden()) then return end
    if not enabled and not preview and not styledText[fs] then return end
    local ok, _, size = pcall(fs.GetFont, fs)
    if not ok or IsSecret(size) or type(size) ~= "number" or size <= 0 then return end
    local flags, shadow
    if enabled then
        flags = mode ~= "shadow" and (eui.OutlineFlagForMode and eui.OutlineFlagForMode("outline") or "OUTLINE") or ""
        shadow = mode == "shadow" or mode == "outlineShadow"
    else
        flags = eui.GetFontOutlineFlag and eui.GetFontOutlineFlag("nameplates") or ""
        -- Match the native FontFamily rule.
        shadow = flags == ""
    end
    local before = fs.GetFontObject and SafePlainCall(fs.GetFontObject, fs)
    eui.SetFontFamily(fs, path, size, flags, shadow)
    if not preview then styledText[fs] = enabled and true or nil end
    local after = fs.GetFontObject and SafePlainCall(fs.GetFontObject, fs)
    return before ~= after
end

function M:ApplyPreviewTextStyles(plate)
    local eui = _G.EllesmereUI
    if not (eui and eui.SetFontFamily and eui.GetFontPath) then return end
    local path = eui.GetFontPath("nameplates")
    if type(path) ~= "string" or path == "" then return end
    local profile = self:Profile()
    for key, fields in pairs(textFields) do
        local mode = profile.textStyles[key]
        for _, field in ipairs(fields) do
            ApplyNameplateTextStyle(plate[field], eui, path, mode, profile.enabled and textModes[mode], true)
        end
    end
end

local function ApplyPlateTextField(plate, ns, eui, path, field, mode, customText)
    local enabled = textModes[mode] and customText
    local changed
    for _, fsKey in ipairs(textFields[field]) do
        if ApplyNameplateTextStyle(plate[fsKey], eui, path, mode, enabled) then changed = true end
    end
    if field == "level" then
        local box = plate._fvLevelBox or plate._fvLevelBoxSpare
        ApplyNameplateTextStyle(box and box._fs, eui, path, mode, textModes[mode] and plate._fvLevelBox ~= nil)
    elseif field == "name" and changed and ns and ns.DebuffColors_NameChanged then
        ns.DebuffColors_NameChanged(plate)
    end
end

function M:UpdatePlateTextStyle(plate, restore, field)
    local eui = _G.EllesmereUI
    if not (plate and eui and eui.SetFontFamily and eui.GetFontPath) then return end
    local ns = self.adapterKey == "ellesmere" and self.adapterState and self.adapterState.namespace
    local profile = self:Profile()
    local styles = not restore and ns and profile.enabled and profile.textStyles or nil
    local path = eui.GetFontPath("nameplates")
    if type(path) ~= "string" or path == "" then return end
    local customText = ns and not (ns.NP_Blizz and ns.NP_Blizz())
    if field then
        ApplyPlateTextField(plate, ns, eui, path, field, styles and styles[field], customText)
    else
        for key in pairs(textFields) do
            ApplyPlateTextField(plate, ns, eui, path, key, styles and styles[key], customText)
        end
    end
end

function M:AttachPlateTextStyle(plate)
    if self.adapterKey ~= "ellesmere" then return end
    if not textHooks[plate] then
        textHooks[plate] = true
        for method, field in pairs(textRefreshHooks) do
            if type(plate[method]) == "function" then
                hooksecurefunc(plate, method, function(owner)
                    SUI:SafeModuleCall(M, "nameplate text style", M.UpdatePlateTextStyle, owner, false, field)
                end)
            end
        end
    end
    SUI:SafeModuleCall(self, "nameplate text style", self.UpdatePlateTextStyle, plate)
end

function M:RefreshRuntimeFlags()
    local profile = self:Profile()
    -- EUI owns the native health fill. Interpolating that same StatusBar breaks
    -- both its pooled value and the aura-rule texture anchored to its fill.
    if profile then profile.smoothHealth = false end
    self.smoothHealthActive = false
    local rules = profile and profile.enabled and self.AuraRules and self.AuraRules:Profile()
    self.auraRulesOn = rules and rules.enabled == true or false
    self.runtimeWanted = profile and profile.enabled == true and (
        (profile.openWorldThreat and (profile.threatBorderEnabled or profile.threatFillEnabled))
        or profile.respectTapDenied ~= false
        or (profile.targetPattern and profile.targetPattern.enabled)
        or profile.learnDebuffs == true or self.auraRulesOn or (tonumber(profile.buffIconsPerRow) or 0) > 0
        or HasTextStyle(profile.textStyles)) and true or false
end

function M:RefreshFeatureDemand()
    local before = self.runtimeWanted
    self:RefreshRuntimeFlags()
    if before ~= self.runtimeWanted then self:RefreshAll(true) end
end

function M:Shutdown()
    self:RefreshBuffRows()
    self:StopRetryLoop()
    wipe(self.pendingUnits)
    if self.learnPendingUnits then wipe(self.learnPendingUnits) end
    if not next(self.plates) and not (self.AuraRules and next(self.AuraRules.rigs)) then
        self.pendingShutdown = nil
        wipe(self.activeUnits)
        return
    end
    if InCombatLockdown and InCombatLockdown() then self.pendingShutdown = true; return end
    self.pendingShutdown = nil
    for unit in pairs(self.plates) do self:DetachPlate(unit) end
    wipe(self.activeUnits)
    if self.AuraRules then self.AuraRules:ResetRuntime() end
end

function M:IsOpenWorld()
    local inInstance = IsInInstance()
    return not inInstance
end

M.THREAT_BORDER_MIN, M.THREAT_BORDER_MAX = 1, 6

function M:GetThreatBorderThickness()
    local size = tonumber(self:Profile().threatBorderThickness) or SUI.NameplateThreatBorderDefault
    return math.max(self.THREAT_BORDER_MIN, math.min(self.THREAT_BORDER_MAX, math.floor(size + .5)))
end

function M:RefreshThreatBorders()
    for _, plate in pairs(self.plates) do
        local frame = plate.__suiThreat
        if frame and frame:IsShown() then self:UpdateThreat(plate) end
    end
end

function M:EnsureThreatDecoration(plate)
    if plate.__suiThreat then return plate.__suiThreat end
    if not plate.health then return nil end
    -- Follow Ellesmere's actual health frame through its target-scale
    -- animation and stay in the plate's own render group.
    local ellesmere = self.adapterKey == "ellesmere"
    local parent = ellesmere and plate.health or (plate.frame or plate.nameplate or plate)
    local frame = CreateFrame("Frame", nil, parent)
    if ellesmere and not plate.settingsPreview then frame:SetFrameStrata("MEDIUM") end
    frame:SetAllPoints(plate.health)
    frame.edgeRect = plate.health
    frame:EnableMouse(false)
    frame:Hide()
    plate.__suiThreat = frame
    return frame
end

function M:ShowThreatDecoration(plate, color, alpha, namespace)
    local frame = self:EnsureThreatDecoration(plate)
    if not frame then return false end
    local shown = frame:IsShown()
    local base = self.AuraRules and self.AuraRules:TopVisualLevel(plate.health)
        or SafePlainCall(plate.health.GetFrameLevel, plate.health)
    if type(base) == "number" then
        local level = base + 3
        local textLevel = self.adapterKey == "ellesmere" and PlateTextLevel(plate)
        if textLevel and textLevel > 2 then
            level = math.min(level, textLevel - 2)
        end
        pcall(frame.SetFrameLevel, frame, level)
    end
    local rect, radius, corners = self:GetPlateEffectShape(plate, namespace)
    if frame.edgeRect ~= rect then
        frame:ClearAllPoints()
        frame:SetAllPoints(rect)
        frame.edgeRect = rect
    end
    local width = self:GetThreatBorderThickness()
    local rounded
    if radius and frame.CreateMaskTexture then
        if not frame.ring then frame.ring = frame:CreateTexture(nil, "OVERLAY", nil, 5) end
        -- The hole stays flush with the health rectangle at every width.
        rounded = pcall(self.PlaceRoundedPlateRing, self, frame.ring, frame, rect, radius, corners, 0, width)
    end
    if frame.ring then
        if rounded then frame.ring:SetVertexColor(color.r, color.g, color.b, alpha) end
        frame.ring:SetShown(rounded == true)
    end
    if not rounded then PlaceSquareEdges(frame, width) end
    for _, edge in ipairs(frame.edges or {}) do
        if not rounded then edge:SetColorTexture(color.r, color.g, color.b, alpha) end
        edge:SetShown(not rounded)
    end
    frame:Show()
    if not shown and self:IsTargetPlate(plate) then self:UpdateTargetAccents(plate, true) end
    return true
end

function M:HideThreatDecoration(plate, frame)
    if not (frame and frame:IsShown()) then return end
    frame:Hide()
    if self:IsTargetPlate(plate) then self:UpdateTargetAccents(plate, true) end
end

function M:WrapHealthBar(bar)
    -- Compatibility entry point only; intentionally does not replace native
    -- StatusBar methods.
end

function M:BindHealthBarOwner(unit, plate)
    local bar = plate and plate.health
    if not bar then return false end
    self:WrapHealthBar(bar)
    return false
end

function M:GetThreatState(unit)
    local profile = self:Profile()
    if not profile or not profile.enabled or not profile.openWorldThreat or not self:IsOpenWorld() then return nil end
    if not unit or self:IsTapColorPriority(unit) then return nil end
    local canAttack, canReadAttack = SafePlainCall(UnitCanAttack, "player", unit)
    if not canReadAttack or not canAttack then return nil end
    local status, canReadStatus = SafePlainCall(UnitThreatSituation, "player", unit)
    if not canReadStatus then return nil end
    if type(status) == "number" then
        if status >= 2 then return "aggro" end
        if status == 1 and profile.nearThreat then return "near" end
    end
    local targetUnit = unit .. "target"
    if UnitExistsPlain(targetUnit) then
        local targetsPlayer, readable = SafePlainCall(UnitIsUnit, targetUnit, "player")
        if readable and targetsPlayer then return "aggro" end
    end
    return nil
end

function M:RestoreThreatFill(plate)
    if not plate or not plate.__suiThreatFillApplied then return false end
    plate.__suiThreatFillApplied = nil
    local adapter = self.activeAdapter
    if not adapter or type(adapter.RestoreHealthColor) ~= "function" then return false end
    self.restoringThreatFill = plate
    local callOK, restored = pcall(adapter.RestoreHealthColor, adapter, self, plate)
    self.restoringThreatFill = nil
    return callOK and restored == true
end

function M:UpdateThreat(plate)
    local state = plate and self:GetThreatState(plate.unit)
    local frame = plate and plate.__suiThreat
    local profile = self:Profile()
    if not state or not profile then
        self:HideThreatDecoration(plate, frame)
        self:RestoreThreatFill(plate)
        return
    end

    local allowBorder = not self.AdapterSupports or self:AdapterSupports("threatBorder")
    if allowBorder and profile.threatBorderEnabled ~= false then
        local color = state == "near" and profile.nearColor or profile.aggroColor
        self:ShowThreatDecoration(plate, color, state == "near" and .72 or 1)
    else
        self:HideThreatDecoration(plate, frame)
    end

    local allowFill = not self.AdapterSupports or self:AdapterSupports("threatFill")
    if allowFill and profile.threatFillEnabled == true and plate.health then
        local color = state == "near" and profile.nearFillColor or profile.aggroFillColor
        color = type(color) == "table" and color or {}
        plate.health:SetStatusBarColor(
            color.r or color[1] or .70,
            color.g or color[2] or .08,
            color.b or color[3] or .04,
            color.a or color[4] or 1
        )
        plate.__suiThreatFillApplied = true
    else
        self:RestoreThreatFill(plate)
    end
end

function M:FindTargetPlate()
    local unit = "target"
    local direct = self.plates and self.plates[unit]
    if direct and direct.health then return unit, direct end
    for plateUnit, plate in pairs(self.plates or {}) do
        local isTarget, readable = SafePlainCall(UnitIsUnit, plateUnit, unit)
        if readable and isTarget and plate and plate.health then
            return plateUnit, plate
        end
    end
    return nil, nil
end


-- EllesmereUI creates the hover overlay lazily on first mouseover. Keep it one
-- tier above target/focus, which themselves sit above conditional aura paint.
-- Text and borders use their own higher tiers and remain untouched.
function M:UpdateHoverOverlay(plate)
    if not plate or not plate.health then return end
    local fill, background = plate.hoverClipFill, plate.hoverClipBg
    if not fill and not background then return end
    local auraLevel = self.AuraRules and self.AuraRules:TopVisualLevel(plate.health)
    local level = (auraLevel or plate.health:GetFrameLevel()) + 2
    if fill then pcall(fill.SetFrameLevel, fill, level) end
    if background then pcall(background.SetFrameLevel, background, level) end
    if self:IsTapColorPriority(plate.unit) then self:UpdateSelectionClipAlpha(plate, self:IsTargetPlate(plate)) end
end

local function RestoreTapDebuffGate(plate, paint)
    local saved = plate.__suiTapDebuffGate
    plate.__suiTapDebuffGate = nil
    if saved and saved.unit == plate.unit and saved.paint == paint then
        paint(plate, saved.health, saved.border, saved.name)
    end
end

function M:ApplyNativeTapPriority(plate, nativePaint)
    local ns = self.adapterKey == "ellesmere" and self.adapterState and self.adapterState.namespace
    if not ns or not plate then return end
    local paint = ns.DebuffColors_Threat
    if not self:IsTapColorPriority(plate.unit) then
        local repaint = plate.__suiTapThreatRepaint
        plate.__suiTapThreatRepaint = nil
        -- The native health pass has already written the new unit's gates.
        if nativePaint then plate.__suiTapDebuffGate = nil
        else
            RestoreTapDebuffGate(plate, paint)
            if repaint and repaint == plate.unit and self.activeAdapter
                and type(self.activeAdapter.RestoreHealthColor) == "function" then
                self.activeAdapter:RestoreHealthColor(self, plate)
            end
        end
        return
    end
    if type(paint) == "function" then
        local saved = plate.__suiTapDebuffGate
        if nativePaint or not saved or saved.unit ~= plate.unit or saved.paint ~= paint then
            saved = saved or {}
            saved.unit, saved.paint = plate.unit, paint
            saved.health, saved.border, saved.name = plate._dcThreatH, plate._dcThreatB, plate._dcThreatN
            plate.__suiTapDebuffGate = saved
            -- EUI's own API gates the colour layers without changing aura data.
            paint(plate, 0, 0, 0)
        end
    end
    if plate._threatBdOn and type(plate.RepaintThreatBorder) == "function" then
        plate.__suiTapThreatRepaint = plate.unit
        plate._threatBdOn = nil
        plate._threatBdKr, plate._threatBdKg, plate._threatBdKb = nil, nil, nil
        plate:RepaintThreatBorder(plate.unit)
    end
    if plate._threatNameOn and plate.name then
        local profile = ns.db and ns.db.profile
        local color = profile and (profile.enemyNameTappedColor or profile.tapped)
            or ns.defaults and ns.defaults.tapped
        if color then
            plate.__suiTapThreatRepaint = plate.unit
            plate.name:SetTextColor(color.r, color.g, color.b, 1)
            plate._nameThR, plate._nameThG, plate._nameThB = nil, nil, nil
        end
    end
end

function M:AttachPlate(unit, forceRebind, skipAura)
    if not self.runtimeWanted then return false end
    local plate = self.GetAdapterPlate and self:GetAdapterPlate(unit)
    if not plate or not plate.health then return false end
    forceRebind = forceRebind or self.plates[unit] ~= plate
    self.pendingUnits[unit] = nil
    self.plates[unit] = plate
    if self.adapterKey == "ellesmere" and not plate.__suiTargetGlowHooked and type(plate.ApplyTarget) == "function" then
        plate.__suiTargetGlowHooked = true
        hooksecurefunc(plate, "ApplyTarget", function(target)
            if M.runtimeWanted then
                SUI:SafeModuleCall(M, "nameplate target accents", M.UpdateTargetAccents, target, target._isTarget == true)
            end
        end)
    end
    self:AttachPlateTextStyle(plate)
    self:BindHealthBarOwner(unit, plate)
    if not plate.__suiColorHooked and type(plate.UpdateHealthColor) == "function" then
        plate.__suiColorHooked = true
        hooksecurefunc(plate, "UpdateHealthColor", function(target)
            if not M.runtimeWanted then return end
            M:ApplyNativeTapPriority(target, true)
            if M.restoringThreatFill ~= target then M:UpdateThreat(target) end
            local rig = M:EnsureAuraBinding(target)
            if rig then M.AuraRules:RestackRig(rig) end
            M:UpdateSelectionVisuals(target)
            M:UpdateHoverOverlay(target)
        end)
    end
    self:ApplyNativeTapPriority(plate)
    self:UpdateThreat(plate)
    local auraAttached = true
    if self.auraRulesOn and self.AuraRules and not skipAura then
        auraAttached = self.AuraRules:AttachPlate(unit, plate, forceRebind) ~= false
    end
    self:UpdateSelectionVisuals(plate)
    self:UpdateHoverOverlay(plate)
    return auraAttached
end

-- EUI reuses the same pooled plate frame for different nameplate tokens and
-- can also exchange bars around target/focus changes. Health colour refreshes
-- are a cheap event-driven point to verify identity. Rebind only on a real
-- mismatch; the normal hot path is just table comparisons.
function M:EnsureAuraBinding(plate)
    if not self.runtimeWanted or not self.auraRulesOn or not plate or not plate.health or not self.AuraRules then return nil end
    local unit = plate.unit
    if not unit or not UnitExistsPlain(unit) or not self.activeUnits[unit] then
        return self.AuraRules.rigs[plate.health]
    end

    local published = self.GetAdapterPlate and self:GetAdapterPlate(unit)
    if published and published ~= plate then plate = published end
    if not plate or not plate.health then return nil end

    for mappedUnit, mappedPlate in pairs(self.plates) do
        if mappedUnit ~= unit and mappedPlate == plate then
            self.plates[mappedUnit] = nil
            self.AuraRules:DetachPlate(mappedUnit)
        end
    end

    local rig = self.AuraRules.rigs[plate.health]
    if self.plates[unit] ~= plate
        or not rig
        or self.AuraRules.units[unit] ~= rig
        or rig.unit ~= unit
        or rig.tapDenied ~= self:IsTapColorPriority(unit)
        or rig.nativePlate ~= plate.nameplate then
        self.plates[unit] = plate
        self:BindHealthBarOwner(unit, plate)
        if not self.AuraRules:AttachPlate(unit, plate, true) then
            self.pendingUnits[unit] = true
            self:EnsureRetryLoop(true)
        end
        rig = self.AuraRules.rigs[plate.health]
    end
    return rig
end

-- NAME_PLATE_UNIT_ADDED can run before EllesmereUI publishes its plate. Retry
-- briefly, then suspend until another relevant plate/target event. This keeps
-- busy pulls reliable without leaving a permanent ticker after an EUI API break.
function M:QueueAttach(unit)
    if not self.runtimeWanted or not unit then return end
    local newlyPending = not self.pendingUnits[unit]
    self.pendingUnits[unit] = true
    self:EnsureRetryLoop(newlyPending)
    SUI:After(0, self, "nameplate attach", function()
        if M.pendingUnits[unit] and UnitExistsPlain(unit) and not M:AttachPlate(unit, true) then
            M.pendingUnits[unit] = true
        end
    end)
end

function M:DetachPlate(unit)
    local plate = self.plates[unit]
    self.activeUnits[unit] = nil
    self.pendingUnits[unit] = nil
    self.plates[unit] = nil
    if plate and plate.__suiThreat then plate.__suiThreat:Hide() end
    if plate then self:RestoreThreatFill(plate) end
    if plate and plate.__suiTargetPattern then plate.__suiTargetPattern:Hide() end
    self:RestoreNativeSelectionGlow(plate)
    RestoreSelectionClipAlpha(plate)
    if plate then
        local ns = self.adapterState and self.adapterState.namespace
        RestoreTapDebuffGate(plate, ns and ns.DebuffColors_Threat)
        plate.__suiTapThreatRepaint = nil
        SUI:SafeModuleCall(self, "restore nameplate text", self.UpdatePlateTextStyle, plate, true)
    end
    if self.AuraRules then self.AuraRules:DetachPlate(unit, plate) end
end

function M:RefreshAll(structural)
    self:RefreshRuntimeFlags()
    if not self.runtimeWanted then self:Shutdown(); return end
    self.pendingShutdown = nil
    if not self.available or not self.activeAdapter then self:Reconnect(); return end
    self:ForEachAdapterPlate(function(unit)
        self.activeUnits[unit] = true
        if not self:AttachPlate(unit, false, structural) then self.pendingUnits[unit] = true end
    end)
    if structural then
        if self.AuraRules then self.AuraRules:RebuildAll() end
        self:RefreshBuffRows()
    end
    self:EnsureRetryLoop(structural == true)
end

function M:ResyncSwappedBars()
    if not self.runtimeWanted then return end
    if not self.available or not self.activeAdapter then return end
    local changed = false
    for unit in pairs(self.activeUnits) do
        if not UnitExistsPlain(unit) then
            self:DetachPlate(unit)
        else
            local plate = self.GetAdapterPlate and self:GetAdapterPlate(unit)
            local rig = self.AuraRules and self.AuraRules.units[unit]
            local profile = self.AuraRules and self.AuraRules:Profile()
            local rulesEnabled = profile and profile.enabled
            if not plate or not plate.health then
                self.pendingUnits[unit] = true
            elseif rulesEnabled and (self.plates[unit] ~= plate or not rig or rig.healthBar ~= plate.health) then
                -- Publish every new plate reference before rebinding any aura
                -- container; ReconcilePlates resolves swaps in a second pass.
                self.plates[unit] = plate
                self.pendingUnits[unit] = nil
                self:BindHealthBarOwner(unit, plate)
                changed = true
            elseif not self.plates[unit] then
                self:AttachPlate(unit, true)
            end
        end
    end
    if changed and self.AuraRules then self.AuraRules:ReconcilePlates(true) end
    self:EnsureRetryLoop()
end

function M:RetryPending()
    for unit in pairs(self.pendingUnits) do
        if not self.activeUnits[unit] or not UnitExistsPlain(unit) then
            self.pendingUnits[unit] = nil
        else
            if not self:AttachPlate(unit, true) then self.pendingUnits[unit] = true end
        end
    end
    if not self:HasPendingUnits() then self:StopRetryLoop() end
end

function M:HasPendingUnits()
    return next(self.pendingUnits) ~= nil
end

function M:StopRetryLoop(suspended)
    if self.retryTicker then self.retryTicker:Cancel(); self.retryTicker = nil end
    self.retrySuspended = suspended == true
    if not suspended then self.retryStartedAt = nil end
end

function M:EnsureRetryLoop(force)
    if not self.runtimeWanted then self:StopRetryLoop(); return end
    if not self:HasPendingUnits() then self:StopRetryLoop(); return end
    if force then self.retrySuspended = nil; self.retryStartedAt = nil end
    if self.retrySuspended then return end
    if self.retryTicker then return end
    self.retryStartedAt = self.retryStartedAt or (GetTime and GetTime() or 0)
    self.retryTicker = C_Timer.NewTicker(.5, function()
        local ok = SUI:SafeModuleCall(M, "nameplate retry", function()
            M:RetryPending()
            if not M:HasPendingUnits() then return end
            local now = GetTime and GetTime() or 0
            if now - (M.retryStartedAt or now) >= 12 then
                M:StopRetryLoop(true)
                return
            end
            M:ResyncSwappedBars()
        end)
        if not ok then M:StopRetryLoop(true) end
    end)
end

function M:PrintStatus()
    local active, attached, pending, rigs, missing, mismatched = 0, 0, 0, 0, 0, 0
    for _ in pairs(self.activeUnits) do active = active + 1 end
    for _ in pairs(self.plates) do attached = attached + 1 end
    for _ in pairs(self.pendingUnits) do pending = pending + 1 end
    if self.AuraRules then for _ in pairs(self.AuraRules.rigs) do rigs = rigs + 1 end end
    if self.AuraRules then
        for unit in pairs(self.activeUnits) do
            local plate = self.plates[unit]
            local rig = plate and plate.health and self.AuraRules.rigs[plate.health]
            if not rig then missing = missing + 1
            elseif rig.unit ~= unit or self.AuraRules.units[unit] ~= rig then mismatched = mismatched + 1 end
        end
    end
    SUI:Print(Text("Адаптер неймплейтов: %s (%s)", "Nameplate adapter: %s (%s)"):format(
        self.adapterName or Text("нет", "none"), self.adapterKey or "—"))
    SUI:Print(Text("Неймплейты: активных %d, подключено %d, ожидает %d. Оформление аур: %d, отсутствует %d, расхождений %d",
        "Nameplates: active %d, attached %d, pending %d. Aura overlays: %d, missing %d, mismatched %d"):format(
        active, attached, pending, rigs, missing, mismatched))
    if self.AuraRules and self.AuraRules.GetDiagnostics then
        local data = self.AuraRules:GetDiagnostics()
        local mode = data.slotApiPresent == true and Text("слоты аур", "aura slots")
            or (data.slotApiPresent == false and Text("группы аур", "aura groups") or Text("нет данных", "unknown"))
        SUI:Print(Text("Ауры: %s, правил %d, контейнеров %d (слоты %d / группы %d), текстур %d, окон обновления %d, сбоев %d",
            "Auras: %s, rules %d, containers %d (slots %d / groups %d), textures %d, refresh windows %d, failures %d"):format(
            mode, data.rules, data.containers, data.slots, data.groups,
            data.visuals, data.pandemics, data.failures))
        SUI:Print(Text("Слои аур: попыток создания %d, ошибок %d%s", "Aura overlays: build attempts %d, failures %d%s"):format(
            data.buildAttempts, data.buildFailures,
            data.lastBuildError and (" • " .. data.lastBuildError) or ""))
        SUI:Print(Text("Восстановление слоев: выполнено %d, подозрительных %d, блокировок %d, лимит %d",
            "Overlay repairs: completed %d, suspect %d, blocked %d, limit %d"):format(
            data.rigRepairs, data.suspectRigs, data.combatBlocked, data.repairCap))
        if data.rigs > 0 then
            local function Project(value) return math.floor(((value or 0) / data.rigs) * 40 + .5) end
            SUI:Print(Text("Оценка на 40 неймплейтов: контейнеров %d, текстур %d, окон обновления %d",
                "Estimate for 40 nameplates: containers %d, textures %d, refresh windows %d"):format(
                Project(data.containers), Project(data.visuals), Project(data.pandemics)))
        end
    end
    if self.AuraCatalog and self.AuraCatalog.GetLearnedCounts then
        local total, available = self.AuraCatalog:GetLearnedCounts()
        SUI:Print(Text("Запомненные дебаффы: %d для этого класса, %d всего, +%d за сеанс",
            "Remembered debuffs: %d for this class, %d total, +%d this session"):format(
            available, total, self.learnedThisSession or 0))
    end
    if UnitExistsPlain("target") then
        local nativePlate = C_NamePlate and C_NamePlate.GetNamePlateForUnit
            and C_NamePlate.GetNamePlateForUnit("target")
        local activePlate
        for unit, plate in pairs(self.plates) do
            local same, readable = SafePlainCall(UnitIsUnit, unit, "target")
            if readable and same then activePlate = plate break end
        end
        local health = activePlate and activePlate.health
        local rig = health and self.AuraRules and self.AuraRules.rigs[health]
        local shown, total = 0, 0
        for _, record in ipairs(rig and rig.rules or {}) do
            for _, visual in ipairs(record.visuals or {}) do
                local texture = visual.texture
                if texture then
                    total = total + 1
                    local visible, readable = SafePlainCall(texture.IsShown, texture)
                    if readable and visible == true then shown = shown + 1 end
                end
            end
        end
        local healthLevel = health and SafePlainCall(health.GetFrameLevel, health) or nil
        local topLevel = health and self.AuraRules and self.AuraRules:TopVisualLevel(health) or nil
        SUI:Print(Text("Цель: неймплейт %s, полоса здоровья %s, слой аур %s",
            "Target: nameplate %s, health bar %s, aura overlay %s"):format(
            tostring(nativePlate), tostring(health), tostring(rig)))
        SUI:Print(Text("Слои цели: здоровье %s, верхний слой SUI %s, видимых текстур %d/%d, создан в бою %s, восстановлений %s",
            "Target layers: health %s, top SUI layer %s, visible textures %d/%d, built in combat %s, repairs %s"):format(
            tostring(healthLevel), tostring(topLevel), shown, total,
            tostring(rig and rig.builtInCombat == true), tostring(rig and rig.repairs or 0)))
    end
end

function M:RegisterEvents()
    if self.eventsRegistered then return end
    self.eventsRegistered = true
    SUI:RegisterModuleEvent(self, "NAME_PLATE_UNIT_ADDED")
    SUI:RegisterModuleEvent(self, "NAME_PLATE_UNIT_REMOVED")
    SUI:RegisterModuleEvent(self, "PLAYER_ENTERING_WORLD")
    SUI:RegisterModuleEvent(self, "ZONE_CHANGED_NEW_AREA")
    SUI:RegisterModuleEvent(self, "PLAYER_REGEN_ENABLED")
    SUI:RegisterModuleEvent(self, "PLAYER_TARGET_CHANGED")
    SUI:RegisterModuleEvent(self, "PLAYER_FOCUS_CHANGED")
    SUI:RegisterModuleEvent(self, "UNIT_FLAGS")
    SUI:RegisterModuleEvent(self, "UNIT_AURA")
    SUI:RegisterModuleEvent(self, "SPELLS_CHANGED")
    SUI:RegisterModuleEvent(self, "PLAYER_SPECIALIZATION_CHANGED")
    SUI:RegisterModuleEvent(self, "TRAIT_CONFIG_UPDATED")
    if SUI.isForever then SUI:RegisterModuleEvent(self, "CHARACTER_POINTS_CHANGED") end
end

function M:Reconnect()
    if not self.runtimeWanted then return false end
    if not self.ConnectNameplateAdapter then
        self.available = false
        return false
    end
    local connected, _, hooksOK = self:ConnectNameplateAdapter()
    if not connected then return false end
    if self:AdapterSupports("targetTexture") then self:RegisterTargetTexture() end
    if self.AuraRules then self.AuraRules:Initialize() end
    SUI:After(0, self, "nameplate adapter reconnect refresh", function() M:RefreshAll(true) end)
    return hooksOK
end

function M:Initialize()
    self:RefreshRuntimeFlags()
    self:RegisterEvents()
    if self.runtimeWanted then
        self:Reconnect()
        self:QueueLearnedDebuffScan("target")
        self:QueueLearnedDebuffScan("focus")
    end
end

function M:OnProfileChanged()
    self:RefreshAll(true)
end

function M:OnEvent(event, unit)
    if event == "PLAYER_REGEN_ENABLED" and self.pendingBuffRows then self:RefreshBuffRows() end
    if not self.runtimeWanted then
        if event == "PLAYER_REGEN_ENABLED" then self:Shutdown() end
        return
    end
    if not self.available and (event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA") then
        self:Reconnect()
    end
    if event == "NAME_PLATE_UNIT_ADDED" then
        self.activeUnits[unit] = true
        self:QueueLearnedDebuffScan(unit)
        if not self:AttachPlate(unit, true) then self:QueueAttach(unit) end
    elseif event == "NAME_PLATE_UNIT_REMOVED" then self:DetachPlate(unit)
    elseif event == "UNIT_AURA" then
        if self.AuraRules and not IsSecret(unit) and type(unit) == "string" then
            self.AuraRules:QueueTextAuraRefresh(unit)
        end
        self:QueueLearnedDebuffScan(unit)
    elseif event == "PLAYER_TARGET_CHANGED" or event == "PLAYER_FOCUS_CHANGED" then
        self:QueueLearnedDebuffScan(event == "PLAYER_TARGET_CHANGED" and "target" or "focus")
        self:ResyncSwappedBars()
        if self.AuraRules then self.AuraRules:RefreshAll(false) end
        for _, plate in pairs(self.plates) do
            self:UpdateThreat(plate)
            self:UpdateSelectionVisuals(plate)
            self:UpdateHoverOverlay(plate)
        end
        self:EnsureRetryLoop(true)
        -- EUI's target overlay/bar exchange can finish later in the same
        -- event dispatch.  One next-frame reconciliation observes the final
        -- ownership map without polling or a permanent OnUpdate.
        SUI:After(0, self, "target ownership refresh", function()
            M:ResyncSwappedBars()
            if M.AuraRules then M.AuraRules:RefreshAll(false) end
            M:RefreshSelectionVisuals()
        end)
    elseif event == "UNIT_FLAGS" then
        -- Tap ownership can change while the plate is already visible. Rebind
        -- aura containers immediately so EUI's grey tapped colour is revealed.
        if unit and self.activeUnits[unit] then self:AttachPlate(unit, true) end
    elseif event == "SPELLS_CHANGED" or event == "PLAYER_SPECIALIZATION_CHANGED" or event == "TRAIT_CONFIG_UPDATED"
        or event == "CHARACTER_POINTS_CHANGED" then
        self:RefreshFeatureDemand()
        if self.AuraCatalog then self.AuraCatalog:Invalidate() end
        if self.AuraRules then self.AuraRules:RebuildAll() end
        if SUI.SettingsUI then SUI.SettingsUI:Refresh() end
    elseif event == "PLAYER_REGEN_ENABLED" then
        if self.AuraRules then
            if self.AuraRules.pendingRebuild then self.AuraRules:RebuildAll() end
            if self.AuraRules.RecoverAfterCombat then self.AuraRules:RecoverAfterCombat() end
        end
        self:RetryPending()
        self:ResyncSwappedBars()
    else self:RefreshAll(false) end
end
