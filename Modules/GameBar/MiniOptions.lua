local _, SUI = ...
local M, W, B = SUI.GameBar, SUI.Widgets, SUI.SettingsBuilder
local Text = SUI.Text

local function P() return SUI:GetModuleProfile("gameBar") end
local function Mini()
    P().miniBar = type(P().miniBar) == "table" and P().miniBar or {}
    return P().miniBar
end
local function MA()
    Mini().appearance = type(Mini().appearance) == "table" and Mini().appearance or {}
    return Mini().appearance
end
local function TP()
    Mini().tooltip = type(Mini().tooltip) == "table" and Mini().tooltip or {}
    return Mini().tooltip
end
local function Add(page, card, widget) return B:AddRow(page, card, widget) end
local function UpdatePreviews(page)
    for _, sample in ipairs(page.miniPreviews) do sample:Refresh() end
end
local function WithPreview(page, set)
    return function(value)
        set(value)
        UpdatePreviews(page)
    end
end
local function Toggle(page, card, label, get, set, detail)
    return Add(page, card, W:Toggle(card, label, get, WithPreview(page, set), detail))
end
local function Slider(page, card, label, low, high, step, get, set)
    return Add(page, card, W:SliderRow(card, label, low, high, step, get, WithPreview(page, set)))
end
local function Choice(page, card, label, choices, get, set)
    return Add(page, card, W:ChoiceRow(card, label, choices, get, WithPreview(page, set)))
end
local function Color(page, card, label, get, set)
    return Add(page, card, W:ColorRow(card, label, get, WithPreview(page, set)))
end
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

local function ApplyMini()
    M:OnProfileChanged()
end

local function RefreshTooltip()
    if M.RefreshActiveTooltip then M:RefreshActiveTooltip() end
end

local function BuildPage(parent)
    local page = B:CreateTabbedPage(parent, Text("Под миникартой", "Minimap bar"), nil, {
        { key = "general", title = Text("Основное", "General") },
        { key = "appearance", title = Text("Оформление", "Appearance") },
        { key = "layout", title = Text("Компоновка", "Layout") },
        { key = "elements", title = Text("Часы и списки", "Clock and lists") },
        { key = "advanced", title = Text("Дополнительно", "Advanced") },
    })

    page.miniPreviews = {}
    local function AddPreview(columns, tab, resting)
        local card = B:AddColumnSection(page, columns, "right", Text("Предпросмотр", "Preview"),
            Text("Показывает оформление и текущие данные панели.", "Shows the panel's live values and style."), true)
        local sample = Add(page, card, M:CreateMiniSettingsPreview(card))
        page.miniPreviews[#page.miniPreviews + 1] = sample
        if resting then
            local play = W:NavigationRow(card, Text("Индикатор зоны отдыха", "Rest area indicator"),
                nil, Text("Проверить Zz", "Preview Zz"), function() M:PreviewMiniResting(sample.resting) end)
            Add(page, card, W:BindAvailability(play, function()
                if Mini().enabled ~= true or Mini().showResting == false then
                    return false, Text("Включи панель и показ Zz.", "Enable the bar and Zz indicator.")
                end
                return true
            end))
        end
        Finish(page, tab, card)
    end

    local columns = B:BeginColumns(page, "general")
    local card = B:AddColumnSection(page, columns, "left", Text("Панель", "Bar"))
    Toggle(page, card, Text("Включить панель", "Enable bar"), function() return Mini().enabled == true end, function(v)
        Mini().enabled = v
        ApplyMini()
        page:Refresh()
    end)
    Toggle(page, card, Text("Блокировать положение", "Lock position"), function() return Mini().locked ~= false end, function(v)
        Mini().locked = v
    end)
    B:AddRow(page, card, W:FeatureToggle(card, "showClock", Text("Часы", "Clock"),
        Text("ЛКМ открывает календарь, ПКМ — часы и будильник.", "Left-click opens the calendar, right-click opens the clock and alarm."),
        nil, function() UpdatePreviews(page) end))
    local fps = Toggle(page, card, Text("Показывать FPS", "Show frame rate"), function() return Mini().showFPS ~= false end, function(v)
        Mini().showFPS = v
        ApplyMini()
    end)
    fps.settingsID = "miniFPS"
    local latency = Toggle(page, card, Text("Показывать задержку", "Show latency"), function() return Mini().showLatency ~= false end, function(v)
        Mini().showLatency = v
        ApplyMini()
    end)
    latency.settingsID = "miniLatency"
    local resting = Toggle(page, card, Text("Показывать Zz в зоне отдыха", "Show Zz in rest areas"), function() return Mini().showResting ~= false end, function(v)
        Mini().showResting = v
        ApplyMini()
        page:Refresh()
    end)
    resting.settingsID = "miniResting"
    Toggle(page, card, Text("Кнопка друзей", "Friends button"), function() return Mini().showFriends ~= false end, function(v)
        Mini().showFriends = v
        ApplyMini()
    end)
    Toggle(page, card, Text("Кнопка гильдии", "Guild button"), function() return Mini().showGuild ~= false end, function(v)
        Mini().showGuild = v
        ApplyMini()
    end)
    local scale = Slider(page, card, Text("Масштаб панели", "Bar scale"), .60, 1.40, .05, function() return Mini().scale or .9 end, function(v)
        Mini().scale = v
        M:ApplyMiniBarPosition()
    end)
    scale.settingsID = "miniScale"
    local transparency = W:TransparencySlider(card, Text("Прозрачность панели", "Bar transparency"), 90,
        function() return Mini().hoverAlpha end, function(opacity)
            Mini().hoverAlpha = opacity
            M:RefreshMiniBarFade()
            UpdatePreviews(page)
        end)
    transparency.settingsID = "miniBarTransparency"
    Add(page, card, W:Help(transparency, Text("Меняет фон, текст и иконки вместе. 0% — непрозрачная панель.",
        "Changes the background, text and icons together. 0% is an opaque bar.")))
    Finish(page, "general", card)

    AddPreview(columns, "general", true)
    B:FinishColumns(page, "general", columns)

    columns = B:BeginColumns(page, "appearance")
    AddPreview(columns, "appearance")
    card = B:AddColumnSection(page, columns, "left", Text("Панель", "Bar"))
    Toggle(page, card, Text("Показывать фон", "Show background"), function() return MA().backdropEnabled ~= false end, function(v)
        MA().backdropEnabled = v
        M:ApplyMiniBarStyle()
        page:Refresh()
    end)
    local backdrop, backdropTransparency = W:BackdropControls(card, MA, function() M:ApplyMiniBarStyle(); UpdatePreviews(page) end)
    backdropTransparency.settingsID = "miniBarBackdropTransparency"
    Add(page, card, backdrop)
    Add(page, card, backdropTransparency)
    Choice(page, card, Text("Стиль рамки", "Border style"), { SOLID = Text("Сплошная", "Solid"), GLOW = Text("Свечение", "Glow") }, function()
        return MA().borderStyle
    end, function(v)
        MA().borderStyle = v
        M:ApplyMiniBarStyle()
    end)
    Color(page, card, Text("Цвет рамки", "Border color"), function() return MA().borderColor end, function(v)
        MA().borderColor = v
        M:ApplyMiniBarStyle()
    end)
    Slider(page, card, Text("Толщина рамки", "Border thickness"), 0, 4, 1, function() return MA().borderSize or 1 end, function(v)
        MA().borderSize = v
        M:ApplyMiniBarStyle()
    end)
    Finish(page, "appearance", card)

    card = B:AddColumnSection(page, columns, "right", Text("Иконки", "Icons"))
    Color(page, card, Text("Базовый цвет", "Base color"), function() return MA().iconColor end, function(v)
        MA().iconColor = v
        M:ApplyMiniBarStyle()
    end)
    Slider(page, card, Text("Яркость иконок", "Icon brightness"), .1, 1, .05, function() return MA().iconAlpha or .9 end, function(v)
        MA().iconAlpha = v
        M:ApplyMiniBarStyle()
    end)
    Slider(page, card, Text("Яркость Zz", "Zz opacity"), .1, 1, .05, function() return MA().restingAlpha or .62 end, function(v)
        MA().restingAlpha = v
        M:ApplyMiniBarStyle()
    end)
    Choice(page, card, Text("Акцент при наведении", "Hover color"), { CLASS = Text("Цвет класса", "Class color"), CUSTOM = Text("Свой цвет", "Custom color") }, function()
        return MA().hoverColorMode
    end, function(v)
        MA().hoverColorMode = v
        M:ApplyMiniBarStyle()
        page:Refresh()
    end)
    local hover = Color(page, card, Text("Свой акцент", "Custom hover color"), function() return MA().hoverColor end, function(v)
        MA().hoverColor = v
        M:ApplyMiniBarStyle()
    end)
    BindAvailable(hover, function() return MA().hoverColorMode == "CUSTOM" end)
    Finish(page, "appearance", card)
    B:FinishColumns(page, "appearance", columns)

    card = B:AddSection(page, "appearance", Text("Текст панели", "Bar text"))
    Choice(page, card, Text("Шрифт", "Font"), function() return M:GetFontChoices() end, function() return MA().font end, function(v)
        MA().font = v
        M:ApplyMiniBarStyle()
    end)
    Slider(page, card, Text("Размер часов", "Clock font size"), 10, 24, 1, function() return MA().clockFontSize or 14 end, function(v)
        MA().clockFontSize = v
        M:ApplyMiniBarStyle()
    end)
    Slider(page, card, Text("Размер показателей", "Stats font size"), 8, 18, 1, function() return MA().dataFontSize or 10 end, function(v)
        MA().dataFontSize = v
        M:ApplyMiniBarStyle()
    end)
    Choice(page, card, Text("Обводка", "Outline"), { NONE = Text("Без обводки", "None"), OUTLINE = Text("Тонкая", "Thin"), THICKOUTLINE = Text("Толстая", "Thick") }, function()
        return MA().outline
    end, function(v)
        MA().outline = v
        M:ApplyMiniBarStyle()
    end)
    Color(page, card, Text("Цвет текста", "Text color"), function() return MA().textColor end, function(v)
        MA().textColor = v
        M:ApplyMiniBarStyle()
    end)
    Slider(page, card, Text("Яркость текста", "Text opacity"), .1, 1, .05, function() return MA().textAlpha or 1 end, function(v)
        MA().textAlpha = v
        M:ApplyMiniBarStyle()
    end)
    Finish(page, "appearance", card)

    card = B:AddSection(page, "appearance", Text("Счетчики друзей и гильдии", "Friend and guild counts"))
    Choice(page, card, Text("Шрифт чисел", "Count font"), function() return M:GetFontChoices() end, function() return MA().badgeFont end, function(v)
        MA().badgeFont = v
        M:ApplyMiniBarStyle()
    end)
    Slider(page, card, Text("Размер чисел", "Count font size"), 8, 24, 1, function() return MA().badgeFontSize or 10 end, function(v)
        MA().badgeFontSize = v
        M:ApplyMiniBarStyle()
    end)
    Color(page, card, Text("Цвет чисел", "Count color"), function() return MA().badgeColor end, function(v)
        MA().badgeColor = v
        M:ApplyMiniBarStyle()
    end)
    Choice(page, card, Text("Обводка чисел", "Count outline"), { NONE = Text("Без обводки", "None"), OUTLINE = Text("Тонкая", "Thin"), THICKOUTLINE = Text("Толстая", "Thick") }, function()
        return MA().badgeOutline
    end, function(v)
        MA().badgeOutline = v
        M:ApplyMiniBarStyle()
    end)
    Slider(page, card, Text("Числа по X", "Count X offset"), -20, 20, 1, function() return MA().badgeX or 0 end, function(v)
        MA().badgeX = v
        M:ApplyMiniBarLayout()
    end)
    Slider(page, card, Text("Числа по Y", "Count Y offset"), -20, 20, 1, function() return MA().badgeY or 4 end, function(v)
        MA().badgeY = v
        M:ApplyMiniBarLayout()
    end)
    Finish(page, "appearance", card)

    card = B:AddSection(page, "appearance", Text("Текст списков", "List text"))
    Choice(page, card, Text("Шрифт", "Font"), function() return M:GetFontChoices() end, function() return TP().font end, function(v)
        TP().font = v
        RefreshTooltip()
    end)
    Slider(page, card, Text("Размер шрифта", "Font size"), 8, 16, 1, function() return TP().fontSize or 10 end, function(v)
        TP().fontSize = v
        RefreshTooltip()
    end)
    Choice(page, card, Text("Обводка", "Outline"), { NONE = Text("Без обводки", "None"), OUTLINE = Text("Тонкая", "Thin"), THICKOUTLINE = Text("Толстая", "Thick") }, function()
        return TP().outline
    end, function(v)
        TP().outline = v
        RefreshTooltip()
    end)
    Finish(page, "appearance", card)

    card = B:AddSection(page, "appearance", Text("Подложка списков", "List background"))
    Toggle(page, card, Text("Показывать фон", "Show background"), function() return TP().backdropEnabled ~= false end, function(v)
        TP().backdropEnabled = v
        RefreshTooltip()
        page:Refresh()
    end)
    local tooltipBackdrop, tooltipTransparency = W:BackdropControls(card, TP, RefreshTooltip)
    tooltipTransparency.settingsID = "socialListBackdropTransparency"
    Add(page, card, tooltipBackdrop)
    Add(page, card, tooltipTransparency)
    Choice(page, card, Text("Стиль рамки", "Border style"), { SOLID = Text("Сплошная", "Solid"), GLOW = Text("Свечение", "Glow") }, function()
        return TP().borderStyle
    end, function(v)
        TP().borderStyle = v
        RefreshTooltip()
    end)
    Color(page, card, Text("Цвет рамки", "Border color"), function() return TP().borderColor end, function(v)
        TP().borderColor = v
        RefreshTooltip()
    end)
    Slider(page, card, Text("Толщина рамки", "Border thickness"), 0, 4, 1, function() return TP().borderSize or 1 end, function(v)
        TP().borderSize = v
        RefreshTooltip()
    end)
    Finish(page, "appearance", card)

    columns = B:BeginColumns(page, "layout")
    AddPreview(columns, "layout")
    card = B:AddColumnSection(page, columns, "left", Text("Общая геометрия", "Bar dimensions"))
    Toggle(page, card, Text("Автоматическая ширина", "Automatic width"), function() return Mini().autoWidth ~= false end, function(v)
        Mini().autoWidth = v
        M:ApplyMiniBarLayout()
        page:Refresh()
    end)
    local width = Slider(page, card, Text("Ширина панели", "Bar width"), 120, 600, 1, function() return Mini().width or 230 end, function(v)
        Mini().width = v
        M:ApplyMiniBarLayout()
    end)
    BindAvailable(width, function() return Mini().autoWidth == false end)
    Slider(page, card, Text("Высота панели", "Bar height"), 22, 80, 1, function() return Mini().height or 30 end, function(v)
        Mini().height = v
        M:ApplyMiniBarLayout()
    end)
    Slider(page, card, Text("Внутренний отступ", "Inner padding"), 0, 20, 1, function() return Mini().padding or 4 end, function(v)
        Mini().padding = v
        M:ApplyMiniBarLayout()
    end)
    Slider(page, card, Text("Интервал элементов", "Item spacing"), 0, 20, 1, function() return Mini().spacing or 4 end, function(v)
        Mini().spacing = v
        M:ApplyMiniBarLayout()
    end)
    Slider(page, card, Text("Содержимое по Y", "Content Y offset"), -20, 20, 1, function() return Mini().contentYOffset or 0 end, function(v)
        Mini().contentYOffset = v
        M:ApplyMiniBarLayout()
    end)
    Finish(page, "layout", card)

    card = B:AddColumnSection(page, columns, "right", Text("Размер элементов", "Item dimensions"))
    Slider(page, card, Text("Друзья и гильдия", "Friends and guild"), 12, 40, 1, function() return Mini().socialIconSize or 18 end, function(v)
        Mini().socialIconSize = v
        M:ApplyMiniBarLayout()
    end)
    local restingSize = Slider(page, card, Text("Размер Zz", "Zz size"), 16, 40, 1, function() return Mini().restingSize or 24 end, function(v)
        Mini().restingSize = v
        M:ApplyMiniBarLayout()
    end)
    restingSize.settingsID = "miniRestingSize"
    Slider(page, card, Text("Ширина часов", "Clock width"), 36, 120, 1, function() return Mini().clockWidth or 48 end, function(v)
        Mini().clockWidth = v
        M:ApplyMiniBarLayout()
    end)
    Slider(page, card, Text("Ширина соц. кнопок", "Social button width"), 20, 80, 1, function() return Mini().socialWidth or 32 end, function(v)
        Mini().socialWidth = v
        M:ApplyMiniBarLayout()
    end)
    Slider(page, card, Text("Ширина FPS", "Frame rate width"), 32, 120, 1, function() return Mini().fpsWidth or 43 end, function(v)
        Mini().fpsWidth = v
        M:ApplyMiniBarLayout()
    end)
    Slider(page, card, Text("Ширина задержки", "Latency width"), 32, 120, 1, function() return Mini().latencyWidth or 48 end, function(v)
        Mini().latencyWidth = v
        M:ApplyMiniBarLayout()
    end)
    Finish(page, "layout", card)
    B:FinishColumns(page, "layout", columns)

    card = B:AddSection(page, "layout", Text("Размеры списков друзей и гильдии", "Friend and guild list dimensions"),
        Text("Настройки списков, которые открываются при наведении на кнопки друзей и гильдии под миникартой.",
            "Controls the lists that appear when you hover over the Friends and Guild buttons below the minimap."))
    Slider(page, card, Text("Ширина списка", "List width"), 280, 600, 5, function() return TP().width or 390 end, function(v)
        TP().width = v
        RefreshTooltip()
    end)
    Slider(page, card, Text("Отступ от края списка", "List edge padding"), 4, 24, 1, function() return TP().padding or 10 end, function(v)
        TP().padding = v
        RefreshTooltip()
    end)
    Slider(page, card, Text("Расстояние между строками", "Spacing between list rows"), 0, 12, 1, function() return TP().rowSpacing or 2 end, function(v)
        TP().rowSpacing = v
        RefreshTooltip()
    end)
    Slider(page, card, Text("Лимит персонажей в списке", "Character limit per list"), 5, 50, 1, function() return TP().maxRows or 24 end, function(v)
        TP().maxRows = v
        RefreshTooltip()
    end)
    Finish(page, "layout", card)

    columns = B:BeginColumns(page, "elements")
    card = B:AddColumnSection(page, columns, "left", Text("Социальные элементы", "Social buttons"))
    Toggle(page, card, Text("Скрывать нулевой онлайн", "Hide zero online counts"), function() return Mini().hideZeroCounts ~= false end, function(v)
        Mini().hideZeroCounts = v
        M:UpdateMiniOnline()
    end)
    Finish(page, "elements", card)

    card = B:AddColumnSection(page, columns, "right", Text("Часы и показатели", "Clock and stats"))
    Toggle(page, card, Text("24-часовой формат", "24-hour clock"), function() return Mini().twentyFourHour ~= false end, function(v)
        Mini().twentyFourHour = v
        M:UpdateClock()
    end)
    Toggle(page, card, Text("Показывать секунды", "Show seconds"), function() return Mini().showSeconds == true end, function(v)
        Mini().showSeconds = v
        M:UpdateClock()
    end)
    Finish(page, "elements", card)
    B:FinishColumns(page, "elements", columns)

    card = B:AddSection(page, "elements", Text("Списки друзей и гильдии", "Friends and guild lists"))
    Toggle(page, card, Text("Сначала группа и текущая зона", "Show group and nearby players first"), function() return TP().groupByContext ~= false end, function(v)
        TP().groupByContext = v
        RefreshTooltip()
    end)

    Toggle(page, card, Text("Показывать другой сервер", "Show other realms"), function() return TP().showRealm ~= false end, function(v)
        TP().showRealm = v
        RefreshTooltip()
    end)
    Toggle(page, card, Text("Показывать роль в группе", "Show group role"), function() return TP().showGroupRole ~= false end, function(v)
        TP().showGroupRole = v
        RefreshTooltip()
    end)
    Finish(page, "elements", card)

    columns = B:BeginColumns(page, "advanced")
    card = B:AddColumnSection(page, columns, "left", Text("Видимость", "Visibility"))
    Toggle(page, card, Text("Только при наведении", "Show on hover"), function() return Mini().mouseover == true end, function(v)
        Mini().mouseover = v
        if M.RefreshMiniBarFade then M:RefreshMiniBarFade() end
        page:Refresh()
    end)
    Choice(page, card, Text("В бою", "In combat"), {
        SHOW = Text("Показывать", "Show"),
        HIDE = Text("Скрывать", "Hide"),
        SHOW_ON_HOVER = Text("По общему режиму", "Use normal visibility"),
    }, function() return Mini().combatVisibility end, function(v)
        Mini().combatVisibility = v
        if M.ApplyMiniBarVisibility then M:ApplyMiniBarVisibility() end
        if M.RefreshMiniBarFade then M:RefreshMiniBarFade() end
    end)
    Toggle(page, card, Text("Скрывать в битве питомцев", "Hide during pet battles"), function() return Mini().hideInPetBattle == true end, function(v)
        Mini().hideInPetBattle = v
        if M.ApplyMiniBarVisibility then M:ApplyMiniBarVisibility() end
    end)
    Finish(page, "advanced", card)
    card = B:AddColumnSection(page, columns, "left", Text("Анимация видимости", "Hover fade"))
    local fadeDelay = Slider(page, card, Text("Задержка исчезновения", "Fade delay"), .03, 1, .01, function()
        return Mini().fadeDelay or .04
    end, function(v)
        Mini().fadeDelay = v
    end)
    local fadeDuration = Slider(page, card, Text("Длительность исчезновения", "Fade duration"), .03, 1, .01, function()
        return Mini().fadeDuration or .11
    end, function(v)
        Mini().fadeDuration = v
    end)
    BindAvailable(fadeDelay, function() return Mini().mouseover == true end)
    BindAvailable(fadeDuration, function() return Mini().mouseover == true end)
    Finish(page, "advanced", card)

    card = B:AddColumnSection(page, columns, "right", Text("Точное положение", "Position offsets"), Text("Смещение относительно нижнего правого угла миникарты.", "Offsets from the bottom-right corner of the minimap."))
    Slider(page, card, Text("Координата X", "X offset"), -300, 300, 1, function() return Mini().x or 0 end, function(v)
        Mini().x = v
        M:ApplyMiniBarPosition()
    end)
    Slider(page, card, Text("Координата Y", "Y offset"), -200, 100, 1, function() return Mini().y or -4 end, function(v)
        Mini().y = v
        M:ApplyMiniBarPosition()
    end)
    Slider(page, card, Text("Отдых по X", "Resting indicator X offset"), -30, 30, 1, function() return Mini().restingX or 2 end, function(v)
        Mini().restingX = v
        M:ApplyMiniBarLayout()
    end)
    Slider(page, card, Text("Отдых по Y", "Resting indicator Y offset"), -30, 30, 1, function() return Mini().restingY or -4 end, function(v)
        Mini().restingY = v
        M:ApplyMiniBarLayout()
    end)
    Add(page, card, W:ActionRow(card, Text("Перемещение мышью", "Drag bar"), Text("Разблокировать", "Unlock"), function()
        Mini().locked = false
        page:Refresh()
    end, true))
    Finish(page, "advanced", card)
    B:FinishColumns(page, "advanced", columns)

    B:SetPageFooter(page, {
        { title = Text("Сбросить мини-панель", "Reset minimap bar"), width = 154, callback = function()
            W:Confirm(Text("Сбросить настройки панели под миникартой?", "Restore the minimap bar defaults?"), function()
                SUI:ResetModuleSection("gameBar", "miniBar")
            end)
        end },
        { title = Text("Сбросить позицию", "Reset position"), width = 132, callback = function()
            W:Confirm(Text("Сбросить положение панели под миникартой?", "Reset the minimap bar position?"), function()
                Mini().x, Mini().y, Mini().scale = 0, -4, .9
                ApplyMini()
                page:Refresh()
            end)
        end },
    })

    page.OnSelected = function()
        M.miniSettingsOpen = true
        if M.uiInitialized then M:ApplyMiniBar() end
    end
    page.OnDeselected = function()
        M.miniSettingsOpen = false
        if M.uiInitialized then M:ApplyMiniBar() end
    end
    return page
end

SUI:RegisterSettingsPage({
    key = "gameBarMini",
    title = Text("Под миникартой", "Minimap bar"),
    group = "ПАНЕЛИ",
    order = 20,
    builder = BuildPage,
})
