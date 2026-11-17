local _, SUI = ...
local Text = SUI.Text
local M = SUI.Nameplates
local W, T = SUI.Widgets, SUI.SettingsTheme
local WHITE = "Interface\\Buttons\\WHITE8x8"
local HEALTH_COLOR = { r = .54, g = .29, b = .17 }
local AURA_COLOR = { r = 1, g = .35, b = .75 }
local TAPPED_HEALTH = { r = .52, g = .52, b = .52 }
local WHITE_TEXT = { 1, 1, 1, 1 }
local BLIZZARD_BAR = "Interface\\TargetingFrame\\UI-StatusBar"

local function SampleBar(parent)
    local track = CreateFrame("Frame", nil, parent)
    track:SetSize(216, 17)
    track:SetPoint("CENTER", parent, "CENTER", 0, -10)
    local fill = CreateFrame("StatusBar", nil, track)
    fill:SetStatusBarTexture(WHITE)
    fill:SetMinMaxValues(0, 100)
    fill:SetValue(72)
    local background = track:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(.045, .038, .033, 1)
    track.rounding = { textures = { fill:GetStatusBarTexture(), background }, roots = {} }
    return track, fill
end

local function SampleText(parent, text, size, anchor, point, relativePoint, x, y, color)
    local label = W:Label(parent, text, size, color or { 1, 1, 1, 1 })
    label:SetPoint(point, anchor, relativePoint, x, y)
    return label
end

local function UpdateSampleShape(bar, fill, eui, radius, corners, border, style)
    if not (eui and eui.RoundCorners) then return end
    local shape = border or bar
    if not border and not bar.rounding.border and bar.rounding.textures[1] == fill
        and bar.rounding.corners == corners and bar.previewRadius == radius then return end
    bar.rounding.textures[1] = fill
    bar.rounding.rect, bar.rounding.border, bar.rounding.style = shape, border, style
    bar.rounding.corners = corners
    bar.previewRadius = radius
    eui.RoundCorners(bar, radius or 0, bar.rounding)
end

local function UpdateSampleBorder(plate, eui, ns, stockArt)
    local pp = eui and eui.PP
    if not pp then return end
    local health = plate.health
    local custom = ns and not stockArt and type(ns.IsCustomBorderEnabled) == "function"
        and ns.IsCustomBorderEnabled() and type(ns.ApplyCustomBorderStyle) == "function"
        and type(ns.HideCustomBorder) == "function"
    local basic = ns and not stockArt and not custom and type(ns.IsBorderEnabled) == "function"
        and ns.IsBorderEnabled() and type(ns.GetBorderColor) == "function" and type(ns.NP_BorderSize) == "function"
        and type(pp.CreateBorder) == "function" and type(pp.SetBorderSize) == "function"
        and type(pp.SetBorderColor) == "function" and type(pp.ShowBorder) == "function" and type(pp.HideBorder) == "function"
    if basic then
        local r, g, b = ns.GetBorderColor()
        local size = ns.NP_BorderSize()
        if not plate.sampleBasicBorder then
            plate.sampleBasicBorder = pp.CreateBorder(health, r, g, b, 1, size, "OVERLAY", 7, true)
        else
            pp.SetBorderSize(health, size)
            pp.SetBorderColor(health, r, g, b, 1)
        end
        pp.ShowBorder(health)
    elseif plate.sampleBasicBorder and type(pp.HideBorder) == "function" then
        pp.HideBorder(health)
    end
    if custom then
        ns.ApplyCustomBorderStyle(plate)
        local border = plate._customBorder
        if border and border:IsShown() then
            border:SetFrameStrata(health:GetFrameStrata())
            return border, border._cbTex
        end
    elseif ns and plate._customBorder and type(ns.HideCustomBorder) == "function" then
        ns.HideCustomBorder(plate)
    end
    if basic then return health, "solid" end
end

local function UpdateSampleBar(track, fill, texture, height, inset)
    if texture ~= fill.previewTexture then
        fill:SetStatusBarTexture(texture)
        fill.previewTexture = texture
    end
    height = math.max(8, math.min(25, tonumber(height) or 17))
    if track:GetHeight() ~= height then track:SetHeight(height) end
    fill:SetPoint("TOPLEFT", track, "TOPLEFT", inset, -inset)
    fill:SetPoint("BOTTOMRIGHT", track, "BOTTOMRIGHT", -inset, inset)
end

function M:CreateSettingsPreview(parent)
    local card = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    card:SetHeight(72)
    T:Backdrop(card, T.input, T.lineSoft)
    local health, statusBar = SampleBar(card)
    local text = CreateFrame("Frame", nil, card)
    text:SetAllPoints()
    text:SetFrameLevel(health:GetFrameLevel() + 8)
    local plate = { frame = card, health = health }
    plate.name = SampleText(text, Text("Болотный кроколиск", "Marsh Crocolisk"), 12, health, "BOTTOMLEFT", "TOPLEFT", 3, 3)
    plate.levelText = SampleText(text, "32", 11, health, "BOTTOMRIGHT", "TOPRIGHT", -3, 3)
    plate.hpText = SampleText(text, "864 | 72%", 11, health, "RIGHT", "RIGHT", -5, 0)
    local icons = {}
    for index = 1, 2 do
        local icon = CreateFrame("Frame", nil, text)
        icon:SetSize(16, 16)
        icon.image = icon:CreateTexture(nil, "ARTWORK")
        icon.image:SetAllPoints()
        icon.image:SetTexCoord(.08, .92, .08, .92)
        T:FrameIcon(icon, icon.image)
        icon:Hide()
        icons[index] = icon
    end

    function card:SetDebuffs(first, second)
        local stock = M.adapterKey == "blizzard"
        local art = { first, second }
        for index, icon in ipairs(icons) do
            icon.image:SetTexture(art[index])
            icon:SetShown(art[index] ~= nil)
            icon:ClearAllPoints()
            local slot = index == 2 and first and 1 or 0
            if stock then
                icon:SetPoint("BOTTOMLEFT", health, "TOPLEFT", slot * 20, 16)
            else
                icon:SetPoint("LEFT", health, "RIGHT", 9 + slot * 20, 0)
            end
        end
    end

    local aura = CreateFrame("Frame", nil, health)
    aura:SetAllPoints()
    aura:SetFrameLevel(health:GetFrameLevel() + 2)
    card:HookScript("OnSizeChanged", function(_, width)
        health:SetWidth(math.min(216, math.max(1, width - 106)))
    end)

    function card:Refresh()
        local eui = _G.EllesmereUI
        local state = M.adapterKey == "ellesmere" and M.adapterState
        local ns = eui and state and state.namespace or nil
        local native = ns and ns.db and ns.db.profile
        local stockArt = M.adapterKey == "blizzard" or (ns and ns.NP_Blizz and ns.NP_Blizz())
        local fallback = stockArt and BLIZZARD_BAR or WHITE
        local function Texture(key)
            if stockArt or not native or type(eui.ResolveTexturePath) ~= "function" then return fallback end
            return eui.ResolveTexturePath(ns.healthBarTextures, native[key], fallback)
        end
        local rule = self.rule
        local auraColor = rule and (rule.color or AURA_COLOR)
        local function ColorFor(target)
            return rule and M.AuraRules:HasColorTarget(rule, target) and auraColor
        end
        local function PaintText(label, color)
            label:SetTextColor(color.r or color[1], color.g or color[2], color.b or color[3], 1)
        end
        local fillColor, borderColor = ColorFor("HEALTH"), ColorFor("BORDER")
        local fill = fillColor or (self.tapped and TAPPED_HEALTH or HEALTH_COLOR)
        UpdateSampleBar(health, statusBar, Texture("healthBarTexture"), native and native.healthBarHeight,
            borderColor and 1 or 0)
        local textSupported = M.AuraRules:SupportsTextColoring()
        plate.hpText:SetShown(M.adapterKey ~= "blizzard")
        PaintText(plate.hpText, (textSupported and ColorFor("TEXT")) or WHITE_TEXT)
        local labelColor = textSupported and ColorFor("LABELS")
        PaintText(plate.name, labelColor or WHITE_TEXT)
        PaintText(plate.levelText, labelColor or WHITE_TEXT)
        statusBar:SetStatusBarColor(fill.r or fill[1], fill.g or fill[2], fill.b or fill[3], fill.a or fill[4] or 1)

        local nativeBorder, borderStyle = UpdateSampleBorder(plate, eui, ns, stockArt)
        local radius, corners = M:GetNativePlateRounding(health, ns)
        local shapeRadius, shapeCorners = radius, corners
        if nativeBorder and nativeBorder ~= health then
            shapeRadius, shapeCorners = M:GetNativePlateRounding(nativeBorder, ns)
        end
        local fillTexture = statusBar:GetStatusBarTexture()
        UpdateSampleShape(health, fillTexture, eui, shapeRadius, shapeCorners, nativeBorder, borderStyle)
        M.AuraRules:PaintPreviewBorder(aura, health, rule, borderColor, ns, radius, corners)
    end
    return card
end

function M:CreateBuffSettingsPreview(parent)
    local card = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    card:SetHeight(84)
    T:Backdrop(card, T.input, T.lineSoft)
    local icons = {}
    local spells = { 21562, 17, 139, 10060, 1243, 1459, 6673, 774, 19740, 1022 }
    for index, spellID in ipairs(spells) do
        local tile = CreateFrame("Frame", nil, card)
        local image = tile:CreateTexture(nil, "ARTWORK")
        image:SetAllPoints()
        local texture = C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(spellID)
        image:SetTexture(texture or 134400)
        T:FrameIcon(tile, image)
        tile.image = image
        icons[index] = tile
    end
    local stockTrack, stockBar = SampleBar(card)
    stockTrack:SetSize(120, 12)
    stockTrack:SetPoint("CENTER", card, "CENTER", 25, 8)
    stockBar:SetAllPoints()
    stockBar:SetStatusBarTexture(BLIZZARD_BAR)
    stockBar:SetStatusBarColor(HEALTH_COLOR.r, HEALTH_COLOR.g, HEALTH_COLOR.b)
    local note = W:Label(card, "", 9, T.muted)

    function card:Refresh()
        local columns, size, height, gap, rowGap, shown = M:GetBuffPreviewLayout()
        local stock = M:UsesBlizzardNameplates()
        stockTrack:SetShown(stock)
        note:SetShown(not columns)
        note:ClearAllPoints()
        if stock then
            note:SetText(Text("Раскладка Blizzard", "Blizzard layout"))
            note:SetPoint("BOTTOM", card, "BOTTOM", 0, 11)
        else
            note:SetText(Text("Перенос не задан в Sintezza UI", "No Sintezza UI row override"))
            note:SetPoint("CENTER")
        end
        if stock and not columns then
            stockTrack:SetPoint("CENTER", card, "CENTER", 25, 8)
            for index, tile in ipairs(icons) do
                tile:SetShown(index <= 2)
                if index <= 2 then
                    tile:SetSize(21, 21)
                    tile.image:SetTexCoord(.08, .92, .08, .92)
                    tile:ClearAllPoints()
                    tile:SetPoint("RIGHT", stockTrack, "LEFT", -9 - (index - 1) * 25, 0)
                end
            end
            return
        end
        if not columns then
            for _, tile in ipairs(icons) do tile:Hide() end
            return
        end
        shown = shown or 8
        local rows = math.ceil(shown / columns)
        local width = card:GetWidth() - (stock and 165 or 26)
        local scale = math.max(.1, math.min(1.65, width / (columns * size + (columns - 1) * gap),
            (card:GetHeight() - 18) / (rows * height + (rows - 1) * rowGap)))
        local u = .42 * math.min(1, size / height)
        local v = .42 * math.min(1, height / size)
        if stock then stockTrack:SetPoint("CENTER", card, "CENTER", (columns * size * scale + 9) / 2, 0) end
        for index, tile in ipairs(icons) do
            local column, row = (index - 1) % columns, math.floor((index - 1) / columns)
            tile:SetShown(index <= shown)
            tile:SetSize(size * scale, height * scale)
            tile.image:SetTexCoord(.5 - u, .5 + u, .5 - v, .5 + v)
            tile:ClearAllPoints()
            if stock then
                tile:SetPoint("RIGHT", stockTrack, "LEFT", -9 - column * (size + gap) * scale,
                    (row - (rows - 1) / 2) * (height + rowGap) * scale)
            else
                tile:SetPoint("CENTER", card, "CENTER", (column - (columns - 1) / 2) * (size + gap) * scale,
                    ((rows - 1) / 2 - row) * (height + rowGap) * scale)
            end
        end
    end
    card:HookScript("OnSizeChanged", card.Refresh)
    return card
end
