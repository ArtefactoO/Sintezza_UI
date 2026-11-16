local _, SUI = ...
local Text = SUI.Text

local M = {}
SUI.RaidTools = M
SUI:RegisterModule("raidTools", M)
M.defaults = SUI.defaults.modules.raidTools

function M:GetProfile() return SUI:GetModuleProfile("raidTools") end
function M:SyncProfile() self.profile = self:GetProfile() end
function M:RefreshSettings() if SUI.SettingsUI then SUI.SettingsUI:Refresh() end end
function M:OpenSettings() SUI:OpenSettings("raidTools") end

function M:RequestSecureUpdate(notify)
    if self.profile and (not self.profile.enabled or not self.profile.raidCheck.enabled) and self.audit and self.audit:IsShown() then
        self:HideAudit()
    end
    if self:InCombat() then
        self.pendingSecureUpdate = true
        if notify ~= false and not self.secureUpdateNotified then
            self.secureUpdateNotified = true
            self:Info(Text("Изменения применятся после выхода из боя.", "Applies after combat."))
        end
    else
        self.pendingSecureUpdate = nil
        self.secureUpdateNotified = nil
        self:ApplyBarSettings()
        if self.audit and self.audit:IsShown() then self:RefreshAudit() end
    end
end

function M:GetRuntimeRoster()
    local rows = self.testMode and self:TestRoster()
        or (self.BuildRoster and self:BuildRoster() or {})
    return self.ApplyReadyState and self:ApplyReadyState(rows) or rows
end

function M:GetRoster() return self:GetRuntimeRoster() end

function M:TestRoster()
    local names = { "Oakwarden", "Cinderleaf", "Moonriver", "Ironbark", "Starbloom", "Runesong", "Stormroot", "Dawnglade" }
    local classes = { "DRUID", "WARRIOR", "PRIEST", "PALADIN", "MAGE", "SHAMAN", "HUNTER", "EVOKER" }
    local rows = {}
    for index, name in ipairs(names) do
        rows[index] = {
            unit = "player", name = name, class = classes[index],
            role = index == 1 and "TANK" or (index == 2 and "HEALER" or "DAMAGER"),
            online = index ~= 8,
            ready = index == 3 and "notready" or (index == 5 and "PENDING" or "ready"),
            aura = {
                food = index == 4 and "MISSING" or "PRESENT",
                flask = index == 6 and "MISSING" or "PRESENT",
                rune = index == 2 and "UNKNOWN" or "PRESENT",
                buffs = index == 7 and "MISSING" or "PRESENT",
            },
        }
    end
    return rows
end

function M:HandleLogin()
    if self.loginHandled then return end
    self:SyncProfile()
    if not self:WantsEvent("PLAYER_LOGIN") then return end
    if self:InCombat() and not (self.panels and self.panels.TARGET and self.panels.WORLD
        and self.panels.CONTROL and self.panels.PING) then
        self.pendingRetry = true
        self.pendingSecureUpdate = true
        return
    end
    if not (self.panels and self.panels.TARGET and self.panels.WORLD and self.panels.CONTROL and self.panels.PING) then
        self.panels = nil
        self:CreateBar()
    end
    self:ApplyBarSettings()
    self.uiInitialized = true
    self.loginHandled = true

    -- The audit window is independent from the four raid panels.  Keep its
    -- initialization isolated so a font/API problem there can never leave
    -- already-created panels at their initial zero size.
    if self.profile.raidCheck.enabled and not self.audit then
        local ok, err = pcall(self.CreateAuditWindow, self)
        if not ok then
            self.auditInitializeError = tostring(err)
            self:Error(Text("Окно проверки рейда не создано: ", "Could not create the ready check window: ") .. self.auditInitializeError)
        else
            self.auditInitializeError = nil
        end
    end
end

function M:RetryInitialization()
    if self:InCombat() then
        self.pendingRetry = true
        self.pendingSecureUpdate = true
        return false, Text("Повторная инициализация выполнится после выхода из боя.", "Raid Tools will restart after combat.")
    end
    self.pendingRetry = nil
    self:SyncProfile()
    if not (self.panels and self.panels.TARGET and self.panels.WORLD and self.panels.CONTROL and self.panels.PING) then
        self.panels = nil
        local ok, err = pcall(self.CreateBar, self)
        if not ok then return false, tostring(err) end
    end
    local ok, err = pcall(self.ApplyBarSettings, self)
    if not ok then return false, tostring(err) end
    self.pendingSecureUpdate = nil
    self.uiInitialized, self.loginHandled = true, true
    if not self.audit then
        local auditOK, auditError = pcall(self.CreateAuditWindow, self)
        if not auditOK then self.auditInitializeError = tostring(auditError) end
    end
    return true, self.auditInitializeError
end

function M:Initialize()
    self:SyncProfile()
    for _, event in ipairs({
        "PLAYER_LOGIN", "PLAYER_REGEN_ENABLED", "READY_CHECK", "READY_CHECK_CONFIRM",
        "READY_CHECK_FINISHED", "GROUP_ROSTER_UPDATE", "PARTY_LEADER_CHANGED",
        "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "UNIT_AURA",
    }) do
        SUI:RegisterModuleEvent(self, event)
    end
    if IsLoggedIn and IsLoggedIn() then SUI:After(0, self, "login", function() M:HandleLogin() end) end
end

function M:OnProfileChanged()
    self:SyncProfile()
    if not self.uiInitialized then self:HandleLogin(); return end
    self:RequestSecureUpdate()
end

function M:SetSettingsOpen(open)
    self.settingsOpen = open == true
    if self.uiInitialized then self:RequestSecureUpdate(false) end
    if not self.settingsOpen then
        local serial = (self.settingsCloseSerial or 0) + 1
        self.settingsCloseSerial = serial
        SUI:After(0, self, "settings close", function()
            if M.settingsOpen or M.settingsCloseSerial ~= serial then return end
            for _, panel in pairs(M.panels or {}) do M:RefreshFade(panel) end
        end)
    end
end

function M:OnEvent(event, unit)
    if event == "PLAYER_LOGIN" then
        self:HandleLogin()
    elseif event == "PLAYER_REGEN_ENABLED" then
        if self.pendingRetry then
            local ok, err = self:RetryInitialization()
            if not ok then self:Error(Text("Не удалось восстановить панели: ", "Could not restore the bars: ") .. tostring(err)) end
        elseif self.pendingSecureUpdate then
            self:RequestSecureUpdate(false)
        end
    elseif event == "READY_CHECK" then
        self.readyCache = {}
        self.readyCheckActive, self.readyCheckFinal = true, false
        if self.profile.enabled and self.profile.raidCheck.enabled and self.profile.raidCheck.autoShow
            and (not self.profile.raidCheck.onlyLeaderAssist or self:CanLeadAction()) then
            self.testMode, self.auditManual = false, false
            self:ShowAudit(false)
        end
    elseif event == "GROUP_ROSTER_UPDATE" or event == "PARTY_LEADER_CHANGED"
        or event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
        -- These are passive game-state changes, not edits made by the user.
        -- Secure panel attributes still refresh after combat, but silently.
        self:RequestSecureUpdate(false)
    elseif event == "READY_CHECK_CONFIRM" then
        if self.audit and self.audit:IsShown() and not self.testMode then self:RefreshAudit(false) end
    elseif event == "READY_CHECK_FINISHED" then
        if self.audit and self.audit:IsShown() and not self.testMode then self:RefreshAudit(false) end
        self.readyCheckActive, self.readyCheckFinal = false, true
        if self.audit and self.audit:IsShown() and not self.testMode then self:ScheduleAuditHide() end
    elseif event == "UNIT_AURA" then
        if self.audit and self.audit:IsShown() and not self.testMode then self:QueueAuraScan(unit) end
    end
end

SLASH_SINTEZZA_RAIDTOOLS1 = "/srt"
SlashCmdList.SINTEZZA_RAIDTOOLS = function(message)
    message = (message or ""):lower():match("^%s*(.-)%s*$")
    if message == "" or message == "settings" then M:OpenSettings()
    elseif message == "unlock" then M:SetEditMode(true)
    elseif message == "lock" then M:SetEditMode(false)
    elseif message == "reset" then M:ResetPanelPositions()
    elseif message == "panels" then M:ShowCorePanels()
    elseif message == "check" then M.testMode = false; M:ShowAudit(true)
    elseif message == "test" then M.testMode = true; M:ShowAudit(true)
    elseif message == "retry" then
        local ok, err = M:RetryInitialization()
        if ok then M:Info(err and (Text("Панели восстановлены; окно проверки: ", "Bars restored. Ready check window: ") .. err) or Text("Панели восстановлены.", "Bars restored."))
        else M:Error(Text("Не удалось восстановить панели: ", "Could not restore the bars: ") .. tostring(err)) end
    elseif message == "status" then
        local count = 0
        for _ in pairs(M.panels or {}) do count = count + 1 end
        M:Info((Text("панелей: %d; UI: %s; ошибка окна: %s", "Bars: %d, UI: %s, window error: %s")):format(count, M.uiInitialized and Text("да", "yes") or Text("нет", "no"), M.auditInitializeError or Text("нет", "no")))
    else M:Info("/srt: settings, unlock, lock, reset, panels, check, test, retry, status") end
end
