local _, SUI = ...
local Text = SUI.Text

local groups = {}
local byID, session = {}, {}
local function Group(title)
    local group = { title = title, rows = {} }
    groups[#groups + 1] = group
    return group
end

local function Add(group, id, ru, en, row)
    row.id, row.label = id, Text(ru, en)
    group.rows[#group.rows + 1] = row
    byID[id] = row
end

local function Function(value) return type(value) == "function" end
local function EUI(module)
    local eui = _G.EllesmereUI
    if not module then return eui end
    return eui and eui._ModuleNS and eui._ModuleNS[module]
end

local function Namespaced(module, member, memberType)
    return function()
        local object = EUI(module)
        return object and type(object[member]) == (memberType or "function")
    end
end

local function World()
    return _G.WorldMapFrame and Function(_G.WorldMapFrame.AddCanvasClickHandler)
end

local function Stitched()
    local api = _G.OpenMapAPI
    return api and api.major == 1 and Function(api.IsStitched) and Function(api.MapFromWorld)
        and Function(api.WorldFromMap)
end

local function LSM()
    local fonts = SUI:GetModule("fontCompatibility")
    return fonts and fonts:GetLSM()
end

local actionBars = "EllesmereUIActionBars"
local cooldownManager = "EllesmereUICooldownManager"
local nameplates = "EllesmereUINameplates"
local shortest = "ShortestPathForever"
local danders = "DandersFrames"

local appearance = Group("EllesmereUI")
local dandersGroup = Group("DandersFrames")
local sharedMedia = Group("LibSharedMedia")
local tacoTip = Group("TacoTip")
local doesItDie = Group("Does It Die Advanced")
local personalFonts = Group("FontMagicCustomFonts / Sintezza UI LocalFonts")
local lueur = Group("Lueur")
local openMap = Group("OpenMap")
local shortestPath = Group("Shortest Path Forever")
local openXP = Group("OpenXP")
local guides = Group("FlowUp / ForeverGuide")
local rivals = Group("Sintezza Rivals")
local execute = Group("Sintezza Execute")
local own = Group("Sintezza UI")
Add(appearance, "plates", "Дополнения к неймплейтам", "Nameplate extensions", {
    feature = "nameplates", probe = function()
        local ns = EUI(nameplates)
        return ns and type(ns.plates) == "table" and Function(_G.hooksecurefunc)
            and Function(ns.EnsureHoverOverlay) and Function(ns.EnsureTargetOverlay)
    end,
    addons = { nameplates }, fallback = function()
        local names = { nameplates, "Plater", "Platynator", "Kui_Nameplates", "NeatPlates", "TidyPlates_ThreatPlates", "ThreatPlates" }
        for _, name in ipairs(names) do if SUI:IsAddonLoaded(name) then return false end end
        return _G.C_NamePlate and Function(_G.C_NamePlate.GetNamePlateForUnit)
    end,
})
Add(appearance, "swipe", "Свайп панелей команд", "Action bar swipes", {
    feature = "actionBars", addons = { actionBars }, parent = "cooldownMasks",
    probe = function()
        local ns = EUI(actionBars)
        return ns and ns.EAB and ns.EAB.db and ns.EAB.db.profile
    end,
    notice = function()
        local module = SUI:GetModule("cooldownMasks")
        if not module:ActionBarSwipeReady() then
            return Text("Установи CD Swipe Opacity = 0 в EllesmereUI.", "Set CD Swipe Opacity to 0 in EllesmereUI.")
        end
    end,
})
Add(appearance, "range", "Выделять иконки вне радиуса", "Highlight out-of-range icons", {
    feature = "rangeFade", addons = { actionBars }, client = "forever",
    probe = function() return SUI.CooldownMasks:RangeFadeSupported() end,
})
local function CDMAPI()
    local ns = EUI(cooldownManager)
    return ns and (type(ns._ecmeFC) == "table" or type(ns._hookFrameData) == "table")
end
Add(appearance, "cdm", "Свайп Cooldown Manager", "Cooldown Manager swipes", {
    feature = "cdm", addons = { cooldownManager }, probe = CDMAPI, parent = "cooldownMasks",
})
Add(appearance, "spark", "Скрывать искру отката", "Hide cooldown spark", {
    feature = "hideSpark", addons = { cooldownManager }, probe = CDMAPI, parent = "cooldownMasks",
})
Add(appearance, "buff", "Эффекты бафов", "Buff effects", {
    feature = "buffEffects", addons = { cooldownManager }, probe = CDMAPI, parent = "cooldownMasks",
})
Add(appearance, "proc", "Эффекты проков", "Proc effects", {
    feature = "procEffects", addons = { cooldownManager }, probe = CDMAPI, parent = "cooldownMasks",
})
Add(appearance, "cdmglow", "Контур свечения бафов", "Shaped cooldown buff glow", {
    addons = { cooldownManager }, reload = true, probe = function()
        local eui, ns = EUI(), EUI(cooldownManager)
        local glow = eui and eui.Glows
        return ns and glow and Function(glow.StartProceduralAnts)
            and Function(glow.StopProceduralAnts) and Function(glow.StartShapeGlow)
    end,
})
Add(appearance, "frames", "Общая форма рамок EllesmereUI", "Shared EllesmereUI frame shape", {
    addons = { "EllesmereUIUnitFrames", "EllesmereUIRaidFrames", "EllesmereUIResourceBars", actionBars, nameplates }, any = true, reload = true,
    probe = function()
        local eui = EUI()
        local ns = eui and eui._ModuleNS
        return ns and (Function(eui.RoundCorners)
            or (ns[nameplates] and Function(ns[nameplates].NP_ApplyRounding))
            or (ns[actionBars] and Function(ns[actionBars].StyleDataBarFrame))
            or (ns.EllesmereUIResourceBars and Function(ns.EllesmereUIResourceBars.ERB_RoundBar)))
    end,
    description = Text("Управляет дополнениями Sintezza к форме, радиусу и окантовке.", "Controls Sintezza's shape, radius, and border adaptations."),
})
Add(appearance, "glow", "Свечение напоминаний о баффах", "Buff reminder glow", {
    addons = { "EllesmereUIAuraBuffReminders" }, reload = true,
    probe = function()
        local eui = EUI()
        local glow = eui and eui.Glows
        return glow and Function(glow.StartSpecGlow) and Function(glow.StartShapeGlow) and Function(glow.StopProceduralAnts)
    end,
})
Add(appearance, "meters", "Дробные значения в счетчике урона", "Decimal values in Damage Meters", {
    addons = { "EllesmereUIDamageMeters" }, client = "forever", reload = true,
    probe = function()
        local eui = EUI()
        return eui and Function(eui.AbbreviateNumber) and Function(eui.NumberFormatOptions)
            and Function(_G.CreateAbbreviateConfig) and Function(_G.AbbreviateNumbers)
    end,
})
Add(appearance, "books", "Кнопки талантов и книги заклинаний", "Talent and spellbook buttons", {
    addons = { "EllesmereUIForeverEssentials" }, client = "forever", reload = true,
    probe = function() return _G.EUI_TalentsRoute ~= nil or _G.EUI_SpellbookRoute ~= nil end,
    fallback = function() return _G.TalentMicroButton or _G.SpellbookMicroButton end,
})
Add(appearance, "tooltip", "Шрифт добавленных строк подсказок", "Font for added tooltip lines", {
    addons = { "EllesmereUIBlizzardSkin" }, reload = true,
    probe = Namespaced(nil, "GetFontPath"),
    notice = function()
        local db = _G.EllesmereUIDB
        if db and db.customTooltips == false then
            return Text("Оформление подсказок выключено в EllesmereUI.", "Tooltip styling is off in EllesmereUI.")
        end
    end,
    description = Text("Включая совместимые строки Mastercraft.", "Includes compatible Mastercraft lines."),
})
Add(own, "combat", "Приоритет боевого шрифта Sintezza", "Sintezza combat font priority", {
    feature = "combatFont", relog = true,
    probe = function() return SUI:GetModule("combatFont"):CanOverride() end,
    conflict = function() return SUI:GetModule("combatFont"):OtherOwner() end,
    notice = function()
        local p = SUI:GetModuleProfile("combatFont")
        if p and (not p.font or p.font == "DEFAULT") then
            return Text("Выбери шрифт в разделе «Боевой текст».", "Choose a font under Combat text.")
        end
    end,
})
Add(appearance, "panelglow", "Свечение игровых и рейдовых панелей", "Game and raid panel glows", {
    addons = { "EllesmereUI" }, probe = Namespaced(nil, "ApplyBorderStyle"), refresh = { "gameBar", "raidTools" },
    description = Text("Используется при выборе стиля «Свечение».", "Used when the Glow style is selected."),
})
Add(appearance, "teleport", "Совместимость с LFG Reminder", "LFG Reminder compatibility", {
    addons = { "EllesmereUIQoL" }, client = "retail", refresh = { "teleportPrompt" },
    probe = function() return type(_G.EllesmereUIDB) == "table" end,
    description = Text("Убирает повторное напоминание о телепорте.", "Avoids a duplicate teleport reminder."),
})

Add(dandersGroup, "danders", "Форма рамок группы и рейда", "Party and raid frame shapes", {
    addons = { danders }, reload = true, probe = function()
        local df = _G.DandersFrames
        return df and Function(df.ApplyFrameBorder) and Function(df.GetFrameDB)
    end,
    description = Text("Текущие настройки рамок DandersFrames сохраняются.", "Current DandersFrames appearance settings are preserved."),
})
Add(dandersGroup, "absorb", "Отступ полосы поглощения", "Absorb inset", {
    feature = "absorb", addons = { danders }, probe = function()
        local df = _G.DandersFrames
        return df and Function(df.GetAbsorbEdgeInset)
    end,
})
Add(sharedMedia, "lsmframes", "Текстуры рамок в SharedMedia", "Frame textures in SharedMedia", {
    feature = "borderMedia", nativeMedia = true,
})
Add(dandersGroup, "lsmfonts", "Кириллица в шрифтах", "Cyrillic font support", {
    feature = "fonts", addons = { danders }, nativeMedia = true,
    probe = function()
        local df, lsm = _G.DandersFrames, LSM()
        return df and Function(df.RegisterFontAlphabetSupport) and lsm and Function(lsm.Fetch)
    end,
})
Add(tacoTip, "tacotip", "Шрифт уровня предметов и GearScore", "Item level and GearScore font", {
    addons = { "TacoTip" }, client = "forever", reload = true,
    probe = function() return _G.TacoTip and Function(_G.TacoTip.RefreshForeverCharacterStatsFooter) and Function(_G.hooksecurefunc) end,
})
Add(doesItDie, "dida", "Скругление прогноза урона", "Rounded damage forecast", {
    addons = { "DoesItDieAdvanced", "EllesmereUI" }, reload = true,
    probe = function()
        return _G.DoesItDieAdvancedRemaining and Function(_G.DoesItDieAdvancedRemaining.CreateMaskTexture)
            and Function(_G.hooksecurefunc) and _G.Enum and _G.Enum.UITextureSliceMode
    end,
})
Add(personalFonts, "magic", "Личные шрифты", "Personal fonts", {
    addons = { "FontMagicCustomFonts", "Sintezza_UI_LocalFonts" }, any = true, info = true,
    description = Text("Доступные файлы выбираются в каталоге боевого текста.", "Available files appear in the combat font catalog."),
})
Add(lueur, "lueur", "Подсветка вне боя", "Highlighting outside combat", {
    feature = "lueurCompatibility", addons = { "Lueur" }, client = "forever",
    probe = function() return SUI:GetModule("lueurCompatibility"):IsAvailable() end,
})

Add(openMap, "party", "Метки группы на карте", "Party markers on the map", {
    feature = "partyMap.markers", addons = { "OpenMap" }, probe = Stitched, fallback = World, parent = "partyMap",
})
Add(own, "waypoint", "Личная метка Sintezza UI", "Sintezza UI waypoint", {
    feature = "mapWaypointControls", client = "forever",
    probe = function()
        return World() and Function(_G.WorldMapFrame.AddCanvasClickHandler)
    end,
    description = Text("Ctrl + ЛКМ ставит метку, Ctrl + ПКМ удаляет.", "Ctrl + left-click places a waypoint, Ctrl + right-click removes it."),
})
Add(shortestPath, "route", "Маршрут Shortest Path", "Shortest Path route", {
    feature = "shortestPathMinimap", addons = { shortest }, client = "forever", version = "v1.37.1",
    probe = function() return SUI:GetModule("shortestPathMinimap"):IsSupported() end,
})
Add(shortestPath, "transport", "Таймеры транспорта на карте", "Transport timers on the world map", {
    feature = "transportMap", addons = { shortest }, client = "forever",
    probe = function() return type(_G.ShortestPathForeverDB) == "table" and World() end,
})
Add(shortestPath, "mini", "Таймеры транспорта на миникарте", "Transport timers on the minimap", {
    feature = "transportMap.minimap", addons = { shortest }, client = "forever",
    probe = function() return type(_G.ShortestPathForeverDB) == "table" and _G.Minimap ~= nil end,
})
Add(openXP, "openxp", "Маршрут к текущему шагу OpenXP", "Route to the current OpenXP step", {
    addons = { "OpenXP", shortest }, client = "forever", parent = "mapWaypointControls", refresh = { "mapWaypointControls" },
    probe = function()
        local api = _G.ShortestPathForever and _G.ShortestPathForever.API
        local guide = _G.RXP
        return api and (api.version == 1 or api.version == 2) and Function(api.NavigateRoute)
            and Function(api.CurrentStop) and Function(api.Active) and Function(api.Cancel)
            and guide and guide.arrowFrame and Function(guide.UpdateMap) and Function(guide.UpdateGotoSteps)
    end,
    conflict = function() return SUI:IsAddonLoaded("RXPGuides") and "RestedXP" end,
    notice = function()
        local settings = _G.ShortestPathForeverDB
        if not settings or settings.restedxp == false or settings.journey == false then
            return Text("Включи следование гайдам RestedXP в Shortest Path.", "Enable RestedXP guide following in Shortest Path.")
        end
    end,
})
Add(openXP, "questie", "Русские подписи в карточке OpenXP", "Russian labels in the OpenXP card", {
    addons = { "OpenXP" }, client = "forever", locale = "ruRU", reload = true,
    probe = function()
        local module = SUI:GetModule("openXPLocalization")
        return module and module.GetGuide and module:GetGuide()
    end,
    description = Text("QuestieDB дополняет названия при наличии.", "QuestieDB supplements matching names when installed."),
})
Add(guides, "guides", "Подхватывать точки гайдов", "Adopt guide waypoints", {
    addons = { "FlowUp", "ForeverGuide" }, any = true, client = "forever", parent = "mapWaypointControls", refresh = { "mapWaypointControls" },
    probe = function()
        return Function(_G.hooksecurefunc) and ((_G.C_Map and Function(_G.C_Map.SetUserWaypoint)
            and Function(_G.C_Map.GetUserWaypoint)) or (not SUI:IsAddonLoaded("TomTom") and _G.TomTom and Function(_G.TomTom.AddWaypoint)))
    end,
})
Add(own, "whispers", "Скрывать ошибки служебных шепотов", "Hide addon whisper errors", {
    feature = "chatWhisperErrors", client = "forever", probe = function()
        return Function(_G.hooksecurefunc) and (_G.C_ChatInfo and Function(_G.C_ChatInfo.SendChatMessage) or Function(_G.SendChatMessage))
    end,
})
Add(rivals, "rivals", "Кнопка боев под кнопкой группы", "PvP markers under Party Map", {
    addons = { "Sintezza_Rivals" }, client = "forever", info = true,
    description = Text("Расположение использует видимую кнопку группы.", "Uses the visible Party Map button as an anchor."),
})
Add(execute, "execute", "Перенос вида прежней риски добивания", "Import the legacy execute appearance", {
    addons = { "Sintezza_Execute" }, client = "forever", info = true,
    description = Text("Импорт при первой настройке базы Execute.", "Imported when Execute first initializes its settings."),
})

local function Profile()
    return SUI:GetModuleProfile("integrations")
end

local function CombatFontSetting()
    local profile = SUI:GetModuleProfile("combatFont")
    return profile and profile.enabled and profile.font ~= "DEFAULT" and profile.font or false
end

local atLogin
if SUI.RegisterModule then
    SUI:RegisterModule("integrationStatus", { Initialize = function()
        atLogin = CombatFontSetting()
        for id, row in pairs(byID) do if row.reload then SUI:IntegrationEnabled(id) end end
    end })
end

function SUI:IntegrationEnabled(id)
    local row = byID[id]
    if not row or row.feature or row.info then return true end
    local profile = Profile()
    if not profile then return true end
    local enabled = profile[id] ~= false
    if row.reload then
        if session[id] == nil then session[id] = enabled end
        return session[id]
    end
    return enabled
end

function SUI:GetIntegrationSetting(row)
    if row.feature then return self:GetFeatureSetting(row.feature) end
    local profile = Profile()
    return not profile or profile[row.id] ~= false
end

function SUI:GetIntegrationGroups() return groups end

local addonNames = {
    EllesmereUIActionBars = "EllesmereUI Action Bars", EllesmereUICooldownManager = "EllesmereUI Cooldown Manager",
    EllesmereUINameplates = "EllesmereUI Nameplates", EllesmereUIUnitFrames = "EllesmereUI Unit Frames",
    EllesmereUIRaidFrames = "EllesmereUI Raid Frames", EllesmereUIResourceBars = "EllesmereUI Resource Bars",
    EllesmereUIAuraBuffReminders = "EllesmereUI Aura Buff Reminders", EllesmereUIBlizzardSkin = "EllesmereUI Blizzard Skin",
    EllesmereUIForeverEssentials = "EllesmereUI Forever Essentials", EllesmereUIDamageMeters = "EllesmereUI Damage Meters",
    EllesmereUIQoL = "EllesmereUI QoL", ShortestPathForever = "Shortest Path Forever",
    DoesItDieAdvanced = "Does It Die Advanced", Sintezza_Rivals = "Sintezza Rivals", Sintezza_Execute = "Sintezza Execute",
}

local function AddonState(row)
    local firstReason
    if not row.addons then return true end
    for _, addon in ipairs(row.addons) do
        local loaded, reason = SUI:GetAddonAvailability(addon, addonNames[addon])
        if row.any and loaded then return true end
        if not row.any and not loaded then return false, reason end
        firstReason = firstReason or reason
    end
    return not row.any, firstReason
end

function SUI:GetIntegrationStatus(row)
    if (row.client == "forever" and not self.isForever) or (row.client == "retail" and self.isForever) then
        local reason = row.client == "forever" and Text("Только WoW Forever", "WoW Forever only") or Text("Только Retail", "Retail only")
        return false, reason, nil, "warning"
    end
    if row.locale and GetLocale() ~= row.locale then
        return false, Text("Только русский клиент", "Russian game client only"), row.description, "warning"
    end
    local ready, reason = AddonState(row)
    local fallback = not ready and row.fallback and row.fallback()
    if not ready and not fallback then return false, reason, row.description, "warning" end
    if row.version and self:GetAddonVersion(row.addons[1]) ~= row.version then
        return false, Text("Несовместимая версия", "Incompatible version"), row.version, "warning"
    end
    local media = row.nativeMedia and LSM()
    if row.nativeMedia and not (media and Function(media.Register)) then
        return false, Text("LibSharedMedia не загружена", "LibSharedMedia is not loaded"), nil, "warning"
    end
    local conflict = row.conflict and row.conflict()
    if conflict then
        return false, Text("Управляет другой аддон", "Managed by another addon"), conflict, "warning"
    end
    if row.probe and not fallback then
        local ok, compatible = pcall(row.probe)
        if not ok or not compatible then
            fallback = row.fallback and row.fallback()
            if not fallback then return false, Text("API недоступен", "API unavailable"), row.description, "warning" end
        end
    end
    local enabled = self:GetIntegrationSetting(row)
    if row.reload and not row.feature and enabled ~= self:IntegrationEnabled(row.id) then
        return true, Text("После /reload", "After /reload"), row.description, "warning"
    end
    if row.relog and atLogin ~= nil and atLogin ~= CombatFontSetting() then
        return true, Text("После повторного входа", "After signing back in"), row.description, "warning"
    end
    if row.feature and (row.feature == "fonts" or row.feature == "borderMedia") and not enabled then
        local module = self:GetModule("fontCompatibility")
        if module and module.reloadRequired then return true, Text("После /reload", "After /reload"), nil, "warning" end
    end
    if row.parent and not self:GetFeature(row.parent) then
        return false, Text("Основная функция выключена", "Parent feature is off"), row.description, "warning"
    end
    if row.info then return false, Text("Доступно", "Available"), row.description, "active" end
    if enabled and row.notice then
        local notice = row.notice()
        if notice then return true, Text("Нужна настройка", "Setup required"), notice, "warning" end
    end
    if enabled and fallback then
        return true, Text("Штатный режим", "Blizzard fallback"), row.description, "active"
    end
    return true, enabled and Text("Включено", "On") or Text("Выключено", "Off"), row.description, enabled and "active" or "off"
end

function SUI:SetIntegrationSetting(row, value)
    if not self:GetIntegrationStatus(row) then return false end
    if row.feature then
        return self:SetFeature(row.feature, value)
    end
    local profile = Profile()
    if not profile then return false end
    if row.reload then self:IntegrationEnabled(row.id) end
    if value then profile[row.id] = nil else profile[row.id] = false end
    if row.refresh then
        for _, key in ipairs(row.refresh) do
            local module = self:GetModule(key)
            if module then self:SafeModuleCall(module, "integration " .. row.id, module.OnProfileChanged) end
        end
        self:RefreshModuleEvents()
    end
    return true
end
