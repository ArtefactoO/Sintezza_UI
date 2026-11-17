local _, SUI = ...
local M = SUI:GetModule("fontCompatibility")

local descriptors = {
    { "unit:player", SUI.Text("Игрок", "Player"), "unit", "player" },
    { "unit:target", SUI.Text("Цель", "Target"), "unit", "target" },
    { "unit:focus", SUI.Text("Фокус", "Focus"), "unit", "focus" },
    { "unit:targettarget", SUI.Text("Цель цели", "Target of target"), "unit", "targettarget" },
    { "unit:focustarget", SUI.Text("Цель фокуса", "Focus target"), "unit", "focustarget" },
    { "unit:pet", SUI.Text("Питомец", "Pet"), "unit", "pet" },
    { "unit:boss", SUI.Text("Боссы", "Bosses"), "unit", "boss" },
    { "dandersParty", SUI.Text("Группа · DandersFrames", "Party · DandersFrames"), "danders", "party" },
    { "dandersRaid", SUI.Text("Рейд · DandersFrames", "Raid · DandersFrames"), "danders", "raid" },
    { "euiParty", SUI.Text("Группа · Ellesmere", "Party · Ellesmere"), "group", "party" },
    { "euiRaid", SUI.Text("Рейд · Ellesmere", "Raid · Ellesmere"), "group", "raid" },
    { "plates", SUI.Text("Неймплейты", "Nameplates"), "plates" },
    { "mana", SUI.Text("Основной ресурс / мана", "Primary resource / mana"), "resource", "primary" },
    { "health", SUI.Text("Отдельная полоса здоровья", "Standalone health bar"), "resource", "health" },
    { "secondary", SUI.Text("Ресурс класса", "Class resource"), "resource", "secondary" },
    { "experience", SUI.Text("Полоса опыта", "Experience bar"), "experience" },
}
local byKey = {}
for _, entry in ipairs(descriptors) do byKey[entry[1]] = entry end
M.FrameElements = descriptors

local function EUI(name)
    local eui = _G.EllesmereUI
    return eui and eui._ModuleNS and eui._ModuleNS[name]
end

local function Profile(ns)
    return ns and ns.db and ns.db.profile
end

local function Combat()
    return InCombatLockdown and InCombatLockdown()
end

local function Dimensions(surface, width, height, range, shift)
    surface.width, surface.height, surface.range, surface.shift = width, height, range, shift or 0
end

local function Matched(surface, id, vertical)
    local eui = _G.EllesmereUI
    if eui and eui.GetWidthMatchTarget and eui.GetHeightMatchTarget then
        local w = eui.GetWidthMatchTarget(id) ~= nil
        local h = eui.GetHeightMatchTarget(id) ~= nil
        if vertical then w, h = h, w end
        surface.widthMatched, surface.heightMatched = w, h
    end
end

local function StandardEdge(surface, addon)
    surface.edge = { texture = "borderTexture", size = "borderSize", exact = "borderSizePx", addon = addon }
end

function M:GetFrameSurface(key)
    local entry = byKey[key]
    if not entry then return end
    local _, _, kind, sub = unpack(entry)
    local integration = kind == "danders" and "danders" or "frames"
    if not SUI:IntegrationEnabled(integration) then return end
    local s = { kind = kind, sub = sub, owner = kind == "danders" and "DandersFrames" or "EllesmereUI" }
    if kind == "unit" then
        local ns = EUI("EllesmereUIUnitFrames")
        local p = Profile(ns)
        s.db = p and p[sub]
        if s.db and type(ns.ReloadFrames) == "function" then
            if ns.UF_Blizz and ns.UF_Blizz() then s.stock = true; return s end
            Dimensions(s, "frameWidth", "healthHeight", { s.db.healthVerticalFill and 20 or 60, 400, 15,
                s.db.healthVerticalFill and 400 or 100 })
            Matched(s, sub)
            -- Small frames can borrow a main frame's outline. A local edit
            -- must not silently change the source used by that other frame.
            if sub == "player" or sub == "target" or sub == "focus" or (sub == "boss" and s.db.borderCustom) then
                StandardEdge(s, "unitframes")
            else
                local donor = sub == "boss" and ns.UF_BossBorderSettings and ns.UF_BossBorderSettings()
                    or ns.GetMiniDonorSettings and ns.GetMiniDonorSettings(sub)
                if donor then s.previewBorder = { kind = kind, db = donor }; StandardEdge(s.previewBorder, "unitframes") end
                s.note = SUI.Text("Окантовка наследуется от основной рамки.", "The border comes from the parent frame.")
            end
        end
    elseif kind == "danders" then
        s.db = self:GetBorderDB(sub)
        if s.db then Dimensions(s, "frameWidth", "frameHeight", { 30, 400, 15, 180 }) end
    elseif kind == "group" then
        local ns = EUI("EllesmereUIRaidFrames")
        local p = Profile(ns)
        s.db = p
        if p and ns.RF_Stock and ns.RF_Stock() then s.stock = true end
        if p and not s.stock and sub == "raid" and type(ns.ReloadFrames) == "function" then
            Dimensions(s, "frameWidth", "frameHeight", { 30, 300, 15, 180 })
            StandardEdge(s, "unitframes")
        elseif p and not s.stock then
            local party = ns._scaledPartyProxy
            if party then s.previewBorder = { kind = kind, db = party }; StandardEdge(s.previewBorder, "unitframes") end
            s.previewWidth, s.previewHeight = p.partyFrameWidth, p.partyFrameHeight
            s.note = SUI.Text("Размер и окантовка группы зависят от разделов профиля EllesmereUI.", "Party size and border use the EllesmereUI profile.")
        end
    elseif kind == "plates" then
        local ns = EUI("EllesmereUINameplates")
        s.db = Profile(ns)
        if s.db and ns.NP_Blizz and ns.NP_Blizz() then s.stock = true; return s end
        if s.db and type(ns.RefreshAllSettings) == "function" and type(ns.BAR_W) == "number" then
            Dimensions(s, "healthBarWidth", "healthBarHeight", { 100, ns.BAR_W + 100, 6, 50 }, ns.BAR_W)
            s.edge = { texture = "customBorderTexture", size = "customBorderSize", exact = "customBorderSizePx",
                enable = "customBorderEnabled", addon = "nameplates" }
            s.roundBlocked = ns.GetWrapBorderCastbar and ns.GetWrapBorderCastbar()
        end
    elseif kind == "resource" then
        local ns = EUI("EllesmereUIResourceBars")
        local p = _G._ERB_AceDB and _G._ERB_AceDB.profile
        s.db = p and p[sub]
        if s.db and ns and ns.ERB_BarsBlizz and ns.ERB_BarsBlizz() then s.stock = true; return s end
        if s.db and type(_G._ERB_Apply) == "function" then
            local secondary = sub == "secondary"
            Dimensions(s, secondary and "pipWidth" or "width", secondary and "pipHeight" or "height", { 30, 600, 4, 80 })
            local orientation = secondary and s.db.pipOrientation or s.db.orientation
            Matched(s, secondary and "ERB_ClassResource" or (sub == "health" and "ERB_Health" or "ERB_Power"),
                orientation == "VERTICAL")
            StandardEdge(s, "resourcebars")
        end
    elseif kind == "experience" then
        local ns = EUI("EllesmereUIActionBars")
        local p = Profile(ns and ns.EAB)
        s.db = p and p.bars and p.bars.XPBar
        if p and p.useBlizzardDataBars then s.stock = true; return s end
        if s.db and type(ns.ApplyDataBarLayout) == "function" then
            local frame = ns.dataBarFrames and ns.dataBarFrames.XPBar
            Dimensions(s, "width", "height", { 50, 1000, 4, 80 })
            Matched(s, "XPBar")
            if frame and frame._xpArtOn then
                s.roundBlocked = true
            else
                s.edge = { texture = "borderTexture", size = "borderThickness", exact = "borderThicknessPx",
                    enable = "customBorder", labelSize = true, addon = "actionbars" }
            end
        end
    end
    return s
end

function M:GetConfiguredFrameDimension(surface, axis)
    local field = surface and surface[axis]
    local value = field and tonumber(surface.db[field])
    if not value then return end
    return value + (axis == "width" and (surface.shift or 0) or 0)
end

function M:GetFrameEdge(surface)
    local eui = _G.EllesmereUI
    local edge, db = surface.edge, surface.db
    if not (edge and db and eui) then return "solid", 1 end
    if edge.enable and not db[edge.enable] then
        if surface.kind == "plates" then return db.showBorder == false and "none" or "solid", db.borderSize or 1 end
        return "solid", 1
    end
    local texture = db[edge.texture]
    if texture == nil or texture == "" then texture = "solid" end
    local size = db[edge.size]
    if edge.labelSize then
        local ns = EUI("EllesmereUIActionBars")
        local step = ns and ns.BORDER_THICKNESS and ns.BORDER_THICKNESS[size or "thin"]
        size = step and step.regular
    end
    size = tonumber(size) or 1
    local px = eui.BorderPx and eui.BorderPx(db[edge.exact], size, texture)
    if not px and eui.BorderLegacyPx then px = eui.BorderLegacyPx(size, texture) end
    return texture, px or size
end

local function Refresh(kind)
    if kind == "unit" then
        local ns = EUI("EllesmereUIUnitFrames")
        if ns and ns.ReloadFrames then ns.ReloadFrames() end
    elseif kind == "group" then
        local ns = EUI("EllesmereUIRaidFrames")
        if ns and ns._euiUnitButtons and next(ns._euiUnitButtons) then
            if ns.ReloadFrames then ns.ReloadFrames() end
            if ns.ReloadPartyFrames then ns.ReloadPartyFrames() end
        end
    elseif kind == "plates" then
        local ns = EUI("EllesmereUINameplates")
        if ns and ns.RefreshAllSettings then ns.RefreshAllSettings() end
    elseif kind == "resource" then
        if _G._ERB_Apply then _G._ERB_Apply() end
    elseif kind == "experience" then
        local ns = EUI("EllesmereUIActionBars")
        if ns and ns.ApplyDataBarLayout then ns.ApplyDataBarLayout("XPBar") end
    elseif kind == "danders:party" or kind == "danders:raid" then
        local df = M:GetDanders()
        local mode = kind == "danders:party" and "party" or "raid"
        local method = df and (mode == "party" and df.UpdatePartyHeaderLayout or df.UpdateRaidHeaderLayout)
        if method then method(df) end
        if df and df.RefreshAllVisibleFrames then df:RefreshAllVisibleFrames() end
    end
end

function M:ApplyFrameAppearanceEdits()
    if Combat() then return end
    local pending = self.pendingFrameAppearance
    self.pendingFrameAppearance = nil
    for kind in pairs(pending or {}) do
        SUI:SafeModuleCall(self, "refresh " .. kind .. " frame appearance", function() Refresh(kind) end)
    end
end

local function Queue(surface)
    local kind = surface.kind == "danders" and ("danders:" .. surface.sub) or surface.kind
    M.pendingFrameAppearance = M.pendingFrameAppearance or {}
    M.pendingFrameAppearance[kind] = true
    if Combat() or M.appearanceRefreshScheduled then return end
    M.appearanceRefreshScheduled = true
    SUI:After(.08, M, "refresh frame appearance", function()
        M.appearanceRefreshScheduled = nil
        M:ApplyFrameAppearanceEdits()
    end)
end

function M:SetFrameDimension(key, axis, value)
    if axis ~= "width" and axis ~= "height" then return end
    local surface = self:GetFrameSurface(key)
    local field = surface and surface[axis]
    if not field or surface[axis .. "Matched"] then return end
    local i = axis == "width" and 1 or 3
    local range = surface.range
    local offset = axis == "width" and surface.shift or 0
    value = math.floor(math.max(range[i], math.min(range[i + 1], tonumber(value) or range[i])) + .5) - offset
    if surface.db[field] == value then return end
    surface.db[field] = value
    Queue(surface)
end

function M:GetFrameEdgeColor(surface)
    local db = surface and surface.edge and surface.db
    if not db then return { 0, 0, 0, 1 } end
    if surface.kind == "resource" then return { db.borderR or 0, db.borderG or 0, db.borderB or 0, db.borderA or 1 } end
    local c = surface.kind == "plates" and db.customBorderColor or db.borderColor
    local a = surface.kind == "plates" and db.customBorderAlpha or db.borderAlpha
    c = c or {}
    return { c.r or 0, c.g or 0, c.b or 0, a or c.a or 1 }
end

local function WriteEdgeColor(surface, r, g, b, a)
    local db = surface.db
    local color = { r = r, g = g, b = b, a = a }
    if surface.kind == "plates" then db.customBorderColor, db.customBorderAlpha = color, a
    elseif surface.kind == "resource" then db.borderR, db.borderG, db.borderB, db.borderA = r, g, b, a
    else db.borderColor, db.borderAlpha = color, a end
end

function M:SetFrameEdgeColor(key, value)
    local surface = self:GetFrameSurface(key)
    if not (surface and surface.edge and type(value) == "table") then return end
    if self:GetFrameEdge(surface) == "none" then return end
    local edge = surface.edge
    if edge.enable and not surface.db[edge.enable] then self:SetFrameEdge(key, "solid", 1) end
    WriteEdgeColor(surface, value[1], value[2], value[3], value[4])
    Queue(surface)
end

function M:SetFrameEdge(key, texture, px, black)
    local surface = self:GetFrameSurface(key)
    local edge, eui = surface and surface.edge, _G.EllesmereUI
    if not (edge and eui and eui.BorderPxStep and eui.BorderPxString and eui.GetBorderDefaultSize) then return false end
    local db = surface.db
    if texture == "none" and surface.kind == "plates" then
        db[edge.enable], db.showBorder = false, false
        Queue(surface)
        return true
    end
    if not texture then texture = self:GetFrameEdge(surface) end
    if texture == "none" then return false end
    local step
    if px then
        px = math.floor(math.max(1, math.min(40, tonumber(px) or 1)) + .5)
        step = eui.BorderPxStep(px, texture)
    else
        step = eui.GetBorderDefaultSize(edge.addon, texture)
        if edge.labelSize and type(step) == "string" then
            local ns = EUI("EllesmereUIActionBars")
            local entry = ns and ns.BORDER_THICKNESS and ns.BORDER_THICKNESS[step]
            step = entry and entry.regular
        end
        step = tonumber(step) or 1
    end
    local oldStyle = db[edge.texture]
    db[edge.texture] = texture
    db[edge.size] = edge.labelSize and (eui.BORDER_LABEL_OF_STEP and eui.BORDER_LABEL_OF_STEP[step] or "thin") or step
    db[edge.exact] = px and eui.BorderPxString(px, step, texture) or false
    if edge.enable then db[edge.enable] = true end
    if oldStyle ~= texture then
        local prefix = surface.kind == "plates" and "customBorder" or "borderTexture"
        db[prefix .. "Offset"], db[prefix .. "OffsetY"] = nil, nil
        db[prefix .. "ShiftX"], db[prefix .. "ShiftY"] = nil, nil
    end
    if black then WriteEdgeColor(surface, 0, 0, 0, 1) end
    Queue(surface)
    return true
end

function M:ApplyThinInterfaceEdges()
    for _, entry in ipairs(descriptors) do
        self:SetFrameEdge(entry[1], "solid", 1, true)
    end
    for _, mode in ipairs({ "party", "raid" }) do
        local db = self:GetBorderDB(mode)
        if db and self:CanDrawThinRoundedBorder() then
            db.frameShowBorder = true
            self:SetBorderPreset(mode, self.ThinRoundedBorderKey)
        end
    end
end

