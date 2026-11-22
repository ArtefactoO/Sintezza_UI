local _, SUI = ...
local Text = SUI.Text
local T, W, B = SUI.SettingsTheme, SUI.Widgets, SUI.SettingsBuilder
local windowAppearance = Sintezza_Theme:NewWindowPreferences(function() return SUI:GetProfile() end)
if Sintezza_Theme.RegisterGlobalWindowPreferences then
    Sintezza_Theme:RegisterGlobalWindowPreferences("Sintezza UI", windowAppearance)
end

local UI = {
    pages = {}, definitions = {}, nav = {}, refreshers = {}, currentPage = "dashboard",
    routes = {
        auraRules = { page = "nameplates", tab = "auras" },
        cooldownBuffEffects = { page = "cooldownMasks", tab = "buffs" },
        cooldownProcEffects = { page = "cooldownMasks", tab = "procs" },
    },
}
SUI.SettingsUI = UI

local NAV_GROUPS = {
    ["ОБЗОР"] = { order = 10 },
    ["ПАНЕЛИ"] = { order = 20, icon = "panels" },
    ["БОЙ"] = { order = 30, icon = "combat" },
    ["ГРУППА И КАРТА"] = { order = 40, icon = "party" },
    ["СИСТЕМА"] = { order = 50, icon = "system" },
}
local NAV_ALIASES = { ["ОБЩЕЕ"] = "ОБЗОР", ["ЭЛЕМЕНТЫ ИНТЕРФЕЙСА"] = "БОЙ" }
local NAV_OVERRIDES = {
    raidTools = { group = "ГРУППА И КАРТА", order = 10 },
    teleportPrompt = { group = "ГРУППА И КАРТА", order = 40 },
    integrations = { group = "СИСТЕМА", order = 10 },
    windowAppearance = { group = "СИСТЕМА", order = 20 },
    diagnostics = { group = "СИСТЕМА", order = 30 },
    profiles = { group = "СИСТЕМА", order = 40 },
}
local WINDOW_WIDTH, WINDOW_HEIGHT, MIN_HEIGHT = 1000, 660, 516
local SIDEBAR_WIDTH = 208

local function NavigationLess(left, right)
    local leftGroup = NAV_GROUPS[left.group] and NAV_GROUPS[left.group].order or 1000
    local rightGroup = NAV_GROUPS[right.group] and NAV_GROUPS[right.group].order or 1000
    if leftGroup ~= rightGroup then return leftGroup < rightGroup end
    if left.group ~= right.group then return tostring(left.group) < tostring(right.group) end
    local leftOrder, rightOrder = tonumber(left.order) or 1000, tonumber(right.order) or 1000
    if leftOrder ~= rightOrder then return leftOrder < rightOrder end
    if left.title ~= right.title then return tostring(left.title) < tostring(right.title) end
    return tostring(left.key) < tostring(right.key)
end

function UI:RevealNav(key)
    local entry = self.navOffsets and self.navOffsets[key]
    local scroll = self.navScroll
    if not entry or not scroll:IsVisible() then return end
    local offset, height = scroll:GetVerticalScroll(), scroll:GetHeight()
    if height <= 0 then return end
    if entry.top < offset then
        scroll.bar:SetValue(entry.top)
    elseif entry.bottom > offset + height then
        scroll.bar:SetValue(entry.bottom - height)
    end
end

function UI:AddRefresher(widget)
    self.refreshers[#self.refreshers + 1] = widget
    return widget
end

function UI:Refresh()
    windowAppearance:Apply()
    for _, widget in ipairs(self.refreshers) do
        if widget.Refresh then
            local ok, err = pcall(widget.Refresh, widget)
            if not ok and SUI.Diagnostics then SUI.Diagnostics:RecordError("settings", "widget refresh", err) end
        end
    end
    local page = self.pages[self.currentPage]
    if page and page.Refresh then
        local ok, err = pcall(page.Refresh, page)
        if not ok and SUI.Diagnostics then
            SUI.Diagnostics:RecordError("settings", "page " .. tostring(self.currentPage), err)
        end
    end
end

local function CreateDashboard(parent)
    local title = Text("Настройки интерфейса", "Interface settings")
    local page = B:CreateTabbedPage(parent, title, Text("Открой раздел по тому, что хочешь изменить в игре.",
        "Choose a section based on what you want to change in game."), { { key = "main" } }, true)
    local columns = B:BeginColumns(page, "main", 18)
    local open = Text("Открыть", "Open")
    local function AddLink(card, label, detail, key, tab)
        B:AddRow(page, card, W:NavigationRow(card, label, detail, open, function() UI:SelectPage(key, tab) end))
    end
    local card = B:AddColumnSection(page, columns, "left", Text("Основные разделы", "Main sections"))
    AddLink(card, Text("Панели", "Bars"), Text("Игровые кнопки, часы, друзья и гильдия.",
        "Game shortcuts, clock, friends and guild."), "gameBarMini", "general")
    AddLink(card, Text("Сигналы", "Alerts"), Text("Бой, скрытность, здоровье и агро.",
        "Combat, stealth, health and aggro."), "combatAlert", "combat")
    if SUI.isForever then
        AddLink(card, Text("Карта и маршруты", "Map and routes"), Text("Личная метка, Shortest Path и таймеры транспорта.",
            "Personal waypoint, Shortest Path and transport timers."), "mapOptions", "display")
    else
        AddLink(card, Text("Группа на карте", "Party on the map"), Text("Метки сопартийцев.", "Party markers."), "partyMap")
    end
    B:FinishCard(page, "main", card)
    card = B:AddColumnSection(page, columns, "right", Text("Быстрый доступ", "Quick access"))
    AddLink(card, Text("Неймплейты", "Nameplates"), Text("Ряды баффов и правила дебаффов.",
        "Buff rows and debuff rules."), "nameplates", "auras")
    AddLink(card, Text("Проверка рейда", "Raid check"), Text("Готовность группы и тест окна.",
        "Group readiness and window preview."), "raidTools", "audit")
    AddLink(card, Text("Шрифт боевых цифр", "Combat numbers font"), Text("Каталог шрифтов и образец.",
        "Font catalog and preview."), "combatFont", "font")
    B:FinishCard(page, "main", card)
    card = B:AddColumnSection(page, columns, "right", Text("Подключения", "Connections"))
    local function AddConnection(title, addon)
        local row = W:NavigationRow(card, title, "", Text("К настройкам", "Open settings"), function()
            for _, group in ipairs(SUI:GetIntegrationGroups()) do
                if group.title == title then UI:JumpTo("integrations", "integrations", nil, nil, group); return end
            end
        end)
        W:WithStatus(row)
        function row:Refresh()
            local available, reason = SUI:GetAddonAvailability(addon, title)
            self.status:SetText(available and Text("Подключен", "Connected") or Text("Недоступен", "Unavailable"))
            Sintezza_Theme:Tint(self.status, "SetTextColor", available and T.accent or T.warning)
            W:Help(self, reason)
        end
        B:AddRow(page, card, row)
    end
    if SUI.isForever then AddConnection("Shortest Path Forever", "ShortestPathForever") end
    AddConnection("EllesmereUI", "EllesmereUI")
    AddLink(card, Text("Все интеграции", "All integrations"), Text("Другие плагины и условия их работы.",
        "Other addons and setup requirements."), "integrations")
    B:FinishCard(page, "main", card)
    B:FinishColumns(page, "main", columns)
    return page
end

local function CreateWindowOptions(parent)
    local page = B:CreateTabbedPage(parent, Text("Оформление окна", "Window appearance"), nil,
        { { key = "general", title = Text("Общие", "General") } }, true)

    local general = B:BeginColumns(page, "general", 24)
    local common = B:AddColumnSection(page, general, "left", Text("Интерфейс", "Interface"))
    local fontButton = W:Button(common, "Sintezza Theme", function()
        Sintezza_Theme:OpenSettings()
    end)
    fontButton:SetHeight(30)
    B:AddRow(page, common, fontButton)
    B:FinishCard(page, "general", common)

    local hover = B:AddColumnSection(page, general, "right", Text("Наведение", "Hover"))
    local intensity
    local effectsToggle = W:Toggle(hover, Text("Анимация наведения", "Hover animation"), function()
        local profile = SUI:GetModuleProfile("interactionEffects")
        return profile and profile.enabled ~= false
    end, function(value)
        local profile = SUI:GetModuleProfile("interactionEffects")
        if not profile then return end
        profile.enabled = value == true
        if SUI.HoverEffects then SUI.HoverEffects:RefreshAll() end
        if intensity then intensity:Refresh() end
    end)
    T:Font(effectsToggle.label, 11, "", T.text, "setting")
    if W.Help then
        W:Help(effectsToggle, Text(
            "При наведении иконки игровых панелей и рейдовых инструментов плавно увеличиваются. Часы подсвечиваются.",
            "Hovering enlarges game-bar and raid-tool icons and highlights the clock."))
    end
    B:AddRow(page, hover, effectsToggle)

    intensity = W:SliderRow(hover, Text("Рост по краям, %", "Edge expansion, %"), 3, 15, 1, function()
        local profile = SUI:GetModuleProfile("interactionEffects")
        return math.floor(((profile and profile.intensity) or .08) * 100 + .5)
    end, function(value)
        local profile = SUI:GetModuleProfile("interactionEffects")
        if not profile then return end
        profile.intensity = math.max(.03, math.min(.15, value / 100))
        if SUI.HoverEffects then SUI.HoverEffects:RefreshAll() end
    end)
    T:Font(intensity.label, 11, "", T.text, "setting")
    if W.Help then
        W:Help(intensity, Text(
            "Задает, насколько увеличивается каждая сторона иконки при наведении.",
            "Sets how much each edge of an icon expands on hover."))
    end
    local originalIntensityRefresh = intensity.Refresh
    function intensity:Refresh()
        originalIntensityRefresh(self)
        local profile = SUI:GetModuleProfile("interactionEffects")
        self:SetAvailable(profile and profile.enabled ~= false)
    end
    B:AddRow(page, hover, intensity)
    B:FinishCard(page, "general", hover)
    B:FinishColumns(page, "general", general)
    local tab = page.tabs.general
    local windowOptions = Sintezza_Theme:CreateWindowOptions(tab.body, T, {
        heading = true,
        windows = { { prefs = windowAppearance } },
        getMinimap = function() return not SUI.db.minimap.hidden end,
        setMinimap = function(value)
            SUI.db.minimap.hidden = not value
            if SUI.MinimapButton then SUI.MinimapButton:RefreshVisibility() end
        end,
    })
    windowOptions:SetPoint("TOPLEFT", tab.body, "TOPLEFT", 0, tab.nextY)
    windowOptions:SetPoint("TOPRIGHT", tab.body, "TOPRIGHT", 0, tab.nextY)
    tab.nextY = tab.nextY - windowOptions:GetHeight() - 10
    tab.body:SetHeight(-tab.nextY + 2)
    page:AddRefresher(windowOptions)
    return page
end

local function CreateDiagnostics(parent)
    local page = B:CreateTabbedPage(parent, Text("Диагностика", "Diagnostics"), nil, { { key = "main" } }, true)
    local tab = page.tabs.main
    local canvas = tab.body
    local section = W:Section(canvas, Text("Состояние", "Status"), nil, "settings")
    section:SetPoint("TOPLEFT", canvas, "TOPLEFT", 0, -12)
    section:SetPoint("TOPRIGHT", canvas, "TOPRIGHT", 0, -12)
    local addons = {
        { label = Text("Игровая панель", "Game Bar"), status = function() return SUI.Diagnostics:ModuleDetails("gameBar") end },
        { label = Text("Рейд-инструменты", "Raid Tools"), status = function() return SUI.Diagnostics:ModuleDetails("raidTools") end },
        { label = Text("Неймплейты", "Nameplates"), status = function() return SUI.Diagnostics:ModuleDetails("nameplates") end },
        { label = Text("Иконки и откат", "Cooldown Masks"), status = function() return SUI.Diagnostics:ModuleDetails("cooldownMasks") end },
        { label = "EllesmereUI Nameplates", addon = "EllesmereUINameplates" },
        { label = "EllesmereUI Cooldown Manager", addon = "EllesmereUICooldownManager" },
        { label = "DandersFrames", addon = "DandersFrames" },
        { label = Text("Ауры на неймплейтах", "Nameplate aura engine"), status = function()
            local module = SUI:GetModule("nameplates")
            local rules = module and module.AuraRules
            if not rules or not rules.GetDiagnostics then return Text("НЕДОСТУПЕН", "UNAVAILABLE"), false end
            local data = rules:GetDiagnostics()
            local mode = data.slotApiPresent == true and Text("СЛОТЫ АУР", "AURA SLOTS")
                or (data.slotApiPresent == false and Text("ГРУППОВЫЕ АУРЫ", "GROUP FALLBACK") or Text("ОЖИДАЕТ НЕЙМПЛЕЙТ", "WAITING FOR NAMEPLATE"))
            local suffix = data.failures > 0 and (Text(" • ОШИБОК ", " • ERRORS ") .. data.failures) or ""
            return mode .. " • " .. data.containers .. Text(" КОНТЕЙНЕРОВ", " CONTAINERS") .. suffix,
                data.failures == 0, data.slotApiPresent == nil
        end },
        { label = Text("Интеграции откатов", "Cooldown hooks"), status = function()
            local module = SUI:GetModule("cooldownMasks")
            if not module then return Text("НЕДОСТУПЕН", "UNAVAILABLE"), false end
            return string.format(Text("ПАНЕЛИ %d  •  CD MANAGER %d", "BARS %d  •  COOLDOWN MANAGER %d"), module.hookedActionBars or 0, module.hookedCooldownManager or 0), true
        end },
    }
    section.states = {}
    local y = -section.headerHeight - 6
    for _, definition in ipairs(addons) do
        local label = W:Label(section, definition.label, 11, T.text)
        label:SetPoint("TOPLEFT", section, "TOPLEFT", 0, y)
        local state = W:Label(section, "", 9, T.muted)
        state:SetPoint("TOPRIGHT", section, "TOPRIGHT", 0, y)
        y = y - 29
        state.addonName = definition.addon
        state.moduleKey = definition.module
        state.status = definition.status
        section.states[#section.states + 1] = state
    end
    function section:Refresh()
        for _, state in ipairs(self.states) do
            if state.status then
                local value, healthy, pending = state.status()
                state:SetText(value)
                local c = pending and T.muted or (healthy and T.accent or T.danger)
                state:SetTextColor(c[1], c[2], c[3], 1)
            else
            local module = state.moduleKey and SUI:GetModule(state.moduleKey)
            local loaded = module and module.initialized ~= false or (state.addonName and SUI:IsAddonLoaded(state.addonName))
            local version = state.addonName and SUI:GetAddonVersion(state.addonName)
            local failure = module and module.initialized == false and module.initializeError
            state:SetText(failure and Text("ОШИБКА ИНИЦИАЛИЗАЦИИ", "STARTUP ERROR") or (loaded and (state.moduleKey and Text("ВСТРОЕН", "BUILT IN") or (Text("ЗАГРУЖЕН  ", "LOADED  ") .. (version or ""))) or Text("НЕ ЗАГРУЖЕН", "NOT LOADED")))
            local c = failure and T.danger or (loaded and T.accent or T.muted)
            state:SetTextColor(c[1], c[2], c[3], 1)
            end
        end
    end
    page:AddRefresher(section)

    local divider = section:CreateTexture(nil, "ARTWORK")
    Sintezza_Theme:Tint(divider, "SetColorTexture", T.lineSoft)
    divider:SetPoint("TOPLEFT", section, "TOPLEFT", 0, y)
    divider:SetPoint("TOPRIGHT", section, "TOPRIGHT", 0, y)
    divider:SetHeight(1)
    Sintezza_Theme:SnapTexture(divider)
    section:SetHeight(-y + 52)

    local reconnect = W:Button(section, Text("Переподключить EUI", "Reconnect EllesmereUI"), function()
        local ok, message = SUI.Diagnostics:ReconnectEUI()
        SUI:Print(message)
        if ok then page:Refresh() end
    end, true)
    reconnect:SetSize(154, 27)
    reconnect:SetPoint("BOTTOMLEFT", section, "BOTTOMLEFT", 0, 8)
    local report = W:Button(section, Text("Скопировать отчет", "Copy report"), function() SUI.Diagnostics:ShowReport() end)
    report:SetSize(146, 27)
    report:SetPoint("LEFT", reconnect, "RIGHT", 8, 0)
    local clear = W:Button(section, Text("Очистить ошибки", "Clear errors"), function() SUI.Diagnostics:ClearErrors() end)
    clear:SetSize(132, 27)
    clear:SetPoint("LEFT", report, "RIGHT", 8, 0)
    page.errorSummary = W:Label(section, "", 9, T.muted)
    page.errorSummary:SetPoint("RIGHT", section, "BOTTOMRIGHT", 0, 21)
    page.errorSummary:SetWidth(190)

    function page:OnRefresh()
        local count = SUI.Diagnostics and SUI.Diagnostics.totalErrors or 0
        self.errorSummary:SetText(count > 0 and (Text("Ошибок: ", "Errors: ") .. count) or Text("Ошибок не зафиксировано", "No errors recorded"))
        local c = count > 0 and T.danger or T.muted
        self.errorSummary:SetTextColor(c[1], c[2], c[3], 1)
    end
    tab.nextY = -12 - section:GetHeight()
    canvas:SetHeight(-tab.nextY + 2)
    return page
end

local function CreatePageError(parent, key, title)
    local page, canvas = W:Page(parent)
    local section = W:Section(canvas, title, nil, "settings")
    section:SetPoint("TOPLEFT", canvas, "TOPLEFT", 0, -12)
    section:SetPoint("TOPRIGHT", canvas, "TOPRIGHT", 0, -12)
    section:SetHeight(96)

    local message = W:Label(section, Text("Не удалось открыть раздел. Сведения об ошибке сохранены в диагностике.",
        "Could not open this page. The error was saved in Diagnostics."), 11, T.muted)
    message:SetPoint("TOPLEFT", section, "TOPLEFT", 0, -section.headerHeight)
    message:SetPoint("TOPRIGHT", section, "TOPRIGHT", 0, -section.headerHeight)
    message:SetWordWrap(true)

    local isDiagnostics = key == "diagnostics"
    local button = W:Button(section, isDiagnostics and Text("Скопировать отчет", "Copy report") or Text("Открыть диагностику", "Open diagnostics"), function()
        if isDiagnostics then SUI.Diagnostics:ShowReport() else UI:SelectPage("diagnostics") end
    end, true)
    button:SetSize(168, 26)
    button:SetPoint("TOPLEFT", message, "BOTTOMLEFT", 0, -12)
    return page
end

function UI:SelectPage(key, requestedTab)
    if self.searchResults and self.searchResults:IsShown() then self:ClearSearch() end
    if key == "features" then
        key, requestedTab = requestedTab == "integrations" and "integrations" or "dashboard", nil
    end
    local route = self.routes[key]
    if route then key, requestedTab = route.page, requestedTab or route.tab end
    if not self.pages[key] and self.definitions[key] then
        local definition = self.definitions[key]
        local host = CreateFrame("Frame", nil, self.content)
        host:SetAllPoints()
        host:Hide()
        local count = #self.refreshers
        local ok, page = pcall(definition.builder, host, UI)
        if ok and page then
            host:Show()
        else
            for index = #self.refreshers, count + 1, -1 do self.refreshers[index] = nil end
            SUI.Diagnostics:RecordError("settings", "build page " .. key, page or "builder returned no frame")
            page = CreatePageError(self.content, key, definition.title or key)
        end
        page.pageKey, page.navKey = key, definition.navKey or key
        self.pages[key] = page
    end
    if not self.pages[key] then key = "dashboard" end
    local previous = self.pages[self.currentPage]
    if previous and previous ~= self.pages[key] and previous.OnDeselected then pcall(previous.OnDeselected, previous) end
    self.currentPage = key
    for pageKey, page in pairs(self.pages) do page:SetShown(pageKey == key) end
    local page = self.pages[key]
    local definition = self.definitions[key]
    self.headerTitle:SetText(page.headerTitle or (definition and definition.title) or "")
    local subtitle = page.headerSubtitle or ""
    local keys = Text("Tab — переход, Enter — выбрать, стрелки — изменить значение.",
        "Tab to move, Enter to select, arrow keys to adjust.")
    W:Help(self.heading, subtitle == "" and keys or (subtitle .. "\n\n" .. keys), self.headerTitle)
    if self.searchHighlight then self.searchHighlight:Hide() end
    if page and page.OnSelected then pcall(page.OnSelected, page) end
    if requestedTab and page and page.SelectTab then page:SelectTab(requestedTab) end
    local navKey = page and page.navKey or key
    for _, section in ipairs(self.navSections) do
        if section.activeKey[navKey] and section.open == false then section.open = nil end
    end
    self:LayoutNavigation(navKey)
    for _, button in ipairs(self.nav) do button:SetSelected(button.pageKey == navKey) end
    self:RevealNav(navKey)
    self:Refresh()
    return page
end

local function SectionOpen(section, key)
    return not section.header or section.open == true or (section.open == nil and section.activeKey[key] == true)
end

local function PaintNavigationArrow(button)
    local color = button.expanded and T.accent or (button.hovered and T.text or T.brass)
    Sintezza_Theme:Tint(button.arrow, "SetVertexColor", color)
end

function UI:LayoutNavigation(key)
    local scroll = self.navScroll
    if not scroll then return end
    local body, y = scroll.body, 3
    self.navOffsets = {}
    local function Place(button, inset)
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", body, "TOPLEFT", inset, -y)
        button:SetPoint("TOPRIGHT", body, "TOPRIGHT", -2, -y)
        y = y + button:GetHeight()
    end
    for _, section in ipairs(self.navSections) do
        local open = SectionOpen(section, key)
        if section.header then
            y = y + 6
            Place(section.header, 0)
            section.header.expanded = open
            section.header.arrow:SetExpanded(open)
            PaintNavigationArrow(section.header)
        end
        for _, button in ipairs(section.buttons) do
            button:SetShown(open == true)
            if open then
                self.navOffsets[button.pageKey] = { top = y, bottom = y + button:GetHeight() }
                Place(button, section.header and 7 or 0)
            end
        end
    end
    body:SetHeight(y + 4)
    scroll:RefreshRange()
end

function UI:BuildNavigation(sidebar)
    local scroll, body, bar = W:ScrollFrame(sidebar)
    scroll:SetPoint("TOPLEFT", sidebar, "TOPLEFT", 8, -8)
    scroll:SetPoint("BOTTOMRIGHT", sidebar, "BOTTOMRIGHT", -12, 8)
    bar:SetPoint("TOPRIGHT", scroll, "TOPRIGHT", 8, 0)
    bar:SetPoint("BOTTOMRIGHT", scroll, "BOTTOMRIGHT", 8, 0)
    scroll:HookScript("OnSizeChanged", function(frame, width)
        body:SetWidth(math.max(1, width))
        frame:RefreshRange()
    end)
    self.navScroll, self.navSections = scroll, {}
    local navDefs = { { title = Text("Главная", "Home"), key = "dashboard", group = "ОБЗОР", order = 10 } }
    for key, definition in pairs(self.definitions) do
        if definition.showInNav ~= false then
            local override = NAV_OVERRIDES[key]
            local group = override and override.group or definition.group or "БОЙ"
            navDefs[#navDefs + 1] = {
                title = definition.title, key = key, group = NAV_ALIASES[group] or group,
                order = override and override.order or definition.order,
            }
        end
    end
    table.sort(navDefs, NavigationLess)
    self.navEntries = navDefs
    local function OpenPage(key) self:SelectPage(key) end
    local section
    for _, definition in ipairs(navDefs) do
        if not section or section.group ~= definition.group then
            local group = NAV_GROUPS[definition.group]
            local current = { group = definition.group, buttons = {}, activeKey = {} }
            self.navSections[#self.navSections + 1] = current
            if group and group.icon then
                current.header = W:NavButton(body, SUI.NavGroupLabel(definition.group), definition.group, function()
                    local page = self.pages[self.currentPage]
                    local key = page and page.navKey or self.currentPage
                    current.open = not SectionOpen(current, key)
                    self:LayoutNavigation(key)
                end, group.icon)
                current.header.text:SetPoint("RIGHT", current.header, "RIGHT", -27, 0)
                current.header.arrow = T:DisclosureArrow(current.header, 18, T.brass)
                current.header.arrow:SetPoint("RIGHT", current.header, "RIGHT", -5, 0)
                current.header:HookScript("OnEnter", PaintNavigationArrow)
                current.header:HookScript("OnLeave", PaintNavigationArrow)
            end
            section = current
        end
        local button = W:NavButton(body, definition.title, definition.key, OpenPage)
        section.buttons[#section.buttons + 1] = button
        section.activeKey[definition.key] = true
        self.nav[#self.nav + 1] = button
    end
    scroll:HookScript("OnShow", function()
        local page = self.pages[self.currentPage]
        self:RevealNav(page and page.navKey or self.currentPage)
    end)
end

function UI:BuildWindow()
    if self.window then return self.window end
    local window = CreateFrame("Frame", "Sintezza_UIWindow", UIParent, "BackdropTemplate")
    window:SetSize(WINDOW_WIDTH, WINDOW_HEIGHT)
    window:SetPoint("CENTER")
    window:SetFrameStrata("DIALOG")
    window:SetClampedToScreen(true)
    window:SetMovable(true)
    window:EnableMouse(true)
    window:RegisterForDrag("LeftButton")
    window:SetScript("OnDragStart", function(frame)
        if windowAppearance:CanMove() then frame:StartMoving() end
    end)
    window:SetScript("OnDragStop", window.StopMovingOrSizing)
    window:SetScript("OnHide", function(frame)
        frame:StopMovingOrSizing()
        frame:UnregisterEvent("ADDON_LOADED")
        frame:UnregisterEvent("PLAYER_REGEN_DISABLED")
        frame:UnregisterEvent("PLAYER_REGEN_ENABLED")
        frame:UnregisterEvent("GLOBAL_MOUSE_DOWN")
        self:ClearSearch()
        if self.searchHighlight then self.searchHighlight:Hide() end
        if SUI.Widgets then SUI.Widgets:CloseColorPicker() end
        local page = UI.pages[UI.currentPage]
        if page and page.OnDeselected then pcall(page.OnDeselected, page) end
    end)
    window:HookScript("OnShow", function(frame)
        frame:RegisterEvent("ADDON_LOADED")
        frame:RegisterEvent("PLAYER_REGEN_DISABLED")
        frame:RegisterEvent("PLAYER_REGEN_ENABLED")
        frame:RegisterEvent("GLOBAL_MOUSE_DOWN")
    end)
    window:SetScript("OnEvent", function(frame, event)
        if event == "GLOBAL_MOUSE_DOWN" then
            if frame.ClearSettingsFocus then frame:ClearSettingsFocus() end
            if self.searchResults and self.searchResults:IsShown()
                and not self.searchResults:IsMouseOver() and not self.searchBox:IsMouseOver() then
                self:ClearSearch()
            end
            return
        end
        if event ~= "ADDON_LOADED" then
            if frame.RefreshSettingsKeyboard then frame:RefreshSettingsKeyboard() end
        end
        if frame.dependencyRefresh then return end
        frame.dependencyRefresh = true
        C_Timer.After(0, function()
            frame.dependencyRefresh = nil
            if frame:IsShown() then self:Refresh() end
        end)
    end)
    T:WindowSurface(window)
    self.window = window
    windowAppearance:Bind(window, {
        resize = {
            minWidth = WINDOW_WIDTH, minHeight = MIN_HEIGHT, maxWidth = 1600, maxHeight = 1100,
            height = function()
                local scale = windowAppearance:Get("scale") / 100
                return math.min(WINDOW_HEIGHT, math.max(MIN_HEIGHT, (UIParent:GetHeight() - 24) / scale))
            end,
        },
    })
    UISpecialFrames[#UISpecialFrames + 1] = "Sintezza_UIWindow"

    local header = W:WindowHeader(window, {
        title = SUI.title, version = SUI.version, icon = SUI.icon,
    })
    local close = header.close
    self:BuildSearch(header)
    W:InstallSettingsKeyboard(self, window, close)

    local sidebar = CreateFrame("Frame", nil, window, "BackdropTemplate")
    sidebar:SetPoint("TOPLEFT", header, "BOTTOMLEFT")
    sidebar:SetPoint("BOTTOMLEFT", window, "BOTTOMLEFT", 1, 1)
    sidebar:SetWidth(SIDEBAR_WIDTH)
    T:SidebarSurface(sidebar)
    local shadow = sidebar:CreateTexture(nil, "OVERLAY")
    shadow:SetPoint("TOPLEFT", sidebar, "TOPRIGHT")
    shadow:SetPoint("BOTTOMLEFT", sidebar, "BOTTOMRIGHT")
    shadow:SetWidth(8)
    shadow:SetColorTexture(0, 0, 0, .26)
    if shadow.SetGradient and CreateColor then
        shadow:SetGradient("HORIZONTAL", CreateColor(0, 0, 0, .38), CreateColor(0, 0, 0, 0))
    end
    local content = CreateFrame("Frame", nil, window)
    content:SetPoint("TOPLEFT", sidebar, "TOPRIGHT", 8, -3)
    content:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -8, 8)
    local heading = CreateFrame("Frame", nil, content)
    heading:SetPoint("TOPLEFT", content, "TOPLEFT", 14, -9)
    heading:SetPoint("TOPRIGHT", content, "TOPRIGHT", -14, -9)
    heading:SetHeight(44)
    local title = W:Label(heading, "", 24, T.text, "display")
    title:SetPoint("TOPLEFT", heading, "TOPLEFT", 0, -3)
    title:SetPoint("TOPRIGHT", heading, "TOPRIGHT", 0, -3)
    title:SetWordWrap(false)
    local separator = heading:CreateTexture(nil, "ARTWORK")
    Sintezza_Theme:Tint(separator, "SetColorTexture", T.lineSoft)
    separator:SetPoint("BOTTOMLEFT")
    separator:SetPoint("BOTTOMRIGHT")
    separator:SetHeight(1)
    self.heading, self.headerTitle = heading, title

    local pages = CreateFrame("Frame", nil, content)
    pages:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", -14, -6)
    pages:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT")
    self.content = pages

    self.definitions.dashboard = { title = Text("Главная", "Home"), builder = CreateDashboard, showInNav = false }
    for _, definition in ipairs(SUI.settingsPages) do self.definitions[definition.key] = definition end
    self.definitions.windowAppearance = { title = Text("Оформление окна", "Window appearance"), builder = CreateWindowOptions }
    self.definitions.diagnostics = { title = Text("Диагностика", "Diagnostics"), builder = CreateDiagnostics }
    self:BuildNavigation(sidebar)
    window:Hide()
    self:SelectPage("dashboard")
    return window
end

function UI:RegisterBlizzardCategory()
    if self.category then return end
    self.category = Sintezza_Theme:RegisterLauncherPage({
        title = "Sintezza UI", icon = SUI.icon,
        buttonLabel = Text("Открыть настройки", "Open settings"),
        open = function() self:Show("dashboard") end,
        appearance = T,
    })
end

function UI:Initialize()
    self:RegisterBlizzardCategory()
end

function UI:Show(page, tab)
    local window = self:BuildWindow()
    windowAppearance:ApplyTo(window)
    self:SelectPage(page or "dashboard", tab)
    window:Show()
    window:Raise()
end
