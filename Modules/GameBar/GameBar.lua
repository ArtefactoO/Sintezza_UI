local _, SUI = ...
local Text = SUI.Text

local M = {}
SUI.GameBar = M
SUI:RegisterModule("gameBar", M)

function M:GetProfile() return SUI:GetModuleProfile("gameBar") end
function M:SyncProfile() self.profile = self:GetProfile() end
function M:RefreshSettings()
    if SUI.SettingsUI then SUI.SettingsUI:Refresh() end
end
function M:OpenSettings() SUI:OpenSettings("gameBar") end

function M:RequestButtonUpdate()
    if self:InCombat() then
        self.pendingSecureUpdate = true
        self:Info(Text("Изменения будут применены после выхода из боя.", "Changes will apply after combat."))
    else
        self.pendingSecureUpdate = nil
        self:ApplyAllSettings()
    end
end

function M:InitializeUI()
    if self.uiInitialized then return end
    if not self.root then self:CreateVisuals() end
    self:ApplyAllSettings(true)
    self.uiInitialized = true
end

function M:HandleLogin()
    if self.loginHandled then return end
    if not self:WantsEvent("PLAYER_LOGIN") then return end
    if self:InCombat() then self.pendingSecureUpdate = true; return end
    self:InitializeUI()
    self.loginHandled = true
    if self:WantsEvent("FRIENDLIST_UPDATE") then self:RequestFriendList() end
    if self:WantsEvent("PLAYER_HOUSE_LIST_UPDATED") then self:RequestHousingData() end
end

function M:Initialize()
    self:SyncProfile()
    for _, event in ipairs({
        "PLAYER_LOGIN", "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED",
        "FRIENDLIST_UPDATE", "GUILD_ROSTER_UPDATE", "PLAYER_GUILD_UPDATE",
        "PLAYER_HOUSE_LIST_UPDATED", "BN_FRIEND_LIST_SIZE_CHANGED", "BN_FRIEND_INFO_CHANGED",
        "PLAYER_UPDATE_RESTING", "PLAYER_FLAGS_CHANGED",
    }) do
        SUI:RegisterModuleEvent(self, event)
    end
    if SUI.isForever then SUI:RegisterModuleEvent(self, "ADDON_LOADED") end
    if IsLoggedIn and IsLoggedIn() then SUI:After(0, self, "login", function() M:HandleLogin() end) end
end

function M:OnProfileChanged()
    self:SyncProfile()
    if not self.uiInitialized then self:HandleLogin(); return end
    if self:InCombat() then
        self.pendingSecureUpdate = true
        self:RestartClockTicker()
        self:RestartMiniBarTicker()
    else self:ApplyAllSettings(true) end
end

function M:OnEvent(event, ...)
    if event == "PLAYER_LOGIN" then
        self:HandleLogin()
    elseif event == "ADDON_LOADED" then
        if ... == "EllesmereUIForeverEssentials" and self.uiInitialized
            and (self:HasButton("TALENTS") or self:HasButton("SPELLBOOK")) then
            self:ApplyButtonAssignments()
        end
    elseif event == "BN_FRIEND_LIST_SIZE_CHANGED" or event == "BN_FRIEND_INFO_CHANGED" then
        self:UpdateBadges("friends")
        self:RefreshActiveTooltip()
    elseif event == "PLAYER_HOUSE_LIST_UPDATED" then
        local houseInfoList = ...
        if type(houseInfoList) ~= "table" and C_Housing and type(C_Housing.GetPlayerOwnedHouses) == "function" then
            local ok, houses = pcall(C_Housing.GetPlayerOwnedHouses)
            if ok then houseInfoList = houses end
        end
        self.playerHouseList = type(houseInfoList) == "table" and houseInfoList or {}
        self.houseInfoLoaded = true
        self.houseInfoRequested = nil
        self:RequestButtonUpdate()
    elseif event == "PLAYER_REGEN_ENABLED" then
        if self.pendingSecureUpdate then
            self.pendingSecureUpdate = nil
            if not self.uiInitialized then self:HandleLogin()
            else self:ApplyAllSettings(true) end
            self:Info(Text("Отложенные изменения применены.", "Pending changes applied."))
        else
            self:ApplyVisibilityDriver()
            if self.ApplyMiniBarVisibility then self:ApplyMiniBarVisibility() end
            self:RefreshFade()
            if self.RefreshMiniBarFade then self:RefreshMiniBarFade() end
        end
        self:RefreshSettings()
    elseif event == "PLAYER_REGEN_DISABLED" then
        self:RefreshFade()
        if self.RefreshMiniBarFade then self:RefreshMiniBarFade() end
    elseif event == "FRIENDLIST_UPDATE" then
        self:UpdateBadges("friends")
        self:RefreshActiveTooltip()
    elseif event == "GUILD_ROSTER_UPDATE" or event == "PLAYER_GUILD_UPDATE" then
        self:UpdateBadges("guild")
        self:RefreshActiveTooltip()
    elseif event == "PLAYER_UPDATE_RESTING" or event == "PLAYER_FLAGS_CHANGED" then
        self:UpdateMiniBarData()
    end
end

SLASH_SINTEZZA_GAMEBAR1 = "/sgb"
SlashCmdList.SINTEZZA_GAMEBAR = function(message)
    local command = (message or ""):lower():match("^%s*(.-)%s*$")
    if command == "" or command == "settings" then
        M:OpenSettings()
    elseif command == "lock" then
        M.profile.locked = true
        M:RefreshSettings()
    elseif command == "unlock" then
        M.profile.locked = false
        M:RefreshSettings()
    elseif command == "reset" then
        M:ResetPosition()
    elseif command == "show" then
        M:FadeTo(1)
        SUI:After(3, M, "temporary show", function() M:RefreshFade() end)
    else
        M:Info(Text("/sgb — настройки. Команды: lock, unlock, reset, show.", "/sgb: settings, lock, unlock, reset, show."))
    end
end
