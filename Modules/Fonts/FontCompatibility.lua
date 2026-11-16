local _, SUI = ...

local M = { sessionRegistered = {}, borderGeometryBeforeEUI = {} }
SUI:RegisterModule("fontCompatibility", M)

local EUI_GLOW_KEY = "SUI EUI Glow"
local EUI_GLOW_PATH = "Interface\\AddOns\\EllesmereUI\\media\\borders\\glow-border"
local SUI_SOFT_GLOW_KEY = "SUI Soft Rounded Glow"
local SUI_SOFT_GLOW_PATH = "Interface\\AddOns\\Sintezza_UI\\Media\\Borders\\sui-rounded-unit-glow.png"
M.SoftRoundedBorderKey = SUI_SOFT_GLOW_KEY
M.ThinRoundedBorderKey = "SUI EUI Rounded Thin"
local aggroGlows = setmetatable({}, { __mode = "k" })
local aggroEdges = { "topLine", "bottomLine", "leftLine", "rightLine" }

local function IsOutsideGlow(preset)
    return preset == EUI_GLOW_KEY or preset == SUI_SOFT_GLOW_KEY
end

local function HasThinBorder(frame)
    return M.IsThinDandersBorderActive and M:IsThinDandersBorderActive(frame)
end

local function PublicNumber(value)
    return type(value) == "number" and not (issecretvalue and issecretvalue(value))
end

local function PublicUnit(unit)
    return type(unit) == "string" and not (issecretvalue and issecretvalue(unit))
end

local function UnitOutOfCombat(frame)
    local unit = frame.unit
    if frame.dfIsTestFrame or not UnitAffectingCombat or not PublicUnit(unit) then return false end
    local ok, combat = pcall(UnitAffectingCombat, unit)
    return ok and not (issecretvalue and issecretvalue(combat)) and combat == false
end

local function SyncAggroVisibility(frame, highlight, state)
    local shown = frame.dfAggroHighlight == highlight and highlight:IsShown()
    state.frame = shown and frame or nil
    if (highlight.IsForbidden and highlight:IsForbidden())
        or (highlight.IsProtected and highlight:IsProtected()) then return shown end
    if shown and UnitOutOfCombat(frame) then
        local alpha = highlight:GetAlpha()
        if PublicNumber(alpha) and alpha > 0 then
            state.combatAlpha = alpha
            highlight:SetAlpha(0)
        end
    elseif state.combatAlpha ~= nil then
        highlight:SetAlpha(state.combatAlpha)
        state.combatAlpha = nil
    end
    return shown
end

local function AddAggroStrip(glow, strips, side, near, far, brightAtFar)
    local texture = glow:CreateTexture(nil, "ARTWORK")
    texture:SetColorTexture(1, 1, 1, 1)
    if side == "TOP" then
        texture:SetPoint("BOTTOMLEFT", glow, "TOPLEFT", 0, near)
        texture:SetPoint("TOPRIGHT", glow, "TOPRIGHT", 0, far)
    elseif side == "BOTTOM" then
        texture:SetPoint("TOPLEFT", glow, "BOTTOMLEFT", 0, -near)
        texture:SetPoint("BOTTOMRIGHT", glow, "BOTTOMRIGHT", 0, -far)
    elseif side == "LEFT" then
        texture:SetPoint("TOPRIGHT", glow, "TOPLEFT", -near, 0)
        texture:SetPoint("BOTTOMLEFT", glow, "BOTTOMLEFT", -far, 0)
    else
        texture:SetPoint("TOPLEFT", glow, "TOPRIGHT", near, 0)
        texture:SetPoint("BOTTOMRIGHT", glow, "BOTTOMRIGHT", far, 0)
    end
    local direction = (side == "TOP" or side == "BOTTOM") and "VERTICAL" or "HORIZONTAL"
    local farAtHigh = side == "TOP" or side == "RIGHT"
    strips[#strips + 1] = { texture = texture, direction = direction, brightAtHigh = brightAtFar == farAtHigh }
end

local AGGRO_CORNERS = "Interface\\AddOns\\Sintezza_UI\\Media\\Borders\\sui-aggro-corners.png"

local function BuildRoundedAggroOutline(highlight)
    local layer = CreateFrame("Frame", nil, highlight)
    layer:EnableMouse(false)
    local parts = {}
    for i, anchor in ipairs({ "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT" }) do
        local texture = layer:CreateTexture(nil, "OVERLAY")
        texture:SetTexture(AGGRO_CORNERS, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE", "LINEAR")
        if texture.SetSnapToPixelGrid then texture:SetSnapToPixelGrid(false) end
        if texture.SetTexelSnappingBias then texture:SetTexelSnappingBias(0) end
        texture:SetPoint(anchor, layer, anchor)
        parts[i] = texture
    end
    for i = 5, 8 do
        local texture = layer:CreateTexture(nil, "OVERLAY")
        texture:SetTexture("Interface\\Buttons\\WHITE8x8")
        if texture.SetSnapToPixelGrid then texture:SetSnapToPixelGrid(false) end
        if texture.SetTexelSnappingBias then texture:SetTexelSnappingBias(0) end
        parts[i] = texture
    end
    parts[5]:SetPoint("TOPLEFT", parts[1], "TOPRIGHT")
    parts[5]:SetPoint("TOPRIGHT", parts[2], "TOPLEFT")
    parts[6]:SetPoint("BOTTOMLEFT", parts[3], "BOTTOMRIGHT")
    parts[6]:SetPoint("BOTTOMRIGHT", parts[4], "BOTTOMLEFT")
    parts[7]:SetPoint("TOPLEFT", parts[1], "BOTTOMLEFT")
    parts[7]:SetPoint("BOTTOMLEFT", parts[3], "TOPLEFT")
    parts[8]:SetPoint("TOPRIGHT", parts[2], "BOTTOMRIGHT")
    parts[8]:SetPoint("BOTTOMRIGHT", parts[4], "TOPRIGHT")
    return layer, parts
end

local function FitAggroCorners(parts, radius, pixel)
    -- Each 64x64 atlas cell contains one 60x60 quarter-ring and a two-texel
    -- gutter on every side so linear filtering cannot sample its neighbours.
    local cell = radius - 4
    local x, y = (cell % 8) * 64, math.floor(cell / 8) * 64
    local u, v, right, bottom = (x + 2) / 512, (y + 2) / 256, (x + 62) / 512, (y + 62) / 256
    parts[1]:SetTexCoord(u, right, v, bottom)
    parts[2]:SetTexCoord(right, u, v, bottom)
    parts[3]:SetTexCoord(u, right, bottom, v)
    parts[4]:SetTexCoord(right, u, bottom, v)
    for i = 1, 4 do parts[i]:SetSize(radius * pixel, radius * pixel) end
    parts[5]:SetHeight(3 * pixel)
    parts[6]:SetHeight(3 * pixel)
    parts[7]:SetWidth(3 * pixel)
    parts[8]:SetWidth(3 * pixel)
end

local function ShowRoundedAggroOutline(state, frame, highlight, eui, shapeRadius, r, g, b, a)
    local layer = state.rounded
    if not layer then
        layer, state.roundedParts = BuildRoundedAggroOutline(highlight)
        state.rounded = layer
    end
    local pixel = eui.PP and eui.PP.perfect
    local scale = highlight:GetEffectiveScale()
    local frameScale = frame:GetEffectiveScale()
    local usableScale = PublicNumber(scale) and scale > 0
    local pixelUnit = PublicNumber(pixel) and pixel > 0 and usableScale and pixel / scale or .5
    local gap = 2 * pixelUnit
    local baseRadius = PublicNumber(frameScale) and frameScale > 0 and usableScale and shapeRadius * frameScale / scale or shapeRadius
    local maxRadius = 32
    local w, h = frame:GetSize()
    if PublicNumber(w) and PublicNumber(h) and PublicNumber(frameScale) and frameScale > 0 and usableScale then
        maxRadius = math.min(maxRadius, math.floor((math.min(w, h) * frameScale / scale / 2 + gap) / pixelUnit))
    end
    local radius = math.max(4, math.min(maxRadius, math.floor((baseRadius + gap) / pixelUnit + .5)))
    local gapChanged = state.roundedGap ~= gap
    if gapChanged then
        layer:ClearAllPoints()
        layer:SetPoint("TOPLEFT", frame, "TOPLEFT", -gap, gap)
        layer:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", gap, -gap)
        state.roundedGap = gap
    end
    local level = highlight:GetFrameLevel() + 1
    if layer:GetFrameLevel() ~= level then layer:SetFrameLevel(level) end
    if gapChanged or state.roundedRadius ~= radius then
        FitAggroCorners(state.roundedParts, radius, pixelUnit)
        state.roundedRadius = radius
    end
    if state.roundedR ~= r or state.roundedG ~= g or state.roundedB ~= b or state.roundedA ~= a then
        for _, part in ipairs(state.roundedParts) do part:SetVertexColor(r, g, b, a) end
    end
    state.roundedR, state.roundedG, state.roundedB, state.roundedA = r, g, b, a
    layer:Show()
end

local function ShowStripAggroGlow(state, highlight, r, g, b, a)
    if not state.glow then
        local glow = CreateFrame("Frame", nil, highlight)
        glow:SetAllPoints(highlight)
        glow:EnableMouse(false)
        state.glow, state.strips = glow, {}
        for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
            AddAggroStrip(glow, state.strips, side, 2, 4, true)
            AddAggroStrip(glow, state.strips, side, 4, 9, false)
        end
    end
    if state.r ~= r or state.g ~= g or state.b ~= b or state.a ~= a then
        local clear, bright = CreateColor(r, g, b, 0), CreateColor(r, g, b, a)
        for _, strip in ipairs(state.strips) do
            if strip.brightAtHigh then
                strip.texture:SetGradient(strip.direction, clear, bright)
            else
                strip.texture:SetGradient(strip.direction, bright, clear)
            end
        end
        state.r, state.g, state.b, state.a = r, g, b, a
    end
    local glow = state.glow
    local level = highlight:GetFrameLevel() + 1
    if glow:GetFrameLevel() ~= level then glow:SetFrameLevel(level) end
    glow:Show()
end

function M:SyncDandersAggroGlow(frame)
    local highlight = frame.dfAggroHighlight
    if not highlight then return end
    local state = aggroGlows[highlight]
    if not state then
        if not highlight:IsShown() then return end
        state = {}
        aggroGlows[highlight] = state
    end
    local shown = SyncAggroVisibility(frame, highlight, state)
    local thin = HasThinBorder(frame)
    local eui = _G.EllesmereUI
    local shapeRadius = self:GetDandersShapeRadius(frame)
    local rounded = thin and shapeRadius > 0 and eui and eui.PP
    local border = frame.border
    local r, g, b, a = highlight._hlR, highlight._hlG, highlight._hlB, highlight._hlA
    if not ((rounded or (self:GetFrameShapeMode() ~= "SQUARE" and border and IsOutsideGlow(border.activeTexture))) and shown and highlight._hlMode == "SOLID"
        and (rounded or type(CreateColor) == "function")
        and PublicNumber(r) and PublicNumber(g) and PublicNumber(b) and PublicNumber(a)) then
        if state.lineAlphas then
            for line, alpha in pairs(state.lineAlphas) do line:SetAlpha(alpha) end
            state.lineAlphas = nil
            if state.glow then state.glow:Hide() end
            if state.rounded then state.rounded:Hide() end
        end
        return
    end

    if rounded then
        if state.glow then state.glow:Hide() end
        ShowRoundedAggroOutline(state, frame, highlight, eui, shapeRadius, r, g, b, a * .55)
    else
        if state.rounded then state.rounded:Hide() end
        ShowStripAggroGlow(state, highlight, r, g, b, a * .45)
    end

    -- Keep the native highlight's shown state and restore its edges if the
    -- user switches to a different border or aggro style.
    state.lineAlphas = state.lineAlphas or {}
    for _, key in ipairs(aggroEdges) do
        local line = highlight[key]
        if line then
            local alpha = line:GetAlpha()
            if state.lineAlphas[line] == nil or alpha ~= 0 then state.lineAlphas[line] = alpha end
            if alpha ~= 0 then line:SetAlpha(0) end
        end
    end
end

function M:RefreshDandersAggroVisibility(unit)
    for highlight, state in pairs(aggroGlows) do
        local frame = state.frame
        if frame and (not unit or (PublicUnit(frame.unit) and frame.unit == unit)) then
            SyncAggroVisibility(frame, highlight, state)
        end
    end
end

function M:InstallDandersAggroGlow()
    if not SUI:IntegrationEnabled("danders") then return end
    local danders = self:GetDanders()
    if not (danders and type(danders.UpdateHighlights) == "function" and hooksecurefunc)
        or self.aggroGlowOwner == danders then return end
    self.aggroGlowOwner = danders
    local function Sync(_, frame)
        if frame and frame.dfAggroHighlight then
            SUI:SafeModuleCall(self, "DandersFrames aggro glow", self.SyncDandersAggroGlow, frame)
        end
    end
    hooksecurefunc(danders, "UpdateHighlights", Sync)
    if type(danders.ApplyFrameBorder) == "function" then hooksecurefunc(danders, "ApplyFrameBorder", Sync) end
    SUI:RegisterModuleEvent(self, "PLAYER_REGEN_DISABLED")
    SUI:RegisterModuleEvent(self, "UNIT_FLAGS")
end

M.BorderPresets = {
    { value = "SOLID", title = SUI.Text("Сплошная", "Solid"), kind = "solid" },
    { value = M.ThinRoundedBorderKey, title = SUI.Text("Тонкая черная EUI", "Thin black EUI"), kind = "solid", roundedThin = true },
    { value = "GRADIENT", title = SUI.Text("Градиент", "Gradient"), kind = "gradient" },
    { value = SUI_SOFT_GLOW_KEY, title = SUI.Text("Скругление SUI", "SUI rounded"), kind = "texture" },
    { value = EUI_GLOW_KEY, title = SUI.Text("Свечение EUI", "EUI glow"), kind = "texture", requiresEUI = true },
    { value = "DF Glow", title = SUI.Text("Свечение Danders", "Danders glow"), kind = "texture" },
    { value = "DF Bevel", title = SUI.Text("Фаска", "Bevel"), kind = "texture" },
    { value = "DF Inset", title = SUI.Text("Внутренняя", "Inset"), kind = "texture" },
    { value = "DF Double", title = SUI.Text("Двойная", "Double"), kind = "texture" },
}

function M:Profile() return SUI:GetModuleProfile("fontCompatibility") end

function M:GetLSM()
    return LibStub and LibStub("LibSharedMedia-3.0", true) or nil
end

function M:GetDanders()
    local danders = _G.DandersFrames
    return type(danders) == "table" and danders or nil
end

function M:HasEUI()
    if type(_G.EllesmereUI) == "table" then return true end
    if C_AddOns and C_AddOns.IsAddOnLoaded then return C_AddOns.IsAddOnLoaded("EllesmereUI") == true end
    return IsAddOnLoaded and IsAddOnLoaded("EllesmereUI") == true
end

function M:CanDrawThinRoundedBorder()
    local eui = _G.EllesmereUI
    return eui and type(eui.RoundCorners) == "function" and type(eui.ApplyBorderStyle) == "function"
        and eui.PP and type(eui.PP.GetBorders) == "function"
end

function M:RegisterBorderMedia()
    local lsm = self:GetLSM()
    if not lsm or type(lsm.Register) ~= "function" then return false end
    -- Danders stores the preset as a border texture. White8x8 is its
    -- plain square fallback until the live EUI renderer draws the contour.
    if self:CanDrawThinRoundedBorder() then
        lsm:Register("border", self.ThinRoundedBorderKey, "Interface\\Buttons\\WHITE8x8")
    end
    if not self:Profile().borderMedia then return false end
    local registered = lsm:Register("border", SUI_SOFT_GLOW_KEY, SUI_SOFT_GLOW_PATH) ~= false
    if self:HasEUI() then
        registered = lsm:Register("border", EUI_GLOW_KEY, EUI_GLOW_PATH) ~= false or registered
    end
    if registered then self.borderMediaRegistered = true end
    return registered
end

-- DandersFrames treats every translucent border's configured edge size as
-- occupied INSIDE the unit frame and shrinks absorb/heal-absorb overlays by
-- that amount.  EUI Glow is centered on and mostly outside the edge, so its
-- 16px render size must not reserve 16px of health-bar content.  Wrap the one
-- native geometry resolver instead of fighting both bar implementations.
function M:InstallAbsorbInsetCompatibility()
    local danders = self:GetDanders()
    if not danders or type(danders.GetAbsorbEdgeInset) ~= "function" then return false end
    if self.absorbInsetOwner == danders and danders.GetAbsorbEdgeInset == self.absorbInsetWrapper then return true end

    local original = danders.GetAbsorbEdgeInset
    local wrapper = function(owner, frame, db)
        if M:Profile().absorbInset and type(db) == "table" and db.frameBorderStyle == "TEXTURE"
            and IsOutsideGlow(db.frameBorderTexture) then
            return 0
        end
        return original(owner, frame, db)
    end
    self.absorbInsetOwner = danders
    self.originalGetAbsorbEdgeInset = original
    self.absorbInsetWrapper = wrapper
    danders.GetAbsorbEdgeInset = wrapper
    return true
end

function M:RefreshAbsorbInsetCompatibility()
    if InCombatLockdown and InCombatLockdown() then self.pendingAbsorbInset = true; return end
    self.pendingAbsorbInset = nil
    if self:Profile().absorbInset then
        self:InstallAbsorbInsetCompatibility()
    else
        local danders = self.absorbInsetOwner
        if danders and danders.GetAbsorbEdgeInset == self.absorbInsetWrapper then
            danders.GetAbsorbEdgeInset = self.originalGetAbsorbEdgeInset
        end
        self.absorbInsetOwner, self.absorbInsetWrapper, self.originalGetAbsorbEdgeInset = nil, nil, nil
    end
end

function M:GetBorderDB(mode)
    local danders = self:GetDanders()
    if not danders then return nil end
    mode = mode == "raid" and "raid" or "party"
    if type(danders.GetDB) == "function" then
        local ok, db = pcall(danders.GetDB, danders, mode)
        if ok and type(db) == "table" then return db end
    end
    return type(danders.db) == "table" and danders.db[mode] or nil
end

function M:BorderChoices()
    local danders, result = self:GetDanders(), {}
    for _, preset in ipairs(self.BorderPresets) do
        if (not preset.requiresEUI or self:HasEUI())
            and (not preset.roundedThin or self:CanDrawThinRoundedBorder()) then
            local entry = { value = preset.value, title = preset.title, kind = preset.kind }
            if preset.kind == "texture" and danders and type(danders.GetBorderTexturePath) == "function" then
                local ok, path = pcall(danders.GetBorderTexturePath, danders, preset.value)
                if ok then entry.texture = path; entry.kind = "border" end
            end
            result[#result + 1] = entry
        end
    end
    local existing = {}
    for _, entry in ipairs(result) do existing[entry.value] = true end
    local other = self:AvailableBorderOptions()
    local keys = {}
    for value in pairs(other) do
        if not existing[value] and value ~= self.ThinRoundedBorderKey then keys[#keys + 1] = value end
    end
    table.sort(keys, function(a, b) return tostring(other[a]):lower() < tostring(other[b]):lower() end)
    for _, value in ipairs(keys) do
        local path
        if danders and type(danders.GetBorderTexturePath) == "function" then
            local ok, resolved = pcall(danders.GetBorderTexturePath, danders, value)
            if ok then path = resolved end
        end
        result[#result + 1] = { value = value, title = other[value], kind = "border", texture = path }
    end
    return result
end

function M:AvailableBorderOptions()
    local danders = self:GetDanders()
    if not danders or type(danders.GetBorderList) ~= "function" then return {} end
    local ok, list = pcall(danders.GetBorderList, danders)
    return ok and type(list) == "table" and list or {}
end

function M:GetBorderPreset(mode)
    local db = self:GetBorderDB(mode)
    if not db then return nil end
    local style = db.frameBorderStyle or "SOLID"
    if style == "TEXTURE" then return db.frameBorderTexture or "SOLID" end
    return style
end

local function ApplyFrame(danders, db, frame)
    if not frame or not frame.border or type(danders.ApplyFrameBorder) ~= "function" then return end
    local ok, err = pcall(danders.ApplyFrameBorder, danders, frame, db)
    if not ok and SUI.Diagnostics then
        SUI.Diagnostics:RecordError("fontCompatibility", "DandersFrames border", err)
    end
    -- Border size participates in DandersFrames' absorb layout cache.  Refresh
    -- the two overlays immediately so changing to/from EUI Glow cannot leave
    -- stale 16px insets until the next shield event.
    frame.dfAbsorbState = nil
    if type(danders.UpdateAbsorb) == "function" then pcall(danders.UpdateAbsorb, danders, frame) end
    if type(danders.UpdateHealAbsorb) == "function" then pcall(danders.UpdateHealAbsorb, danders, frame) end
end

function M:RefreshBorder(mode)
    mode = mode == "raid" and "raid" or "party"
    self.pendingBorders = self.pendingBorders or {}
    if InCombatLockdown and InCombatLockdown() then
        self.pendingBorders[mode] = true
        return false
    end

    local danders, db = self:GetDanders(), self:GetBorderDB(mode)
    if not danders or not db then return false end
    self:InstallDandersAggroGlow()
    local apply = function(frame) ApplyFrame(danders, db, frame) end
    if mode == "raid" then
        if type(danders.IterateRaidFrames) == "function" then pcall(danders.IterateRaidFrames, danders, apply) end
        for _, frame in pairs(danders.testRaidFrames or {}) do apply(frame) end
    else
        if type(danders.IteratePartyFrames) == "function" then pcall(danders.IteratePartyFrames, danders, apply) end
        if type(danders.IterateArenaFrames) == "function" then pcall(danders.IterateArenaFrames, danders, apply) end
        for _, frame in pairs(danders.testPartyFrames or {}) do apply(frame) end
    end
    self.pendingBorders[mode] = nil
    return true
end

function M:SetBorderValue(mode, key, value)
    local db = self:GetBorderDB(mode)
    if not db then return false end
    db[key] = value
    self:RefreshBorder(mode)
    return true
end

function M:SetBorderColorValue(mode, key, value)
    value = type(value) == "table" and value or { 0, 0, 0, 1 }
    return self:SetBorderValue(mode, key, {
        r = value.r or value[1] or 0,
        g = value.g or value[2] or 0,
        b = value.b or value[3] or 0,
        a = value.a or value[4] or 1,
    })
end

function M:SetBorderColor(mode, value)
    return self:SetBorderColorValue(mode, "frameBorderColor", value)
end

function M:SetBorderPreset(mode, preset)
    local db = self:GetBorderDB(mode)
    if not db then return false end
    if preset == self.ThinRoundedBorderKey and not self:CanDrawThinRoundedBorder() then return false end
    mode = mode == "raid" and "raid" or "party"
    local previousPreset = self:GetBorderPreset(mode)
    if IsOutsideGlow(preset) and not IsOutsideGlow(previousPreset) then
        self.borderGeometryBeforeEUI[mode] = {
            size = tonumber(db.frameBorderSize) or 1,
            inset = tonumber(db.frameBorderInset) or 0,
        }
    elseif IsOutsideGlow(previousPreset) and not IsOutsideGlow(preset) then
        local previous = self.borderGeometryBeforeEUI[mode]
        db.frameBorderSize = previous and previous.size or 1
        db.frameBorderInset = previous and previous.inset or 0
        self.borderGeometryBeforeEUI[mode] = nil
    end
    if preset == "SOLID" or preset == "GRADIENT" then
        db.frameBorderStyle = preset
    else
        db.frameBorderStyle = "TEXTURE"
        db.frameBorderTexture = preset
        -- EllesmereUI's normal textured glow is a 16px edge expanded by half
        -- its size.  Reproduce that pair exactly; DF Glow is a different,
        -- inward-biased asset and remains available under its explicit name.
        if IsOutsideGlow(preset) then
            db.frameBorderSize = 16
            db.frameBorderInset = -8
        elseif preset == self.ThinRoundedBorderKey then
            db.frameBorderSize = 1
            db.frameBorderInset = 0
            db.frameBorderColor = { r = 0, g = 0, b = 0, a = 1 }
            db.frameBorderColorSource = "STATIC"
            db.frameBorderUseClassColor = false
            db.frameBorderUseRoleColor = false
        elseif preset == "DF Glow" and (tonumber(db.frameBorderInset) or 0) >= 0 then
            db.frameBorderInset = -math.max(1, math.floor(((tonumber(db.frameBorderSize) or 1) / 2) + .5))
        end
    end
    self:RefreshBorder(mode)
    return true
end

function M:GetBorderOutset(mode)
    local db = self:GetBorderDB(mode)
    return db and math.max(0, -(tonumber(db.frameBorderInset) or 0)) or 0
end

function M:SetBorderOutset(mode, value)
    return self:SetBorderValue(mode, "frameBorderInset", -math.max(0, tonumber(value) or 0))
end

function M:SetBorderSize(mode, value)
    local db = self:GetBorderDB(mode)
    if not db then return false end
    local oldSize = tonumber(db.frameBorderSize) or 1
    local oldInset = tonumber(db.frameBorderInset) or 0
    local followsGlowEdge = db.frameBorderStyle == "TEXTURE"
        and (db.frameBorderTexture == "DF Glow" or IsOutsideGlow(db.frameBorderTexture))
        and (oldInset == 0 or oldInset == -math.max(1, math.floor((oldSize / 2) + .5)))
    db.frameBorderSize = value
    if followsGlowEdge then
        db.frameBorderInset = -math.max(1, math.floor(((tonumber(value) or 1) / 2) + .5))
    end
    self:RefreshBorder(mode)
    return true
end

function M:ResetBorder(mode)
    local db = self:GetBorderDB(mode)
    if not db then return false end
    db.frameShowBorder = true
    db.frameBorderStyle = "SOLID"
    db.frameBorderTexture = "SOLID"
    db.frameBorderSize = 1
    db.frameBorderInset = 0
    db.frameBorderColor = { r = 0, g = 0, b = 0, a = 1 }
    db.frameBorderColorSource = "STATIC"
    db.frameBorderUseClassColor = false
    db.frameBorderUseRoleColor = false
    self.borderGeometryBeforeEUI[mode == "raid" and "raid" or "party"] = nil
    self:RefreshBorder(mode)
    return true
end

function M:BorderStatus(mode)
    local danders = self:GetDanders()
    if not danders then return SUI.Text("DandersFrames не загружен", "DandersFrames is not loaded") end
    if not self:GetBorderDB(mode) then return SUI.Text("Профиль DandersFrames еще не готов", "DandersFrames profile is not ready") end
    if self.pendingBorders and self.pendingBorders[mode] then return SUI.Text("Изменение применится после выхода из боя", "Applies after combat") end
    return SUI.Text("Изменения сохраняются в активном профиле DandersFrames", "Saved in the active DandersFrames profile")
end

function M:AvailableFonts()
    local lsm = self:GetLSM()
    local result = {}
    if lsm and lsm.List then
        for _, name in ipairs(lsm:List("font")) do
            result[#result + 1] = { name = name, path = lsm:Fetch("font", name, true) }
        end
    end
    table.sort(result, function(a, b) return a.name:lower() < b.name:lower() end)
    return result
end

function M:RegisterSelected()
    local profile = self:Profile()
    local danders = _G.DandersFrames
    local lsm = self:GetLSM()
    if not profile or not profile.enabled or not danders
        or type(danders.RegisterFontAlphabetSupport) ~= "function" or not lsm then return end
    local registered
    for name, selected in pairs(profile.fonts or {}) do
        if selected then
            local path = lsm:Fetch("font", name, true)
            if path then
                danders:RegisterFontAlphabetSupport(path, { "roman", "russian" })
                registered = not self.sessionRegistered[name] or registered
                self.sessionRegistered[name] = true
            end
        end
    end
    if registered then self:RefreshDandersFonts() end
end

function M:RefreshDandersFonts()
    local danders = self:GetDanders()
    if not danders then return false end
    if InCombatLockdown and InCombatLockdown() then
        self.pendingFontRefresh = true
        return false
    end
    self.pendingFontRefresh = nil
    if type(danders.RefreshAllFonts) == "function" then pcall(danders.RefreshAllFonts, danders) end
    local pinned = danders.PinnedFrames
    if pinned and type(pinned.RefreshFonts) == "function" then pcall(pinned.RefreshFonts, pinned) end
    local preview = danders.TextDesigner and danders.TextDesigner.Preview
    if preview and type(preview.RefreshLiveFrames) == "function" then pcall(preview.RefreshLiveFrames, preview) end
    return true
end

function M:Initialize()
    self:RegisterBorderMedia()
    self:InstallDandersAggroGlow()
    if self:Profile().absorbInset then self:RefreshAbsorbInsetCompatibility() end
    self:RegisterSelected()
    SUI:RegisterModuleEvent(self, "PLAYER_REGEN_ENABLED")
end

function M:SetEnabled(enabled)
    local profile = self:Profile()
    profile.enabled = enabled == true
    if profile.enabled then
        self:RegisterSelected()
    elseif next(self.sessionRegistered) then
        self.reloadRequired = true
    end
end

function M:SetFontSelected(name, selected)
    local profile = self:Profile()
    profile.fonts[name] = selected == true or nil
    if selected and profile.enabled then
        self:RegisterSelected()
    elseif self.sessionRegistered[name] then
        self.reloadRequired = true
    end
end

function M:OnProfileChanged()
    local profile = self:Profile()
    if profile.borderMedia and not self.borderMediaRegistered then self:RegisterBorderMedia() end
    if not profile.borderMedia and self.borderMediaRegistered then self.reloadRequired = true end
    if profile.absorbInset or self.absorbInsetOwner then self:RefreshAbsorbInsetCompatibility() end
    for name in pairs(self.sessionRegistered) do
        if not profile.enabled or not profile.fonts[name] then self.reloadRequired = true end
    end
    self:RegisterSelected()
end

function M:OnEvent(event, unit)
    if event == "UNIT_FLAGS" then
        if PublicUnit(unit) then self:RefreshDandersAggroVisibility(unit) end
        return
    end
    if event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
        self:RefreshDandersAggroVisibility()
    end
    if event ~= "PLAYER_REGEN_ENABLED" then return end
    if self.pendingAbsorbInset then self:RefreshAbsorbInsetCompatibility() end
    if self.pendingBorders then
        if self.pendingBorders.party then self:RefreshBorder("party") end
        if self.pendingBorders.raid then self:RefreshBorder("raid") end
    end
    if self.pendingFontRefresh then self:RefreshDandersFonts() end
end

function M:Status()
    if not _G.DandersFrames then return SUI.Text("DandersFrames не загружен", "DandersFrames is not loaded") end
    if not self:GetLSM() then return SUI.Text("LibSharedMedia не загружена", "LibSharedMedia is not loaded") end
    if self.reloadRequired then return SUI.Text("Требуется /reload для удаления регистрации", "Removing registered media requires /reload") end
    return SUI.Text("Готово", "Ready")
end
