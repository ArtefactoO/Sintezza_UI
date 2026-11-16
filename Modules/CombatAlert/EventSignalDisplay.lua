local _, SUI = ...
local M, Text = SUI.CombatAlert, SUI.Text
local theme = Sintezza_Theme
local assets = "Interface\\AddOns\\Sintezza_UI\\Media\\CombatAlert\\"
local atlas = assets .. "event-alerts.png"
local glyphs = assets .. "signal-glyphs.png"

local definitions = {
    healthAlert = {
        caption = Text("МАЛО ЗДОРОВЬЯ", "LOW HEALTH"),
        defaultStyle = "PULSE",
        styles = { PULSE = true, FISSURE = true, PLAQUE = true },
    },
    aggroAlert = {
        caption = Text("АГРО", "AGGRO"),
        defaultStyle = "THREAT",
        styles = { THREAT = true, CREST = true, BRACKETS = true },
    },
}

local function Clamp(value, minimum, maximum, fallback)
    value = tonumber(value) or fallback
    return math.max(minimum, math.min(maximum, value))
end

function M:GetExtraAlertProfile(kind)
    local profile = self:Profile()
    if profile and type(profile[kind]) == "table" then return profile[kind] end
    return SUI.defaults.modules.combatAlert[kind]
end

function M:GetExtraAlertStyle(kind)
    local definition = definitions[kind]
    local profile = self:GetExtraAlertProfile(kind)
    return definition.styles[profile.style] and profile.style or definition.defaultStyle
end

function M:GetExtraAlertCaption(kind, detail)
    local definition = definitions[kind]
    local profile = self:GetExtraAlertProfile(kind)
    if type(profile.text) == "string" and profile.text ~= "" then return profile.text end
    if kind == "healthAlert" and not (issecretvalue and issecretvalue(detail))
        and type(detail) == "number" and detail >= 0 and detail <= 100 and detail == math.floor(detail) then
        return ("%s · %d%%"):format(definition.caption, detail)
    end
    return definition.caption
end

function M:SetExtraAlertText(kind, text)
    local profile = self:Profile()
    if not profile or type(profile[kind]) ~= "table" or type(text) ~= "string" then return end
    profile[kind].text = text:gsub("%c", " "):match("^%s*(.-)%s*$")
end

local function SetCell(texture, cell)
    local left = (cell % 2) / 2
    local top = math.floor(cell / 2) / 2
    texture:SetTexture(atlas)
    texture:SetTexCoord(left, left + .5, top, top + .5)
end

local function ApplyFont(region, selection, size)
    local combatFont = SUI:GetModule("combatFont")
    if combatFont and combatFont:ApplyToAlert(region, size, "OUTLINE") then return end
    SUI.Theme:ApplyTextFont(region, selection, size, "OUTLINE")
end

local function Paint(self, rig, profile)
    local color = profile.useThemeColors ~= false and SUI.SettingsTheme.accent or profile.color
    color = type(color) == "table" and color or SUI.defaults.modules.combatAlert[rig.kind].color
    local r = Clamp(color.r or color[1], 0, 1, 1)
    local g = Clamp(color.g or color[2], 0, 1, 1)
    local b = Clamp(color.b or color[3], 0, 1, 1)
    local a = Clamp(color.a or color[4], 0, 1, 1)
    local white = profile.useThemeColors ~= false and .27 or 0
    rig.caption:SetTextColor(white + r * (1 - white), white + g * (1 - white), white + b * (1 - white), a)
    if rig.factionCrest then
        rig.icon:SetVertexColor(1, 1, 1, a)
    else
        rig.icon:SetVertexColor(r, g, b, a)
    end
    rig.ring:SetVertexColor(r, g, b, a * .60)
    self:TintVariant(rig.variant, r, g, b, a, .30)
end

local function Build(self, kind)
    self.animations = self.animations or {}
    local frame = CreateFrame("Frame", nil, UIParent)
    frame:SetSize(400, 136)
    frame:SetFrameStrata("HIGH")
    frame:SetFrameLevel(41)
    frame:EnableMouse(false)
    frame:Hide()

    local ring = frame:CreateTexture(nil, "BACKGROUND")
    SetCell(ring, 2)
    local icon = frame:CreateTexture(nil, "ARTWORK")
    local title = CreateFrame("Frame", nil, frame)
    title:SetFrameLevel(frame:GetFrameLevel() + 4)
    title:SetSize(380, 48)
    title:EnableMouse(false)
    local caption = title:CreateFontString(nil, "OVERLAY")
    caption:SetPoint("LEFT")
    caption:SetPoint("RIGHT")
    caption:SetWordWrap(false)
    caption:SetJustifyH("CENTER")
    caption:SetShadowColor(0, 0, 0, 1)
    caption:SetShadowOffset(2, -2)

    local display = frame:CreateAnimationGroup()
    self:NewAlpha(display, 1, 0, 1, .14)
    self:NewAlpha(display, 2, 1, 1, .61)
    self:NewAlpha(display, 3, 1, 0, .26)
    display:SetScript("OnFinished", function() self:StopExtraAlert(kind) end)

    local grow = icon:CreateAnimationGroup()
    local pop = self:NewScale(grow, 1, .83, 1.07, .21)
    local settle = self:NewScale(grow, 2, 1.07, 1, .14)

    local flash = ring:CreateAnimationGroup()
    self:NewScale(flash, 1, .65, 1.40, .48)
    self:NewAlpha(flash, 1, .90, 0, .48)
    flash:SetScript("OnFinished", function() ring:Hide() end)

    local groups = { display, grow, flash }
    local rig = { kind = kind, base = frame, title = title, caption = caption, icon = icon,
        ring = ring, display = display, grow = grow, pop = pop, settle = settle, flash = flash, groups = groups,
        variant = { base = frame, groups = groups, y = 0 } }
    theme:TrackAppearance(frame, "state", function()
        if frame:IsShown() then Paint(self, rig, self:GetExtraAlertProfile(kind)) end
    end)
    return rig
end

function M:StopExtraAlert(kind)
    local rig = self.extraAlerts and self.extraAlerts[kind]
    if not rig then return end
    for _, group in ipairs(rig.groups) do
        if group:IsPlaying() then group:Stop() end
    end
    self:HideVariant(rig.variant)
    rig.base:Hide()
    rig.icon:Hide()
    rig.ring:Hide()
end

function M:StopExtraAlerts()
    self:StopExtraAlert("healthAlert")
    self:StopExtraAlert("aggroAlert")
end

local function Play(self, kind, detail, preview)
    if not definitions[kind] then return false end
    local profile = self:GetExtraAlertProfile(kind)
    if not preview and profile.enabled ~= true then return false end
    self.extraAlerts = self.extraAlerts or {}
    local rig = self.extraAlerts[kind] or Build(self, kind)
    self.extraAlerts[kind] = rig
    self:StopExtraAlert(kind)

    local combatProfile = self:Profile() or {}
    local reduced = combatProfile.reducedMotion == true
    local style = self:GetExtraAlertStyle(kind)
    local showIcon, showCaption = profile.mode ~= "TEXT", profile.mode ~= "ICON"
    rig.factionCrest = showIcon and style == "CREST" and self:ApplyFactionEmblem(rig.icon)
    local size = Clamp(profile.size, 36, 120, 68)
    local fontSize = Clamp(profile.fontSize, 16, 48, 27)
    rig.base:ClearAllPoints()
    rig.base:SetPoint("CENTER", UIParent, "CENTER", Clamp(profile.x, -600, 600, 0), Clamp(profile.y, -400, 400, 0))
    rig.title:ClearAllPoints()
    rig.title:SetPoint("CENTER", rig.base, "CENTER", 0, showIcon and -size * .48 or 0)
    ApplyFont(rig.caption, combatProfile.font or "INTERFACE", fontSize)
    rig.caption:SetText((self:GetExtraAlertCaption(kind, detail):gsub("|", "||")))
    rig.caption:SetShown(showCaption)
    rig.variant.y = showCaption and size * .19 or 0
    Paint(self, rig, profile)
    self:ApplyAnimationSpeed()
    rig.base:Show()
    rig.display:Play()

    if showIcon then
        if self:HasVisualVariant(style, false) then
            self:PlayVariant(rig.variant, style, "enter", size, showCaption and rig.title, rig.caption)
        else
            if style == "CREST" then
                if not rig.factionCrest then
                    rig.icon:SetTexture(glyphs)
                    rig.icon:SetTexCoord(.25, .50, 0, 1)
                end
            else
                SetCell(rig.icon, style == "PULSE" and 0 or 1)
            end
            rig.icon:SetSize(size, size)
            rig.icon:ClearAllPoints()
            rig.icon:SetPoint("CENTER", rig.base, "CENTER", 0, rig.variant.y)
            rig.pop:SetScaleFrom(reduced and 1 or .83, reduced and 1 or .83)
            rig.pop:SetScaleTo(reduced and 1 or 1.07, reduced and 1 or 1.07)
            rig.settle:SetScaleFrom(reduced and 1 or 1.07, reduced and 1 or 1.07)
            rig.icon:Show()
            rig.grow:Play()
            if style == "PULSE" and not reduced then
                rig.ring:SetSize(size, size)
                rig.ring:ClearAllPoints()
                rig.ring:SetPoint("CENTER", rig.icon)
                rig.ring:Show()
                rig.flash:Play()
            end
        end
    end
    return true
end

function M:PlayExtraAlert(kind, detail)
    return Play(self, kind, detail, false)
end

function M:PreviewExtraAlert(kind)
    local detail = kind == "healthAlert" and math.floor(Clamp(self:GetExtraAlertProfile(kind).threshold, 5, 90, 25))
    return Play(self, kind, detail, true)
end
