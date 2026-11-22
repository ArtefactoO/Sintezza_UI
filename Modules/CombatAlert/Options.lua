local _, SUI = ...
local M, T, W, B, Text = SUI.CombatAlert, SUI.SettingsTheme, SUI.Widgets, SUI.SettingsBuilder, SUI.Text

local function Profile() return M:Profile() end

local visuals = {
    SWORDS = SUI.Text("Мечи", "Swords"),
    CREST = SUI.Text("Герб", "Crest"),
    SLASH = SUI.Text("Резкий взмах", "Slash"),
    BANNER = SUI.Text("Знамя", "Banner"),
    BRACKETS = SUI.Text("Скобы", "Brackets"),
    PLAQUE = SUI.Text("Плашка", "Plaque"),
}
local visualOrder = { SWORDS = 1, CREST = 2, SLASH = 3, BANNER = 4, BRACKETS = 5, PLAQUE = 6 }
local stealthVisuals = {
    EYE = SUI.Text("Прищур", "Squint"),
    CREST = visuals.CREST, SLASH = visuals.SLASH,
    TRACKS = SUI.Text("Следы", "Tracks"),
    MASK = SUI.Text("Маска", "Mask"),
    MIST = SUI.Text("Дымка", "Mist"),
}
local stealthVisualOrder = { EYE = 1, CREST = 2, SLASH = 3, TRACKS = 4, MASK = 5, MIST = 6 }

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
    local edit = W:EditBox(row, SUI.Text("По умолчанию", "Default text"), function() end)
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
    return W:Help(row, SUI.Text("Очисти поле, чтобы вернуть стандартный текст сигнала.",
        "Clear the field to restore the default alert text."))
end

local function AlertTextRow(parent, title, field)
    return SignalTextRow(parent, title,
        function() return M:GetAlertText(field) end,
        function(value) M:SetAlertText(field, value) end)
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

local modes = {
    BOTH = Text("Эффект и текст", "Effect and text"),
    TEXT = Text("Только текст", "Text only"),
    ICON = Text("Только эффект", "Effect only"),
}
local modeOrder = { BOTH = 1, TEXT = 2, ICON = 3 }
local healthStyles = { PULSE = Text("Пульс", "Pulse"), PLAQUE = visuals.PLAQUE }
local healthStyleOrder = { PULSE = 1, PLAQUE = 2 }
local aggroStyles = { THREAT = Text("Предупреждение", "Warning"), CREST = visuals.CREST, BRACKETS = visuals.BRACKETS }
local aggroStyleOrder = { THREAT = 1, CREST = 2, BRACKETS = 3 }

local function RefreshEventAlerts()
    local module = SUI:GetModule("eventAlerts")
    if module then module:OnProfileChanged() end
end

local function AddRow(page, section, row, available)
    if available then BindAvailable(row, available) end
    return B:AddRow(page, section, row)
end

local function AddSlider(page, section, label, options, key, low, high, step, available, apply, suffix)
    return AddRow(page, section, W:SliderRow(section, label, low, high, step,
        function() return options()[key] end,
        function(value)
            options()[key] = value
            if apply then apply() end
        end, suffix), available)
end

local function AddPreview(page, columns, tab, play, single)
    local section = B:AddColumnSection(page, columns, "right", Text("Предпросмотр", "Preview"),
        Text("Сигнал проиграется в выбранном положении поверх открытых окон.",
            "The alert plays at its configured position above open windows."))
    local row = CreateFrame("Frame", nil, section)
    row:SetHeight(32)
    local first = W:Button(row, single and Text("Проверить сигнал", "Preview alert") or Text("Вход", "Enter"),
        function() play(true) end, true)
    first:SetHeight(26)
    first:SetPoint("LEFT", row, "LEFT")
    if single then
        first:SetPoint("RIGHT", row, "RIGHT")
    else
        first:SetPoint("RIGHT", row, "CENTER", -4, 0)
        local last = W:Button(row, Text("Выход", "Leave"), function() play(false) end)
        last:SetHeight(26)
        last:SetPoint("LEFT", row, "CENTER", 4, 0)
        last:SetPoint("RIGHT", row, "RIGHT")
    end
    B:AddRow(page, section, row)
    B:FinishCard(page, tab, section)
end

local function AddTrigger(page, columns, description, get, set, help, available)
    local section = B:AddColumnSection(page, columns, "left", Text("Срабатывание", "Trigger"), description)
    AddRow(page, section, W:Toggle(section, Text("Включить сигнал", "Enable alert"), get, function(value)
        set(value)
        page:Refresh()
    end, help, true), available)
    return section
end

local function AddPosition(page, columns, tab, options, xKey, yKey, available, apply)
    local section = B:AddColumnSection(page, columns, "left", Text("Положение", "Position"))
    AddSlider(page, section, Text("Смещение X", "X offset"), options, xKey, -600, 600, 5, available, apply)
    AddSlider(page, section, Text("Смещение Y", "Y offset"), options, yKey, -400, 400, 5, available, apply)
    B:FinishCard(page, tab, section)
end

local function AddColors(page, columns, tab, options, entries, available, apply)
    local section = B:AddColumnSection(page, columns, "right", Text("Цвета", "Colors"))
    AddRow(page, section, W:Toggle(section, Text("Использовать цвета темы", "Use theme colors"),
        function() return options().useThemeColors ~= false end, function(value)
            options().useThemeColors = value
            if apply then apply() end
            page:Refresh()
        end), available)
    local function ManualColors()
        return (not available or available()) and options().useThemeColors == false
    end
    for _, entry in ipairs(entries) do
        local key, label = entry[1], entry[2]
        AddRow(page, section, W:ColorRow(section, label, function() return options()[key] end, function(value)
            options()[key] = value
            if apply then apply() end
        end), ManualColors)
    end
    B:FinishCard(page, tab, section)
end

local function CombatEnabled() return Profile().enabled ~= false end

local function BuildCombatTab(page)
    local tab = "combat"
    local columns = B:BeginColumns(page, tab)
    AddPreview(page, columns, tab, function(active) M:Preview(active and "enter" or "leave") end)

    local trigger = AddTrigger(page, columns, nil, CombatEnabled,
        function(value) SUI:SetFeature("combatAlert", value) end,
        Text("Общий переключатель для боя и скрытности.", "Master switch for combat and stealth alerts."))
    AddRow(page, trigger, W:Toggle(trigger, Text("Показывать вход", "Show entry"),
        function() return Profile().showEnter ~= false end,
        function(value) SUI:SetFeature("combatEnter", value) end), CombatEnabled)
    AddRow(page, trigger, W:Toggle(trigger, Text("Показывать выход", "Show exit"),
        function() return Profile().showLeave ~= false end, function(value)
            SUI:SetFeature("combatLeave", value)
            page:Refresh()
        end), CombatEnabled)
    AddSlider(page, trigger, Text("Задержка выхода", "Exit delay"), Profile, "leaveDelay", 0, .60, .05,
        function() return CombatEnabled() and Profile().showLeave ~= false end)
    B:FinishCard(page, tab, trigger)

    local function EffectsEnabled() return CombatEnabled() and Profile().style ~= "TEXT" end
    local function TextEnabled() return CombatEnabled() and Profile().style ~= "SWORDS" end

    local content = B:AddColumnSection(page, columns, "left", Text("Содержимое", "Content"))
    AddRow(page, content, W:ChoiceRow(content, Text("Режим", "Mode"), modes,
        function() return Profile().style == "SWORDS" and "ICON" or Profile().style or "BOTH" end,
        function(value)
            Profile().style = value == "ICON" and "SWORDS" or value
            page:Refresh()
        end, modeOrder), CombatEnabled)
    AddRow(page, content, W:ChoiceRow(content, Text("Вид сигнала", "Signal style"), visuals,
        function() return M:GetVisualStyle() end, function(value)
            Profile().visualStyle = value
            page:Refresh()
        end, visualOrder), EffectsEnabled)
    AddRow(page, content, AlertTextRow(content, Text("Текст входа", "Entry text"), "enterText"), TextEnabled)
    AddRow(page, content, AlertTextRow(content, Text("Текст выхода", "Exit text"), "leaveText"), TextEnabled)
    B:FinishCard(page, tab, content)
    AddPosition(page, columns, tab, Profile, "x", "y", CombatEnabled, Apply)

    local appearance = B:AddColumnSection(page, columns, "right", Text("Оформление", "Appearance"))
    AddSlider(page, appearance, Text("Размер эффекта", "Effect size"), Profile, "swordSize", 56, 148, 2, EffectsEnabled, Apply)
    AddRow(page, appearance, FontRow(appearance, "font", Apply), function() return TextEnabled() and not UsesCombatFont() end)
    AddSlider(page, appearance, Text("Размер текста", "Text size"), Profile, "fontSize", 20, 52, 1, TextEnabled, Apply)
    AddSlider(page, appearance, Text("Свечение эффекта", "Effect glow"), Profile, "glowIntensity", 0, 1, .05,
        function() return EffectsEnabled() and (M:GetVisualStyle() ~= "SWORDS" or Profile().reducedMotion ~= true) end,
        function() M:RefreshSignalColors() end)
    B:FinishCard(page, tab, appearance)
    AddColors(page, columns, tab, Profile, {
        { "enterColor", Text("Вход в бой", "Enter combat") },
        { "leaveColor", Text("Выход из боя", "Leave combat") },
    }, CombatEnabled, function() M:RefreshSignalColors() end)

    local motion = B:AddColumnSection(page, columns, "left", Text("Анимация", "Animation"))
    AddRow(page, motion, W:Toggle(motion, Text("Уменьшенная анимация", "Reduced motion"),
        function() return Profile().reducedMotion == true end, function(value)
            Profile().reducedMotion = value
            page:Refresh()
        end, Text("Настройка общая для всех четырех сигналов.", "Shared by all four alerts.")), CombatEnabled)
    local speed = AddSlider(page, motion, Text("Скорость", "Speed"), Profile, "speed", .50, 1.75, .05, CombatEnabled,
        function() M:ApplyAnimationSpeed() end)
    W:Help(speed, Text("Скорость общая для всех четырех сигналов.", "Speed is shared by all four alerts."))
    AddSlider(page, motion, Text("Разлет мечей", "Sword spread"), Profile, "swordDistance", 30, 150, 2,
        function() return EffectsEnabled() and Profile().reducedMotion ~= true and M:GetVisualStyle() == "SWORDS" end)
    B:FinishCard(page, tab, motion)
    B:FinishColumns(page, tab, columns)
end

local function BuildStealthTab(page)
    local tab = "stealth"
    local columns = B:BeginColumns(page, tab)
    AddPreview(page, columns, tab, function(active) M:PreviewStealth(active) end)

    local function Enabled() return CombatEnabled() and Profile().stealthEnabled ~= false end
    local trigger = AddTrigger(page, columns, nil, function() return Profile().stealthEnabled ~= false end,
        function(value) SUI:SetFeature("stealth", value) end,
        Text("Для скрытности нужен общий переключатель на вкладке «Бой».",
            "Stealth requires the master switch on the Combat tab."), CombatEnabled)
    AddRow(page, trigger, W:Toggle(trigger, Text("Показывать вход", "Show entry"),
        function() return Profile().showStealthEnter ~= false end,
        function(value) SUI:SetFeature("stealthEnter", value) end), Enabled)
    AddRow(page, trigger, W:Toggle(trigger, Text("Показывать выход", "Show exit"),
        function() return Profile().showStealthLeave ~= false end,
        function(value) SUI:SetFeature("stealthLeave", value) end), Enabled)
    B:FinishCard(page, tab, trigger)

    local content = B:AddColumnSection(page, columns, "left", Text("Содержимое", "Content"))
    AddRow(page, content, W:ChoiceRow(content, Text("Вид сигнала", "Signal style"), stealthVisuals,
        function() return M:GetStealthVisualStyle() end, function(value)
            Profile().stealthVisualStyle = value
            M:RefreshStealthState()
        end, stealthVisualOrder), Enabled)
    AddRow(page, content, AlertTextRow(content, Text("Текст входа", "Entry text"), "stealthEnterText"), Enabled)
    AddRow(page, content, AlertTextRow(content, Text("Текст выхода", "Exit text"), "stealthLeaveText"), Enabled)
    B:FinishCard(page, tab, content)
    AddPosition(page, columns, tab, Profile, "stealthX", "stealthY", Enabled, ApplyStealth)

    local appearance = B:AddColumnSection(page, columns, "right", Text("Оформление", "Appearance"))
    AddSlider(page, appearance, Text("Размер эффекта", "Effect size"), Profile, "stealthIconSize", 42, 88, 2, Enabled, ApplyStealth)
    AddRow(page, appearance, FontRow(appearance, "stealthFont", ApplyStealth), function() return Enabled() and not UsesCombatFont() end)
    AddSlider(page, appearance, Text("Размер текста", "Text size"), Profile, "stealthFontSize", 12, 30, 1, Enabled, ApplyStealth)
    AddSlider(page, appearance, Text("Свечение эффекта", "Effect glow"), Profile, "stealthGlowIntensity", 0, 1, .05, Enabled,
        function() M:RefreshSignalColors() end)
    B:FinishCard(page, tab, appearance)
    AddColors(page, columns, tab, Profile, {
        { "stealthEnterColor", Text("Вход в скрытность", "Enter stealth") },
        { "stealthLeaveColor", Text("Выход из скрытности", "Leave stealth") },
    }, Enabled, function() M:RefreshSignalColors() end)
    B:FinishColumns(page, tab, columns)
end

local function BuildExtraAlertTab(page, tab)
    local health = tab == "healthAlert"
    local function Options() return M:GetExtraAlertProfile(tab) end
    local columns = B:BeginColumns(page, tab)
    AddPreview(page, columns, tab, function() M:PreviewExtraAlert(tab) end, true)
    local trigger = AddTrigger(page, columns, health
        and Text("После сигнала сначала восстанови здоровье до верхнего порога.",
            "After an alert, recover to the higher threshold before it can trigger again.")
        or Text("Сигнал работает в подземельях и рейдах.", "This alert runs in dungeons and raids."),
        function() return Options().enabled == true end, function(value)
            Options().enabled = value
            if not value then M:StopExtraAlert(tab) end
            RefreshEventAlerts()
        end)
    if health then
        B:AddRow(page, trigger, W:Toggle(trigger, Text("Только в подземельях и рейдах", "Dungeons and raids only"),
            function() return Options().instanceOnly == true end, function(value)
                Options().instanceOnly = value or nil
                RefreshEventAlerts()
            end))
        B:AddRow(page, trigger, W:SliderRow(trigger, Text("Порог здоровья", "Health threshold"), 5, 90, 1,
            function() return Options().threshold end, function(value)
                local options = Options()
                options.threshold = value
                options.rearm = math.max(options.rearm, value + 1)
                RefreshEventAlerts()
                page:Refresh()
            end, "%"))
        local rearm = W:SliderRow(trigger, Text("Уровень восстановления", "Rearm at"), Options().threshold + 1, 100, 1,
            function() return Options().rearm end, function(value)
                local options = Options()
                options.rearm = math.max(value, options.threshold + 1)
                RefreshEventAlerts()
                page:Refresh()
            end, "%")
        local refresh = rearm.Refresh
        function rearm:Refresh()
            self:SetRange(Options().threshold + 1, 100)
            refresh(self)
        end
        B:AddRow(page, trigger, rearm)
    end
    B:FinishCard(page, tab, trigger)

    local function EffectsEnabled() return Options().mode ~= "TEXT" end
    local function TextEnabled() return Options().mode ~= "ICON" end

    local content = B:AddColumnSection(page, columns, "left", Text("Содержимое", "Content"))
    B:AddRow(page, content, W:ChoiceRow(content, Text("Режим", "Mode"), modes,
        function() return Options().mode end, function(value)
            Options().mode = value
            page:Refresh()
        end, modeOrder))
    AddRow(page, content, W:ChoiceRow(content, Text("Вид сигнала", "Signal style"), health and healthStyles or aggroStyles,
        function() return M:GetExtraAlertStyle(tab) end, function(value) Options().style = value end,
        health and healthStyleOrder or aggroStyleOrder), EffectsEnabled)
    AddRow(page, content, SignalTextRow(content, Text("Текст сигнала", "Alert text"),
        function() return Options().text end, function(value) M:SetExtraAlertText(tab, value) end), TextEnabled)
    B:FinishCard(page, tab, content)
    AddPosition(page, columns, tab, Options, "x", "y")

    local appearance = B:AddColumnSection(page, columns, "right", Text("Оформление", "Appearance"))
    AddSlider(page, appearance, Text("Размер эффекта", "Effect size"), Options, "size", 36, 120, 1, EffectsEnabled)
    AddSlider(page, appearance, Text("Размер текста", "Text size"), Options, "fontSize", 16, 48, 1, TextEnabled)
    B:FinishCard(page, tab, appearance)
    AddColors(page, columns, tab, Options, { { "color", Text("Цвет сигнала", "Alert color") } })
    B:FinishColumns(page, tab, columns)
end

local function BuildPage(parent)
    local page = B:CreateTabbedPage(parent, Text("Сигналы", "Alerts"), "", {
        { key = "combat", title = Text("Бой", "Combat") },
        { key = "stealth", title = Text("Скрытность", "Stealth") },
        { key = "healthAlert", title = Text("Здоровье", "Health") },
        { key = "aggroAlert", title = Text("Агро", "Aggro") },
    })
    BuildCombatTab(page)
    BuildStealthTab(page)
    BuildExtraAlertTab(page, "healthAlert")
    BuildExtraAlertTab(page, "aggroAlert")
    B:SetPageFooter(page, {{
        title = Text("Сбросить модуль", "Reset module"), width = 132,
        callback = function()
            W:Confirm(Text("Сбросить настройки всех сигналов?", "Reset all alert settings?"),
                function() SUI:ResetModuleProfile("combatAlert") end)
        end,
    }})
    page:Refresh()
    return page
end

SUI:RegisterSettingsPage({ key = "combatAlert", title = Text("Сигналы", "Alerts"), group = "ЭЛЕМЕНТЫ ИНТЕРФЕЙСА", order = 10, builder = BuildPage })
