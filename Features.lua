local _, SUI = ...
local Text = SUI.Text

local function P(key) return SUI:GetModuleProfile(key) or {} end

local GameBar, SpecBar = SUI.GameBar, SUI:GetModule("specBar")
local Combat, Teleport = SUI:GetModule("combatAlert"), SUI:GetModule("teleportPrompt")
local Raid, Plates, Cooldowns = SUI.RaidTools, SUI.Nameplates, SUI.CooldownMasks
local Fonts = SUI:GetModule("fontCompatibility")

function GameBar:HasButton(id)
    local profile = P("gameBar")
    if not profile.enabled or (profile.hiddenButtons and profile.hiddenButtons[id]) then return false end
    for _, buttons in ipairs({ profile.leftButtons or {}, profile.rightButtons or {} }) do
        for _, value in ipairs(buttons) do if value == id then return true end end
    end
    return false
end

function GameBar:WantsEvent(event)
    local profile = P("gameBar")
    local mini = profile.miniBar or {}
    local mainOn, miniOn = profile.enabled == true, mini.enabled == true
    if event == "PLAYER_REGEN_ENABLED" and self.pendingSecureUpdate then return true end
    if event == "PLAYER_HOUSE_LIST_UPDATED" then return not SUI.isForever and self:HasButton("HOME") end
    if event == "FRIENDLIST_UPDATE" or event == "BN_FRIEND_LIST_SIZE_CHANGED" or event == "BN_FRIEND_INFO_CHANGED" then
        return self:HasButton("FRIENDS") or (miniOn and mini.showFriends ~= false)
    end
    if event == "GUILD_ROSTER_UPDATE" or event == "PLAYER_GUILD_UPDATE" then
        return self:HasButton("GUILD") or (miniOn and mini.showGuild ~= false)
    end
    if event == "PLAYER_UPDATE_RESTING" or event == "PLAYER_FLAGS_CHANGED" then
        return miniOn and mini.showResting ~= false
    end
    return mainOn or miniOn
end

function SpecBar:WantsEvent(event)
    if event == "PLAYER_REGEN_ENABLED" and self.pendingSecureUpdate then return true end
    if not self:HasActiveButtons() then return false end
    if SUI.isForever then
        return event ~= "PLAYER_LOOT_SPEC_UPDATED" and event ~= "PLAYER_SPECIALIZATION_CHANGED"
    end
    return event ~= "CHARACTER_POINTS_CHANGED" and event ~= "PLAYER_TALENT_UPDATE"
end

function Combat:WantsEvent(event)
    local profile = P("combatAlert")
    if not profile.enabled then return false end
    local stealth = profile.stealthEnabled and (profile.showStealthEnter or profile.showStealthLeave)
    if event == "UPDATE_STEALTH" or event == "PLAYER_ENTERING_WORLD" then return stealth end
    return profile.showEnter or profile.showLeave
end

function Teleport:WantsEvent(event)
    if SUI.isForever then return false end
    if event == "PLAYER_REGEN_ENABLED" and (self.pendingDeactivate or self.pendingBuild or self.pendingAppearance) then return true end
    if not self:IsEnabled() then return false end
    if event == "SPELL_UPDATE_COOLDOWN" then
        return self.pendingEntry ~= nil and P("teleportPrompt").showCooldown ~= false
    end
    return true
end

function Raid:WantsEvent(event)
    local profile = P("raidTools")
    local audit = profile.raidCheck or {}
    if event == "PLAYER_REGEN_ENABLED" and (self.pendingSecureUpdate or self.pendingRetry) then return true end
    if not profile.enabled then return false end
    if event == "UNIT_AURA" then
        local columns = audit.columns or {}
        return audit.enabled and (columns.food or columns.flask or columns.rune or columns.buffs)
            and self.audit and self.audit:IsShown() and not self.testMode
    end
    if event == "READY_CHECK" or event == "READY_CHECK_CONFIRM" or event == "READY_CHECK_FINISHED" then return audit.enabled end
    for _, panel in pairs(profile.panels or {}) do
        if panel.enabled then return true end
    end
    return audit.enabled
end

function Plates:WantsEvent(event)
    if event == "PLAYER_REGEN_ENABLED" and (self.pendingShutdown or self.pendingBuffRows) then return true end
    if not self.runtimeWanted then return false end
    if event == "UNIT_AURA" then return P("nameplates").learnDebuffs == true end
    return true
end

function Cooldowns:WantsEvent(event)
    local p = P("cooldownMasks")
    if not self:HasVisuals() then return false end
    if event == "UNIT_AURA" then return p.buffEffects and p.buffEffects.enabled ~= false end
    if event == "SPELL_ACTIVATION_OVERLAY_SHOW" or event == "SPELL_ACTIVATION_OVERLAY_HIDE" then
        return p.procEffects and p.procEffects.enabled == true
    end
    if event == "ACTIONBAR_UPDATE_COOLDOWN" or event == "ACTIONBAR_SLOT_CHANGED"
        or event == "SPELL_UPDATE_COOLDOWN" or event == "SPELL_UPDATE_CHARGES" then
        return self:ActionBarSwipeReady() and p.actionBars ~= false
    end
    return true
end

function Fonts:WantsEvent(event)
    if event == "PLAYER_REGEN_ENABLED" then
        local borders = self.pendingBorders
        return self.pendingRoundedFrames or self.pendingFrameAppearance or self.pendingDispelShape or self.pendingEUISeams or self.pendingNameplateSeams
            or self.pendingFontRefresh or self.pendingAbsorbInset
            or (borders and (borders.party or borders.raid))
    end
    if event == "NAME_PLATE_UNIT_ADDED" then return self.didPlateNS ~= nil or self.roundingNameplateNS ~= nil end
    if event == "UNIT_AURA" then return self.didPlateNS ~= nil end
    return event == "PLAYER_ENTERING_WORLD" or event == "ADDON_LOADED"
end

SUI.featureGroups = {
    { key = "panels", title = Text("Панели", "Bars") },
    { key = "raid", title = Text("Группа", "Group") },
    { key = "visual", title = Text("Бой и цели", "Combat and targets") },
    { key = "cooldowns", title = Text("Откат", "Cooldowns") },
    { key = "compat", title = Text("Оформление", "Appearance") },
}
SUI.featureList, SUI.featureByID = {}, {}

local function Add(group, id, label, moduleKey, path, available, reason)
    local def = { group = group, id = id, label = label, moduleKey = moduleKey,
        path = path, available = available, reason = reason }
    SUI.featureList[#SUI.featureList + 1] = def
    SUI.featureByID[id] = def
    return def
end
local function Retail() return not SUI.isForever end

Add("panels", "gameBar", Text("Игровая панель", "Game bar"), "gameBar", { "enabled" })
Add("panels", "gameClock", Text("Часы игровой панели", "Game bar clock"), "gameBar", { "clock", "enabled" })
Add("panels", "miniBar", Text("Панель у миникарты", "Minimap bar"), "gameBar", { "miniBar", "enabled" })
for _, item in ipairs({
    { "showClock", Text("Часы миникарты", "Minimap clock") }, { "showFriends", Text("Друзья у миникарты", "Friends on the minimap bar") },
    { "showGuild", Text("Гильдия у миникарты", "Guild on the minimap bar") }, { "showResting", Text("Индикатор отдыха", "Resting indicator") },
    { "showFPS", "FPS" }, { "showLatency", Text("Задержка", "Latency") },
}) do
    Add("panels", item[1], item[2], "gameBar", { "miniBar", item[1] })
end
Add("panels", "specBar", Text("Панель талантов / спека", "Talent and spec bar"), "specBar", { "enabled" })
Add("panels", "specActive", SUI.isForever and Text("Кнопка талантов", "Talent button") or Text("Кнопка специализации", "Spec button"), "specBar", { "showActive" })
Add("panels", "specLoot", Text("Специализация добычи", "Loot specialization"), "specBar", { "showLoot" }, Retail, Text("В Forever нет отдельного выбора спека добычи.", "Forever does not have a separate loot specialization."))
for _, id in ipairs({ "CHARACTER", "SPELLBOOK", "TALENTS", "FRIENDS", "GUILD", "GROUP_FINDER", "PROFESSION",
    "GAMEMENU", "HOME", "ACHIEVEMENTS", "ENCOUNTER_JOURNAL", "COLLECTIONS", "BLIZZARD_SHOP", "BAGS" }) do
    local entry = GameBar:GetButtonEntry(id)
    local function Available() return GameBar:IsButtonAvailable(id) end
    local def = Add("panels", "bar." .. id, Text("Панель: ", "Bar: ") .. entry.label, "gameBar", { "hiddenButtons", id }, Available)
    def.invert = true
end
Add("raid", "raidTools", Text("Рейд-инструменты", "Raid tools"), "raidTools", { "enabled" })
Add("raid", "partyMap", Text("Группа на карте", "Party on the map"), "partyMap", { "enabled" })
Add("raid", "partyMap.markers", Text("Метки группы на карте", "Party markers"), "partyMap", { "markers" })
local function Forever() return SUI.isForever end
local foreverOnly = Text("Доступно в WoW Forever.", "Available in WoW Forever.")
Add("raid", "mapDisplay.stackTabs", Text("Разнести вкладки справа", "Stack right-side tabs"), "mapDisplay", { "stackTabs" }, Forever, foreverOnly)
Add("raid", "mapWaypointControls", Text("Личная метка Sintezza UI", "Sintezza UI waypoint"), "mapWaypointControls", { "enabled" },
    function() return SUI.isForever end, Text("Доступно в WoW Forever.", "Available in WoW Forever."))
Add("raid", "shortestPathMinimap", Text("Маршрут Shortest Path", "Shortest Path route"), "shortestPathMinimap", { "enabled" },
    function() return SUI:GetModule("shortestPathMinimap"):IsSupported() end,
    Text("Нужна совместимая версия Shortest Path Forever.", "Requires a compatible version of Shortest Path Forever."))
Add("raid", "transportMap", Text("Таймеры транспорта на карте", "Transport timers on the world map"), "transportMap", { "enabled" },
    function() return SUI.isForever end, Text("Расписание рассчитано для WoW Forever.", "Schedules are for WoW Forever."))
Add("raid", "transportMap.minimap", Text("Таймеры транспорта на миникарте", "Transport timers on the minimap"), "transportMap", { "minimap" },
    function() return SUI.isForever end, Text("Расписание рассчитано для WoW Forever.", "Schedules are for WoW Forever."))
for _, item in ipairs({ { "TARGET", Text("Метки целей", "Target markers") }, { "WORLD", Text("Метки мира", "World markers") },
    { "CONTROL", Text("Панель команд", "Action bar") }, { "PING", Text("Пинги миникарты", "Minimap pings") } }) do
    Add("raid", item[1], item[2], "raidTools", { "panels", item[1], "enabled" })
end
Add("raid", "ready", Text("Кнопка проверки готовности", "Ready check button"), "raidTools", { "actions", "readyCheck" })
Add("raid", "pull", Text("Отсчет до боя", "Pull timer"), "raidTools", { "actions", "pullTimer" })
Add("raid", "clear", Text("Кнопка очистки меток мира", "Clear world markers button"), "raidTools", { "actions", "worldClear" })
Add("raid", "raidCheck", Text("Окно проверки рейда", "Raid check window"), "raidTools", { "raidCheck", "enabled" })
Add("raid", "raidAuto", Text("Открывать проверку автоматически", "Open raid check automatically"), "raidTools", { "raidCheck", "autoShow" })
for _, item in ipairs({ { "food", Text("Проверять еду", "Check food") }, { "flask", Text("Проверять настой", "Check flask") },
    { "rune", Text("Проверять руну", "Check rune") }, { "buffs", Text("Проверять бафы", "Check buffs") } }) do
    Add("raid", item[1], item[2], "raidTools", { "raidCheck", "columns", item[1] },
        item[1] == "rune" and Retail or nil)
end
Add("raid", "teleport", Text("Напоминание о телепорте", "Teleport reminder"), "teleportPrompt", { "enabled" }, Retail, Text("Каталог телепортов относится к Retail.", "Teleport list is for Retail."))

Add("visual", "combatAlert", Text("Сигналы боя и скрытности", "Combat and stealth alerts"), "combatAlert", { "enabled" })
Add("visual", "combatFont", Text("Приоритет боевого шрифта Sintezza", "Sintezza combat font priority"), "combatFont", { "enabled" })
Add("visual", "combatEnter", Text("Вход в бой", "Enter combat"), "combatAlert", { "showEnter" })
Add("visual", "combatLeave", Text("Выход из боя", "Leave combat"), "combatAlert", { "showLeave" })
Add("visual", "stealth", Text("Сигнал скрытности", "Stealth alert"), "combatAlert", { "stealthEnabled" })
Add("visual", "stealthEnter", Text("Вход в скрытность", "Enter stealth"), "combatAlert", { "showStealthEnter" })
Add("visual", "stealthLeave", Text("Выход из скрытности", "Leave stealth"), "combatAlert", { "showStealthLeave" })
Add("visual", "nameplates", Text("Дополнения к неймплейтам", "Nameplate extensions"), "nameplates", { "enabled" })
Add("visual", "threat", Text("Угроза в открытом мире", "Open-world threat"), "nameplates", { "openWorldThreat" })
Add("visual", "threatNear", Text("Предупреждение об угрозе", "Threat warning"), "nameplates", { "nearThreat" })
Add("visual", "threatBorder", Text("Контур угрозы", "Threat border"), "nameplates", { "threatBorderEnabled" })
Add("visual", "threatFill", Text("Заливка угрозы", "Threat fill"), "nameplates", { "threatFillEnabled" })
Add("visual", "targetPattern", Text("Узор выбранной цели", "Target pattern"), "nameplates", { "targetPattern", "enabled" })
Add("visual", "auraRules", Text("Правила окраски по аурам", "Aura color rules"), "nameplates", nil).resolve = function() return Plates.AuraRules:Profile(), "enabled" end
Add("visual", "pandemic", Text("Подсветка Pandemic", "Pandemic highlight"), "nameplates", { "auraRules", "pandemic", "enabled" })
Add("visual", "learnDebuffs", Text("Запоминать увиденные дебаффы", "Remember seen debuffs"), "nameplates", { "learnDebuffs" })

Add("cooldowns", "cooldownMasks", Text("Иконки и откат", "Icons and cooldowns"), "cooldownMasks", { "enabled" })
Add("cooldowns", "actionBars", Text("Свайп панелей действий EUI", "EllesmereUI action bar swipe"), "cooldownMasks", { "actionBars" })
Add("cooldowns", "rangeFade", Text("Выделять иконки вне радиуса", "Highlight out-of-range icons"), "cooldownMasks", { "rangeFade" },
    function() return Cooldowns:RangeFadeSupported() end, Text("Требуются панели команд EllesmereUI в Forever.", "Requires EllesmereUI Action Bars in Forever."))
Add("cooldowns", "cdm", Text("Свайп Cooldown Manager EUI", "EllesmereUI Cooldown Manager swipe"), "cooldownMasks", { "cooldownManager" })
Add("cooldowns", "hideSpark", Text("Скрывать искру отката", "Hide cooldown spark"), "cooldownMasks", { "hideSpark" })
Add("cooldowns", "buffEffects", Text("Эффекты бафов", "Buff effects"), "cooldownMasks", { "buffEffects", "enabled" })
Add("cooldowns", "procEffects", Text("Эффекты проков", "Proc effects"), "cooldownMasks", { "procEffects", "enabled" })

Add("compat", "fonts", Text("Кириллица в DandersFrames", "Cyrillic in DandersFrames"), "fontCompatibility", { "enabled" })
Add("compat", "borderMedia", Text("Текстуры рамок в SharedMedia", "Frame textures in SharedMedia"), "fontCompatibility", { "borderMedia" })
Add("compat", "absorb", Text("Отступ щитов DandersFrames", "DandersFrames absorb inset"), "fontCompatibility", { "absorbInset" })
Add("compat", "hover", Text("Анимация наведения", "Hover animation"), "interactionEffects", { "enabled" })
Add("compat", "chatWhisperErrors", Text("Скрывать ошибки служебных шепотов", "Hide addon whisper errors"), "chatWhisperErrors", { "enabled" },
    function() return SUI.isForever end, Text("Доступно в WoW Forever.", "Available in WoW Forever."))
Add("compat", "lueurCompatibility", Text("Lueur: подсветка вне боя", "Lueur: highlight outside combat"), "lueurCompatibility", { "enabled" },
    function() return SUI:GetModule("lueurCompatibility"):IsAvailable() end,
    Text("Требуется Lueur в Forever. Подсветка остается вне боя, а в бою приостанавливается.", "Requires Lueur in Forever. Highlighting pauses in combat."))
local minimap = Add("compat", "minimap", Text("Кнопка Sintezza UI у миникарты", "Sintezza UI minimap button"))
minimap.resolve = function() return SUI.db and SUI.db.minimap, "hidden" end
minimap.invert = true

local ACTION_BARS = { "EllesmereUIActionBars", Text("Панели команд EllesmereUI", "EllesmereUI Action Bars") }
local COOLDOWN_MANAGER = { "EllesmereUICooldownManager", "Cooldown Manager EllesmereUI" }
local DANDERS = { "DandersFrames", "DandersFrames" }
local UNIT_FRAMES = { "EllesmereUIUnitFrames", Text("Рамки игроков EllesmereUI", "EllesmereUI Unit Frames") }
local NAMEPLATES = { "EllesmereUINameplates", Text("Неймплейты EllesmereUI", "EllesmereUI Nameplates") }
local SHARED_MEDIA = { nil, "LibSharedMedia" }
local SHORTEST_PATH = { "ShortestPathForever", "Shortest Path Forever" }
local requirements = {
    shortestPathMinimap = { SHORTEST_PATH },
    transportMap = { SHORTEST_PATH },
    ["transportMap.minimap"] = { SHORTEST_PATH },
    actionBars = { ACTION_BARS },
    rangeFade = { ACTION_BARS },
    cdm = { COOLDOWN_MANAGER },
    hideSpark = { COOLDOWN_MANAGER },
    buffEffects = { COOLDOWN_MANAGER },
    procEffects = { COOLDOWN_MANAGER },
    cooldownMasks = { ACTION_BARS, COOLDOWN_MANAGER, any = true },
    fonts = { DANDERS, SHARED_MEDIA },
    borderMedia = { SHARED_MEDIA },
    absorb = { DANDERS },
    rounded = { DANDERS, UNIT_FRAMES, NAMEPLATES, any = true },
    ["rounded.dandersFrames"] = { DANDERS },
    ["rounded.unitFrames"] = { UNIT_FRAMES },
    ["rounded.nameplates"] = { NAMEPLATES },
    lueurCompatibility = { { "Lueur", "Lueur" } },
}
local foreverRequirements = { transportMap = true, shortestPathMinimap = true, rangeFade = true, lueurCompatibility = true }

function SUI:GetAddonAvailability(folder, title)
    local api = C_AddOns
    title = title or folder
    if not api then return false, title .. Text(" не загружен", " is not loaded") end
    if api.DoesAddOnExist and not api.DoesAddOnExist(folder) then
        return false, Text("Нет аддона ", "Missing addon ") .. title
    end
    local reason
    if api.GetAddOnInfo then
        local ok, name, _, _, _, cause = pcall(api.GetAddOnInfo, folder)
        if not ok or not name or cause == "MISSING" then return false, Text("Нет аддона ", "Missing addon ") .. title end
        reason = cause
    end
    if api.GetAddOnEnableState and api.GetAddOnEnableState(folder) == 0 then
        return false, title .. Text(" отключен", " is disabled")
    end
    local loading, loaded
    if api.IsAddOnLoaded then loading, loaded = api.IsAddOnLoaded(folder) end
    if loaded == true or (loaded == nil and loading == true) then return true end
    if reason == "INTERFACE_VERSION" or reason == "INCOMPATIBLE" then
        return false, title .. Text(" несовместим с клиентом", " is incompatible with this client")
    end
    return false, title .. Text(" не загружен", " is not loaded")
end

function SUI:GetFeatureRequirementLabel(id)
    local deps = requirements[id]
    if not deps then return end
    local names = {}
    for i, item in ipairs(deps) do names[i] = item[2] end
    return table.concat(names, deps.any and Text(" или ", " or ") or Text(" и ", " and "))
end

function SUI:GetFeatureAvailability(id)
    local def = self.featureByID[id]
    if not def then return false end
    if foreverRequirements[id] and not self.isForever then return false, Text("Доступно в WoW Forever", "Available in WoW Forever") end
    local deps = requirements[id]
    if deps then
        local found
        for _, item in ipairs(deps) do
            local available, reason
            if item == SHARED_MEDIA then
                available, reason = Fonts:GetLSM() ~= nil, Text("LibSharedMedia не загружена", "LibSharedMedia is not loaded")
            else
                available, reason = self:GetAddonAvailability(item[1], item[2])
            end
            found = found or available
            if not deps.any and not available then return false, reason end
        end
        if deps.any and not found then return false, Text("Нужны ", "Requires ") .. self:GetFeatureRequirementLabel(id) end
    end
    if def.available and not def.available() then return false, def.reason or Text("Недоступно в этой версии WoW", "Unavailable on this WoW client") end
    return true
end

local function Resolve(def)
    if def.resolve then return def.resolve() end
    local node, path = P(def.moduleKey), def.path
    for index = 1, #path - 1 do
        node = node[path[index]]
        if type(node) ~= "table" then return nil end
    end
    return node, path[#path]
end

function SUI:GetFeatureSetting(id)
    local def = self.featureByID[id]
    if not def then return false end
    local node, key = Resolve(def)
    if not node then return false end
    if def.invert then return node[key] ~= true end
    return node[key] == true
end

function SUI:GetFeature(id)
    return self:GetFeatureAvailability(id) and self:GetFeatureSetting(id)
end

function SUI:SetFeature(id, value)
    local def = self.featureByID[id]
    if not def or not self:GetFeatureAvailability(id) then return false end
    local node, key = Resolve(def)
    if not node then return false end
    local enabled = value == true
    if def.invert then node[key] = not enabled else node[key] = enabled end
    local m = self:GetModule(def.moduleKey)
    if m then
        if id == "hideSpark" then self:SafeModuleCall(m, "feature " .. id, m.SetHideSpark, enabled)
        elseif m.OnProfileChanged then self:SafeModuleCall(m, "feature " .. id, m.OnProfileChanged)
        else self:SafeModuleCall(m, "feature " .. id, m.RefreshAll, true) end
        if not enabled and (id == "fonts" or id == "borderMedia") and m.reloadRequired then
            self:Print(Text("Для снятия регистрации шрифтов или текстур нужен /reload.", "Use /reload to unregister fonts or textures."))
        end
    elseif id == "hover" then
        self.HoverEffects:RefreshAll()
    elseif id == "minimap" then
        self.MinimapButton:RefreshVisibility()
    end
    self:RefreshModuleEvents()
    return true
end
