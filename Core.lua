local ADDON_NAME, SUI = ...

_G.Sintezza_UI = SUI
SUI.name = ADDON_NAME
SUI.title = "Sintezza UI"
SUI.version = (C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version")) or "1.5.153"
local interface = GetBuildInfo and select(4, GetBuildInfo())
SUI.isForever = type(interface) == "number" and interface >= 16000 and interface < 17000
SUI.modules = {}
SUI.moduleOrder = {}
SUI.settingsPages = {}
SUI.eventSubscribers = {}
SUI.activeEvents = {}
SUI.invalidEvents = {}
SUI.initialized = false

function SUI:Print(message)
    DEFAULT_CHAT_FRAME:AddMessage("|cff0cd29fSintezza UI:|r " .. tostring(message))
end

function SUI:RegisterModule(key, module)
    assert(type(key) == "string" and type(module) == "table", "invalid module")
    if self.modules[key] then return self.modules[key] end
    module.key = key
    module.addon = self
    self.modules[key] = module
    self.moduleOrder[#self.moduleOrder + 1] = key
    return module
end

function SUI:GetModule(key)
    return self.modules[key]
end

function SUI:SafeModuleCall(module, context, method, ...)
    if type(module) ~= "table" then return false, "module is unavailable" end
    local callback = type(method) == "string" and module[method] or method
    if type(callback) ~= "function" then return true end
    local ok, result = pcall(callback, module, ...)
    if not ok then
        if self.Diagnostics then
            self.Diagnostics:RecordError(module.key or "core", context or tostring(method), result)
        end
        self:Print((module.key or "core") .. ": " .. tostring(result))
    end
    return ok, result
end

function SUI:After(delay, module, context, callback)
    if not (C_Timer and C_Timer.After) or type(callback) ~= "function" then return end
    C_Timer.After(delay or 0, function()
        self:SafeModuleCall(module, context or "timer", callback)
    end)
end

function SUI:RegisterSettingsPage(definition)
    if not definition or not definition.key or not definition.builder then return end
    self.settingsPages[#self.settingsPages + 1] = definition
end

function SUI:RegisterModuleEvent(module, event)
    local list = self.eventSubscribers[event]
    if not list then
        list = {}
        self.eventSubscribers[event] = list
    end
    for _, current in ipairs(list) do
        if current == module then return end
    end
    list[#list + 1] = module
    if self.initialized then self:RefreshModuleEvents() end
end

function SUI:RefreshModuleEvents()
    local plates = self.modules.nameplates
    if self.initialized and plates and plates.RefreshFeatureDemand and not plates.initializeError then
        self:SafeModuleCall(plates, "nameplate feature demand", plates.RefreshFeatureDemand)
    end
    for event, subscribers in pairs(self.eventSubscribers) do
        if not self.invalidEvents[event] then
            local wanted = false
            for _, module in ipairs(subscribers) do
                if not module.initializeError and (not module.WantsEvent or module:WantsEvent(event)) then
                    wanted = true
                    break
                end
            end
            if wanted and not self.activeEvents[event] then
                local valid = not (C_EventUtils and C_EventUtils.IsEventValid) or C_EventUtils.IsEventValid(event)
                if valid and pcall(self.eventFrame.RegisterEvent, self.eventFrame, event) then
                    self.activeEvents[event] = true
                else
                    self.invalidEvents[event] = true
                end
            elseif not wanted and self.activeEvents[event] then
                self.eventFrame:UnregisterEvent(event)
                self.activeEvents[event] = nil
            end
        end
    end
end

function SUI:DispatchEvent(event, ...)
    local list = self.eventSubscribers[event]
    if not list then return end
    for _, module in ipairs(list) do
        if module.OnEvent and not module.initializeError and (not module.WantsEvent or module:WantsEvent(event)) then
            self:SafeModuleCall(module, event, module.OnEvent, event, ...)
        end
    end
    if event == "PLAYER_REGEN_ENABLED" then self:RefreshModuleEvents() end
end

function SUI:IsAddonLoaded(name)
    return C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded(name) or false
end

function SUI:GetAddonVersion(name)
    if not C_AddOns or not C_AddOns.GetAddOnMetadata then return nil end
    return C_AddOns.GetAddOnMetadata(name, "Version")
end

function SUI:OpenSettings(page, tab)
    if self.SettingsUI then self.SettingsUI:Show(page, tab) end
end

function SUI:OpenTalents()
    if self.isForever or (InCombatLockdown and InCombatLockdown()) then return false end
    local fn = (PlayerSpellsUtil and PlayerSpellsUtil.ToggleClassTalentFrame) or ToggleTalentFrame
    if type(fn) ~= "function" then return false end
    local ok = pcall(fn)
    return ok
end

function SUI:GetClassSpecScope()
    local _, class, classID = UnitClass("player")
    if self.isForever then return tostring(classID or 0) .. ":forever", class or "UNKNOWN", 0, "Forever" end
    local api = C_SpecializationInfo or {}
    local getSpec = api.GetSpecialization or GetSpecialization
    local getInfo = api.GetSpecializationInfo or GetSpecializationInfo
    local index = type(getSpec) == "function" and getSpec()
    local id, name
    if not (issecretvalue and issecretvalue(index)) and type(index) == "number" and type(getInfo) == "function" then
        id, name = getInfo(index)
        if issecretvalue and (issecretvalue(id) or issecretvalue(name)) then id, name = nil, nil end
    end
    return tostring(classID or 0) .. ":" .. tostring(id or 0), class or "UNKNOWN", id or 0, name or SUI.Text("Без специализации", "No specialization")
end

SUI.eventFrame = CreateFrame("Frame")
SUI.eventFrame:RegisterEvent("ADDON_LOADED")
SUI.eventFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" and (...) == ADDON_NAME then
        SUI.eventFrame:UnregisterEvent("ADDON_LOADED")
        if SUI.Initialize then SUI:Initialize() end
        return
    end
    SUI:DispatchEvent(event, ...)
end)

SLASH_SINTEZZA_UI1 = "/sui"
SLASH_SINTEZZA_UI2 = "/sintezzaui"
SLASH_SINTEZZA_UI3 = "/standaloneui"
SlashCmdList.SINTEZZA_UI = function(input)
    input = (input or ""):lower():match("^%s*(.-)%s*$")
    if input == "whisperlog" then
        local module = SUI:GetModule("chatWhisperErrors")
        if module then module:PrintStatus() end
        return
    end
    if input == "npstatus" then
        local module = SUI:GetModule("nameplates")
        if module and module.PrintStatus then module:PrintStatus() end
        return
    end
    if input == "dida" then
        local module = SUI:GetModule("fontCompatibility")
        if module then module:PrintDidaShapeStatus() end
        return
    end
    if input == "tipfont" then
        local module = SUI:GetModule("fontCompatibility")
        if module and module.PrintTooltipFontStatus then module:PrintTooltipFontStatus() end
        return
    end
    if input == "report" then
        if SUI.Diagnostics then SUI.Diagnostics:ShowReport() end
        return
    elseif input == "reconnect" then
        if SUI.Diagnostics then
            local _, message = SUI.Diagnostics:ReconnectEUI()
            SUI:Print(message)
        end
        return
    end
    local aliases = {
        nameplates = "nameplates",
        np = "nameplates",
        auras = "auraRules",
        rules = "auraRules",
        cooldowns = "cooldownMasks",
        swipe = "cooldownMasks",
        masks = "cooldownMasks",
        buffs = "cooldownBuffEffects",
        procs = "cooldownProcEffects",
        gamebar = "gameBar",
        bar = "gameBar",
        raid = "raidTools",
        raidtools = "raidTools",
        fonts = "combatFont",
        profiles = "profiles",
        features = "features",
        status = "diagnostics",
    }
    SUI:OpenSettings(aliases[input] or "dashboard")
end
