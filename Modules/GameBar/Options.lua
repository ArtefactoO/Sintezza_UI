local _, SUI = ...
local M, W, B, T = SUI.GameBar, SUI.Widgets, SUI.SettingsBuilder, SUI.SettingsTheme
local Text = SUI.Text

local function P() return SUI:GetModuleProfile("gameBar") end
local function A() return P().appearance end

local function Add(page, card, widget) return B:AddRow(page, card, widget) end
local function Toggle(page, card, label, get, set) return Add(page, card, W:Toggle(card, label, get, set)) end
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
    local page = B:CreateTabbedPage(parent, Text("Игровая панель", "Game bar"), nil, {
        { key = "general", title = Text("Основное", "General") },
        { key = "appearance", title = Text("Оформление", "Appearance") },
        { key = "layout", title = Text("Компоновка", "Layout") },
        { key = "elements", title = Text("Элементы", "Elements") },
        { key = "advanced", title = Text("Дополнительно", "Advanced") },
    })

    local function Apply()
        M:OnProfileChanged()
        page:Refresh()
    end
    local function Preview(group, tab)
        local card = B:AddColumnSection(page, group, "right", Text("Предпросмотр", "Preview"),
            Text("Показывает иконки, часы и оформление из текущего профиля.", "Shows the icons, clock and style from your active profile."))
        Add(page, card, M:CreateSettingsBarPreview(card, P))
        Finish(page, tab, card)
    end

    local columns = B:BeginColumns(page, "general")
    local card = B:AddColumnSection(page, columns, "left", Text("Основные настройки", "General settings"))
    Toggle(page, card, Text("Включить панель", "Enable bar"), function() return P().enabled end, function(v) P().enabled = v; Apply() end)
    Toggle(page, card, Text("Блокировать положение", "Lock position"), function() return P().locked end, function(v) P().locked = v end)
    Finish(page, "general", card)

    Preview(columns, "general")
    card = B:AddColumnSection(page, columns, "left", Text("Видимость", "Visibility"))
    Toggle(page, card, Text("Только при наведении", "Show on hover"), function() return P().mouseover end, function(v)
        P().mouseover = v; M:RefreshFade(); page:Refresh()
    end)
    local transparency = W:TransparencySlider(card, Text("Прозрачность панели", "Bar transparency"), 90,
        function() return P().hoverAlpha end, function(opacity)
            P().hoverAlpha = opacity
            M:RefreshFade()
            page:Refresh()
        end)
    transparency.settingsID = "gameBarTransparency"
    Add(page, card, W:Help(transparency, Text("Меняет фон, текст и иконки вместе. 0% — непрозрачная панель.",
        "Changes the background, text and icons together. 0% is an opaque bar.")))
    Choice(page, card, Text("В бою", "In combat"), { SHOW = Text("Показывать", "Show"), HIDE = Text("Скрывать", "Hide"), SHOW_ON_HOVER = Text("По общему режиму", "Use normal visibility") }, function() return P().combatVisibility end, function(v)
        P().combatVisibility = v; M:ApplyVisibilityDriver(); M:RefreshFade()
    end)
    Toggle(page, card, Text("Скрывать в битве питомцев", "Hide during pet battles"), function() return P().hideInPetBattle end, function(v) P().hideInPetBattle = v; M:ApplyVisibilityDriver() end)
    Finish(page, "general", card)
    B:FinishColumns(page, "general", columns)

    columns = B:BeginColumns(page, "appearance")
    Preview(columns, "appearance")
    card = B:AddColumnSection(page, columns, "left", Text("Панели", "Panels"))
    Toggle(page, card, Text("Показывать фон", "Show background"), function() return A().backdropEnabled end, function(v) A().backdropEnabled = v; Apply() end)
    local backdropColor, backdropTransparency = W:BackdropControls(card, A, Apply)
    backdropTransparency.settingsID = "gameBarBackdropTransparency"
    Add(page, card, backdropColor)
    Add(page, card, backdropTransparency)
    Choice(page, card, Text("Стиль рамки", "Border style"), { SOLID = Text("Сплошная", "Solid"), GLOW = Text("Свечение", "Glow") }, function() return A().borderStyle end, function(v) A().borderStyle = v; Apply() end)
    Color(page, card, Text("Цвет рамки", "Border color"), function() return A().borderColor end, function(v) A().borderColor = v; Apply() end)
    Slider(page, card, Text("Толщина рамки", "Border thickness"), 0, 4, 1, function() return A().borderSize end, function(v) A().borderSize = v; Apply() end)
    Finish(page, "appearance", card)

    card = B:AddColumnSection(page, columns, "right", Text("Иконки", "Icons"))
    Color(page, card, Text("Базовый цвет", "Base color"), function() return A().iconColor end, function(v) A().iconColor = v; Apply() end)
    Slider(page, card, Text("Масштаб глифа", "Icon scale"), .55, 1, .05, function() return A().iconScale end, function(v) A().iconScale = v; Apply() end)
    Slider(page, card, Text("Яркость иконок", "Icon brightness"), .3, 1, .05, function() return A().iconAlpha end, function(v) A().iconAlpha = v; Apply() end)
    Choice(page, card, Text("Акцент при наведении", "Hover color"), { CLASS = Text("Цвет класса", "Class color"), CUSTOM = Text("Свой цвет", "Custom color") }, function() return A().hoverColorMode end, function(v) A().hoverColorMode = v; Apply() end)
    local customHover = Color(page, card, Text("Свой акцент", "Custom hover color"), function() return A().hoverColor end, function(v) A().hoverColor = v; Apply() end)
    BindAvailable(customHover, function() return A().hoverColorMode == "CUSTOM" end)
    Finish(page, "appearance", card)
    B:FinishColumns(page, "appearance", columns)

    card = B:AddSection(page, "appearance", Text("Часы", "Clock"))
    Add(page, card, W:FeatureToggle(card, "gameClock", Text("Показывать часы игровой панели", "Show the game bar clock")))
    Choice(page, card, Text("Шрифт", "Font"), function() return M:GetFontChoices() end, function() return A().timeFont end, function(v) A().timeFont = v; Apply() end)
    Slider(page, card, Text("Размер шрифта", "Font size"), 10, 40, 1, function() return A().timeFontSize end, function(v) A().timeFontSize = v; Apply() end)
    Choice(page, card, Text("Обводка", "Outline"), { NONE = Text("Без обводки", "None"), OUTLINE = Text("Тонкая", "Thin"), THICKOUTLINE = Text("Толстая", "Thick") }, function() return A().timeOutline end, function(v) A().timeOutline = v; Apply() end)
    Toggle(page, card, Text("24-часовой формат", "24-hour clock"), function() return P().clock.twentyFourHour end, function(v) P().clock.twentyFourHour = v; M:UpdateClock(); page:Refresh() end)
    Toggle(page, card, Text("Показывать секунды", "Show seconds"), function() return A().showSeconds end, function(v) A().showSeconds = v; M:RestartClockTicker(); page:Refresh() end)
    Finish(page, "appearance", card)

    columns = B:BeginColumns(page, "layout")
    Preview(columns, "layout")
    card = B:AddColumnSection(page, columns, "left", Text("Общая геометрия", "Bar dimensions"))
    Slider(page, card, Text("Общий масштаб", "Overall scale"), .5, 2, .05, function() return P().scale end, function(v) P().scale = v; Apply() end)
    Slider(page, card, Text("Размер иконок", "Icon size"), 14, 40, 1, function() return A().iconSize end, function(v) A().iconSize = v; Apply() end)
    Slider(page, card, Text("Интервал кнопок", "Button spacing"), 0, 20, 1, function() return A().buttonSpacing end, function(v) A().buttonSpacing = v; Apply() end)
    Slider(page, card, Text("Внутренний отступ", "Inner padding"), 0, 16, 1, function() return A().panelPadding end, function(v) A().panelPadding = v; Apply() end)
    Finish(page, "layout", card)

    card = B:AddColumnSection(page, columns, "left", Text("Часы и секции", "Clock and sections"))
    Slider(page, card, Text("Ширина часов", "Clock width"), 60, 220, 1, function() return A().timeWidth end, function(v) A().timeWidth = v; Apply() end)
    Slider(page, card, Text("Высота часов", "Clock height"), 24, 80, 1, function() return A().timeHeight end, function(v) A().timeHeight = v; Apply() end)
    Slider(page, card, Text("Промежуток секций", "Section spacing"), 0, 30, 1, function() return A().segmentGap end, function(v) A().segmentGap = v; Apply() end)
    Slider(page, card, Text("Вертикальное смещение", "Y offset"), -20, 20, 1, function() return A().verticalAlignment end, function(v) A().verticalAlignment = v; Apply() end)
    Finish(page, "layout", card)
    B:FinishColumns(page, "layout", columns)

    local function List(side) return side == "left" and P().leftButtons or P().rightButtons end
    local function Move(side, index, targetSide, targetIndex)
        M:NormalizeButtonSlots()
        local from, to = List(side), List(targetSide)
        if side == targetSide then
            local id = table.remove(from, index); table.insert(from, targetIndex, id)
        else
            from[index], to[targetIndex] = to[targetIndex], from[index]
        end
        M:RequestButtonUpdate(); page:Refresh()
    end
    local function SetAction(side, index, replacement)
        M:NormalizeButtonSlots()
        local list, current = List(side), List(side)[index] or "NONE"
        if replacement ~= "NONE" then
            for _, otherSide in ipairs({ "left", "right" }) do
                for otherIndex = 1, 7 do
                    if List(otherSide)[otherIndex] == replacement then List(otherSide)[otherIndex] = current end
                end
            end
        end
        list[index] = replacement
        M:RequestButtonUpdate(); page:Refresh()
    end

    card = B:AddSection(page, "elements", Text("Предпросмотр и порядок кнопок", "Preview and button order"),
        Text("Перетащи иконку в другой слот. Нажми на слот, чтобы заменить или скрыть кнопку. «Переместить» позволяет выбрать место без перетаскивания.",
            "Drag an icon to another slot. Select a slot to replace or hide its button. Use Move to choose a destination without dragging."), true)
    local editor = { Move = Move, Refresh = function() page:Refresh() end }
    local preview = Add(page, card, M:CreateSettingsBarPreview(card, P, editor))
    local inspector = W:SettingRow(card, "", 36)
    local visible = W:Button(inspector, "", function()
        local slot = editor.selection
        local id = List(slot.side)[slot.index]
        if id and id ~= "NONE" and M:GetButtonEntry(id) then
            P().hiddenButtons[id] = not P().hiddenButtons[id]
            M:RequestButtonUpdate()
            page:Refresh()
        end
    end)
    local replace
    replace = W:Button(inspector, Text("Заменить", "Replace"), function()
        local slot = editor.selection
        W:OpenChoiceMenu(replace, M:GetButtonChoices(), function() return List(slot.side)[slot.index] or "NONE" end,
            function(value) SetAction(slot.side, slot.index, value) end)
    end)
    local move
    move = W:Button(inspector, Text("Переместить", "Move"), function()
        local slot = editor.selection
        local choices, order = {}, {}
        for sideIndex, side in ipairs({ "left", "right" }) do
            local label = side == "left" and Text("Слева", "Left") or Text("Справа", "Right")
            for index = 1, 7 do
                local id = (sideIndex - 1) * 7 + index
                local entry = M:GetButtonEntry(List(side)[index])
                choices[id] = ("%s %d · %s"):format(label, index, entry and entry.label or Text("Пустой слот", "Empty slot"))
                order[id] = id
            end
        end
        local from = (slot.side == "left" and 0 or 7) + slot.index
        W:OpenChoiceMenu(move, choices, function() return from end, function(id)
            if id == from then return end
            local side = id <= 7 and "left" or "right"
            local index = (id - 1) % 7 + 1
            editor.selection = preview.slots[side][index]
            Move(slot.side, slot.index, side, index)
        end, order)
    end)
    move:SetSize(124, 26)
    move:SetPoint("RIGHT", inspector, "RIGHT")
    replace:SetSize(108, 26)
    replace:SetPoint("RIGHT", move, "LEFT", -8, 0)
    visible:SetSize(98, 26)
    visible:SetPoint("RIGHT", replace, "LEFT", -8, 0)
    inspector.label:SetPoint("RIGHT", visible, "LEFT", -10, 0)
    function inspector:Refresh()
        local slot = editor.selection
        local id = List(slot.side)[slot.index]
        local entry = M:GetButtonEntry(id)
        local side = slot.side == "left" and Text("Слева", "Left") or Text("Справа", "Right")
        self.label:SetText(("%s %d · %s"):format(side, slot.index, entry and entry.label or Text("Пустой слот", "Empty slot")))
        visible.text:SetText(id and P().hiddenButtons[id] and Text("Показать", "Show") or Text("Скрыть", "Hide"))
        visible:SetEnabled(entry ~= nil)
    end
    Add(page, card, inspector)
    Finish(page, "elements", card)

    columns = B:BeginColumns(page, "advanced")
    card = B:AddColumnSection(page, columns, "left", Text("Анимация видимости", "Hover fade"))
    local fadeDelay = Slider(page, card, Text("Задержка исчезновения", "Fade delay"), .03, 1, .01, function() return P().fadeDelay end, function(v) P().fadeDelay = v end)
    local fadeDuration = Slider(page, card, Text("Длительность fade", "Fade duration"), .03, 1, .01, function() return P().fadeDuration end, function(v) P().fadeDuration = v end)
    BindAvailable(fadeDelay, function() return P().mouseover == true end)
    BindAvailable(fadeDuration, function() return P().mouseover == true end)
    Finish(page, "advanced", card)

    card = B:AddColumnSection(page, columns, "right", Text("Точное положение", "Position offsets"), Text("Координаты относительно верхнего центра экрана.", "Offsets from the top center of the screen."))
    Slider(page, card, Text("Координата X", "X offset"), -2000, 2000, 1, function() return P().x end, function(v) P().x = v; M:ApplyPosition() end)
    Slider(page, card, Text("Координата Y", "Y offset"), -2000, 2000, 1, function() return P().y end, function(v) P().y = v; M:ApplyPosition() end)
    Add(page, card, W:ActionRow(card, Text("Перемещение мышью", "Drag bar"), Text("Разблокировать", "Unlock"), function() P().locked = false; page:Refresh() end, true))
    Finish(page, "advanced", card)
    B:FinishColumns(page, "advanced", columns)

    B:SetPageFooter(page, {
        { title = Text("Сбросить основную", "Reset game bar"), width = 148, callback = function()
            W:Confirm(Text("Сбросить настройки основной Game Bar?", "Restore the game bar defaults?"), function()
                SUI:ResetModuleProfilePreserving("gameBar", { "miniBar" })
            end)
        end },
        { title = Text("Сбросить позицию", "Reset position"), width = 132, callback = function()
            W:Confirm(Text("Сбросить положение Game Bar?", "Reset the game bar position?"), function() M:ResetPosition() end)
        end },
    })

    page.OnSelected = function()
        M.settingsOpen = true
        if M.uiInitialized then
            M:ApplyVisibilityDriver()
            M:FadeTo(P().hoverAlpha or 1)
        end
    end
    page.OnDeselected = function()
        M.settingsOpen = false
        if M.uiInitialized then
            M:ApplyVisibilityDriver()
            M:RefreshFade()
        end
    end
    return page
end

SUI:RegisterSettingsPage({ key = "gameBar", title = Text("Игровая панель", "Game bar"), group = "ПАНЕЛИ", order = 10, builder = BuildPage })
