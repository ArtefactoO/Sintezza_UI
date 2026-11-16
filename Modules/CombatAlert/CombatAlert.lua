local _, SUI = ...
local Text = SUI.Text
local sharedTheme = Sintezza_Theme

local M = SUI:RegisterModule("combatAlert", {
    title = Text("Сигнал боя", "Combat alert"),
    playSerial = 0,
    eventSerial = 0,
})
SUI.CombatAlert = M

M.textPresets = {
    enterText = {
        ["В БОЙ"] = Text("В БОЙ", "IN COMBAT"),
        ["БОЙ НАЧАЛСЯ"] = Text("БОЙ НАЧАЛСЯ", "COMBAT STARTED"),
        ["СРАЖЕНИЕ"] = Text("СРАЖЕНИЕ", "FIGHT"),
    },
    leaveText = {
        ["БОЙ ОКОНЧЕН"] = Text("БОЙ ОКОНЧЕН", "COMBAT ENDED"),
        ["ВНЕ БОЯ"] = Text("ВНЕ БОЯ", "OUT OF COMBAT"),
        ["КОНЕЦ БОЯ"] = Text("КОНЕЦ БОЯ", "END OF COMBAT"),
    },
    stealthEnterText = {
        ["СКРЫТНОСТЬ"] = Text("СКРЫТНОСТЬ", "STEALTH"),
        ["НЕВИДИМОСТЬ"] = Text("НЕВИДИМОСТЬ", "INVISIBLE"),
        ["+ СКРЫТНОСТЬ"] = Text("+ СКРЫТНОСТЬ", "+ STEALTH"),
    },
    stealthLeaveText = {
        ["СКРЫТНОСТЬ СНЯТА"] = Text("СКРЫТНОСТЬ СНЯТА", "STEALTH ENDED"),
        ["ВИДИМ"] = Text("ВИДИМ", "VISIBLE"),
        ["- СКРЫТНОСТЬ"] = Text("- СКРЫТНОСТЬ", "- STEALTH"),
    },
}

function M:GetAlertText(field)
    local profile = self:Profile()
    local custom = profile and type(profile.customText) == "table" and profile.customText[field]
    if type(custom) == "string" and custom ~= "" then return custom end
    local choice = profile and profile[field]
    if type(choice) ~= "string" or choice == "" then choice = SUI.defaults.modules.combatAlert[field] end
    return self.textPresets[field][choice] or choice
end

function M:SetAlertText(field, value)
    local profile = self:Profile()
    if not profile or not self.textPresets[field] or type(value) ~= "string" then return end
    local text = value:gsub("%c", " "):match("^%s*(.-)%s*$")
    if text == self:GetAlertText(field) then return end
    if type(profile.customText) ~= "table" then profile.customText = {} end
    profile.customText[field] = text ~= "" and text or nil
    if text == "" then profile[field] = SUI.defaults.modules.combatAlert[field] end
    if field == "stealthEnterText" then self:RefreshStealthState() end
end

local function PlainText(text)
    return (text:gsub("|", "||"))
end

local SWORD_TEXTURE = "Interface\\AddOns\\Sintezza_UI\\Media\\CombatAlert\\sword.png"
local STEALTH_TEXTURE = "Interface\\AddOns\\Sintezza_UI\\Media\\CombatAlert\\stealth-eye.png"
local GLYPH_TEXTURE = "Interface\\AddOns\\Sintezza_UI\\Media\\CombatAlert\\signal-glyphs.png"
local IMPACT_TEXTURE = "Interface\\Cooldown\\star4"
local glyphs = {
    SEAL = { column = 0, startScale = .58, startY = 0, startAngle = -34 },
    CREST = { column = 1, startScale = .88, startY = 17, startAngle = 0 },
    EMBERS = { column = 2, startScale = .70, startY = -10, startAngle = 0 },
    SLASH = { column = 3, startScale = .12, startY = 0, startAngle = 0 },
}
local sparks = {
    { -.23, .08, -12, 20 }, { .21, .16, 18, 16 },
    { .12, .37, 9, 22 }, { -.15, .31, -11, 13 },
}

local function Clamp(value, minimum, maximum, fallback)
    value = tonumber(value) or fallback
    return math.max(minimum, math.min(maximum, value))
end

local function ColorValues(value, fallback)
    value = type(value) == "table" and value or fallback
    return tonumber(value.r or value[1]) or fallback[1],
        tonumber(value.g or value[2]) or fallback[2],
        tonumber(value.b or value[3]) or fallback[3],
        tonumber(value.a or value[4]) or fallback[4] or 1
end

local function SignalColor(profile, value, fallback, departing)
    if profile.useThemeColors == false then
        local r, g, b, a = ColorValues(value, fallback)
        return r, g, b, a, r, g, b
    end
    local r, g, b = ColorValues(SUI.SettingsTheme.accent, fallback)
    -- Exit captions are paler, while both states retain the same palette accent.
    local white = departing and .46 or .30
    return r, g, b, 1, white + r * (1 - white), white + g * (1 - white), white + b * (1 - white)
end

local function SetAnimationSmoothing(animation, smoothing)
    if animation and animation.SetSmoothing then animation:SetSmoothing(smoothing) end
end

function M:Profile()
    return SUI:GetModuleProfile("combatAlert")
end

function M:GetVisualStyle(profile)
    local style = (profile or self:Profile() or {}).visualStyle
    return (glyphs[style] or self:HasVisualVariant(style, false)) and style or "SWORDS"
end

function M:GetStealthVisualStyle(profile)
    local style = (profile or self:Profile() or {}).stealthVisualStyle
    return (glyphs[style] or self:HasVisualVariant(style, true)) and style or "EYE"
end

function M:RegisterAnimation(animation, duration, delay)
    self.animations[#self.animations + 1] = animation
    animation.__suiDuration = duration
    animation.__suiDelay = delay or 0
    animation:SetDuration(duration)
    if animation.SetStartDelay then animation:SetStartDelay(delay or 0) end
    return animation
end

function M:NewAlpha(group, order, fromAlpha, toAlpha, duration, delay)
    local animation = self:RegisterAnimation(group:CreateAnimation("Alpha"), duration, delay)
    animation:SetOrder(order)
    animation:SetFromAlpha(fromAlpha)
    animation:SetToAlpha(toAlpha)
    return animation
end

function M:NewScale(group, order, fromScale, toScale, duration, delay)
    local animation = self:RegisterAnimation(group:CreateAnimation("Scale"), duration, delay)
    animation:SetOrder(order)
    animation:SetScaleFrom(fromScale, fromScale)
    animation:SetScaleTo(toScale, toScale)
    if animation.SetOrigin then animation:SetOrigin("CENTER", 0, 0) end
    SetAnimationSmoothing(animation, "OUT")
    return animation
end

function M:NewScaleXY(group, order, fromX, fromY, toX, toY, duration, delay)
    local animation = self:RegisterAnimation(group:CreateAnimation("Scale"), duration, delay)
    animation:SetOrder(order)
    animation:SetScaleFrom(fromX, fromY)
    animation:SetScaleTo(toX, toY)
    if animation.SetOrigin then animation:SetOrigin("CENTER", 0, 0) end
    SetAnimationSmoothing(animation, "OUT")
    return animation
end
function M:NewTranslation(group, order, duration)
    local animation = self:RegisterAnimation(group:CreateAnimation("Translation"), duration)
    animation:SetOrder(order)
    SetAnimationSmoothing(animation, "OUT")
    return animation
end

function M:NewRotation(group, order, duration)
    local animation = self:RegisterAnimation(group:CreateAnimation("Rotation"), duration)
    animation:SetOrder(order)
    if animation.SetOrigin then animation:SetOrigin("CENTER", 0, 0) end
    SetAnimationSmoothing(animation, "OUT")
    return animation
end

function M:BuildSwordGroups(texture)
    local enter = texture:CreateAnimationGroup()
    enter.fadeIn = self:NewAlpha(enter, 1, 0, 1, .10)
    enter.move = self:NewTranslation(enter, 1, .22)
    enter.rotation = self:NewRotation(enter, 1, .22)
    enter.scale = self:NewScale(enter, 1, .90, 1, .22)
    enter.hold = self:NewAlpha(enter, 2, 1, 1, .58)
    enter.fadeOut = self:NewAlpha(enter, 3, 1, 0, .30)

    local leave = texture:CreateAnimationGroup()
    leave.fadeIn = self:NewAlpha(leave, 1, 0, 1, .16)
    leave.hold = self:NewAlpha(leave, 2, 1, 1, .42)
    leave.move = self:NewTranslation(leave, 3, .34)
    leave.rotation = self:NewRotation(leave, 3, .34)
    leave.fadeOut = self:NewAlpha(leave, 3, 1, 0, .34)

    local function HideTexture() texture:Hide() end
    enter:SetScript("OnFinished", HideTexture)
    leave:SetScript("OnFinished", HideTexture)

    self.groups[#self.groups + 1] = enter
    self.groups[#self.groups + 1] = leave
    return { enter = enter, leave = leave }
end

function M:BuildTextGroups(frame)
    local enter = frame:CreateAnimationGroup()
    enter.fadeIn = self:NewAlpha(enter, 1, 0, 1, .16, .13)
    enter.punch = self:NewScale(enter, 1, .84, 1.08, .16, .13)
    enter.settle = self:NewScale(enter, 2, 1.08, 1, .10)
    enter.hold = self:NewAlpha(enter, 3, 1, 1, .42)
    enter.fadeOut = self:NewAlpha(enter, 4, 1, 0, .28)

    local leave = frame:CreateAnimationGroup()
    leave.fadeIn = self:NewAlpha(leave, 1, 0, 1, .18)
    leave.punch = self:NewScale(leave, 1, .94, 1.02, .18)
    leave.settle = self:NewScale(leave, 2, 1.02, 1, .10)
    leave.hold = self:NewAlpha(leave, 2, 1, 1, .48)
    leave.fadeOut = self:NewAlpha(leave, 3, 1, 0, .32)

    local function Finish(group)
        if M.playSerial == group.__suiSerial and M.frame then M.frame:Hide() end
    end
    enter:SetScript("OnFinished", Finish)
    leave:SetScript("OnFinished", Finish)
    self.groups[#self.groups + 1] = enter
    self.groups[#self.groups + 1] = leave
    return { enter = enter, leave = leave }
end

function M:BuildImpactGroup(texture)
    local group = texture:CreateAnimationGroup()
    group.fadeIn = self:NewAlpha(group, 1, 0, 1, .10, .17)
    group.bloom = self:NewScale(group, 1, .35, 1.18, .10, .17)
    group.fadeOut = self:NewAlpha(group, 2, 1, 0, .18)
    group:SetScript("OnFinished", function() texture:Hide() end)
    self.groups[#self.groups + 1] = group
    return group
end

function M:BuildGlyph(frame, y, groups)
    local holder = CreateFrame("Frame", nil, frame)
    holder:SetFrameLevel(frame:GetFrameLevel() + 2)
    holder:EnableMouse(false)
    holder:Hide()

    local glow = holder:CreateTexture(nil, "BACKGROUND")
    glow:SetTexture(IMPACT_TEXTURE)
    glow:SetBlendMode("ADD")
    glow:SetPoint("CENTER")
    local art = holder:CreateTexture(nil, "ARTWORK")
    art:SetAllPoints()
    art:SetTexture(GLYPH_TEXTURE)
    local enter, leave = holder:CreateAnimationGroup(), holder:CreateAnimationGroup()
    local turnGroup = art:CreateAnimationGroup()
    self:NewAlpha(enter, 1, 0, 1, .16)
    local rise = self:NewTranslation(enter, 1, .40)
    local turn = self:NewRotation(turnGroup, 1, .40)
    local scale = self:NewScale(enter, 1, 1, 1, .40)
    self:NewAlpha(enter, 2, 1, 1, .42)
    self:NewAlpha(enter, 3, 1, 0, .26)
    self:NewAlpha(leave, 1, 0, 1, .16)
    self:NewAlpha(leave, 2, 1, 1, .44)
    local drift = self:NewTranslation(leave, 3, .30)
    self:NewAlpha(leave, 3, 1, 0, .30)
    local function Hide() holder:Hide() end
    enter:SetScript("OnFinished", Hide)
    leave:SetScript("OnFinished", Hide)
    groups[#groups + 1] = enter
    groups[#groups + 1] = leave
    groups[#groups + 1] = turnGroup

    local particles = {}
    for index, offsets in ipairs(sparks) do
        local texture = holder:CreateTexture(nil, "OVERLAY")
        texture:SetColorTexture(1, 1, 1, 1)
        texture:SetSize(4, 4)
        texture:SetRotation(math.pi / 4)
        local spread = texture:CreateAnimationGroup()
        local move = self:NewTranslation(spread, 1, .60)
        move:SetOffset(offsets[3], offsets[4])
        self:NewAlpha(spread, 1, 0, .95, .14)
        self:NewAlpha(spread, 2, .95, 0, .28)
        groups[#groups + 1] = spread
        particles[index] = { texture = texture, spread = spread }
    end
    return { base = frame, y = y, groups = groups, holder = holder, art = art, glow = glow, enter = enter, leave = leave,
        rise = rise, turn = turn, turnGroup = turnGroup, scale = scale, drift = drift, particles = particles }
end

local function TintGlyph(rig, r, g, b, a, glow)
    rig.art:SetVertexColor(r, g, b, a)
    rig.glow:SetVertexColor(r, g, b, glow)
    rig.opacity = a
    if rig.emblem then rig.emblem:SetAlpha(a) end
    for _, particle in ipairs(rig.particles) do particle.texture:SetVertexColor(r, g, b, a) end
    M:TintVariant(rig, r, g, b, a, glow)
end

function M:ApplyFactionEmblem(emblem)
    if type(UnitFactionGroup) ~= "function" or not Sintezza_Theme.GetFactionCrest then return false end
    local texture = Sintezza_Theme:GetFactionCrest(UnitFactionGroup("player"))
    if not texture or not emblem:SetTexture(texture) then return false end
    emblem:SetTexCoord(0, 1, 0, 1)
    return true
end

local function ApplyFactionCrest(rig, size)
    if not rig.emblem then
        rig.emblem = rig.holder:CreateTexture(nil, "ARTWORK")
        rig.emblem:SetPoint("CENTER")
    end
    if not M:ApplyFactionEmblem(rig.emblem) then return false end
    rig.emblem:SetSize(size * .80, size * .80)
    rig.emblem:SetAlpha(rig.opacity or 1)
    return true
end

function M:PlayGlyph(rig, style, kind, size, textAnchor, text)
    local spec = glyphs[style]
    if not spec then return self:PlayVariant(rig, style, kind, size, textAnchor, text) end
    local reduced = (self:Profile() or {}).reducedMotion == true
    local entering = kind == "enter"
    local startY = entering and not reduced and spec.startY or 0
    local startAngle = entering and not reduced and spec.startAngle or 0
    local startScale = entering and not reduced and spec.startScale or 1
    local slash = style == "SLASH"
    local anchoredToText = slash and textAnchor
    local holder = rig.holder
    local width, height = size, size
    if slash then
        local textWidth = anchoredToText and text:GetStringWidth() or 0
        width = math.min(rig.base:GetWidth(), math.max(size * 2.5, textWidth + 50))
        height = math.max(38, size * .66)
    end
    holder:SetSize(width, height)
    rig.glow:SetSize(size, size)
    holder:ClearAllPoints()
    holder:SetPoint("CENTER", anchoredToText or rig.base, "CENTER", 0, (anchoredToText and 0 or rig.y) + startY)
    rig.art:SetTexCoord(spec.column / 4, (spec.column + 1) / 4, slash and .20 or 0, slash and .83 or 1)
    rig.art:SetRotation(math.rad(startAngle))
    local factionCrest = style == "CREST" and ApplyFactionCrest(rig, size)
    rig.art:SetShown(not factionCrest)
    if rig.emblem then rig.emblem:SetShown(factionCrest) end
    rig.rise:SetOffset(0, -startY)
    rig.turn:SetDegrees(-startAngle)
    rig.scale:SetScaleFrom(startScale, slash and 1 or startScale)
    rig.scale:SetScaleTo(1, 1)
    rig.drift:SetOffset(0, reduced and 0 or style == "EMBERS" and 8 or -6)

    local showSparks = style == "EMBERS" and not reduced
    for index, particle in ipairs(rig.particles) do
        particle.texture:SetShown(showSparks)
        if showSparks then
            local offsets = sparks[index]
            particle.texture:ClearAllPoints()
            particle.texture:SetPoint("CENTER", holder, "CENTER", offsets[1] * size, offsets[2] * size)
        end
    end
    holder:Show()
    local group = entering and rig.enter or rig.leave
    group:Play()
    if startAngle ~= 0 then rig.turnGroup:Play() end
    if showSparks then
        for _, particle in ipairs(rig.particles) do particle.spread:Play() end
    end
end

function M:BuildStealthIconGroups(frame)
    local enter = frame:CreateAnimationGroup()
    enter.fadeIn = self:NewAlpha(enter, 1, 0, 1, .10)
    enter.reveal = self:NewScaleXY(enter, 1, .82, .55, 1, 1, .14)
    enter.hold = self:NewAlpha(enter, 2, 1, 1, .14)
    enter.close = self:NewScaleXY(enter, 3, 1, 1, 1.15, .08, .24)
    enter.fadeOut = self:NewAlpha(enter, 3, 1, 0, .24)

    local leave = frame:CreateAnimationGroup()
    leave.fadeIn = self:NewAlpha(leave, 1, 0, 1, .12)
    leave.open = self:NewScaleXY(leave, 1, 1.12, .08, 1, 1, .22)
    leave.hold = self:NewAlpha(leave, 2, 1, 1, .28)
    leave.fadeOut = self:NewAlpha(leave, 3, 1, 0, .24)

    local function HideIcon() frame:Hide() end
    enter:SetScript("OnFinished", HideIcon)
    leave:SetScript("OnFinished", HideIcon)
    self.stealthGroups[#self.stealthGroups + 1] = enter
    self.stealthGroups[#self.stealthGroups + 1] = leave
    return { enter = enter, leave = leave }
end

function M:BuildStealthTextGroups(frame)
    local enter = frame:CreateAnimationGroup()
    enter.fadeIn = self:NewAlpha(enter, 1, 0, 1, .12, .06)
    enter.scale = self:NewScale(enter, 1, .90, 1, .12, .06)
    enter.hold = self:NewAlpha(enter, 2, 1, 1, .28)
    enter.fadeOut = self:NewAlpha(enter, 3, 1, 0, .20)

    local leave = frame:CreateAnimationGroup()
    leave.fadeIn = self:NewAlpha(leave, 1, 0, 1, .12)
    leave.scale = self:NewScale(leave, 1, .92, 1.03, .12)
    leave.settle = self:NewScale(leave, 2, 1.03, 1, .08)
    leave.hold = self:NewAlpha(leave, 2, 1, 1, .40)
    leave.fadeOut = self:NewAlpha(leave, 3, 1, 0, .22)

    local function Finish(group)
        if M.stealthPlaySerial == group.__suiSerial then M:RefreshStealthState() end
    end
    enter:SetScript("OnFinished", Finish)
    leave:SetScript("OnFinished", Finish)
    self.stealthGroups[#self.stealthGroups + 1] = enter
    self.stealthGroups[#self.stealthGroups + 1] = leave
    return { enter = enter, leave = leave }
end
function M:EnsureFrame()
    if self.frame then return self.frame end
    self.groups, self.animations = {}, self.animations or {}

    local frame = CreateFrame("Frame", "Sintezza_UICombatAlertFrame", UIParent)
    frame:SetSize(420, 220)
    frame:SetFrameStrata("HIGH")
    frame:SetFrameLevel(40)
    frame:EnableMouse(false)
    frame:Hide()

    local left = frame:CreateTexture(nil, "ARTWORK", nil, 1)
    left:SetTexture(SWORD_TEXTURE)
    left:SetBlendMode("BLEND")
    local right = frame:CreateTexture(nil, "ARTWORK", nil, 1)
    right:SetTexture(SWORD_TEXTURE)
    right:SetBlendMode("BLEND")

    local impact = frame:CreateTexture(nil, "OVERLAY", nil, 2)
    impact:SetTexture(IMPACT_TEXTURE)
    impact:SetBlendMode("ADD")
    impact:SetPoint("CENTER", frame, "CENTER", 0, 18)
    impact:Hide()

    local textFrame = CreateFrame("Frame", nil, frame)
    textFrame:SetSize(400, 64)
    textFrame:SetPoint("CENTER", frame, "CENTER", 0, -54)
    textFrame:SetFrameLevel(frame:GetFrameLevel() + 4)
    textFrame:EnableMouse(false)

    local text = textFrame:CreateFontString(nil, "OVERLAY")
    text:SetPoint("LEFT")
    text:SetPoint("RIGHT")
    text:SetWordWrap(false)
    text:SetJustifyH("CENTER")
    text:SetShadowColor(0, 0, 0, 1)
    text:SetShadowOffset(2, -2)

    self.frame = frame
    self.leftSword, self.rightSword = left, right
    self.impact = impact
    self.textFrame, self.text = textFrame, text
    self.leftGroups = self:BuildSwordGroups(left)
    self.rightGroups = self:BuildSwordGroups(right)
    self.glyph = self:BuildGlyph(frame, 18, self.groups)
    self.textGroups = self:BuildTextGroups(textFrame)
    self.impactGroup = self:BuildImpactGroup(impact)
    sharedTheme:TrackAppearance(frame, "state", function() self:ApplySceneColor(self.sceneKind or "enter") end)
    self:ApplyAppearance()
    return frame
end

function M:EnsureStealthFrame()
    if self.stealthFrame then return self.stealthFrame end
    self:EnsureFrame()
    self.stealthGroups = {}

    local frame = CreateFrame("Frame", "Sintezza_UIStealthAlertFrame", UIParent)
    frame:SetSize(280, 128)
    frame:SetFrameStrata("HIGH")
    frame:SetFrameLevel(39)
    frame:EnableMouse(false)
    frame:Hide()

    local iconFrame = CreateFrame("Frame", nil, frame)
    iconFrame:SetSize(62, 62)
    iconFrame:SetPoint("CENTER", frame, "CENTER", 0, 17)
    iconFrame:SetFrameLevel(frame:GetFrameLevel() + 2)
    iconFrame:EnableMouse(false)

    local glow = iconFrame:CreateTexture(nil, "ARTWORK", nil, 1)
    glow:SetTexture(IMPACT_TEXTURE)
    glow:SetBlendMode("ADD")
    glow:SetAllPoints(iconFrame)
    local eye = iconFrame:CreateTexture(nil, "OVERLAY", nil, 2)
    eye:SetTexture(STEALTH_TEXTURE)
    eye:SetAllPoints(iconFrame)
    eye:SetBlendMode("BLEND")

    local textFrame = CreateFrame("Frame", nil, frame)
    textFrame:SetSize(270, 42)
    textFrame:SetPoint("CENTER", frame, "CENTER", 0, -34)
    textFrame:SetFrameLevel(frame:GetFrameLevel() + 3)
    textFrame:EnableMouse(false)
    local text = textFrame:CreateFontString(nil, "OVERLAY")
    text:SetPoint("LEFT")
    text:SetPoint("RIGHT")
    text:SetWordWrap(false)
    text:SetJustifyH("CENTER")
    text:SetShadowColor(0, 0, 0, 1)
    text:SetShadowOffset(1, -1)

    self.stealthFrame = frame
    self.stealthIconFrame, self.stealthEye, self.stealthGlow = iconFrame, eye, glow
    self.stealthTextFrame, self.stealthText = textFrame, text
    self.stealthGlyph = self:BuildGlyph(frame, 17, self.stealthGroups)
    self.stealthIconGroups = self:BuildStealthIconGroups(iconFrame)
    self.stealthTextGroups = self:BuildStealthTextGroups(textFrame)
    sharedTheme:TrackAppearance(frame, "state", function() self:ApplyStealthColor(self.stealthSceneActive) end)
    self:ApplyStealthAppearance()
    return frame
end
function M:GetAnimationSpeed()
    local profile = self:Profile() or {}
    return Clamp(profile.speed, .50, 1.75, 1)
end

function M:ApplyAnimationSpeed()
    local speed = self:GetAnimationSpeed()
    for _, animation in ipairs(self.animations or {}) do
        animation:SetDuration(animation.__suiDuration / speed)
        if animation.SetStartDelay then animation:SetStartDelay(animation.__suiDelay / speed) end
    end
end

local function ApplySignalFont(region, selection, size)
    local combatFont = SUI:GetModule("combatFont")
    if combatFont and combatFont:ApplyToAlert(region, size, "OUTLINE") then return end
    SUI.Theme:ApplyTextFont(region, selection, size, "OUTLINE")
end

function M:ApplyAppearance(kind)
    if not self.frame then return end
    local profile = self:Profile() or {}
    local size = Clamp(profile.fontSize, 20, 52, 32)
    local swordSize = Clamp(profile.swordSize, 56, 148, 94)
    ApplySignalFont(self.text, profile.font, size)
    self.leftSword:SetSize(swordSize, swordSize)
    self.rightSword:SetSize(swordSize, swordSize)
    local impactSize = math.max(38, swordSize * .72)
    self.impact:SetSize(impactSize, impactSize)
    self.frame:ClearAllPoints()
    self.frame:SetPoint("CENTER", UIParent, "CENTER",
        Clamp(profile.x, -600, 600, 0), Clamp(profile.y, -400, 400, 115))
    self:ApplyAnimationSpeed()
    if kind then self:ApplySceneColor(kind) end
end

function M:ApplySceneColor(kind)
    local profile = self:Profile() or {}
    local fallback = kind == "enter" and { .98, .36, .10, 1 } or { .12, .84, .70, 1 }
    local color = kind == "enter" and profile.enterColor or profile.leaveColor
    self.sceneKind = kind
    local r, g, b, a, captionR, captionG, captionB = SignalColor(profile, color, fallback, kind == "leave")
    local glow = Clamp(profile.glowIntensity, 0, 1, .72)
    self.text:SetTextColor(captionR, captionG, captionB, a)
    self.leftSword:SetVertexColor(r, g, b, math.min(1, a * .88))
    self.rightSword:SetVertexColor(r, g, b, math.min(1, a * .88))
    self.impact:SetVertexColor(r, g, b, glow)
    TintGlyph(self.glyph, r, g, b, a, glow * .32)
end
function M:ApplyStealthAppearance(active)
    if not self.stealthFrame then return end
    local profile = self:Profile() or {}
    local size = Clamp(profile.stealthFontSize, 12, 30, 19)
    local iconSize = Clamp(profile.stealthIconSize, 42, 88, 58)
    ApplySignalFont(self.stealthText, profile.stealthFont, size)
    self.stealthIconFrame:SetSize(iconSize, iconSize)
    self.stealthFrame:ClearAllPoints()
    self.stealthFrame:SetPoint("CENTER", UIParent, "CENTER",
        Clamp(profile.stealthX, -600, 600, 0), Clamp(profile.stealthY, -400, 400, 35))
    self:ApplyAnimationSpeed()
    if active ~= nil then self:ApplyStealthColor(active) end
end

function M:ApplyStealthColor(active)
    local profile = self:Profile() or {}
    local fallback = active and { .58, .38, .98, 1 } or { .62, .76, .88, 1 }
    local color = active and profile.stealthEnterColor or profile.stealthLeaveColor
    self.stealthSceneActive = active
    local r, g, b, a, captionR, captionG, captionB = SignalColor(profile, color, fallback, active == false)
    local glow = Clamp(profile.stealthGlowIntensity, 0, 1, .42)
    self.stealthText:SetTextColor(captionR, captionG, captionB, a)
    self.stealthEye:SetVertexColor(r, g, b, math.min(1, a * .94))
    self.stealthGlow:SetVertexColor(r, g, b, glow)
    TintGlyph(self.stealthGlyph, r, g, b, a, glow * .52)
end

function M:RefreshSignalColors()
    if self.frame then self:ApplySceneColor(self.sceneKind or "enter") end
    if self.stealthFrame then self:ApplyStealthColor(self.stealthSceneActive) end
end

function M:StopAnimations()
    for _, group in ipairs(self.groups or {}) do
        if group:IsPlaying() then group:Stop() end
    end
    if self.frame then
        self.frame:Hide()
        self.leftSword:SetAlpha(1)
        self.rightSword:SetAlpha(1)
        self.textFrame:SetAlpha(1)
        self.impact:SetAlpha(1)
        self.impact:Hide()
        self.glyph.holder:Hide()
        self:HideVariant(self.glyph)
    end
end
function M:StopStealthAnimations()
    for _, group in ipairs(self.stealthGroups or {}) do
        if group:IsPlaying() then group:Stop() end
    end
    if self.stealthFrame then
        self.stealthFrame:Hide()
        self.stealthIconFrame:SetAlpha(1)
        self.stealthTextFrame:SetAlpha(1)
        self.stealthGlyph.holder:Hide()
        self:HideVariant(self.stealthGlyph)
    end
end

function M:ConfigureStealthScene(active)
    local profile = self:Profile() or {}
    local reduced = profile.reducedMotion == true
    local iconGroup = active and self.stealthIconGroups.enter or self.stealthIconGroups.leave
    local textGroup = active and self.stealthTextGroups.enter or self.stealthTextGroups.leave
    if active then
        if reduced then
            iconGroup.reveal:SetScaleFrom(1, 1); iconGroup.reveal:SetScaleTo(1, 1)
            iconGroup.close:SetScaleFrom(1, 1); iconGroup.close:SetScaleTo(1, 1)
            textGroup.scale:SetScaleFrom(1, 1); textGroup.scale:SetScaleTo(1, 1)
        else
            iconGroup.reveal:SetScaleFrom(.82, .55); iconGroup.reveal:SetScaleTo(1, 1)
            iconGroup.close:SetScaleFrom(1, 1); iconGroup.close:SetScaleTo(1.15, .08)
            textGroup.scale:SetScaleFrom(.90, .90); textGroup.scale:SetScaleTo(1, 1)
        end
    else
        if reduced then
            iconGroup.open:SetScaleFrom(1, 1); iconGroup.open:SetScaleTo(1, 1)
            textGroup.scale:SetScaleFrom(1, 1); textGroup.scale:SetScaleTo(1, 1)
            textGroup.settle:SetScaleFrom(1, 1); textGroup.settle:SetScaleTo(1, 1)
        else
            iconGroup.open:SetScaleFrom(1.12, .08); iconGroup.open:SetScaleTo(1, 1)
            textGroup.scale:SetScaleFrom(.92, .92); textGroup.scale:SetScaleTo(1.03, 1.03)
            textGroup.settle:SetScaleFrom(1.03, 1.03); textGroup.settle:SetScaleTo(1, 1)
        end
    end
    self.stealthText:SetText(PlainText(self:GetAlertText(active and "stealthEnterText" or "stealthLeaveText")))
end

function M:PlayStealth(active, preview)
    self:StopStealthAnimations()
    local profile = self:Profile()
    if not profile then return false end
    if not preview and (profile.enabled == false or profile.stealthEnabled == false) then return false end
    if active and not preview and profile.showStealthEnter == false then return false end
    if not active and not preview and profile.showStealthLeave == false then return false end

    self:EnsureFrame()
    self:EnsureStealthFrame()
    self.stealthPlaySerial = (self.stealthPlaySerial or 0) + 1
    local serial = self.stealthPlaySerial
    self:ApplyStealthAppearance(active)
    self:ConfigureStealthScene(active)
    self.stealthFrame:Show()

    local style = self:GetStealthVisualStyle(profile)
    if style == "EYE" then
        self.stealthIconFrame:Show()
        local iconGroup = active and self.stealthIconGroups.enter or self.stealthIconGroups.leave
        iconGroup:Play()
    else
        self.stealthIconFrame:Hide()
        self:PlayGlyph(self.stealthGlyph, style, active and "enter" or "leave",
            Clamp(profile.stealthIconSize, 42, 88, 58), self.stealthTextFrame, self.stealthText)
    end
    local textGroup = active and self.stealthTextGroups.enter or self.stealthTextGroups.leave
    textGroup.__suiSerial = serial
    if active then textGroup.fadeOut:SetToAlpha(preview and 0 or 1) end
    textGroup:Play()
    return true
end

-- Restore the steady label after animations, previews, reloads and profile changes.
-- No animation or timer remains active while the player stays stealthed.
function M:RefreshStealthState()
    self.stealthPlaySerial = (self.stealthPlaySerial or 0) + 1
    self:StopStealthAnimations()
    local profile = self:Profile()
    if not profile or profile.enabled == false or profile.stealthEnabled == false then
        self.stealthed = false
        return
    end
    self.stealthed = self:GetStealthState()
    if not self.stealthed or profile.showStealthEnter == false then return end
    self:EnsureStealthFrame()
    self:ApplyStealthAppearance(true)
    self:ConfigureStealthScene(true)
    self.stealthIconFrame:Hide()
    self.stealthTextFrame:SetAlpha(1)
    self.stealthFrame:Show()
end

function M:PreviewStealth(active)
    self.stealthEventSerial = (self.stealthEventSerial or 0) + 1
    return self:PlayStealth(active == true, true)
end

function M:ConfigureScene(kind)
    local profile = self:Profile() or {}
    local distance = Clamp(profile.swordDistance, 30, 150, 84)
    local reduced = profile.reducedMotion == true
    local leftX, rightX = 0, 0
    local leftAngle, rightAngle = 45, -45
    local leftMove, rightMove, leftTurn, rightTurn = 0, 0, 0, 0

    if kind == "enter" and not reduced then
        leftX, rightX = -distance, distance
        leftAngle, rightAngle = -16, 16
        leftMove, rightMove = distance, -distance
        leftTurn, rightTurn = 61, -61
    elseif kind == "leave" and not reduced then
        leftMove, rightMove = -distance, distance
        leftTurn, rightTurn = -61, 61
    end

    self.leftSword:ClearAllPoints()
    self.leftSword:SetPoint("CENTER", self.frame, "CENTER", leftX, 18)
    self.rightSword:ClearAllPoints()
    self.rightSword:SetPoint("CENTER", self.frame, "CENTER", rightX, 18)
    self.leftSword:SetRotation(math.rad(leftAngle))
    self.rightSword:SetRotation(math.rad(rightAngle))

    local leftGroup = self.leftGroups[kind]
    local rightGroup = self.rightGroups[kind]
    leftGroup.move:SetOffset(leftMove, 0)
    rightGroup.move:SetOffset(rightMove, 0)
    leftGroup.rotation:SetDegrees(leftTurn)
    rightGroup.rotation:SetDegrees(rightTurn)
    if kind == "enter" then
        local startScale = reduced and 1 or .90
        leftGroup.scale:SetScaleFrom(startScale, startScale); leftGroup.scale:SetScaleTo(1, 1)
        rightGroup.scale:SetScaleFrom(startScale, startScale); rightGroup.scale:SetScaleTo(1, 1)
    end


    local textGroup = self.textGroups[kind]
    if reduced then
        if kind == "enter" then
            textGroup.punch:SetScaleFrom(1, 1); textGroup.punch:SetScaleTo(1, 1)
            textGroup.settle:SetScaleFrom(1, 1); textGroup.settle:SetScaleTo(1, 1)
        else
            textGroup.punch:SetScaleFrom(1, 1); textGroup.punch:SetScaleTo(1, 1)
            textGroup.settle:SetScaleFrom(1, 1); textGroup.settle:SetScaleTo(1, 1)
        end
    elseif kind == "enter" then
        textGroup.punch:SetScaleFrom(.84, .84); textGroup.punch:SetScaleTo(1.08, 1.08)
        textGroup.settle:SetScaleFrom(1.08, 1.08); textGroup.settle:SetScaleTo(1, 1)
    else
        textGroup.punch:SetScaleFrom(.94, .94); textGroup.punch:SetScaleTo(1.02, 1.02)
        textGroup.settle:SetScaleFrom(1.02, 1.02); textGroup.settle:SetScaleTo(1, 1)
    end
end

function M:Play(kind, preview)
    local profile = self:Profile()
    if not profile then return false end
    if not preview and profile.enabled == false then return false end
    if kind == "enter" and not preview and profile.showEnter == false then return false end
    if kind == "leave" and not preview and profile.showLeave == false then return false end

    self:EnsureFrame()
    self.playSerial = self.playSerial + 1
    local serial = self.playSerial
    self:StopAnimations()
    self:ApplyAppearance(kind)

    local style = profile.style or "BOTH"
    local shape = self:GetVisualStyle(profile)
    local showEffect = style ~= "TEXT"
    local showSwords = showEffect and shape == "SWORDS"
    local showText = style ~= "SWORDS"
    self:ConfigureScene(kind)
    self.leftSword:SetShown(showSwords)
    self.rightSword:SetShown(showSwords)
    self.text:SetShown(showText)
    self.text:SetText(PlainText(self:GetAlertText(kind == "enter" and "enterText" or "leaveText")))
    self.frame:Show()

    local textGroup = self.textGroups[kind]
    textGroup.__suiSerial = serial
    textGroup:Play()
    if showSwords then
        self.leftGroups[kind]:Play()
        self.rightGroups[kind]:Play()
    elseif showEffect then
        self:PlayGlyph(self.glyph, shape, kind, Clamp(profile.swordSize, 56, 148, 94),
            showText and self.textFrame, self.text)
    end
    if showSwords and kind == "enter" and profile.reducedMotion ~= true
        and Clamp(profile.glowIntensity, 0, 1, .72) > 0 then
        self.impact:Show()
        self.impactGroup:Play()
    end
    return true
end

function M:Preview(kind)
    self.eventSerial = self.eventSerial + 1
    return self:Play(kind == "leave" and "leave" or "enter", true)
end

function M:GetStealthState()
    if type(IsStealthed) ~= "function" then return false end
    local ok, value = pcall(IsStealthed)
    return ok and value == true
end

function M:OnEvent(event)
    local profile = self:Profile()
    if event == "PLAYER_ENTERING_WORLD" then
        self.stealthEventSerial = (self.stealthEventSerial or 0) + 1
        self:RefreshStealthState()
        return
    elseif event == "UPDATE_STEALTH" then
        local current = self:GetStealthState()
        local previous = self.stealthed
        self.stealthed = current
        if previous == current then return end
        self.stealthPlaySerial = (self.stealthPlaySerial or 0) + 1
        self:StopStealthAnimations()
        if not profile or profile.enabled == false or profile.stealthEnabled == false then return end
        self.stealthEventSerial = (self.stealthEventSerial or 0) + 1
        local stealthSerial = self.stealthEventSerial
        SUI:After(.04, self, "stealth alert edge", function()
            if M.stealthEventSerial ~= stealthSerial or M.stealthed ~= current then return end
            M:PlayStealth(current)
        end)
        return
    end

    if not profile or profile.enabled == false then return end
    self.eventSerial = self.eventSerial + 1
    local serial = self.eventSerial
    if event == "PLAYER_REGEN_DISABLED" then
        self:Play("enter")
    elseif event == "PLAYER_REGEN_ENABLED" then
        local delay = Clamp(profile.leaveDelay, 0, .60, .20)
        SUI:After(delay, self, "combat alert leave", function()
            if M.eventSerial ~= serial then return end
            if InCombatLockdown and InCombatLockdown() then return end
            M:Play("leave")
        end)
    end
end

function M:OnProfileChanged()
    self.eventSerial = self.eventSerial + 1
    self.playSerial = self.playSerial + 1
    self.stealthEventSerial = (self.stealthEventSerial or 0) + 1
    self.stealthPlaySerial = (self.stealthPlaySerial or 0) + 1
    self:StopAnimations()
    self:StopStealthAnimations()
    if self.StopExtraAlerts then self:StopExtraAlerts() end
    local detector = SUI:GetModule("eventAlerts")
    if detector and detector.initialized then
        SUI:SafeModuleCall(detector, "extra alert settings", detector.OnProfileChanged)
    end
    self:ApplyAppearance()
    self:RefreshStealthState()
end

M.RefreshAll = M.OnProfileChanged

function M:Initialize()
    self:RefreshStealthState()
    SUI:RegisterModuleEvent(self, "PLAYER_REGEN_DISABLED")
    SUI:RegisterModuleEvent(self, "PLAYER_REGEN_ENABLED")
    SUI:RegisterModuleEvent(self, "UPDATE_STEALTH")
    SUI:RegisterModuleEvent(self, "PLAYER_ENTERING_WORLD")
end
