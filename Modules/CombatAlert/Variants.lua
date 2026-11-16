local _, SUI = ...
local M = SUI.CombatAlert
local ATLAS = "Interface\\AddOns\\Sintezza_UI\\Media\\CombatAlert\\signal-variants.png"

M.visualVariants = {
    BANNER = {
        { cell = 0, width = 1.06, height = 1.12, enterY = .06, scaleFromY = .08, scaleToY = .08, origin = "TOP", banner = true },
    },
    BRACKETS = {
        { cell = 1, width = .62, height = .85, captionSide = -1, enterX = -.47, leaveX = -.44 },
        { cell = 1, width = .62, height = .85, captionSide = 1, enterX = .47, leaveX = .44, flip = true },
    },
    FISSURE = {
        { cell = 2, width = 1.95, height = .55, scaleFromX = .07, scaleToX = .07, glow = true },
    },
    PLAQUE = {
        { cell = 3, width = 1.92, height = .64, fitCaption = true, enterX = -.52, leaveX = .34 },
    },
    TRACKS = {
        stealth = true,
        { cell = 4, width = .43, height = .61, x = -.20, y = -.06, fadeDelay = .12 },
        { cell = 4, width = .43, height = .61, x = .18, y = .12, fadeDelay = .31, flip = true },
    },
    MASK = {
        stealth = true,
        { cell = 5, width = .50, height = .84, x = -.186, enterX = -.31, leaveX = -.32 },
        { cell = 5, width = .50, height = .84, x = .186, enterX = .31, leaveX = .32, flip = true },
    },
    MIST = {
        stealth = true,
        { cell = 6, width = 2.55, height = .83, fitCaption = true, enterX = -.28, leaveX = .30,
            scaleFromX = .73, scaleToX = 1.30, scaleFromY = .78, scaleToY = 1.20, glow = true },
    },
}

function M:HasVisualVariant(style, stealth)
    local variant = self.visualVariants[style]
    return variant and (variant.stealth == true) == stealth
end

local function SetCell(texture, cell, flip)
    local left, right = (cell % 4) / 4, ((cell % 4) + 1) / 4
    local top, bottom = math.floor(cell / 4) / 2, (math.floor(cell / 4) + 1) / 2
    texture:SetTexture(ATLAS)
    texture:SetTexCoord(flip and right or left, flip and left or right, top, bottom)
end

function M:BuildVariantPart(rig, info)
    local holder = CreateFrame("Frame", nil, rig.base)
    holder:SetFrameLevel(rig.base:GetFrameLevel() + 2)
    holder:EnableMouse(false)
    holder:Hide()
    local art = holder:CreateTexture(nil, "ARTWORK")
    art:SetAllPoints()
    SetCell(art, info.cell, info.flip)

    local enter, leave = holder:CreateAnimationGroup(), holder:CreateAnimationGroup()
    local part = { holder = holder, art = art, info = info, enter = enter, leave = leave }
    if info.banner then
        part.mark = holder:CreateTexture(nil, "OVERLAY")
        part.mark:SetPoint("CENTER", holder, "CENTER", 0, -4)
        SetCell(part.mark, 7)
        part.emblem = holder:CreateTexture(nil, "OVERLAY", nil, 1)
        part.emblem:SetPoint("CENTER", part.mark)
    end

    if info.fadeDelay then
        part.waitEnter = self:NewAlpha(enter, 1, 1, 1, info.fadeDelay)
        part.waitLeave = self:NewAlpha(leave, 1, 0, 0, info.fadeDelay)
        self:NewAlpha(enter, 2, 1, 0, .24)
        self:NewAlpha(leave, 2, 0, 1, .16)
        self:NewAlpha(leave, 3, 1, 1, .27)
        self:NewAlpha(leave, 4, 1, 0, .19)
    else
        self:NewAlpha(enter, 1, 0, 1, .14)
        part.moveIn = self:NewTranslation(enter, 1, .25)
        part.scaleIn = self:NewScaleXY(enter, 1, 1, 1, 1, 1, .25)
        self:NewAlpha(enter, 2, 1, 1, .38)
        self:NewAlpha(enter, 3, 1, 0, .27)
        self:NewAlpha(leave, 1, 0, 1, .12)
        self:NewAlpha(leave, 2, 1, 1, .32)
        part.moveOut = self:NewTranslation(leave, 3, .28)
        part.scaleOut = self:NewScaleXY(leave, 3, 1, 1, 1, 1, .28)
        self:NewAlpha(leave, 3, 1, 0, .28)
        if info.origin then
            if part.scaleIn.SetOrigin then part.scaleIn:SetOrigin(info.origin, 0, 0) end
            if part.scaleOut.SetOrigin then part.scaleOut:SetOrigin(info.origin, 0, 0) end
        end
    end
    local function Hide() holder:Hide() end
    enter:SetScript("OnFinished", Hide)
    leave:SetScript("OnFinished", Hide)
    rig.groups[#rig.groups + 1] = enter
    rig.groups[#rig.groups + 1] = leave
    return part
end

local function PaintParts(rig, r, g, b, a, glow)
    for _, part in ipairs(rig.activeVariant or {}) do
        local opacity = part.info.glow and a * math.min(1, .53 + glow) or a
        part.art:SetVertexColor(r, g, b, opacity)
        if part.mark then part.mark:SetVertexColor(r, g, b, a) end
        if part.emblem then part.emblem:SetAlpha(a) end
    end
end

function M:TintVariant(rig, r, g, b, a, glow)
    rig.variantColor = rig.variantColor or {}
    local color = rig.variantColor
    color[1], color[2], color[3], color[4], color[5] = r, g, b, a, glow
    if rig.activeVariant then PaintParts(rig, r, g, b, a, glow) end
end

function M:HideVariant(rig)
    if not rig.activeVariant then return end
    for _, part in ipairs(rig.activeVariant) do part.holder:Hide() end
    rig.activeVariant = nil
end

function M:PlayVariant(rig, style, kind, size, textAnchor, text)
    local variant = self.visualVariants[style]
    if not variant then return end
    rig.variants = rig.variants or {}
    local parts = rig.variants[style]
    if not parts then
        parts = {}
        for index, info in ipairs(variant) do parts[index] = self:BuildVariantPart(rig, info) end
        rig.variants[style] = parts
        self:ApplyAnimationSpeed()
    end
    rig.activeVariant = parts
    local color = rig.variantColor
    if color then PaintParts(rig, unpack(color)) end

    local reduced = (self:Profile() or {}).reducedMotion == true
    local speed = self:GetAnimationSpeed()
    local entering = kind == "enter"
    local captionWidth = textAnchor and math.min(rig.base:GetWidth() - 40, text:GetStringWidth()) or 0
    for _, part in ipairs(parts) do
        local info, holder = part.info, part.holder
        local moveX, moveY = 0, 0
        if entering and not reduced then
            moveX, moveY = (info.enterX or 0) * size, (info.enterY or 0) * size
        end
        local attach = (info.fitCaption or info.captionSide) and textAnchor
        local width = info.width * size
        if info.fitCaption then width = math.min(rig.base:GetWidth(), math.max(width, captionWidth + size * .58)) end
        local x = (info.x or 0) * size
        if info.captionSide then
            x = info.captionSide * math.max(size * .55, captionWidth * .5 + size * .21)
        end
        holder:SetSize(width, info.height * size)
        holder:ClearAllPoints()
        holder:SetPoint("CENTER", attach or rig.base, "CENTER", x + moveX, (attach and 0 or rig.y) + (info.y or 0) * size + moveY)

        if part.waitEnter then
            local delay = reduced and .10 or info.fadeDelay
            part.waitEnter:SetDuration(delay / speed)
            part.waitLeave:SetDuration(delay / speed)
        else
            part.moveIn:SetOffset(-moveX, -moveY)
            part.moveOut:SetOffset(reduced and 0 or (info.leaveX or 0) * size, reduced and 0 or (info.leaveY or 0) * size)
            part.scaleIn:SetScaleFrom(reduced and 1 or info.scaleFromX or 1, reduced and 1 or info.scaleFromY or 1)
            part.scaleOut:SetScaleTo(reduced and 1 or info.scaleToX or 1, reduced and 1 or info.scaleToY or 1)
        end
        if part.emblem then
            local show = self:ApplyFactionEmblem(part.emblem)
            part.mark:SetSize(size * .40, size * .40)
            part.emblem:SetSize(size * .43, size * .43)
            part.emblem:SetShown(show)
            part.mark:SetShown(not show)
        end
        holder:Show()
        part[kind]:Play()
    end
end
