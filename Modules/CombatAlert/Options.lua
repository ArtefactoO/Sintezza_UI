local _, SUI = ...
local M, T, W, B = SUI.CombatAlert, SUI.SettingsTheme, SUI.Widgets, SUI.SettingsBuilder

local function Profile() return M:Profile() end

local visuals = {
    SWORDS = SUI.Text("Мечи", "Swords"),
    SEAL = SUI.Text("Рунная печать", "Runic seal"),
    CREST = SUI.Text("Герб", "Crest"),
    EMBERS = SUI.Text("Искры", "Embers"),
    SLASH = SUI.Text("Резкий взмах", "Slash"),
    BANNER = SUI.Text("Знамя", "Banner"),
    BRACKETS = SUI.Text("Скобы", "Brackets"),
    FISSURE = SUI.Text("Трещина", "Fissure"),
    PLAQUE = SUI.Text("Плашка", "Plaque"),
}
local visualOrder = { SWORDS = 1, SEAL = 2, CREST = 3, EMBERS = 4, SLASH = 5, BANNER = 6, BRACKETS = 7, FISSURE = 8, PLAQUE = 9 }
local stealthVisuals = {
    EYE = SUI.Text("Глаз", "Eye"),
    SEAL = visuals.SEAL, CREST = visuals.CREST, EMBERS = visuals.EMBERS, SLASH = visuals.SLASH,
    TRACKS = SUI.Text("Следы", "Tracks"),
    MASK = SUI.Text("Маска", "Mask"),
    MIST = SUI.Text("Дымка", "Mist"),
}
local stealthVisualOrder = { EYE = 1, SEAL = 2, CREST = 3, EMBERS = 4, SLASH = 5, TRACKS = 6, MASK = 7, MIST = 8 }

local function BindAvailable(row, predicate)
    local refresh = row.Refresh
    function row:Refresh(...)
        if refresh then refresh(self, ...) end
        self:SetAvailable(predicate())
    end
    row:Refresh()
    return row
end

local function SignalTextRow(parent, title, getText, setText)
    local row = W:SettingRow(parent, title, 34)
    local edit = W:EditBox(row, SUI.Text("Пустое поле вернет исходный текст", "Clear to restore the default"), function() end)
    edit:SetHeight(28)
    edit:SetPoint("LEFT", row, "CENTER", -8, 0)
    edit:SetPoint("RIGHT", row, "RIGHT", -8, 0)
    row.label:ClearAllPoints()
    row.label:SetPoint("LEFT", row, "LEFT", 0, 0)
    row.label:SetPoint("RIGHT", edit, "LEFT", -10, 0)
    if edit.SetMaxLetters then edit:SetMaxLetters(48) end

    local available = true
    edit:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    edit:SetScript("OnEscapePressed", function(self)
        self:SetText(getText())
        self:ClearFocus()
    end)
    edit:HookScript("OnEditFocusLost", function(self)
        if available then setText(self:GetText()) end
        self:SetText(getText())
    end)
    edit:HookScript("OnHide", function(self)
        if self:HasFocus() then self:ClearFocus() end
    end)
    function row:Refresh()
        if not edit:HasFocus() then edit:SetText(getText()) end
    end
    function row:SetAvailable(value)
        available = value
        self:SetAlpha(value and 1 or .40)
        edit.skipSettingsFocus = not value
        if not value and edit:HasFocus() then edit:ClearFocus() end
        edit:EnableMouse(value)
    end
    return row
end

local function AlertTextRow(parent, title, field)
    return SignalTextRow(parent, title,
        function() return M:GetAlertText(field) end,
        function(value) M:SetAlertText(field, value) end)
end

local function ThemeColorRow(parent, page)
    return W:Toggle(parent, SUI.Text("Использовать цвета темы", "Use theme colors"),
        function() return Profile().useThemeColors ~= false end, function(value)
            Profile().useThemeColors = value
            M:RefreshSignalColors()
            page:Refresh()
        end)
end

local function Apply()
    M:ApplyAppearance()
end

local function ApplyStealth()
    M:ApplyStealthAppearance()
end

local FONT_ORDER = { INTERFACE = 1, DEFAULT = 2, COMBAT = 3 }
local function UsesCombatFont()
    local module = SUI:GetModule("combatFont")
    return module and module.alertPath ~= nil
end

local function FontRow(card, key, apply)
    return W:ChoiceRow(card, SUI.Text("Шрифт текста", "Text font"), function() return T:TextFontChoices(true) end,
        function() return UsesCombatFont() and "COMBAT" or Profile()[key] end, function(value)
            Profile()[key] = value
            apply()
        end, FONT_ORDER)
end

local extraModes = {
    BOTH = SUI.Text("Эффект и текст", "Effect and text"),
    TEXT = SUI.Text("Только текст", "Text only"),
    ICON = SUI.Text("Только эффект", "Effect only"),
}
local extraModeOrder = { BOTH = 1, TEXT = 2, ICON = 3 }
local healthStyles = { PULSE = SUI.Text("Пульс", "Pulse"), FISSURE = visuals.FISSURE, PLAQUE = visuals.PLAQUE }
local healthStyleOrder = { PULSE = 1, FISSURE = 2, PLAQUE = 3 }
local aggroStyles = { THREAT = SUI.Text("Предупреждение", "Warning"), CREST = visuals.CREST, BRACKETS = visuals.BRACKETS }
local aggroStyleOrder = { THREAT = 1, CREST = 2, BRACKETS = 3 }

local function RefreshEventAlerts()
    local module = SUI:GetModule("eventAlerts")
    if module then module:OnProfileChanged() end
end

local function BuildExtraAlertTab(page, kind)
    local health = kind == "healthAlert"
    local function Options() return M:GetExtraAlertProfile(kind) end
    local state = B:AddSection(page, kind, SUI.Text("Срабатывание", "Trigger"),
        health and SUI.Text("После сигнала сначала восстанови здоровье до верхнего порога.",
            "After an alert, recover to the higher threshold before it can trigger again.")
        or SUI.Text("Сигнал работает в подземельях и рейдах.", "This alert runs in dungeons and raids."))
    local enable = W:Toggle(state, SUI.Text("Включить сигнал", "Enable alert"),
        function() return Options().enabled == true end, function(value)
            Options().enabled = value
            if not value then M:StopExtraAlert(kind) end
            RefreshEventAlerts()
            page:Refresh()
        end, nil, true)
    B:AddRow(page, state, enable)
    if health then
        local threshold = W:SliderRow(state, SUI.Text("Порог здоровья", "Health threshold"), 5, 90, 1,
            function() return Options().threshold end, function(value)
                local options = Options()
                options.threshold = value
                options.rearm = math.max(options.rearm, value + 1)
                RefreshEventAlerts()
                page:Refresh()
            end, "%")
        B:AddRow(page, state, threshold)
        local rearm = W:SliderRow(state, SUI.Text("Уровень восстановления", "Rearm at"), 6, 100, 1,
            function() return Options().rearm end, function(value)
                local options = Options()
                options.rearm = math.max(value, options.threshold + 1)
                RefreshEventAlerts()
                page:Refresh()
            end, "%")
        B:AddRow(page, state, rearm)
    end
    B:FinishCard(page, kind, state)

    local content = B:AddSection(page, kind, SUI.Text("Содержимое", "Content"))
    local mode = W:ChoiceRow(content, SUI.Text("Режим", "Mode"), extraModes,
        function() return Options().mode end, function(value) Options().mode = value; page:Refresh() end, extraModeOrder)
    B:AddRow(page, content, mode)
    local visual = W:ChoiceRow(content, SUI.Text("Вид сигнала", "Signal style"), health and healthStyles or aggroStyles,
        function() return M:GetExtraAlertStyle(kind) end, function(value) Options().style = value end,
        health and healthStyleOrder or aggroStyleOrder)
    B:AddRow(page, content, visual)
    BindAvailable(visual, function() return Options().mode ~= "TEXT" end)
    local caption = SignalTextRow(content, SUI.Text("Текст сигнала", "Alert text"),
        function() return Options().text end, function(value) M:SetExtraAlertText(kind, value) end)
    B:AddRow(page, content, caption)
    BindAvailable(caption, function() return Options().mode ~= "ICON" end)
    local sample = CreateFrame("Frame", nil, content)
    sample:SetHeight(32)
    local button = W:Button(sample, SUI.Text("Проверить сигнал", "Preview alert"), function() M:PreviewExtraAlert(kind) end, true)
    button:SetSize(163, 26)
    button:SetPoint("LEFT")
    B:AddRow(page, content, sample)
    B:FinishCard(page, kind, content)

    local columns = B:BeginColumns(page, kind)
    local visual = B:AddColumnSection(page, columns, "left", SUI.Text("Размер и цвета", "Size and colors"))
    local placement = B:AddColumnSection(page, columns, "right", SUI.Text("Положение", "Position"))
    local function Slider(section, title, key, low, high, step)
        return B:AddRow(page, section, W:SliderRow(section, title, low, high, step,
            function() return Options()[key] end, function(value) Options()[key] = value end))
    end
    local iconSize = Slider(visual, SUI.Text("Размер эффекта", "Effect size"), "size", 36, 120, 1)
    local fontSize = Slider(visual, SUI.Text("Размер текста", "Text size"), "fontSize", 16, 48, 1)
    BindAvailable(iconSize, function() return Options().mode ~= "TEXT" end)
    BindAvailable(fontSize, function() return Options().mode ~= "ICON" end)
    local themeColors = W:Toggle(visual, SUI.Text("Использовать цвета темы", "Use theme colors"),
        function() return Options().useThemeColors ~= false end,
        function(value) Options().useThemeColors = value; page:Refresh() end)
    B:AddRow(page, visual, themeColors)
    local color = W:ColorRow(visual, SUI.Text("Цвет сигнала", "Alert color"),
        function() return Options().color end, function(value) Options().color = value end)
    B:AddRow(page, visual, color)
    BindAvailable(color, function() return Options().useThemeColors == false end)
    Slider(placement, SUI.Text("Смещение X", "X offset"), "x", -600, 600, 5)
    Slider(placement, SUI.Text("Смещение Y", "Y offset"), "y", -400, 400, 5)
    B:FinishCard(page, kind, visual)
    B:FinishCard(page, kind, placement)
    B:FinishColumns(page, kind, columns)
end

local function BuildPage(parent)
    local page = B:CreateTabbedPage(parent, SUI.Text("Сигнал боя", "Combat alert"),
        "", {
            { key = "combat", title = SUI.Text("Бой", "Combat") },
            { key = "stealth", title = SUI.Text("Скрытность", "Stealth") },
            { key = "healthAlert", title = SUI.Text("Здоровье", "Health") },
            { key = "aggroAlert", title = SUI.Text("Агро", "Aggro") },
        })

    local state = B:AddSection(page, "combat", SUI.Text("Состояние", "Status"))
    local enabled = W:Toggle(state, SUI.Text("Включить сигнал боя", "Enable combat alert"), function() return Profile().enabled ~= false end, function(value)
        SUI:SetFeature("combatAlert", value)
        page:Refresh()
    end)
    B:AddRow(page, state, enabled)
    local enter = W:Toggle(state, SUI.Text("Показывать вход в бой", "Show entering combat"), function() return Profile().showEnter ~= false end, function(value)
        SUI:SetFeature("combatEnter", value)
    end)
    B:AddRow(page, state, enter)
    local leave = W:Toggle(state, SUI.Text("Показывать окончание боя", "Show leaving combat"), function() return Profile().showLeave ~= false end, function(value)
        SUI:SetFeature("combatLeave", value)
        page:Refresh()
    end)
    B:AddRow(page, state, leave)
    local reduced = W:Toggle(state, SUI.Text("Уменьшенная анимация", "Reduced motion"), function() return Profile().reducedMotion == true end, function(value)
        Profile().reducedMotion = value
        page:Refresh()
    end)
    B:AddRow(page, state, reduced)
    BindAvailable(enter, function() return Profile().enabled ~= false end)
    BindAvailable(leave, function() return Profile().enabled ~= false end)
    BindAvailable(reduced, function() return Profile().enabled ~= false end)
    B:FinishCard(page, "combat", state)

    local content = B:AddSection(page, "combat", SUI.Text("Содержимое", "Content"))
    local style = W:ChoiceRow(content, SUI.Text("Режим", "Mode"), {
        BOTH = SUI.Text("Эффект и текст", "Effect and text"),
        TEXT = SUI.Text("Только текст", "Text only"),
        SWORDS = SUI.Text("Только эффект", "Effect only"),
    }, function() return Profile().style or "BOTH" end, function(value)
        Profile().style = value
        page:Refresh()
    end)
    B:AddRow(page, content, style)
    local visual = W:ChoiceRow(content, SUI.Text("Вид сигнала", "Signal style"), visuals, function()
        return M:GetVisualStyle()
    end, function(value)
        Profile().visualStyle = value
        page:Refresh()
    end, visualOrder)
    B:AddRow(page, content, visual)
    BindAvailable(visual, function()
        return Profile().enabled ~= false and Profile().style ~= "TEXT"
    end)
    local enterText = AlertTextRow(content, SUI.Text("Текст входа", "Entry text"), "enterText")
    B:AddRow(page, content, enterText)
    local leaveText = AlertTextRow(content, SUI.Text("Текст выхода", "Exit text"), "leaveText")
    B:AddRow(page, content, leaveText)
    BindAvailable(style, function() return Profile().enabled ~= false end)
    BindAvailable(enterText, function() return Profile().enabled ~= false and Profile().style ~= "SWORDS" end)
    BindAvailable(leaveText, function() return Profile().enabled ~= false and Profile().style ~= "SWORDS" end)
    B:FinishCard(page, "combat", content)

    local preview = B:AddSection(page, "combat", SUI.Text("Предпросмотр", "Preview"))
    local previewRow = CreateFrame("Frame", nil, preview)
    previewRow:SetHeight(32)
    local previewEnter = W:Button(previewRow, SUI.Text("В БОЙ", "IN COMBAT"), function() M:Preview("enter") end, true)
    previewEnter:SetSize(132, 26)
    previewEnter:SetPoint("LEFT")
    local previewLeave = W:Button(previewRow, SUI.Text("БОЙ ОКОНЧЕН", "COMBAT ENDED"), function() M:Preview("leave") end)
    previewLeave:SetSize(154, 26)
    previewLeave:SetPoint("LEFT", previewEnter, "RIGHT", 8, 0)
    B:AddRow(page, preview, previewRow)
    B:FinishCard(page, "combat", preview)

    local stealthState = B:AddSection(page, "stealth", SUI.Text("Состояние", "Status"))
    local stealthEnabled = W:Toggle(stealthState, SUI.Text("Сигнал скрытности", "Stealth alert"), function() return Profile().stealthEnabled ~= false end, function(value)
        SUI:SetFeature("stealth", value)
        page:Refresh()
    end)
    B:AddRow(page, stealthState, stealthEnabled)
    local stealthEnter = W:Toggle(stealthState, SUI.Text("Показывать вход", "Show entering stealth"), function() return Profile().showStealthEnter ~= false end, function(value)
        SUI:SetFeature("stealthEnter", value)
    end)
    B:AddRow(page, stealthState, stealthEnter)
    local stealthLeave = W:Toggle(stealthState, SUI.Text("Показывать выход", "Show leaving stealth"), function() return Profile().showStealthLeave ~= false end, function(value)
        SUI:SetFeature("stealthLeave", value)
    end)
    B:AddRow(page, stealthState, stealthLeave)
    local stealthVisualStyle = W:ChoiceRow(stealthState, SUI.Text("Вид сигнала", "Signal style"), stealthVisuals, function()
        return M:GetStealthVisualStyle()
    end, function(value)
        Profile().stealthVisualStyle = value
    end, stealthVisualOrder)
    B:AddRow(page, stealthState, stealthVisualStyle)
    BindAvailable(stealthEnabled, function() return Profile().enabled ~= false end)
    BindAvailable(stealthEnter, function() return Profile().enabled ~= false and Profile().stealthEnabled ~= false end)
    BindAvailable(stealthLeave, function() return Profile().enabled ~= false and Profile().stealthEnabled ~= false end)
    BindAvailable(stealthVisualStyle, function() return Profile().enabled ~= false and Profile().stealthEnabled ~= false end)
    B:FinishCard(page, "stealth", stealthState)

    local stealthContent = B:AddSection(page, "stealth", SUI.Text("Текст", "Text"), SUI.Text("Текст виден во время скрытности.", "Text remains visible while stealthed."))
    local stealthEnterText = AlertTextRow(stealthContent, SUI.Text("Текст входа", "Entry text"), "stealthEnterText")
    B:AddRow(page, stealthContent, stealthEnterText)
    local stealthLeaveText = AlertTextRow(stealthContent, SUI.Text("Текст выхода", "Exit text"), "stealthLeaveText")
    B:AddRow(page, stealthContent, stealthLeaveText)
    BindAvailable(stealthEnterText, function() return Profile().enabled ~= false and Profile().stealthEnabled ~= false end)
    BindAvailable(stealthLeaveText, function() return Profile().enabled ~= false and Profile().stealthEnabled ~= false end)
    B:FinishCard(page, "stealth", stealthContent)

    local stealthPreview = B:AddSection(page, "stealth", SUI.Text("Предпросмотр", "Preview"))
    local stealthPreviewRow = CreateFrame("Frame", nil, stealthPreview)
    stealthPreviewRow:SetHeight(32)
    local previewStealthEnter = W:Button(stealthPreviewRow, SUI.Text("СКРЫТНОСТЬ", "STEALTH"), function() M:PreviewStealth(true) end, true)
    previewStealthEnter:SetSize(144, 26)
    previewStealthEnter:SetPoint("LEFT")
    local previewStealthLeave = W:Button(stealthPreviewRow, SUI.Text("СКРЫТНОСТЬ СНЯТА", "STEALTH ENDED"), function() M:PreviewStealth(false) end)
    previewStealthLeave:SetSize(176, 26)
    previewStealthLeave:SetPoint("LEFT", previewStealthEnter, "RIGHT", 8, 0)
    B:AddRow(page, stealthPreview, stealthPreviewRow)
    B:FinishCard(page, "stealth", stealthPreview)

    local stealthColumns = B:BeginColumns(page, "stealth")
    local stealthVisual = B:AddColumnSection(page, stealthColumns, "left", SUI.Text("Размер и свечение", "Size and glow"))
    local stealthFont = B:AddRow(page, stealthVisual, FontRow(stealthVisual, "stealthFont", ApplyStealth))
    local stealthFontSize = W:SliderRow(stealthVisual, SUI.Text("Размер текста", "Text size"), 12, 30, 1, function() return Profile().stealthFontSize or 19 end, function(value)
        Profile().stealthFontSize = value; ApplyStealth()
    end)
    B:AddRow(page, stealthVisual, stealthFontSize)
    local stealthIconSize = W:SliderRow(stealthVisual, SUI.Text("Размер знака", "Symbol size"), 42, 88, 2, function() return Profile().stealthIconSize or 58 end, function(value)
        Profile().stealthIconSize = value; ApplyStealth()
    end)
    B:AddRow(page, stealthVisual, stealthIconSize)
    local stealthGlow = W:SliderRow(stealthVisual, SUI.Text("Свечение", "Glow"), 0, 1, .05, function() return Profile().stealthGlowIntensity or .42 end, function(value)
        Profile().stealthGlowIntensity = value
        M:RefreshSignalColors()
    end)
    B:AddRow(page, stealthVisual, stealthGlow)
    BindAvailable(stealthFontSize, function() return Profile().enabled ~= false and Profile().stealthEnabled ~= false end)
    BindAvailable(stealthFont, function()
        return not UsesCombatFont() and Profile().enabled ~= false and Profile().stealthEnabled ~= false
    end)
    BindAvailable(stealthIconSize, function() return Profile().enabled ~= false and Profile().stealthEnabled ~= false end)
    BindAvailable(stealthGlow, function() return Profile().enabled ~= false and Profile().stealthEnabled ~= false end)
    B:FinishCard(page, "stealth", stealthVisual)

    local stealthPosition = B:AddColumnSection(page, stealthColumns, "right", SUI.Text("Положение", "Position"))
    local stealthX = W:SliderRow(stealthPosition, SUI.Text("Смещение X", "X offset"), -600, 600, 5, function() return Profile().stealthX or 0 end, function(value)
        Profile().stealthX = value; ApplyStealth()
    end)
    B:AddRow(page, stealthPosition, stealthX)
    local stealthY = W:SliderRow(stealthPosition, SUI.Text("Смещение Y", "Y offset"), -400, 400, 5, function() return Profile().stealthY or 35 end, function(value)
        Profile().stealthY = value; ApplyStealth()
    end)
    B:AddRow(page, stealthPosition, stealthY)
    BindAvailable(stealthX, function() return Profile().enabled ~= false and Profile().stealthEnabled ~= false end)
    BindAvailable(stealthY, function() return Profile().enabled ~= false and Profile().stealthEnabled ~= false end)
    B:FinishCard(page, "stealth", stealthPosition)
    B:FinishColumns(page, "stealth", stealthColumns)

    local stealthColors = B:AddSection(page, "stealth", SUI.Text("Цвета", "Colors"))
    local stealthThemeColors = B:AddRow(page, stealthColors, ThemeColorRow(stealthColors, page))
    BindAvailable(stealthThemeColors, function() return Profile().enabled ~= false and Profile().stealthEnabled ~= false end)
    local stealthEnterColor = W:ColorRow(stealthColors, SUI.Text("Вход в скрытность", "Entering stealth"), function() return Profile().stealthEnterColor end, function(value)
        Profile().stealthEnterColor = value
        M:RefreshSignalColors()
    end)
    B:AddRow(page, stealthColors, stealthEnterColor)
    local stealthLeaveColor = W:ColorRow(stealthColors, SUI.Text("Выход из скрытности", "Leaving stealth"), function() return Profile().stealthLeaveColor end, function(value)
        Profile().stealthLeaveColor = value
        M:RefreshSignalColors()
    end)
    B:AddRow(page, stealthColors, stealthLeaveColor)
    local function StealthManualColors()
        local profile = Profile()
        return profile.enabled ~= false and profile.stealthEnabled ~= false and profile.useThemeColors == false
    end
    BindAvailable(stealthEnterColor, StealthManualColors)
    BindAvailable(stealthLeaveColor, StealthManualColors)
    B:FinishCard(page, "stealth", stealthColors)
    local motionColumns = B:BeginColumns(page, "combat")
    local motion = B:AddColumnSection(page, motionColumns, "left", SUI.Text("Движение", "Motion"))
    local speed = W:SliderRow(motion, SUI.Text("Скорость", "Speed"), .50, 1.75, .05, function() return Profile().speed or 1 end, function(value)
        Profile().speed = value; Apply()
    end)
    B:AddRow(page, motion, speed)
    local swordSize = W:SliderRow(motion, SUI.Text("Размер эффекта", "Effect size"), 56, 148, 2, function() return Profile().swordSize or 94 end, function(value)
        Profile().swordSize = value; Apply()
    end)
    B:AddRow(page, motion, swordSize)
    local distance = W:SliderRow(motion, SUI.Text("Разлет мечей", "Sword spread"), 30, 150, 2, function() return Profile().swordDistance or 84 end, function(value)
        Profile().swordDistance = value
    end)
    B:AddRow(page, motion, distance)
    local glow = W:SliderRow(motion, SUI.Text("Свечение эффекта", "Effect glow"), 0, 1, .05, function() return Profile().glowIntensity or .72 end, function(value)
        Profile().glowIntensity = value
        M:RefreshSignalColors()
    end)
    B:AddRow(page, motion, glow)
    BindAvailable(speed, function() return Profile().enabled ~= false end)
    BindAvailable(swordSize, function() return Profile().enabled ~= false and Profile().style ~= "TEXT" end)
    BindAvailable(distance, function()
        return Profile().enabled ~= false and Profile().style ~= "TEXT" and Profile().reducedMotion ~= true
            and M:GetVisualStyle() == "SWORDS"
    end)
    BindAvailable(glow, function()
        return Profile().enabled ~= false and Profile().style ~= "TEXT"
            and (M:GetVisualStyle() ~= "SWORDS" or Profile().reducedMotion ~= true)
    end)
    B:FinishCard(page, "combat", motion)

    local geometry = B:AddColumnSection(page, motionColumns, "right", SUI.Text("Текст и положение", "Text and position"))
    local combatFont = B:AddRow(page, geometry, FontRow(geometry, "font", Apply))
    local fontSize = W:SliderRow(geometry, SUI.Text("Размер текста", "Text size"), 20, 52, 1, function() return Profile().fontSize or 32 end, function(value)
        Profile().fontSize = value; Apply()
    end)
    B:AddRow(page, geometry, fontSize)
    local offsetX = W:SliderRow(geometry, SUI.Text("Смещение X", "X offset"), -600, 600, 5, function() return Profile().x or 0 end, function(value)
        Profile().x = value; Apply()
    end)
    B:AddRow(page, geometry, offsetX)
    local offsetY = W:SliderRow(geometry, SUI.Text("Смещение Y", "Y offset"), -400, 400, 5, function() return Profile().y or 115 end, function(value)
        Profile().y = value; Apply()
    end)
    B:AddRow(page, geometry, offsetY)
    local leaveDelay = W:SliderRow(geometry, SUI.Text("Задержка выхода", "Exit delay"), 0, .60, .05, function() return Profile().leaveDelay or .20 end, function(value)
        Profile().leaveDelay = value
    end)
    B:AddRow(page, geometry, leaveDelay)
    BindAvailable(fontSize, function() return Profile().enabled ~= false and Profile().style ~= "SWORDS" end)
    BindAvailable(combatFont, function()
        return not UsesCombatFont() and Profile().enabled ~= false and Profile().style ~= "SWORDS"
    end)
    BindAvailable(offsetX, function() return Profile().enabled ~= false end)
    BindAvailable(offsetY, function() return Profile().enabled ~= false end)
    BindAvailable(leaveDelay, function() return Profile().enabled ~= false and Profile().showLeave ~= false end)
    B:FinishCard(page, "combat", geometry)
    B:FinishColumns(page, "combat", motionColumns)

    local colors = B:AddSection(page, "combat", SUI.Text("Цвета", "Colors"))
    local themeColors = B:AddRow(page, colors, ThemeColorRow(colors, page))
    BindAvailable(themeColors, function() return Profile().enabled ~= false end)
    local enterColor = W:ColorRow(colors, SUI.Text("Вход в бой", "Enter combat"), function() return Profile().enterColor end, function(value)
        Profile().enterColor = value
        M:RefreshSignalColors()
    end)
    B:AddRow(page, colors, enterColor)
    local leaveColor = W:ColorRow(colors, SUI.Text("Окончание боя", "Leave combat"), function() return Profile().leaveColor end, function(value)
        Profile().leaveColor = value
        M:RefreshSignalColors()
    end)
    B:AddRow(page, colors, leaveColor)
    local function CombatManualColors()
        return Profile().enabled ~= false and Profile().useThemeColors == false
    end
    BindAvailable(enterColor, CombatManualColors)
    BindAvailable(leaveColor, CombatManualColors)
    B:FinishCard(page, "combat", colors)

    BuildExtraAlertTab(page, "healthAlert")
    BuildExtraAlertTab(page, "aggroAlert")
    B:SetPageFooter(page, {{
        title = SUI.Text("Сбросить модуль", "Reset module"), width = 132,
        callback = function()
            W:Confirm(SUI.Text("Сбросить настройки сигнала боя?", "Reset combat alert settings?"), function() SUI:ResetModuleProfile("combatAlert") end)
        end,
    }})
    page:Refresh()
    return page
end

SUI:RegisterSettingsPage({ key = "combatAlert", title = SUI.Text("Сигнал боя", "Combat alert"), group = "ЭЛЕМЕНТЫ ИНТЕРФЕЙСА", order = 10, builder = BuildPage })
