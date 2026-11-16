local _, SUI = ...

local HoverEffects = {}
SUI:RegisterModule("interactionEffects", HoverEffects)
SUI.HoverEffects = HoverEffects

local ENTER_DURATION = .10
local LEAVE_DURATION = .14
local ICON_EDGE_GROWTH = 2
local registered = setmetatable({}, { __mode = "k" })
local active = {}
local driver = CreateFrame("Frame")

local function Clamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, tonumber(value) or minimum))
end

local function Profile()
    return SUI:GetModuleProfile("interactionEffects") or SUI.defaults.modules.interactionEffects
end

local function Enabled()
    local profile = Profile()
    return not profile or profile.enabled ~= false
end

local function Intensity()
    local profile = Profile()
    return Clamp(profile and profile.intensity or .08, .03, .15)
end

local function SetColor(region, color)
    if not region or not color then return end
    region:SetVertexColor(color[1], color[2], color[3], color[4] or 1)
end

local function SyncTexture(state)
    local source, overlay = state.icon, state.overlay
    if not source or not overlay then return end
    local atlas = source.GetAtlas and source:GetAtlas()
    if atlas and atlas ~= "" and overlay.SetAtlas then
        overlay:SetAtlas(atlas, false)
    else
        overlay:SetTexture(source:GetTexture())
    end
    local coords = { source:GetTexCoord() }
    if #coords > 0 then overlay:SetTexCoord(unpack(coords)) end
    overlay:SetBlendMode("BLEND")
end

local function ApplyIcon(state, value)
    state.value = Clamp(value, 0, 1)
    local source, overlay = state.icon, state.overlay
    if not source or not overlay then return end
    -- The setting describes growth around the icon rather than growth of its
    -- full diameter.  Treat it as a per-edge value so an 8% micro-pop remains
    -- visible on 18-24px glyphs after their transparent texture padding.
    local scale = 1 + (Intensity() * ICON_EDGE_GROWTH * state.value)
    overlay:SetSize(state.width * scale, state.height * scale)
    -- The overlay is the enlarged visual replacement, not an additive copy.
    -- Cross-fade the source out while it grows so the resting-size glyph does
    -- not remain visible underneath.  Only vertex colour is touched: badges,
    -- secure hit boxes and the owning button's alpha stay unchanged.
    local base = state.baseColor or { 1, 1, 1, 1 }
    source:SetVertexColor(base[1], base[2], base[3], (base[4] or 1) * (1 - state.value))
    SetColor(overlay, state.hoverColor)
    overlay:SetAlpha(state.value)
    overlay:SetShown(state.value > .001 and source:IsShown())
end

local function ApplyClock(state, value)
    state.value = Clamp(value, 0, 1)
    local text = state.text
    if not text then return end
    text:SetScale(1 + Intensity() * .5 * state.value)
    local base, hover = state.baseColor, state.hoverColor
    local blend = .30 * state.value
    text:SetTextColor(
        base[1] + (hover[1] - base[1]) * blend,
        base[2] + (hover[2] - base[2]) * blend,
        base[3] + (hover[3] - base[3]) * blend,
        base[4] or 1
    )
end

local function Apply(state, value)
    if state.kind == "clock" then ApplyClock(state, value) else ApplyIcon(state, value) end
end

local function Stop(owner)
    active[owner] = nil
    if not next(active) then driver:SetScript("OnUpdate", nil) end
end

local function NormalizeDisabled(state)
    Stop(state.owner)
    Apply(state, 0)
    if state.kind == "icon" then
        SetColor(state.icon, state.hovered and state.hoverColor or state.baseColor)
    end
end

local function DriverOnUpdate(_, elapsed)
    for owner, item in pairs(active) do
        if registered[owner] ~= item then
            active[owner] = nil
        else
            item.elapsed = item.elapsed + elapsed
            local progress = math.min(1, item.elapsed / item.duration)
            local smooth = progress * progress * (3 - 2 * progress)
            Apply(item, item.from + (item.target - item.from) * smooth)
            if progress >= 1 then active[owner] = nil end
        end
    end
    if not next(active) then driver:SetScript("OnUpdate", nil) end
end

local function Animate(state, target)
    if not Enabled() then
        NormalizeDisabled(state)
        return
    end
    local from = state.value or 0
    if math.abs(target - from) < .001 then
        Stop(state.owner)
        Apply(state, target)
        return
    end
    state.from = from
    state.target = target
    state.elapsed = 0
    local baseDuration = target > from and ENTER_DURATION or LEAVE_DURATION
    state.duration = math.max(.01, baseDuration * math.abs(target - from))
    active[state.owner] = state
    driver:SetScript("OnUpdate", DriverOnUpdate)
end

function HoverEffects:ConfigureIcon(owner, icon, width, height, baseColor, hoverColor)
    if not owner or not icon then return end
    local state = registered[owner]
    if not state or state.kind ~= "icon" then
        local overlay = owner:CreateTexture(nil, "ARTWORK", nil, 1)
        overlay:SetPoint("CENTER", icon, "CENTER")
        overlay:SetAlpha(0)
        overlay:Hide()
        state = { kind = "icon", owner = owner, overlay = overlay, hovered = false, value = 0 }
        registered[owner] = state
    end
    state.icon = icon
    state.width = math.max(1, tonumber(width) or icon:GetWidth() or 1)
    state.height = math.max(1, tonumber(height) or icon:GetHeight() or 1)
    state.baseColor = baseColor or { 1, 1, 1, 1 }
    state.hoverColor = hoverColor or state.baseColor
    state.overlay:ClearAllPoints()
    state.overlay:SetPoint("CENTER", icon, "CENTER")
    SyncTexture(state)
    if Enabled() then
        SetColor(icon, state.baseColor)
        Apply(state, state.value or 0)
    else
        NormalizeDisabled(state)
    end
end

function HoverEffects:SetIconHovered(owner, hovered)
    local state = registered[owner]
    if not state or state.kind ~= "icon" then return end
    state.hovered = hovered == true
    Animate(state, state.hovered and 1 or 0)
end

function HoverEffects:ConfigureClock(owner, text, baseColor, hoverColor)
    if not owner or not text then return end
    local state = registered[owner]
    if not state or state.kind ~= "clock" then
        state = { kind = "clock", owner = owner, hovered = false, value = 0 }
        registered[owner] = state
    end
    state.text = text
    state.baseColor = baseColor or { 1, 1, 1, 1 }
    state.hoverColor = hoverColor or state.baseColor
    Apply(state, Enabled() and (state.value or 0) or 0)
end

function HoverEffects:SetClockHovered(owner, hovered)
    local state = registered[owner]
    if not state or state.kind ~= "clock" then return end
    state.hovered = hovered == true
    Animate(state, state.hovered and 1 or 0)
end

function HoverEffects:Reset(owner)
    local state = registered[owner]
    if not state then return end
    state.hovered = false
    Stop(owner)
    if state.kind == "icon" then SetColor(state.icon, state.baseColor) end
    Apply(state, 0)
end

function HoverEffects:RefreshAll()
    for owner, state in pairs(registered) do
        Stop(owner)
        if Enabled() then
            if state.kind == "icon" then SetColor(state.icon, state.baseColor) end
            Apply(state, state.hovered and 1 or 0)
        else
            NormalizeDisabled(state)
        end
    end
end

function HoverEffects:ResetAll()
    for owner in pairs(registered) do self:Reset(owner) end
end

function HoverEffects:HasActiveAnimations()
    return next(active) ~= nil
end

function HoverEffects:Initialize()
    self:RefreshAll()
end

function HoverEffects:OnProfileChanged()
    self:ResetAll()
end
