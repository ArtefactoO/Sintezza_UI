local _, SUI = ...
local Text = SUI.Text

local D = {
    errors = {},
    totalErrors = 0,
}
SUI.Diagnostics = D

local function CountKeys(value)
    local count = 0
    for _ in pairs(type(value) == "table" and value or {}) do count = count + 1 end
    return count
end

local function Stamp()
    return date and date("%H:%M:%S") or tostring(GetTime and math.floor(GetTime()) or 0)
end

function D:RecordError(moduleKey, context, err)
    moduleKey = tostring(moduleKey or "core")
    local state = self.errors[moduleKey] or { count = 0 }
    state.count = state.count + 1
    state.context = tostring(context or "runtime")
    state.message = err and tostring(err) or Text("Неизвестная ошибка", "Unknown error")
    state.time = Stamp()
    self.errors[moduleKey] = state
    self.totalErrors = self.totalErrors + 1

    local module = SUI:GetModule(moduleKey)
    if module then module.runtimeError = state.message end
end

function D:ClearErrors()
    wipe(self.errors)
    self.totalErrors = 0
    self.protectedSnapshot = nil
    for _, module in pairs(SUI.modules or {}) do module.runtimeError = nil end
    if SUI.SettingsUI then SUI.SettingsUI:Refresh() end
end

function D:ClearModuleError(moduleKey, reconnectOnly)
    local state = self.errors[moduleKey]
    if reconnectOnly and state and state.context ~= "reconnect"
        and not tostring(state.context or ""):find("^hook ") then return end
    if state then
        self.totalErrors = math.max(0, self.totalErrors - (state.count or 0))
        self.errors[moduleKey] = nil
    end
    local module = SUI:GetModule(moduleKey)
    if module then module.runtimeError = nil end
end

function D:ModuleDetails(key)
    local module = SUI:GetModule(key)
    if not module then return SUI.Text("НЕДОСТУПЕН", "UNAVAILABLE"), false end
    local err = self.errors[key]
    if module.initialized == false or err then
        return SUI.Text("ОШИБКА", "ERROR") .. (err and (" ×" .. err.count) or ""), false
    end
    local profile = SUI:GetModuleProfile(key)
    if profile and profile.enabled == false then return SUI.Text("ОТКЛЮЧЕН", "DISABLED"), true end
    if key == "gameBar" then
        if not module.uiInitialized then return SUI.Text("ОЖИДАЕТ UI", "WAITING FOR UI"), false end
        return SUI.Text("ВСТРОЕН • ", "INTEGRATED · ") .. CountKeys(module.buttons) .. SUI.Text(" КНОПОК", " BUTTONS"), true
    elseif key == "raidTools" then
        if not module.uiInitialized then return SUI.Text("ОЖИДАЕТ UI", "WAITING FOR UI"), false end
        local audit = module.auditInitializeError and SUI.Text(" • ОШИБКА ОКНА", " · WINDOW ERROR") or ""
        return SUI.Text("ВСТРОЕН • ", "INTEGRATED · ") .. CountKeys(module.panels) .. SUI.Text(" ПАНЕЛИ", " PANELS") .. audit,
            module.auditInitializeError == nil
    elseif key == "nameplates" then
        local retry = module.retryTicker and Text(" • ПЕРЕПОДКЛЮЧЕНИЕ", " · RETRYING")
            or (module.retrySuspended and Text(" • ПОВТОРЫ ОСТАНОВЛЕНЫ", " · RETRIES STOPPED") or "")
        local connection = module.available and (SUI.Text("ПОДКЛЮЧЕН • ", "CONNECTED · ") .. tostring(module.adapterName or "?")) or SUI.Text("ОЖИДАЕТ АДАПТЕР", "WAITING FOR ADAPTER")
        return connection
            .. (" • %d/%d"):format(CountKeys(module.plates), CountKeys(module.activeUnits))
            .. retry, module.available == true
    elseif key == "cooldownMasks" then
        return (SUI.Text("ВСТРОЕН • AB %d • CDM %d", "INTEGRATED · AB %d · CDM %d")):format(
            module.hookedActionBars or 0, module.hookedCooldownManager or 0), true
    elseif key == "shortestPathMinimap" then
        if not module:IsSupported() then return SUI.Text("ОЖИДАЕТ SHORTEST PATH", "WAITING FOR SHORTEST PATH"), false end
        if not module.enabled then return SUI.Text("ШТАТНЫЙ МАРШРУТ", "DEFAULT ROUTE"), true end
        local function CountDots(painter)
            local count = 0
            if painter then
                for _, marker in ipairs(painter.markers) do
                    if marker.active then count = count + 1 end
                end
            end
            return count
        end
        return (SUI.Text("ПОДКЛЮЧЕН • МИНИКАРТА %d • КАРТА %d", "CONNECTED · MINIMAP %d · MAP %d")):format(CountDots(module.minimap), CountDots(module.world)), true
    end
    return module.initialized == true and SUI.Text("ВСТРОЕН", "INTEGRATED") or SUI.Text("ОЖИДАЕТ", "PENDING"), module.initialized == true
end

function D:ReconnectEUI()
    if InCombatLockdown and InCombatLockdown() then
        return false, SUI.Text("Переподключение доступно после выхода из боя.", "Reconnect is available after combat.")
    end

    local failures = {}
    local nameplates = SUI:GetModule("nameplates")
    if nameplates and nameplates.Reconnect then
        local ok, result = pcall(nameplates.Reconnect, nameplates)
        if not ok or result == false then
            failures[#failures + 1] = Text("Неймплейты", "Nameplates")
            if not ok then self:RecordError("nameplates", "reconnect", result) end
        else
            self:ClearModuleError("nameplates", true)
        end
    end

    local cooldowns = SUI:GetModule("cooldownMasks")
    if cooldowns and (cooldowns.Reconnect or cooldowns.RefreshAll) then
        local callback = cooldowns.Reconnect or cooldowns.RefreshAll
        local ok, result = pcall(callback, cooldowns)
        if not ok or result == false then
            failures[#failures + 1] = Text("Оформление отката", "Cooldown Masks")
            if not ok then self:RecordError("cooldownMasks", "reconnect", result) end
        else
            self:ClearModuleError("cooldownMasks", true)
        end
    end

    if SUI.SettingsUI then SUI.SettingsUI:Refresh() end
    if #failures > 0 then return false, SUI.Text("Не удалось подключить: ", "Could not connect: ") .. table.concat(failures, ", ") end
    return true, SUI.Text("Компоненты EllesmereUI переподключены.", "EllesmereUI components reconnected.")
end

-- Read security metadata only. Never invoke Show/Hide/Update or repair a
-- Blizzard field from diagnostics: doing so would overwrite the evidence.
local function GamepadInputStatus()
    local interface = C_InputInterfaceStyle
    local types = Enum and Enum.InputDeviceInterfaceType
    local style = Text("недоступен", "unavailable")
    if interface and types and type(interface.GetCurrentStyle) == "function" then
        local ok, value = pcall(interface.GetCurrentStyle)
        if ok and not (issecretvalue and issecretvalue(value)) and type(value) == "number" then
            style = value == types.Gamepad and Text("геймпад", "Gamepad") or Text("режим ", "style ") .. value
        end
    end
    local getCVar = (C_CVar and C_CVar.GetCVar) or GetCVar
    if type(getCVar) == "function" then
        local ok, value = pcall(getCVar, "InputDeviceInterfaceStyle")
        if ok and not (issecretvalue and issecretvalue(value)) and type(value) == "string" then
            style = style .. "; InputDeviceInterfaceStyle=" .. value
        end
    end
    return style
end

function D:ActionBarTaintReport()
    local lines = {}
    if SUI.isForever then lines[1] = Text("Режим ввода: ", "Input interface: ") .. GamepadInputStatus() end
    if type(issecurevariable) ~= "function" then
        lines[#lines + 1] = Text("Данные о защищенности недоступны", "Security metadata unavailable")
        return table.concat(lines, "\n")
    end
    local unavailable, secure = Text("недоступно", "unavailable"), Text("защищено", "secure")
    local function SecurityStatus(owner, key)
        local ok, clean, source = pcall(issecurevariable, owner, key)
        if not ok or (issecretvalue and (issecretvalue(clean) or issecretvalue(source))) then return unavailable end
        if clean == true then return secure end
        if clean == false then
            return Text("нарушена защита (%s)", "tainted by %s"):format(
                type(source) == "string" and source or Text("неизвестный источник", "unknown source"))
        end
        return unavailable
    end
    local function Inspect(owner, label, keys)
        if not owner then lines[#lines + 1] = label .. ": " .. unavailable; return end
        for _, key in ipairs(keys) do
            lines[#lines + 1] = label .. "." .. key .. "=" .. SecurityStatus(owner, key)
        end
    end
    Inspect(_G, "global", { "MainActionBar", "ActionBarController_UpdateAll",
        "ValidateActionBarTransition", "CURRENT_ACTION_BAR_STATE" })
    if SUI.isForever then
        Inspect(_G, "global", { "ActionButton_UpdateCooldown", "ActionButton_ApplyCooldown", "GamepadMainActionBarFrame" })
        Inspect(GamepadMainActionBarFramePageUnitTopCenteredAnchorTopBarActionButton2,
            "GamepadTop2", { "action", "OnEvent", "UpdateCooldown", "Cooldown", "cooldown" })
        Inspect(GamepadMainActionBarFramePageUnitRightCenteredAnchorRightBarActionButton5,
            "GamepadRight5", { "action", "OnEvent", "UpdateCooldown", "Cooldown", "cooldown" })
        Inspect(PlayerSpellsFrame, "PlayerSpellsFrame", { "SetTab", "TrySetTab", "TabSystem" })
    end
    Inspect(MainActionBar, "MainActionBar", { "isShownExternal", "visibility", "editModeForceShow",
        "Show", "Hide", "SetShown", "ShowOverride", "HideOverride", "UpdateVisibility", "SetShownBase" })
    Inspect(ActionBarButtonEventsFrame, "ButtonEvents", { "frames", "RegisterEvent", "RegisterUnitEvent" })
    Inspect(ActionBarActionEventsFrame, "ActionEvents", { "frames", "RegisterEvent", "RegisterUnitEvent" })
    local tracked = {}
    if ActionButton4 then tracked[ActionButton4] = "ActionButton4" end
    if ActionButton9 then
        tracked[ActionButton9] = "ActionButton9"
        Inspect(ActionButton9, "ActionButton9", { "action", "actionButtonCastType", "Update",
            "UpdatePressAndHoldAction", "OnActionBarSlotChanged" })
    end
    if ActionButton10 then tracked[ActionButton10] = "ActionButton10" end
    if MultiBarBottomLeftButton3 then tracked[MultiBarBottomLeftButton3] = "MultiBarBottomLeftButton3" end
    local frames = ActionBarButtonEventsFrame and ActionBarButtonEventsFrame.frames
    if type(frames) == "table" then
        local eabCount, eabTainted, eabExample = 0, 0, nil
        local ok = pcall(function()
            for index, button in pairs(frames) do
                if not (issecretvalue and (issecretvalue(index) or issecretvalue(button))) then
                    local name = tracked[button]
                    if name then
                        lines[#lines + 1] = "ButtonEvents.frames[" .. name .. "]=" .. SecurityStatus(frames, index)
                        tracked[button] = nil
                    end
                    if button and button.GetName then
                        local okName, buttonName = pcall(button.GetName, button)
                        if okName and type(buttonName) == "string" and buttonName:match("^EABButton%d+$") then
                            eabCount = eabCount + 1
                            local state = SecurityStatus(frames, index)
                            if state ~= secure then
                                eabTainted = eabTainted + 1
                                if not eabExample then eabExample = buttonName .. "=" .. state end
                            end
                        end
                    end
                end
            end
        end)
        if not ok then
            lines[#lines + 1] = Text("ButtonEvents.frames: записи недоступны", "ButtonEvents.frames: entries unavailable")
        end
        lines[#lines + 1] = Text("ButtonEvents.EAB: записей %d, без защиты %d%s",
            "ButtonEvents.EAB: %d entries, %d nonsecure%s"):format(
            eabCount, eabTainted, eabExample and Text(", пример: ", ", first: ") .. eabExample or "")
    end
    for _, name in pairs(tracked) do
        lines[#lines + 1] = "ButtonEvents.frames[" .. name .. "]=" .. Text("нет в списке", "not listed")
    end
    return table.concat(lines, "\n")
end

function D:OnEvent(event, addonName, functionName)
    if addonName ~= SUI.name then return end
    if event ~= "ADDON_ACTION_BLOCKED" and event ~= "ADDON_ACTION_FORBIDDEN" then return end
    self:RecordError("protectedActions", event, functionName)
    -- Keep one snapshot per diagnostic session, even during a repeated error
    -- flood. Ordinary events and idle time never trigger a security scan.
    if not self.protectedSnapshot then
        local inCombat = InCombatLockdown and InCombatLockdown()
        self.protectedSnapshot = Text("%s: %s в %s, бой: %s", "%s: %s at %s, combat: %s"):format(
            event, tostring(functionName or Text("неизвестная функция", "unknown function")), Stamp(),
            inCombat and Text("да", "yes") or Text("нет", "no"))
            .. "\n" .. self:ActionBarTaintReport()
    end
end

SUI:RegisterModuleEvent(D, "ADDON_ACTION_BLOCKED")
SUI:RegisterModuleEvent(D, "ADDON_ACTION_FORBIDDEN")

function D:BuildReport()
    local lines = {
        Text("Диагностический отчет Sintezza UI", "Sintezza UI diagnostic report"),
        Text("Версия: ", "Version: ") .. tostring(SUI.version),
        Text("Клиент: ", "Client: ") .. (SUI.isForever and "WoW Forever" or "Retail"),
        Text("Профиль: ", "Profile: ") .. tostring(SUI.db and SUI.db.activeProfile or "?"),
        Text("Бой: ", "Combat: ") .. ((InCombatLockdown and InCombatLockdown()) and Text("да", "yes") or Text("нет", "no")),
        Text("Ошибок: ", "Errors: ") .. tostring(self.totalErrors),
        "",
        Text("Модули:", "Modules:"),
    }
    for _, key in ipairs(SUI.moduleOrder or {}) do
        local state = self:ModuleDetails(key)
        lines[#lines + 1] = ("- %s: %s"):format(key, state)
    end
    local cooldowns = SUI:GetModule("cooldownMasks")
    if cooldowns and type(cooldowns.ShadeDiagnostic) == "function" then
        local ok, details = pcall(cooldowns.ShadeDiagnostic, cooldowns)
        if ok then lines[#lines + 1] = Text("- оформление отката: ", "- cooldown shade: ") .. details end
    end
    local subscriptions, enabledFeatures = {}, {}
    for event in pairs(SUI.activeEvents) do subscriptions[#subscriptions + 1] = event end
    table.sort(subscriptions)
    for _, def in ipairs(SUI.featureList or {}) do
        if SUI:GetFeature(def.id) then enabledFeatures[#enabledFeatures + 1] = def.id end
    end
    lines[#lines + 1] = Text("Включенные функции: ", "Configured switches: ") .. table.concat(enabledFeatures, ", ")
    lines[#lines + 1] = Text("Подписки на события: ", "Subscribed events: ") .. table.concat(subscriptions, ", ")
    lines[#lines + 1] = ""
    if cooldowns and cooldowns.BroadcasterGuard then
        lines[#lines + 1] = Text("Защита панели команд: ", "Action-bar guard: ") .. cooldowns.BroadcasterGuard:Diagnostic()
    end
    lines[#lines + 1] = Text("Текущее состояние защиты панели команд:", "Action-bar security now:")
    lines[#lines + 1] = self:ActionBarTaintReport()
    if self.protectedSnapshot then
        lines[#lines + 1] = Text("Первая блокировка защищенного действия:", "First protected-action snapshot:")
        lines[#lines + 1] = self.protectedSnapshot
    end
    lines[#lines + 1] = Text("Аддоны:", "AddOns:")
    for _, addon in ipairs({
        "EllesmereUI", "EllesmereUIActionBars", "EllesmereUICooldownManager",
        "EllesmereUINameplates", "DandersFrames", "SharedMediaAdditionalFonts", "ShortestPathForever",
    }) do
        local loaded = SUI:IsAddonLoaded(addon)
        lines[#lines + 1] = ("- %s: %s %s"):format(addon,
            loaded and Text("загружен", "loaded") or Text("не загружен", "not loaded"), SUI:GetAddonVersion(addon) or "")
    end
    if self.totalErrors > 0 then
        lines[#lines + 1] = ""
        lines[#lines + 1] = Text("Последние ошибки:", "Last errors:")
        for key, state in pairs(self.errors) do
            lines[#lines + 1] = ("- %s [%s] %s: %s"):format(
                key, state.time or "?", state.context or "runtime", state.message or "?")
        end
    end
    return table.concat(lines, "\n")
end

function D:ShowReport()
    if not self.reportFrame then
        local T, W = SUI.SettingsTheme, SUI.Widgets
        local frame = CreateFrame("Frame", "Sintezza_UIDiagnosticReport", UIParent, "BackdropTemplate")
        frame:SetSize(690, 430)
        frame:SetPoint("CENTER")
        frame:SetFrameStrata("FULLSCREEN_DIALOG")
        frame:SetClampedToScreen(true)
        frame:EnableMouse(true)
        T:WindowSurface(frame)

        W:WindowHeader(frame, {
            icon = Sintezza_Theme.icons.Sintezza_UI,
            title = SUI.Text("Диагностический отчет", "Diagnostic report"),
            subtitle = SUI.Text("Ctrl+A, Ctrl+C — скопировать", "Ctrl+A, Ctrl+C to copy"),
        })

        local scroll = CreateFrame("ScrollFrame", nil, frame, "BackdropTemplate")
        scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -58)
        scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -29, 16)
        T:Backdrop(scroll, T.input, T.lineSoft)
        local edit = CreateFrame("EditBox", nil, scroll)
        edit:SetMultiLine(true)
        edit:SetAutoFocus(false)
        edit:SetWidth(640)
        edit:SetFontObject(ChatFontNormal)
        edit:SetTextInsets(10, 10, 8, 8)
        edit:SetHeight(720)
        edit:SetScript("OnEscapePressed", function() frame:Hide() end)
        scroll:SetScrollChild(edit)
        SUI.SettingsTheme:AttachScrollBar(scroll, frame, 34)
        frame.edit = edit
        self.reportFrame = frame
    end
    self.reportFrame.edit:SetText(self:BuildReport())
    self.reportFrame:Show()
    self.reportFrame.edit:SetFocus()
    self.reportFrame.edit:HighlightText()
end
