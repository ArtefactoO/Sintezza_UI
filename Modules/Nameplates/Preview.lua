local _, SUI = ...
local Text = SUI.Text
local M = SUI.Nameplates
local W, T = SUI.Widgets, SUI.SettingsTheme
local WHITE = "Interface\\Buttons\\WHITE8x8"
local HEALTH_COLOR = { r = .54, g = .29, b = .17 }
local AURA_COLOR = { r = 1, g = .35, b = .75 }
local WHITE_TEXT = { 1, 1, 1, 1 }
local QUEST_TEXT = { 1, .84, .49, 1 }

local function SampleBar(parent, anchor, point, relativePoint, x, y, width, height, value)
    local bar = CreateFrame("StatusBar", nil, parent)
    bar:SetSize(width, height)
    bar:SetPoint(point, anchor, relativePoint, x, y)
    bar:SetStatusBarTexture(WHITE)
    bar:SetMinMaxValues(0, 100)
    bar:SetValue(value)
    bar.background = bar:CreateTexture(nil, "BACKGROUND")
    bar.background:SetAllPoints()
    bar.background:SetColorTexture(.045, .038, .033, 1)
    bar.rounding = { textures = { bar:GetStatusBarTexture(), bar.background }, roots = {} }
    return bar
end

local function SampleText(parent, text, size, anchor, point, relativePoint, x, y, color)
    local label = W:Label(parent, text, size, color or { 1, 1, 1, 1 })
    label:SetPoint(point, anchor, relativePoint, x, y)
    return label
end

local function UpdateSampleShape(bar, eui, radius, corners)
    if not (eui and eui.RoundCorners) then return end
    local fill = bar:GetStatusBarTexture()
    if bar.rounding.textures[1] == fill and bar.rounding.corners == corners and bar.previewRadius == radius then return end
    bar.rounding.textures[1] = fill
    bar.rounding.corners = corners
    bar.previewRadius = radius
    eui.RoundCorners(bar, radius or 0, bar.rounding)
end

function M:CreateSettingsPreview(parent)
    local card = W:Card(parent, Text("Предпросмотр", "Preview"), "")
    card:SetHeight(122)
    local scene = CreateFrame("Frame", nil, card)
    scene:SetSize(320, 100)
    scene:SetPoint("RIGHT", card, "RIGHT", -11, 0)
    local surface = scene:CreateTexture(nil, "BACKGROUND")
    surface:SetAllPoints()
    surface:SetColorTexture(.29, .25, .20, 1)
    card:HookScript("OnSizeChanged", function(_, width)
        card.description:SetWidth(math.max(1, width - 358))
    end)
    card.description:SetMaxLines(2)

    local health = SampleBar(scene, scene, "CENTER", "CENTER", 10, 10, 216, 20, 72)
    local cast = SampleBar(scene, health, "TOP", "BOTTOM", 0, -5, 216, 16, 56)
    cast:SetStatusBarColor(.58, .41, .18)
    local text = CreateFrame("Frame", nil, scene)
    text:SetAllPoints()
    text:SetFrameLevel(health:GetFrameLevel() + 8)
    local plate = { frame = scene, health = health, healthTextFrame = text, settingsPreview = true }
    plate.name = SampleText(text, Text("Болотный кроколиск", "Marsh Crocolisk"), 12, health, "BOTTOMLEFT", "TOPLEFT", 3, 3)
    plate.levelText = SampleText(text, "32", 11, health, "BOTTOMRIGHT", "TOPRIGHT", -3, 3)
    plate.hpText = SampleText(text, "864 | 72%", 11, health, "RIGHT", "RIGHT", -5, 0)
    plate.questText = SampleText(text, "2/6", 10, health, "RIGHT", "LEFT", -6, 0, QUEST_TEXT)
    plate.castName = SampleText(text, Text("Ядовитый укус", "Venomous bite"), 10, cast, "LEFT", "LEFT", 5, 0)
    plate.castTimer = SampleText(text, Text("1.4 с", "1.4 s"), 10, cast, "RIGHT", "RIGHT", -5, 0)
    plate.totText = SampleText(text, Text("Цель моба · Лиара", "Enemy's target · Liara"), 9, cast, "TOPLEFT", "BOTTOMLEFT", 0, -3)
    plate.castTarget = SampleText(text, Text("Каст в Лиару", "Casting at Liara"), 9, cast, "TOPRIGHT", "BOTTOMRIGHT", 0, -3)

    local aura = CreateFrame("Frame", nil, health)
    aura:SetAllPoints()
    aura:SetFrameLevel(health:GetFrameLevel() + 2)
    card.threat, card.target = "normal", true

    local states = W:Segmented(card, { Text("Обычный", "Normal"), Text("Рядом", "Near"), Text("Агро", "Aggro") }, { "normal", "near", "aggro" },
        function() return card.threat end,
        function(value) card.threat = value; card:Refresh() end)
    states:SetSize(214, 28)
    states:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", 14, 14)
    local target = W:Toggle(card, Text("Цель", "Target"), function() return card.target end,
        function(value) card.target = value; card:Refresh() end)
    target:SetWidth(84)
    target:SetPoint("LEFT", states, "RIGHT", 10, 0)

    function card:Refresh()
        local profile = M:Profile()
        local eui = _G.EllesmereUI
        local ns = eui and eui._ModuleNS and eui._ModuleNS.EllesmereUINameplates
        local native = ns and ns.db and ns.db.profile
        local texture = native and eui.ResolveTexturePath
            and eui.ResolveTexturePath(ns.healthBarTextures, native.healthBarTexture, WHITE) or WHITE
        if texture ~= health.previewTexture then
            health:SetStatusBarTexture(texture)
            health.previewTexture = texture
        end

        local near = self.threat == "near"
        local threat = profile.enabled ~= false and profile.openWorldThreat and self.threat ~= "normal"
            and (not near or profile.nearThreat)
        local fill = threat and profile.threatFillEnabled
            and (near and profile.nearFillColor or profile.aggroFillColor) or HEALTH_COLOR
        local rule = self.rule
        local auraColor = rule and (rule.color or AURA_COLOR)
        local function ColorFor(target)
            return rule and M.AuraRules:HasColorTarget(rule, target) and auraColor
        end
        local function PaintText(label, color)
            label:SetTextColor(color.r or color[1], color.g or color[2], color.b or color[3], 1)
        end
        fill = ColorFor("HEALTH") or fill
        PaintText(plate.hpText, ColorFor("TEXT") or WHITE_TEXT)
        local labelColor = ColorFor("LABELS")
        PaintText(plate.name, labelColor or WHITE_TEXT)
        PaintText(plate.levelText, labelColor or WHITE_TEXT)
        PaintText(plate.totText, labelColor or WHITE_TEXT)
        PaintText(plate.questText, labelColor or QUEST_TEXT)
        health:SetStatusBarColor(fill.r or fill[1], fill.g or fill[2], fill.b or fill[3], fill.a or fill[4] or 1)

        local radius, corners = M:GetNativePlateRounding(health, ns)
        UpdateSampleShape(health, eui, radius, corners)
        local castRadius, castCorners = M:GetNativePlateRounding(cast, ns)
        UpdateSampleShape(cast, eui, castRadius, castCorners)
        if threat and profile.threatBorderEnabled ~= false then
            M:ShowThreatDecoration(plate, near and profile.nearColor or profile.aggroColor, near and .72 or 1, ns)
        else
            M:HideThreatDecoration(plate, plate.__suiThreat)
        end
        M.AuraRules:PaintPreviewBorder(aura, health, rule, ColorFor("BORDER"), ns, radius, corners)
        M:UpdateTargetPattern(plate, self.target)
        M:UpdateNativeSelectionGlow(plate, self.target, ns)
        M:ApplyPreviewTextStyles(plate)
        self.description:SetText(rule and (Text("Аура · ", "Aura · ") .. self.ruleLabel) or "")
    end
    return card
end
