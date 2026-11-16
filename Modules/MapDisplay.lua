local _, SUI = ...
local MapDisplay = SUI:RegisterModule("mapDisplay", {})

local TAB_GAP = -4

local function WeakKeys()
    return setmetatable({}, { __mode = "k" })
end

local tabAnchors, watchedTabs, watchedOwners = WeakKeys(), WeakKeys(), WeakKeys()

local function Public(value)
    if not (issecretvalue and issecretvalue(value)) then return value end
end

local function CanChange(frame)
    return frame and not (frame.IsForbidden and frame:IsForbidden())
        and not (frame.IsProtected and frame:IsProtected())
end

local function ReadAnchor(tab)
    if tab:GetNumPoints() == 1 then return { tab:GetPoint(1) } end
end

local function SameAnchor(a, b)
    return a and b and a[1] == b[1] and a[2] == b[2] and a[3] == b[3] and a[4] == b[4] and a[5] == b[5]
end

local function RestoreTab(tab)
    local state = tabAnchors[tab]
    if not state then return end
    tabAnchors[tab] = nil
    if CanChange(tab) and SameAnchor(ReadAnchor(tab), state.applied) then
        tab:ClearAllPoints()
        tab:SetPoint(unpack(state.original, 1, 5))
    end
end

local function MuddyTabs(map)
    if not (C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("MuddyBoots")) then return end
    local quests, boots
    for _, child in ipairs({ map:GetChildren() }) do
        -- Muddy Boots creates two unnamed LargeSideTab frames directly under the map.
        if child.SetChecked and child.SetCustomOnMouseUpHandler and not child:GetName() then
            if child.key == "quest" then quests = child end
            if child.key == "muddyboots" then boots = child end
        end
    end
    if quests and boots then return quests, boots end
end

local function LastQuestLogTab(log)
    if not (log and log:IsVisible()) then return end
    local column = {}
    for _, tab in ipairs({ log:GetChildren() }) do
        if tab:IsShown() and tab.SetChecked and tab.SetCustomOnMouseUpHandler then
            local anchor = ReadAnchor(tab)
            if anchor then column[tab] = anchor end
        end
    end

    -- The native and ForeverCore columns anchor to the log, then to the preceding tab.
    local last, bottom
    for tab in pairs(column) do
        local anchor = column[tab]
        local depth = 0
        while column[anchor[2]] and depth < 16 do
            anchor = column[anchor[2]]
            depth = depth + 1
        end
        if anchor[2] == log and anchor[3] == "TOPRIGHT" then
            local y = Public(tab:GetBottom())
            if y and (not bottom or y < bottom) then last, bottom = tab, y end
        end
    end
    return last
end

local function WatchTab(tab)
    if not tab or watchedTabs[tab] or not hooksecurefunc then return end
    watchedTabs[tab] = true
    local function Changed()
        if MapDisplay.enabled and not MapDisplay.updatingTabs then MapDisplay:Queue() end
    end
    hooksecurefunc(tab, "SetPoint", Changed)
    local shown = tab:IsShown()
    local function VisibilityChanged()
        local current = tab:IsShown()
        if shown ~= current then
            shown = current
            Changed()
        end
    end
    for _, method in ipairs({ "SetShown", "Show", "Hide" }) do
        hooksecurefunc(tab, method, VisibilityChanged)
    end
end

local function UpdateTabs(map, enabled)
    local first, last
    if enabled and map and map:IsVisible() then
        local quests, boots = MuddyTabs(map)
        if quests then
            WatchTab(quests)
            WatchTab(boots)
            first = quests:IsShown() and quests or (boots:IsShown() and boots or nil)
            last = LastQuestLogTab(map.QuestLog or _G.QuestMapFrame)
        end
    end
    for tab in pairs(tabAnchors) do
        if tab ~= first or not last then RestoreTab(tab) end
    end
    if not (first and last and CanChange(first)) then return end
    local original = ReadAnchor(first)
    local state = tabAnchors[first]
    if not original or (state and SameAnchor(original, state.applied) and state.applied[2] == last) then return end
    if state and SameAnchor(original, state.applied) then original = state.original end
    first:ClearAllPoints()
    first:SetPoint("TOP", last, "BOTTOM", 0, TAB_GAP)
    tabAnchors[first] = { original = original, applied = ReadAnchor(first) }
end

local function WatchOwner(owner, methods)
    if not owner or watchedOwners[owner] or not hooksecurefunc then return end
    watchedOwners[owner] = true
    for _, method in ipairs(methods) do
        if type(owner[method]) == "function" then
            hooksecurefunc(owner, method, function()
                if MapDisplay.enabled then MapDisplay:Queue() end
            end)
        end
    end
end

function MapDisplay:Refresh()
    if InCombatLockdown and InCombatLockdown() then
        if not self.pending then
            self.pending = true
            SUI:RefreshModuleEvents()
        end
        return
    end
    local map = _G.WorldMapFrame
    if self.enabled then
        WatchOwner(map, { "SetQuestLogPanelShown", "OnFrameSizeChanged" })
        local forever = _G.ForeverCore
        WatchOwner(forever and forever.QuestLogTabs, { "Register", "SetTabShown" })
    end
    self.updatingTabs = true
    UpdateTabs(map, self.enabled)
    self.updatingTabs = nil
end

function MapDisplay:Queue()
    if self.queued then return end
    self.queued = true
    SUI:After(0, self, "map tabs", function(module)
        module.queued = nil
        module:Refresh()
    end)
end

function MapDisplay:OnProfileChanged()
    if not SUI.isForever then return end
    local profile = SUI:GetModuleProfile(self.key)
    self.enabled = profile and profile.stackTabs == true
    self:Queue()
end

function MapDisplay:Initialize()
    if not SUI.isForever then return end
    SUI:RegisterModuleEvent(self, "ADDON_LOADED")
    SUI:RegisterModuleEvent(self, "PLAYER_REGEN_ENABLED")
    if EventRegistry and EventRegistry.RegisterCallback then
        local function Changed(module)
            if module.enabled then module:Queue() end
        end
        for _, event in ipairs({ "WorldMapOnShow", "WorldMapOnHide", "WorldMapMaximized", "WorldMapMinimized",
            "QuestLog.SetDisplayMode" }) do
            EventRegistry:RegisterCallback(event, Changed, self)
        end
    end
    self:OnProfileChanged()
end

function MapDisplay:WantsEvent(event)
    if event == "PLAYER_REGEN_ENABLED" then return self.pending end
    return self.enabled
end

function MapDisplay:OnEvent(event, addon)
    if event == "PLAYER_REGEN_ENABLED" then
        self.pending = nil
        self:Queue()
    elseif addon == "Blizzard_WorldMap" or addon == "MuddyBoots"
        or addon == "ForeverCore" or addon == "ShortestPathForever" then
        self:Queue()
    end
end
