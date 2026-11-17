local _, SUI = ...
local M, W, B = SUI.RaidTools, SUI.Widgets, SUI.SettingsBuilder
local Text = SUI.Text
local PANEL_ORDER = { "TARGET", "WORLD", "CONTROL", "PING" }
local PANEL_NAMES = { TARGET = Text("Метки цели", "Target markers"), WORLD = Text("Метки местности", "World markers"), CONTROL = Text("Команды", "Actions"), PING = Text("Пинги", "Pings") }

local function P() return SUI:GetModuleProfile("raidTools") end
local function A() return P().appearance end
local function R() return P().raidCheck end
local function Add(page, card, widget) return B:AddRow(page, card, widget) end
local function Toggle(page, card, label, get, set, help) return Add(page, card, W:Toggle(card, label, get, set, help)) end
local function Slider(page, card, label, low, high, step, get, set) return Add(page, card, W:SliderRow(card, label, low, high, step, get, set)) end
local function Choice(page, card, label, choices, get, set) return Add(page, card, W:ChoiceRow(card, label, choices, get, set)) end
local function Color(page, card, label, get, set) return Add(page, card, W:ColorRow(card, label, get, set)) end
local function Finish(page, tab, card) B:FinishCard(page, tab, card) end

local function BindAvailable(row, predicate)
    local refresh = row.Refresh
    function row:Refresh(...)
        if refresh then refresh(self, ...) end
        self:SetAvailable(predicate())
    end
    row:Refresh()
    return row
end

local function BuildPage(parent)
    local page = B:CreateTabbedPage(parent, Text("Рейд-инструменты", "Raid tools"), nil, {
        { key = "general", title = Text("Основное", "General") },
        { key = "panels", title = Text("Панели", "Bars") },
        { key = "appearance", title = Text("Оформление", "Appearance") },
        { key = "audit", title = Text("Проверка", "Ready check") },
        { key = "advanced", title = Text("Дополнительно", "Advanced") },
    })
    page.panelID = "TARGET"

    local function Apply()
        M:OnProfileChanged()
        page:Refresh()
    end
    local function AddPreview(columns, tab)
        local preview = B:AddColumnSection(page, columns, "right", Text("Предпросмотр", "Preview"),
            Text("Показывает выбранную рейдовую панель с действующим размером, цветом и ориентацией.",
                "Shows the selected raid bar with its current size, color and orientation."), true)
        Add(page, preview, M:CreateSettingsPanelPreview(preview, P, function() return page.panelID end))
        Finish(page, tab, preview)
    end

    local columns = B:BeginColumns(page, "general")
    local card = B:AddColumnSection(page, columns, "left", Text("Модуль и панели", "Module and bars"))
    Toggle(page, card, Text("Включить Raid Tools", "Enable Raid Tools"), function() return P().enabled end, function(v)
        SUI:SetFeature("raidTools", v)
    end)
    Toggle(page, card, Text("Блокировать положение", "Lock positions"), function() return P().locked end, function(v) P().locked = v; P().editMode = false; Apply() end)
    for _, id in ipairs(PANEL_ORDER) do
        local panelID = id
        Toggle(page, card, PANEL_NAMES[panelID], function() return P().panels[panelID].enabled end, function(v) P().panels[panelID].enabled = v; Apply() end)
    end
    Toggle(page, card, Text("Скрывать недоступные метки", "Hide unavailable markers"), function() return P().panels.WORLD.hideWhenUnavailable end, function(v) P().panels.WORLD.hideWhenUnavailable = v; Apply() end)
    Finish(page, "general", card)

    card = B:AddColumnSection(page, columns, "right", Text("Команды", "Actions"))
    Add(page, card, W:FeatureToggle(card, "ready", Text("Разрешить запуск проверки готовности", "Allow starting a ready check"),
        Text("Лидер или помощник может запросить у группы подтверждение готовности.",
            "A leader or assistant can ask group members to confirm readiness."), nil,
        function() page:Refresh() end))
    Add(page, card, W:FeatureToggle(card, "pull", Text("Кнопка отсчета до боя", "Pull countdown button"),
        Text("ЛКМ запускает общий отсчет, ПКМ отменяет. Нужна группа и права лидера или помощника.",
            "Left-click starts a group countdown and right-click cancels it. Requires a group and leader or assistant permissions."), nil,
        function() page:Refresh() end))
    Add(page, card, W:FeatureToggle(card, "clear", Text("Кнопка очистки меток мира", "Clear world markers button")))
    local pullSeconds = Slider(page, card, Text("Пул-таймер, секунд", "Pull timer, seconds"), 3, 20, 1, function() return P().actions.pullSeconds end, function(v) P().actions.pullSeconds = math.floor(v + .5); Apply() end)
    W:Help(pullSeconds, Text("Длительность группового и пробного отсчета.", "Duration of the group and preview countdowns."))
    Add(page, card, W:Help(W:ActionRow(card, Text("Предпросмотр отсчета", "Countdown preview"),
        Text("Запустить", "Start"), function() M:PreviewPullCountdown() end),
        Text("Открывает личное окно отсчета. Работает без группы и ничего ей не отправляет.",
            "Opens a private countdown window. Works solo and sends nothing to the group.")))
    Toggle(page, card, Text("Shift + клик: метка под курсором", "Shift+click: mark unit under cursor"),
        function() return P().actions.useMouseover end, function(v) P().actions.useMouseover = v; Apply() end,
        Text("Наведи курсор на персонажа или его рамку и с Shift нажми кнопку метки. Обычный клик ставит метку текущей цели.",
            "Hover over a unit or its frame, then Shift-click a marker button. A regular click marks your current target."))
    local readyCheck = Add(page, card, W:ActionRow(card, Text("Проверка готовности", "Ready check"), Text("Запустить", "Start"), function() M:StartReadyCheck() end, true))
    BindAvailable(readyCheck, function() return P().enabled == true and P().actions.readyCheck ~= false end)
    Finish(page, "general", card)
    B:FinishColumns(page, "general", columns)

    columns = B:BeginColumns(page, "panels")
    AddPreview(columns, "panels")
    card = B:AddColumnSection(page, columns, "left", Text("Выбранная панель", "Selected bar"))
    local panelSelector = W:Segmented(card,
        { Text("Цель", "Target"), Text("Местность", "World"), Text("Команды", "Actions"), Text("Пинги", "Pings") }, PANEL_ORDER,
        function() return page.panelID end,
        function(value) page.panelID = value; page:Refresh() end)
    Add(page, card, panelSelector)
    Choice(page, card, Text("Ориентация", "Orientation"), { HORIZONTAL = Text("Горизонтальная", "Horizontal"), VERTICAL = Text("Вертикальная", "Vertical") }, function() return P().panels[page.panelID].orientation end, function(v) P().panels[page.panelID].orientation = v; Apply() end)
    Slider(page, card, Text("Масштаб панели", "Bar scale"), .5, 2, .05, function() return P().panels[page.panelID].scale end, function(v) P().panels[page.panelID].scale = v; Apply() end)
    Toggle(page, card, Text("Только при наведении", "Show on hover"), function() return P().panels[page.panelID].mouseover end, function(v) P().panels[page.panelID].mouseover = v; Apply() end)
    local panelAlpha = Slider(page, card, Text("Яркость при наведении", "Hover opacity"), .1, 1, .05, function() return P().panels[page.panelID].hoverAlpha end, function(v) P().panels[page.panelID].hoverAlpha = v; Apply() end)
    BindAvailable(panelAlpha, function() return P().panels[page.panelID].mouseover == true end)
    Finish(page, "panels", card)

    card = B:AddColumnSection(page, columns, "left", Text("Общая геометрия", "All bars"))
    Slider(page, card, Text("Размер кнопок", "Button size"), 16, 42, 1, function() return A().iconSize end, function(v) A().iconSize = v; Apply() end)
    Slider(page, card, Text("Интервал кнопок", "Button spacing"), 0, 16, 1, function() return A().spacing end, function(v) A().spacing = v; Apply() end)
    Slider(page, card, Text("Внутренний отступ", "Padding"), 0, 16, 1, function() return A().padding end, function(v) A().padding = v; Apply() end)
    Finish(page, "panels", card)

    B:FinishColumns(page, "panels", columns)
    columns = B:BeginColumns(page, "appearance")
    AddPreview(columns, "appearance")
    card = B:AddColumnSection(page, columns, "left", Text("Фон и рамка", "Background and border"))
    Toggle(page, card, Text("Показывать фон", "Show background"), function() return A().backdropEnabled end, function(v) A().backdropEnabled = v; Apply() end)
    local background = Color(page, card, Text("Цвет и прозрачность", "Background color and opacity"), function() return A().backdrop end, function(v) A().backdrop = v; Apply() end)
    BindAvailable(background, function() return A().backdropEnabled == true end)
    Choice(page, card, Text("Стиль рамки", "Border style"), { SOLID = Text("Сплошная", "Solid"), GLOW = Text("Свечение", "Glow") }, function() return A().borderStyle end, function(v) A().borderStyle = v; Apply() end)
    Color(page, card, Text("Цвет рамки", "Border color"), function() return A().border end, function(v) A().border = v; Apply() end)
    Slider(page, card, Text("Толщина рамки", "Border width"), 0, 4, 1, function() return A().borderSize end, function(v) A().borderSize = v; Apply() end)
    Finish(page, "appearance", card)

    card = B:AddColumnSection(page, columns, "right", Text("Иконки", "Icons"))
    Color(page, card, Text("Базовый цвет", "Base color"), function() return A().iconColor end, function(v) A().iconColor = v; Apply() end)
    Slider(page, card, Text("Масштаб глифа", "Icon scale"), .55, 1, .05, function() return A().iconScale end, function(v) A().iconScale = v; Apply() end)
    Slider(page, card, Text("Яркость", "Opacity"), .3, 1, .05, function() return A().iconAlpha end, function(v) A().iconAlpha = v; Apply() end)
    Choice(page, card, Text("Акцент при наведении", "Hover color"), { CLASS = Text("Цвет класса", "Class color"), CUSTOM = Text("Свой цвет", "Custom color") }, function() return A().hoverColorMode end, function(v) A().hoverColorMode = v; Apply() end)
    local customHover = Color(page, card, Text("Свой акцент", "Custom hover color"), function() return A().hoverColor end, function(v) A().hoverColor = v; Apply() end)
    BindAvailable(customHover, function() return A().hoverColorMode == "CUSTOM" end)
    Finish(page, "appearance", card)
    B:FinishColumns(page, "appearance", columns)

    card = B:AddSection(page, "appearance", Text("Подписи режима настройки", "Edit-mode labels"))
    Choice(page, card, Text("Шрифт", "Font"), function() return M:GetFontChoices() end, function() return A().font end, function(v) A().font = v; Apply() end)
    Slider(page, card, Text("Размер", "Size"), 9, 24, 1, function() return A().fontSize end, function(v) A().fontSize = v; Apply() end)
    Choice(page, card, Text("Обводка", "Outline"), { NONE = Text("Без обводки", "None"), OUTLINE = Text("Тонкая", "Thin"), THICKOUTLINE = Text("Толстая", "Thick") }, function() return A().outline end, function(v) A().outline = v; Apply() end)
    Color(page, card, Text("Цвет подписи", "Text color"), function() return A().accent end, function(v) A().accent = v; Apply() end)
    Add(page, card, W:ActionRow(card, Text("Оформление Game Bar", "Game Bar appearance"), Text("Взять стиль", "Copy style"), function()
        local source = SUI:GetModuleProfile("gameBar") and SUI:GetModuleProfile("gameBar").appearance
        if not source then return end
        A().backdropEnabled = source.backdropEnabled
        A().backdrop = SUI.DeepCopy(source.backdropColor)
        A().borderStyle = source.borderStyle
        A().border = SUI.DeepCopy(source.borderColor)
        A().borderSize = source.borderSize
        A().iconColor = SUI.DeepCopy(source.iconColor)
        A().iconScale = source.iconScale
        A().iconAlpha = source.iconAlpha
        A().hoverColorMode = source.hoverColorMode
        A().hoverColor = SUI.DeepCopy(source.hoverColor)
        Apply(); SUI:Print(Text("Оформление Game Bar скопировано в Raid Tools.", "Game Bar style copied."))
    end, true))
    Finish(page, "appearance", card)

    columns = B:BeginColumns(page, "audit")
    card = B:AddColumnSection(page, columns, "left", Text("Поведение", "Behavior"))
    Toggle(page, card, Text("Включить окно", "Enable ready check window"), function() return R().enabled end, function(v)
        if not v then M:HideAudit() end
        SUI:SetFeature("raidCheck", v)
        page:Refresh()
    end)
    local autoShow = Toggle(page, card, Text("Показывать автоматически", "Open automatically"), function() return R().autoShow end, function(v) R().autoShow = v end)
    local autoHide = Toggle(page, card, Text("Скрывать автоматически", "Close automatically"), function() return R().autoHide end, function(v) R().autoHide = v; page:Refresh() end)
    local hideDelay = Slider(page, card, Text("Задержка скрытия", "Close delay"), 1, 20, 1, function() return R().autoHideDelay end, function(v) R().autoHideDelay = v end)
    BindAvailable(autoShow, function() return R().enabled == true end)
    BindAvailable(autoHide, function() return R().enabled == true end)
    BindAvailable(hideDelay, function() return R().enabled == true and R().autoHide == true end)
    Toggle(page, card, Text("Только лидер или помощник", "Leader or assistant only"), function() return R().onlyLeaderAssist end, function(v) R().onlyLeaderAssist = v end)
    Choice(page, card, Text("Сортировка", "Sort by"), { NOT_READY = Text("Сначала неготовые", "Not ready first"), GROUP = Text("Порядок группы", "Group order") }, function() return R().sort end, function(v) R().sort = v; if M.audit and M.audit:IsShown() then M:RefreshAudit() end end)
    Finish(page, "audit", card)

    card = B:AddColumnSection(page, columns, "right", Text("Содержимое окна", "Window contents"),
        Text("Проверяются видимые ауры. Для еды нужен эффект сытости, для рейдового бафа достаточно одного из поддерживаемых эффектов.",
            "Checks visible auras. Food requires Well Fed, and one supported raid buff is enough."))
    for _, column in ipairs({ { "food", Text("Еда", "Food") }, { "flask", Text("Фласка", "Flask") }, { "rune", Text("Руна", "Rune") }, { "buffs", Text("Рейдовый баф", "Raid buff") } }) do
        local key, label = column[1], column[2]
        if key ~= "rune" or not SUI.isForever then
            Toggle(page, card, label, function() return R().columns[key] end, function(v) R().columns[key] = v; if M.audit and M.audit:IsShown() then M:RefreshAudit() end end)
        end
    end
    Slider(page, card, Text("Масштаб окна", "Window scale"), .6, 1.6, .05, function() return R().scale end, function(v) R().scale = v; if M.audit then M.audit:SetScale(v) end end)
    Toggle(page, card, Text("Блокировать окно", "Lock window"), function() return R().locked end, function(v) R().locked = v end)
    Add(page, card, W:ActionRow(card, Text("Тест проверки рейда", "Raid check test"), Text("Открыть", "Open"), function() M.testMode = true; M:ShowAudit(true) end, true))
    Finish(page, "audit", card)
    B:FinishColumns(page, "audit", columns)

    card = B:AddSection(page, "advanced", Text("Выбранная панель", "Selected bar"))
    local advancedSelector = W:Segmented(card,
        { Text("Цель", "Target"), Text("Местность", "World"), Text("Команды", "Actions"), Text("Пинги", "Pings") }, PANEL_ORDER,
        function() return page.panelID end,
        function(value) page.panelID = value; page:Refresh() end)
    Add(page, card, advancedSelector)
    Finish(page, "advanced", card)

    columns = B:BeginColumns(page, "advanced")
    card = B:AddColumnSection(page, columns, "left", Text("Анимация видимости", "Hover fade"))
    local fadeDelay = Slider(page, card, Text("Задержка исчезновения", "Fade delay"), .03, 1, .01, function() return P().panels[page.panelID].fadeDelay end, function(v) P().panels[page.panelID].fadeDelay = v end)
    local fadeDuration = Slider(page, card, Text("Длительность fade", "Fade duration"), .03, 1, .01, function() return P().panels[page.panelID].fadeDuration end, function(v) P().panels[page.panelID].fadeDuration = v end)
    BindAvailable(fadeDelay, function() return P().panels[page.panelID].mouseover == true end)
    BindAvailable(fadeDuration, function() return P().panels[page.panelID].mouseover == true end)
    Finish(page, "advanced", card)

    card = B:AddColumnSection(page, columns, "right", Text("Точное положение", "Position"))
    Slider(page, card, Text("Координата X", "X position"), -2000, 2000, 1, function() return P().panels[page.panelID].x end, function(v) P().panels[page.panelID].x = v; Apply() end)
    Slider(page, card, Text("Координата Y", "Y position"), -2000, 2000, 1, function() return P().panels[page.panelID].y end, function(v) P().panels[page.panelID].y = v; Apply() end)
    Add(page, card, W:ActionRow(card, Text("Основные панели", "Main bars"), Text("Показать", "Show"), function() M:ShowCorePanels() end, true))
    Finish(page, "advanced", card)
    B:FinishColumns(page, "advanced", columns)

    B:SetPageFooter(page, {
        { title = Text("Сбросить модуль", "Reset module"), width = 132, callback = function()
            W:Confirm(Text("Сбросить настройки Raid Tools?", "Reset Raid Tools settings?"), function() SUI:ResetModuleProfile("raidTools") end)
        end },
        { title = Text("Сбросить позиции", "Reset positions"), width = 132, callback = function()
            W:Confirm(Text("Сбросить позиции Raid Tools?", "Reset Raid Tools positions?"), function() M:ResetPanelPositions() end)
        end },
    })

    page.OnSelected = function() M:SetSettingsOpen(true) end
    page.OnDeselected = function() M:SetSettingsOpen(false) end
    return page
end

SUI:RegisterSettingsPage({ key = "raidTools", title = Text("Рейд-инструменты", "Raid tools"), group = "ПАНЕЛИ", order = 30, builder = BuildPage })
