local _, SUI = ...
local M = SUI.CooldownMasks
local Text = SUI.Text

-- EUI re-registers the stock broadcasters for press-and-hold/vehicle support.
-- Both full button updates and direct cooldown/LOC events can reach the stock
-- SetCooldown with secret numbers from that tainted dispatch. Suspend those
-- events while restricted; never replace handlers or write stock button state.
local G = {
    hooked = setmetatable({}, { __mode = "k" }),
    suppressed = false,
}
M.BroadcasterGuard = G

-- EUI 9.2.9 registers these only in its full broadcaster mode. Blizzard's
-- ACTIONBAR_SLOT_CHANGED and PLAYER_ENTERING_WORLD registrations must survive.
local updateEvents = {
    ACTIONBAR_UPDATE_COOLDOWN = true,
    ACTIONBAR_UPDATE_STATE = true,
    ACTIONBAR_UPDATE_USABLE = true,
    SPELL_UPDATE_COOLDOWN = true,
    UPDATE_SHAPESHIFT_FORM = true,
    UNIT_SPELLCAST_START = true,
    UNIT_SPELLCAST_STOP = true,
    UNIT_SPELLCAST_SUCCEEDED = true,
    UNIT_SPELLCAST_FAILED = true,
    UNIT_SPELLCAST_INTERRUPTED = true,
}
local delayedEUIEvents = {
    UNIT_ENTERED_VEHICLE = true,
    UNIT_EXITED_VEHICLE = true,
    UPDATE_VEHICLE_ACTIONBAR = true,
    UPDATE_OVERRIDE_ACTIONBAR = true,
    UPDATE_EXTRA_ACTIONBAR = true,
}
local function Namespace()
    local ns = EllesmereUI and EllesmereUI._ModuleNS
        and EllesmereUI._ModuleNS.EllesmereUIActionBars
    if ns and type(ns.ResyncBroadcaster) == "function"
        and type(ns.QuietBroadcasters) == "function" then return ns end
end

local function EUIOwnsBroadcaster(ns)
    -- EUI 9.3 recomputes its own quiet/full registrations and checks whether
    -- cooldowns are secret. Do not hook or mutate Blizzard's broadcaster when
    -- that owner is present: its two native seeding events share the frame.
    return ns and type(ns.RefreshBroadcaster) == "function"
end

function G:IsRestricted()
    if self.loadingWorld or self.changingRestrictions
        or (InCombatLockdown and InCombatLockdown()) then return true end
    if not (C_Secrets and type(C_Secrets.ShouldCooldownsBeSecret) == "function") then return false end
    local ok, restricted = pcall(C_Secrets.ShouldCooldownsBeSecret)
    if not ok or (issecretvalue and issecretvalue(restricted)) then return true end
    return restricted == true
end

local function HasUnsafeEvents(frame)
    if not frame or not frame.IsEventRegistered then return false end
    for event in pairs(updateEvents) do
        if frame:IsEventRegistered(event) then return true end
    end
    return false
end

function G:Suppress()
    local ns = Namespace()
    if not ns then return end
    if not HasUnsafeEvents(ActionBarButtonEventsFrame)
        and not HasUnsafeEvents(ActionBarActionEventsFrame) then return end
    -- Use EUI's own quiet set so its registration state stays coherent.
    ns.QuietBroadcasters()
    self.suppressed = true
end

function G:HookFrame(frame)
    if not frame or not frame.UnregisterEvent or not frame.IsEventRegistered then return end
    local installed = self.hooked[frame]
    if not installed then
        installed = {}
        self.hooked[frame] = installed
    end
    -- The second broadcaster uses RegisterUnitEvent for spellcast events.
    -- Hook each method once and close re-registration before dispatch can run.
    for _, method in ipairs({ "RegisterEvent", "RegisterUnitEvent" }) do
        if type(frame[method]) == "function" and not installed[method] then
            hooksecurefunc(frame, method, function(target, event)
                if updateEvents[event] and Namespace() and G:IsRestricted() then
                    G:Suppress()
                end
            end)
            installed[method] = true
        end
    end
end

function G:Refresh()
    local ns = Namespace()
    if not ns then return end
    if EUIOwnsBroadcaster(ns) then
        self.delegated = true
        -- EUI 9.3 can keep its tick registrations during combat even when
        -- cooldown arguments are secret. Quiet only that unsafe set, through
        -- EUI's own function; never hook its stock event frame in this mode.
        if self:IsRestricted() then
            self:Suppress()
        elseif self.suppressed then
            self.suppressed = false
            local ok = SUI:SafeModuleCall(M, "restore EUI broadcaster", ns.ResyncBroadcaster)
            if not ok then self.suppressed = true end
        end
        return
    end
    self.delegated = false
    self:HookFrame(ActionBarButtonEventsFrame)
    self:HookFrame(ActionBarActionEventsFrame)
    if self:IsRestricted() then
        self:Suppress()
    elseif self.suppressed then
        -- Let EUI recompute its own vehicle/extra/press-and-hold registrations.
        -- Replaying a saved list would resurrect events EUI no longer wants.
        self.suppressed = false
        local ok = SUI:SafeModuleCall(M, "restore EUI broadcaster", ns.ResyncBroadcaster)
        if not ok then self.suppressed = true end
    end
end

function G:OnEvent(event)
    if delayedEUIEvents[event] then
        -- EUI schedules its own visibility-based registration on the next
        -- frame. Recheck just after it, then stop; there is no idle ticker.
        if not self.euiRefreshScheduled then
            self.euiRefreshScheduled = true
            SUI:After(.05, M, "EUI broadcaster state", function()
                G.euiRefreshScheduled = false
                G:Refresh()
            end)
        end
    elseif event == "PLAYER_LEAVING_WORLD" then
        -- Close the gap before ENTERING_WORLD is delivered on a restricted map.
        self.loadingWorld = true
        self:Refresh()
    elseif event == "ADDON_RESTRICTION_STATE_CHANGED" then
        -- This event precedes activation; the live predicate can still say false
        -- during its dispatch. Suspend now, then query after the transition.
        self.changingRestrictions = true
        self:Refresh()
        if self.refreshScheduled then return end
        self.refreshScheduled = true
        SUI:After(0, M, "cooldown restrictions", function()
            G.refreshScheduled = false
            G.changingRestrictions = false
            G:Refresh()
        end)
    elseif event == "PLAYER_ENTERING_WORLD" then
        self.loadingWorld = false
        self:Refresh()
    elseif event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
        self:Refresh()
    end
end

function G:Diagnostic()
    if M.broadcasterIsolation then
        return Text("отключено (изоляция событий панели команд)", "disabled (broadcaster isolation)")
    end
    local ns = Namespace()
    if not ns then return Text("не применяется", "not applicable") end
    local yes, no = Text("да", "yes"), Text("нет", "no")
    local function Registration(frame, event)
        return frame and frame.IsEventRegistered and frame:IsEventRegistered(event) and yes or no
    end
    local fields = {
        Text("владелец=", "owner=") .. (EUIOwnsBroadcaster(ns) and "EUI" or "SUI"),
        Text("ограничение=", "restricted=") .. (self:IsRestricted() and yes or no),
        Text("события приостановлены=", "events suspended=") .. (self.suppressed and yes or no),
    }
    for _, event in ipairs({
        "ACTIONBAR_SLOT_CHANGED", "PLAYER_ENTERING_WORLD",
        "ACTIONBAR_UPDATE_COOLDOWN", "SPELL_UPDATE_COOLDOWN",
        "ACTIONBAR_UPDATE_STATE", "ACTIONBAR_UPDATE_USABLE",
    }) do
        fields[#fields + 1] = event .. "=" .. Registration(ActionBarButtonEventsFrame, event)
    end
    fields[#fields + 1] = "UNIT_SPELLCAST_START=" .. Registration(ActionBarActionEventsFrame, "UNIT_SPELLCAST_START")
    return table.concat(fields, ", ")
end

function G:Initialize()
    -- Crash compatibility is independent of the optional visual-mask settings.
    SUI:RegisterModuleEvent(M, "PLAYER_LEAVING_WORLD")
    if C_RestrictedActions and C_RestrictedActions.GetAddOnRestrictionState then
        SUI:RegisterModuleEvent(M, "ADDON_RESTRICTION_STATE_CHANGED")
    end
    for event in pairs(delayedEUIEvents) do SUI:RegisterModuleEvent(M, event) end
    self:Refresh()
end
