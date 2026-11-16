local _, SUI = ...
local M = SUI.CooldownMasks

local icons = setmetatable({}, { __mode = "k" })
local pending = {}
local hookedNamespace, queued, refresh, painting

local function Adapter()
    local ns = M:ActionBarNamespace()
    if not (ns and ns.EAB and ns.EAB.ApplyRangeColoring and ns.barButtons and ns._eabFD
        and ns._internals and ns._internals.GetButtonActionSlot and ns._eabRangeSweepBar) then return end
    return ns
end

function M:RangeFadeSupported()
    return SUI.isForever and Adapter() ~= nil
end

local function EnabledProfile()
    local profile = M:Profile()
    if SUI.isForever and profile and profile.rangeFade == true then return profile end
end

local function Settings(ns, barKey)
    local db = ns.EAB.db
    local bars = db and db.profile and db.profile.bars
    return bars and bars[barKey]
end

local function IsSecret(value)
    return issecretvalue and issecretvalue(value)
end

local function UsableColor(ns, button)
    local getUsable = (C_ActionBar and C_ActionBar.IsUsableAction) or IsUsableAction
    if not getUsable then return 1, 1, 1 end
    local ok, slot = pcall(ns._internals.GetButtonActionSlot, button)
    if not ok or IsSecret(slot) or type(slot) ~= "number" then return 1, 1, 1 end
    local readable, usable, noMana = pcall(getUsable, slot)
    if not readable or IsSecret(usable) or IsSecret(noMana) or usable ~= false then return 1, 1, 1 end
    if noMana then return .5, .5, 1 end
    return .4, .4, .4
end

local function Paint(icon, state, ns, profile)
    local data = ns and ns._eabFD[state.button]
    local settings = data and Settings(ns, state.barKey)
    local tinted = settings and settings.outOfRangeColoring and data.rangeTinted == true
    local dormant = ns and ns._eabBarDormant and ns._eabBarDormant[state.barKey]
    local fade = profile and tinted and not dormant and (state.button.icon or state.button.Icon) == icon
    if not fade and not state.faded then return end

    local r, g, b, alpha = 1, 1, 1, 1
    if fade then
        local c = profile.rangeColorEnabled and profile.rangeColor
        if c then
            r, g, b = c[1], c[2], c[3]
        else
            r, g, b = UsableColor(ns, state.button)
        end
        alpha = math.max(.1, math.min(1, tonumber(profile.rangeOpacity) or .45))
    elseif tinted then
        local c = settings.outOfRangeColor
        r, g, b = c and c.r or .7, c and c.g or .2, c and c.b or .2
    elseif ns then
        r, g, b = UsableColor(ns, state.button)
    end

    -- Vertex alpha composes with the texture's existing opacity and keeps the mask.
    -- Only the EUI icon texture is painted. The secure button and its swipe stay separate.
    painting = true
    local ok = pcall(icon.SetVertexColor, icon, r, g, b, alpha)
    painting = false
    if ok then state.faded = fade or nil end
end

local function Queue(icon)
    if icon then pending[icon] = true end
    if queued then return end
    queued = true
    SUI:After(0, M, "action bar range appearance", function()
        queued = false
        local ns, profile = Adapter(), EnabledProfile()
        if refresh then
            refresh = false
            if profile and ns then
                for barKey, buttons in pairs(ns.barButtons) do
                    local s = Settings(ns, barKey)
                    if s and s.outOfRangeColoring then
                        for _, button in ipairs(buttons) do
                            local texture = button.icon or button.Icon
                            if M:IsEUIOwnedActionButton(button) and texture and texture.SetVertexColor then
                                local state = icons[texture]
                                if not state then
                                    state = {}
                                    icons[texture] = state
                                    hooksecurefunc(texture, "SetVertexColor", function(self)
                                        if not painting and EnabledProfile() then Queue(self) end
                                    end)
                                end
                                state.button, state.barKey = button, barKey
                                pending[texture] = true
                            end
                        end
                    end
                end
            end
            for texture, state in pairs(icons) do
                if state.faded then pending[texture] = true end
            end
        end
        for texture in pairs(pending) do
            pending[texture] = nil
            Paint(texture, icons[texture], ns, profile)
        end
    end)
end

function M:RefreshRangeFade()
    local ns = Adapter()
    local active = ns and EnabledProfile()
    if active and hookedNamespace ~= ns then
        hookedNamespace = ns
        -- Range events, paging and visibility remain owned by EllesmereUI.
        local function OnEUIRangeRefresh()
            if EnabledProfile() then self:RefreshRangeFade() end
        end
        hooksecurefunc(ns.EAB, "ApplyRangeColoring", OnEUIRangeRefresh)
        hooksecurefunc(ns, "_eabRangeSweepBar", OnEUIRangeRefresh)
    end
    if not active and not next(icons) then return end
    refresh = true
    Queue()
end
