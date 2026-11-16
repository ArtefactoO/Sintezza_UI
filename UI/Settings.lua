local _, SUI = ...
local Text = SUI.Text
local T, W, B = SUI.SettingsTheme, SUI.Widgets, SUI.SettingsBuilder
local windowAppearance = Sintezza_Theme:NewWindowPreferences(function() return SUI:GetProfile() end)

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
    ["ОБЗОР"] = { order = 10, icon = "overview" },
    ["ПАНЕЛИ"] = { order = 20, icon = "panels" },
    ["БОЙ"] = { order = 30, icon = "combat" },
    ["ГРУППА И КАРТА"] = { order = 40, icon = "party" },
}
local NAV_ALIASES = { ["ОБЩЕЕ"] = "ОБЗОР", ["ЭЛЕМЕНТЫ ИНТЕРФЕЙСА"] = "БОЙ" }
local NAV_OVERRIDES = {
    raidTools = { group = "ГРУППА И КАРТА", order = 10 },
    teleportPrompt = { group = "ГРУППА И КАРТА", order = 40 },
}
local WINDOW_WIDTH, WINDOW_HEIGHT, MIN_HEIGHT = 1000, 660, 516
local HEADER_HEIGHT, SIDEBAR_WIDTH = 72, 208

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
    local page = B:CreateTabbedPage(parent, Text("Настройки интерфейса", "Interface settings"), nil, {
            { key = "general", title = Text("Общие", "General") },
        }, true)
    UI.pages.dashboard = page

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
    local page, canvas = W:Page(parent)
    local card = W:Card(canvas, Text("Состояние", "Status"))
    card:SetPoint("TOPLEFT", canvas, "TOPLEFT", 0, -12)
    card:SetPoint("TOPRIGHT", canvas, "TOPRIGHT", 0, -12)
    card:SetHeight(396)
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
    card.states = {}
    for index, definition in ipairs(addons) do
        local label = W:Label(card, definition.label, 11, T.text)
        label:SetPoint("TOPLEFT", card, "TOPLEFT", 14, -58 - (index - 1) * 29)
        local state = W:Label(card, "", 9, T.muted)
        state:SetPoint("TOPRIGHT", card, "TOPRIGHT", -14, -58 - (index - 1) * 29)
        state.addonName = definition.addon
        state.moduleKey = definition.module
        state.status = definition.status
        card.states[#card.states + 1] = state
    end
    function card:Refresh()
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
    UI:AddRefresher(card)

    local divider = card:CreateTexture(nil, "ARTWORK")
    Sintezza_Theme:Tint(divider, "SetColorTexture", T.lineSoft)
    divider:SetPoint("TOPLEFT", card, "TOPLEFT", 14, -320)
    divider:SetPoint("TOPRIGHT", card, "TOPRIGHT", -14, -320)
    divider:SetHeight(1)

    local reconnect = W:Button(card, Text("Переподключить EUI", "Reconnect EllesmereUI"), function()
        local ok, message = SUI.Diagnostics:ReconnectEUI()
        SUI:Print(message)
        if ok then page:Refresh() end
    end, true)
    reconnect:SetSize(154, 27)
    reconnect:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", 14, 14)
    local report = W:Button(card, Text("Скопировать отчет", "Copy report"), function() SUI.Diagnostics:ShowReport() end)
    report:SetSize(146, 27)
    report:SetPoint("LEFT", reconnect, "RIGHT", 8, 0)
    local clear = W:Button(card, Text("Очистить ошибки", "Clear errors"), function() SUI.Diagnostics:ClearErrors() end)
    clear:SetSize(132, 27)
    clear:SetPoint("LEFT", report, "RIGHT", 8, 0)
    page.errorSummary = W:Label(card, "", 9, T.muted)
    page.errorSummary:SetPoint("RIGHT", card, "BOTTOMRIGHT", -14, 28)
    page.errorSummary:SetWidth(190)

    function page:Refresh()
        local count = SUI.Diagnostics and SUI.Diagnostics.totalErrors or 0
        self.errorSummary:SetText(count > 0 and (Text("Ошибок: ", "Errors: ") .. count) or Text("Ошибок не зафиксировано", "No errors recorded"))
        local c = count > 0 and T.danger or T.muted
        self.errorSummary:SetTextColor(c[1], c[2], c[3], 1)
    end
    return page
end

local function CreatePageError(parent, key, title)
    local page, canvas = W:Page(parent)
    local card = W:Card(canvas, title, Text("Не удалось открыть раздел. Сведения об ошибке сохранены в диагностике.", "Could not open this page. The error was saved in Diagnostics."))
    card:SetPoint("TOPLEFT", canvas, "TOPLEFT", 0, -12)
    card:SetPoint("TOPRIGHT", canvas, "TOPRIGHT", 0, -12)
    card:SetHeight(96)
    local isDiagnostics = key == "diagnostics"
    local button = W:Button(card, isDiagnostics and Text("Скопировать отчет", "Copy report") or Text("Открыть диагностику", "Open diagnostics"), function()
        if isDiagnostics then SUI.Diagnostics:ShowReport() else UI:SelectPage("diagnostics") end
    end, true)
    button:SetSize(168, 26)
    button:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", 14, 12)
    return page
end

function UI:SelectPage(key, requestedTab)
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
    self.headerSubtitle:SetText(subtitle)
    local titleInset = subtitle == "" and -math.floor((HEADER_HEIGHT - self.headerTitle:GetHeight()) / 2) or -11
    self.headerTitle:SetPoint("TOPLEFT", self.headerBrand, "TOPRIGHT", 24, titleInset)
    self.headerTitle:SetPoint("TOPRIGHT", self.headerBrand:GetParent(), "TOPRIGHT", -50, titleInset)
    if page and page.OnSelected then pcall(page.OnSelected, page) end
    if requestedTab and page and page.SelectTab then page:SelectTab(requestedTab) end
    local navKey = page and page.navKey or key
    for _, button in ipairs(self.nav) do button:SetSelected(button.pageKey == navKey) end
    self:RevealNav(navKey)
    self:Refresh()
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
            return
        end
        if event ~= "ADDON_LOADED" then
            if frame.RefreshSettingsKeyboard then frame:RefreshSettingsKeyboard() end
            return
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

    local header = CreateFrame("Frame", nil, window, "BackdropTemplate")
    header:SetPoint("TOPLEFT", window, "TOPLEFT", 1, -1)
    header:SetPoint("TOPRIGHT", window, "TOPRIGHT", -1, -1)
    header:SetHeight(HEADER_HEIGHT)
    T:HeaderSurface(header)

    local brand = CreateFrame("Frame", nil, header)
    brand:SetPoint("TOPLEFT")
    brand:SetPoint("BOTTOMLEFT")
    brand:SetWidth(SIDEBAR_WIDTH)
    local icon = brand:CreateTexture(nil, "ARTWORK")
    icon:SetTexture(Sintezza_Theme.icons.Sintezza_UI)
    icon:SetSize(36, 36)
    icon:SetPoint("LEFT", 12, 0)
    local name = W:Label(brand, "Sintezza UI", 16, T.text, "display")
    name:SetPoint("LEFT", icon, "RIGHT", 8, 7)
    local version = W:Label(brand, "v" .. SUI.version, 9, T.dim)
    version:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 1, -3)

    local close = W:CloseButton(header, function() window:Hide() end, nil, true)
    close:SetPoint("TOPRIGHT", -10, -10)
    local title = W:Label(header, "", 25, T.text, "display")
    title:SetPoint("TOPLEFT", brand, "TOPRIGHT", 24, -11)
    title:SetPoint("TOPRIGHT", -50, -11)
    title:SetHeight(31)
    title:SetWordWrap(false)
    local keys = W:Label(header, Text("Tab · переход   Enter · выбрать   Стрелки · изменить", "Tab · move   Enter · select   Arrows · adjust"), 9, T.dim)
    keys:SetPoint("BOTTOMRIGHT", -16, 14)
    keys:Hide()
    local subtitle = W:Label(header, "", 10, T.muted)
    subtitle:SetPoint("BOTTOMLEFT", brand, "BOTTOMRIGHT", 25, 14)
    subtitle:SetPoint("BOTTOMRIGHT", -265, 14)
    subtitle:SetHeight(22)
    subtitle:SetJustifyV("BOTTOM")
    subtitle:SetWordWrap(true)
    self.headerTitle, self.headerSubtitle = title, subtitle
    self.headerBrand = brand
    W:InstallSettingsKeyboard(self, window, close, keys)

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
    self.content = content

    CreateDashboard(content)
    for _, definition in ipairs(SUI.settingsPages) do self.definitions[definition.key] = definition end
    self.definitions.diagnostics = { title = Text("Диагностика", "Diagnostics"), builder = CreateDiagnostics }

    local navDefs = { { title = Text("Главная", "Home"), key = "dashboard", group = "ОБЗОР", order = 10 } }
    for _, definition in ipairs(SUI.settingsPages) do
        if definition.showInNav ~= false then
            local override = NAV_OVERRIDES[definition.key]
            local group = override and override.group or definition.group or "БОЙ"
            navDefs[#navDefs + 1] = {
                title = definition.key == "specBar" and SUI.isForever and Text("Панель талантов", "Talent bar") or definition.title,
                key = definition.key,
                group = NAV_ALIASES[group] or group,
                order = override and override.order or definition.order,
            }
        end
    end
    table.sort(navDefs, NavigationLess)

    local footer = CreateFrame("Frame", nil, sidebar, "BackdropTemplate")
    footer:SetHeight(36)
    footer:SetPoint("BOTTOMLEFT", sidebar, "BOTTOMLEFT", 1, 1)
    footer:SetPoint("BOTTOMRIGHT", sidebar, "BOTTOMRIGHT", -1, 1)
    self.navFooter = footer
    T:Backdrop(footer, T.sidebar, T.lineSoft)
    local function OpenPage(key) self:SelectPage(key) end
    local diagnostics = W:NavButton(footer, Text("Диагностика", "Diagnostics"), "diagnostics", OpenPage, "system")
    diagnostics:SetPoint("TOPLEFT", footer, "TOPLEFT", 8, -4)
    diagnostics:SetPoint("TOPRIGHT", footer, "TOPRIGHT", -8, -4)
    self.nav[#self.nav + 1] = diagnostics

    local scroll, body, bar = W:ScrollFrame(sidebar)
    scroll:SetPoint("TOPLEFT", sidebar, "TOPLEFT", 8, -8)
    scroll:SetPoint("BOTTOMRIGHT", footer, "TOPRIGHT", -12, 5)
    bar:SetPoint("TOPRIGHT", scroll, "TOPRIGHT", 8, 0)
    bar:SetPoint("BOTTOMRIGHT", scroll, "BOTTOMRIGHT", 8, 0)
    scroll:HookScript("OnSizeChanged", function(frame, width)
        body:SetWidth(math.max(1, width))
        frame:RefreshRange()
    end)
    self.navScroll, self.navOffsets = scroll, {}
    local y, previousGroup = 2, nil
    for _, definition in ipairs(navDefs) do
        if definition.group ~= previousGroup then
            if previousGroup then
                y = y + 7
                local divider = body:CreateTexture(nil, "ARTWORK")
                Sintezza_Theme:Tint(divider, "SetColorTexture", T.lineSoft)
                divider:SetHeight(1)
                divider:SetPoint("TOPLEFT", body, "TOPLEFT", 8, -y)
                divider:SetPoint("TOPRIGHT", body, "TOPRIGHT", -6, -y)
                y = y + 7
            end
            local group = NAV_GROUPS[definition.group]
            local tile = CreateFrame("Frame", nil, body, "BackdropTemplate")
            tile:SetSize(18, 18)
            tile:SetPoint("TOPLEFT", body, "TOPLEFT", 6, -y)
            T:Backdrop(tile, T.header, T.lineSoft)
            local icon = T:Glyph(tile, group and group.icon or "overview", 16)
            icon:SetPoint("CENTER")
            local groupLabel = W:Label(body, SUI.NavGroupLabel(definition.group), 9, T.muted)
            groupLabel:SetPoint("LEFT", tile, "RIGHT", 8, 0)
            y = y + 23
        end
        local button = W:NavButton(body, definition.title, definition.key, OpenPage)
        button:SetPoint("TOPLEFT", body, "TOPLEFT", 0, -y)
        button:SetPoint("TOPRIGHT", body, "TOPRIGHT", -1, -y)
        self.navOffsets[definition.key] = { top = y, bottom = y + button:GetHeight() }
        y = y + button:GetHeight()
        self.nav[#self.nav + 1] = button
        previousGroup = definition.group
    end
    body:SetSize(math.max(1, scroll:GetWidth()), y + 4)
    scroll:HookScript("OnShow", function()
        local page = self.pages[self.currentPage]
        self:RevealNav(page and page.navKey or self.currentPage)
    end)
    window:Hide()
    self:SelectPage("dashboard")
    return window
end

function UI:RegisterBlizzardCategory()
    if not Settings or not Settings.RegisterCanvasLayoutCategory then return end
    local panel = CreateFrame("Frame")
    panel.name = "Sintezza UI"
    local title = W:Label(panel, "Sintezza UI", 18, T.text)
    local icon = panel:CreateTexture(nil, "ARTWORK")
    icon:SetSize(24, 24)
    icon:SetPoint("TOPLEFT", panel, "TOPLEFT", 18, -18)
    icon:SetTexture(Sintezza_Theme.icons.Sintezza_UI)
    title:SetPoint("LEFT", icon, "RIGHT", 8, 0)
    local button = W:Button(panel, Text("Открыть настройки", "Open settings"), function()
        if SettingsPanel and SettingsPanel:IsShown() then HideUIPanel(SettingsPanel) end
        UI:Show("dashboard")
    end, true)
    button:SetSize(170, 28)
    button:SetPoint("TOPLEFT", icon, "BOTTOMLEFT", 0, -16)
    local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
    Settings.RegisterAddOnCategory(category)
    self.category = category
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
