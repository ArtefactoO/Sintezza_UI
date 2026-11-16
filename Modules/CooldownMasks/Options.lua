local _, SUI = ...
local M, E = SUI.CooldownMasks, SUI.CooldownMasks.Effects
local T, W, B = SUI.SettingsTheme, SUI.Widgets, SUI.SettingsBuilder
local Text = SUI.Text

local function Profile() return M:Profile() end

local function BindAvailable(row, id, predicate)
    return W:BindAvailability(row, function()
        local available, reason = SUI:GetFeatureAvailability(id)
        if not available then return false, reason end
        if predicate then return predicate() end
        return true
    end)
end

local function RuleColor(level)
    return level and level.color or { .10, 1, .72, .58 }
end

local function BuildPage(parent)
    local page = B:CreateTabbedPage(parent, SUI.Text("Иконки и откат", "Icons and cooldowns"), "", {
        { key = "swipe", title = SUI.Text("Откат", "Cooldowns") },
        { key = "buffs", title = SUI.Text("Условия бафов", "Buff rules") },
        { key = "procs", title = SUI.Text("Проки", "Procs") },
    })

    local swipeColumns = B:BeginColumns(page, "swipe")
    local targets = B:AddColumnSection(page, swipeColumns, "left", SUI.Text("Область действия", "Scope"))
    local function Refresh() page:Refresh() end
    local function MasksEnabled()
        return SUI:GetFeature("cooldownMasks"), SUI.Text("Включите «Исправлять форму свайпа».", "Enable “Fix swipe shape”.")
    end
    local masksEnabled = W:FeatureToggle(targets, "cooldownMasks", SUI.Text("Исправлять форму свайпа", "Fix swipe shape"), nil, nil, Refresh)
    B:AddRow(page, targets, masksEnabled)
    local actionBars = W:FeatureToggle(targets, "actionBars", SUI.Text("Панели команд EUI", "EUI action bars"), nil, MasksEnabled, Refresh)
    B:AddRow(page, targets, actionBars)
    local nativeStatus = W:SettingRow(targets, SUI.Text("Свайп EllesmereUI", "EllesmereUI swipe"))
    nativeStatus.value = W:Label(nativeStatus, "", 9, T.muted)
    nativeStatus.value:SetPoint("RIGHT", nativeStatus, "RIGHT", -8, 0)
    function nativeStatus:Refresh()
        local available, reason = SUI:GetFeatureAvailability("actionBars")
        self.label:SetText(available and SUI.Text("Свайп EllesmereUI", "EllesmereUI swipe") or "")
        self.value:SetText(reason or (M:ActionBarSwipeReady() and SUI.Text("0% • круглый слой готов", "0% · Circular swipe ready") or SUI.Text("Установите CD Swipe Opacity = 0", "Set CD Swipe Opacity to 0")))
    end
    B:AddRow(page, targets, nativeStatus)
    B:AddRow(page, targets, BindAvailable(W:ActionRow(targets, SUI.Text("После изменения в EUI", "After changing EUI"), SUI.Text("Применить", "Apply"), function()
        M:RefreshAll()
        page:Refresh()
    end, true), "actionBars"))
    local cooldownManager = W:FeatureToggle(targets, "cdm", "Cooldown Manager", nil, MasksEnabled, Refresh)
    B:AddRow(page, targets, cooldownManager)
    B:FinishCard(page, "swipe", targets)

    local appearance = B:AddColumnSection(page, swipeColumns, "right", SUI.Text("Отображение", "Display"))
    local hideSpark = W:FeatureToggle(appearance, "hideSpark", SUI.Text("Скрывать искру CDM", "Hide CDM spark"), nil, MasksEnabled, Refresh)
    B:AddRow(page, appearance, hideSpark)
    local shades = { [0.38] = SUI.Text("Светлое", "Light"), [0.55] = SUI.Text("Среднее", "Medium"), [0.72] = SUI.Text("Темное", "Dark") }
    local function ShadeValue(value, fallback)
        local alpha = tonumber(value) or fallback
        if alpha < .47 then return .38 end
        if alpha < .64 then return .55 end
        return .72
    end
    local mainShade = W:ChoiceRow(appearance, SUI.Text("Обычный откат и GCD", "Cooldown and GCD"), shades, function()
        return ShadeValue(Profile().mainSwipeAlpha, .55)
    end, function(value)
        Profile().mainSwipeAlpha = value
        M:RefreshAll()
    end)
    B:AddRow(page, appearance, mainShade)
    local chargeShade = W:ChoiceRow(appearance, SUI.Text("Перезарядка зарядов", "Charge recharge"), shades, function()
        return ShadeValue(Profile().chargeSwipeAlpha, .38)
    end, function(value)
        Profile().chargeSwipeAlpha = value
        M:RefreshAll()
    end)
    B:AddRow(page, appearance, chargeShade)
    local function ActionSwipeEnabled()
        local enabled, reason = MasksEnabled()
        if not enabled then return false, reason end
        if not SUI:GetFeature("actionBars") then return false, SUI.Text("Включите «Панели команд EUI».", "Enable “EUI action bars”.") end
        return M:ActionBarSwipeReady(), SUI.Text("В EllesmereUI установите CD Swipe Opacity = 0.", "Set CD Swipe Opacity to 0 in EllesmereUI.")
    end
    BindAvailable(mainShade, "actionBars", ActionSwipeEnabled)
    BindAvailable(chargeShade, "actionBars", ActionSwipeEnabled)
    B:FinishCard(page, "swipe", appearance)
    B:FinishColumns(page, "swipe", swipeColumns)

    local range = B:AddSection(page, "swipe", Text("Дальность", "Range"),
        Text("Для панелей с включенным Out of Range Coloring в EllesmereUI.", "Applies to bars with Out of Range Coloring enabled in EllesmereUI."))
    local function RangeEnabled()
        return SUI:GetFeature("rangeFade"), Text("Включите «Выделять иконки вне радиуса».", "Enable 'Highlight out-of-range icons'.")
    end
    local rangeFade = W:FeatureToggle(range, "rangeFade", Text("Выделять иконки вне радиуса", "Highlight out-of-range icons"), nil, nil, Refresh)
    B:AddRow(page, range, rangeFade)
    local rangeOpacity = W:SliderRow(range, Text("Непрозрачность иконки, %", "Icon opacity, %"), 10, 100, 5, function()
        return (Profile().rangeOpacity or .45) * 100
    end, function(value)
        Profile().rangeOpacity = value / 100
        M:RefreshRangeFade()
    end)
    B:AddRow(page, range, BindAvailable(rangeOpacity, "rangeFade", RangeEnabled))
    local rangeColorEnabled = W:Toggle(range, Text("Окрашивать иконки", "Tint icons"), function() return Profile().rangeColorEnabled end, function(value)
        Profile().rangeColorEnabled = value
        M:RefreshRangeFade()
        Refresh()
    end, nil, true)
    B:AddRow(page, range, BindAvailable(rangeColorEnabled, "rangeFade", RangeEnabled))
    local rangeColor = W:ColorSwatch(range, Text("Цвет иконки", "Icon color"), function() return Profile().rangeColor end, function(r, g, b)
        Profile().rangeColor = { r, g, b }
        M:RefreshRangeFade()
    end)
    function rangeColor:SetAvailable(available)
        self:SetEnabled(available)
        self:SetAlpha(available and 1 or .38)
    end
    B:AddRow(page, range, BindAvailable(rangeColor, "rangeFade", function()
        local enabled, reason = RangeEnabled()
        if not enabled then return false, reason end
        return Profile().rangeColorEnabled, Text("Включите «Окрашивать иконки».", "Enable 'Tint icons'.")
    end))
    B:FinishCard(page, "swipe", range)

    local buffState = B:AddSection(page, "buffs", SUI.Text("Условия по стакам", "Stack thresholds"), SUI.Text("До четырех порогов на баф; высокий порог перекрывает предыдущие.", "Up to four thresholds per buff. Higher thresholds take priority."))
    local buffsEnabled = W:FeatureToggle(buffState, "buffEffects", SUI.Text("Включить эффекты бафов", "Enable buff effects"), nil, nil, Refresh)
    B:AddRow(page, buffState, buffsEnabled)
    local buffScope = W:SettingRow(buffState, SUI.Text("Текущая область", "Current scope"))
    buffScope.value = W:Label(buffScope, "", 9, T.accent)
    buffScope.value:SetPoint("RIGHT", buffScope, "RIGHT", -8, 0)
    function buffScope:Refresh() self.value:SetText(E:ScopeLabel()) end
    B:AddRow(page, buffState, buffScope)
    B:FinishCard(page, "buffs", buffState)

    local buffAppearance = B:AddSection(page, "buffs", SUI.Text("Пульсация", "Pulse"), SUI.Text("Звук зависит от доступности числа стаков в Aura API; визуальные пороги работают и с secret-значениями.", "Sound needs a readable stack count. Visual effects also support hidden values."))
    local buffSpeed = W:SliderRow(buffAppearance, SUI.Text("Полный цикл, сек.", "Cycle duration, sec."), .2, 2.5, .05, function() return E:BuffRoot().speed end, function(value)
        E:BuffRoot().speed = value; E:RefreshAll()
    end)
    B:AddRow(page, buffAppearance, buffSpeed)
    local buffIntensity = W:SliderRow(buffAppearance, SUI.Text("Глубина пульсации", "Pulse intensity"), .1, 1, .05, function() return E:BuffRoot().intensity end, function(value)
        E:BuffRoot().intensity = value; E:RefreshAll()
    end)
    B:AddRow(page, buffAppearance, buffIntensity)
    local function BuffsEnabled()
        return SUI:GetFeature("buffEffects"), SUI.Text("Включите эффекты бафов.", "Enable buff effects.")
    end
    BindAvailable(buffSpeed, "buffEffects", BuffsEnabled)
    BindAvailable(buffIntensity, "buffEffects", BuffsEnabled)
    B:FinishCard(page, "buffs", buffAppearance)

    local buffTab = page.tabs.buffs
    page.buffListStart, page.buffRows = buffTab.nextY, {}
    page.buffEmpty = W:Label(buffTab.body, SUI.Text("В Cooldown Manager не выбрано ни одного бафа.", "No buffs selected in Cooldown Manager."), 10, T.muted)
    page.buffEmpty:SetPoint("TOPLEFT", buffTab.body, "TOPLEFT", 8, page.buffListStart - 8)

    local function EnsureRule(row)
        local entry = row.entry
        local rule = entry and E:GetRule(entry.cdID, false, entry)
        if not rule and entry then
            rule = E:GetRule(entry.cdID, true, entry)
            rule.enabled = false
        end
        row.rule = rule
        return rule
    end

    local function LevelFor(row, levelRow, create)
        local rule = create and EnsureRule(row) or row.rule
        if rule then E:NormalizeRule(rule) end
        return rule and rule.levels[levelRow.levelIndex], rule
    end

    local function AcquireBuffRow(index)
        local row = page.buffRows[index]
        if row then row:Show(); return row end
        row = W:Card(buffTab.body, "", "")
        row.title:Hide(); row.description:Hide(); row.levelRows = {}
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(28, 28); row.icon:SetPoint("TOPLEFT", row, "TOPLEFT", 12, -10)
        row.name = W:Label(row, "", 11, T.text)
        row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 8, -1); row.name:SetPoint("TOPRIGHT", row, "TOPRIGHT", -132, -11)
        row.state = W:Label(row, "", 9, T.muted); row.state:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -2)
        row.toggle = W:Toggle(row, SUI.Text("Активно", "Enabled"), function() return row.rule and row.rule.enabled ~= false end, function(value)
            if row.entry then E:SetRuleEnabled(row.entry, value) end; page:Refresh()
        end)
        row.toggle:SetSize(108, 28); row.toggle:SetPoint("TOPRIGHT", row, "TOPRIGHT", -7, -8)
        row.combat = W:Toggle(row, SUI.Text("Только в бою", "In combat only"), function() return row.rule and row.rule.onlyCombat == true end, function(value)
            local rule = EnsureRule(row); if not rule then return end
            rule.onlyCombat = value; E:RefreshAll(); page:Refresh()
        end)
        row.combat:SetSize(162, 27); row.combat:SetPoint("TOPLEFT", row, "TOPLEFT", 12, -43)
        row.group = W:Toggle(row, SUI.Text("Только в группе", "In a group only"), function() return row.rule and row.rule.onlyGroup == true end, function(value)
            local rule = EnsureRule(row); if not rule then return end
            rule.onlyGroup = value; E:RefreshAll(); page:Refresh()
        end)
        row.group:SetSize(168, 27); row.group:SetPoint("LEFT", row.combat, "RIGHT", 12, 0)
        row.addLevel = W:Button(row, SUI.Text("+ порог", "+ Threshold"), function()
            local rule = EnsureRule(row)
            if rule and not E:AddRuleLevel(rule) then SUI:Print(SUI.Text("Доступно не более четырех порогов.", "Up to four thresholds.")) end
            E:RefreshAll(); page:Refresh()
        end, true)
        row.addLevel:SetSize(82, 24); row.addLevel:SetPoint("TOPRIGHT", row, "TOPRIGHT", -12, -45)

        local function AcquireLevel(levelIndex)
            local line = row.levelRows[levelIndex]
            if line then line:Show(); return line end
            line = CreateFrame("Frame", nil, row, "BackdropTemplate"); line:SetHeight(38); line.levelIndex = levelIndex
            T:Backdrop(line, { T.input[1], T.input[2], T.input[3], .46 }, T.lineSoft)
            line.label = W:Label(line, SUI.Text("Порог", "Threshold"), 9, T.muted); line.label:SetPoint("LEFT", line, "LEFT", 12, 0); line.label:SetWidth(52)
            line.minus = W:Button(line, "-", function()
                local level = LevelFor(row, line, true); if not level then return end
                level.threshold = math.max(2, level.threshold - 1); E:NormalizeRule(row.rule); E:RefreshAll(); page:Refresh()
            end)
            line.minus:SetSize(22, 22); line.minus:SetPoint("LEFT", line, "LEFT", 68, 0)
            line.threshold = W:Label(line, "2", 10, T.text); line.threshold:SetPoint("LEFT", line.minus, "RIGHT", 5, 0); line.threshold:SetWidth(24); line.threshold:SetJustifyH("CENTER")
            line.plus = W:Button(line, "+", function()
                local level = LevelFor(row, line, true); if not level then return end
                level.threshold = math.min(20, level.threshold + 1); E:NormalizeRule(row.rule); E:RefreshAll(); page:Refresh()
            end)
            line.plus:SetSize(22, 22); line.plus:SetPoint("LEFT", line.threshold, "RIGHT", 5, 0)
            line.effectLabel = W:Label(line, SUI.Text("Эффект", "Effect"), 9, T.muted)
            line.effectLabel:SetPoint("LEFT", line.plus, "RIGHT", 14, 0)
            line.effectLabel:SetWidth(48)
            line.mode = W:Segmented(line, { SUI.Text("Пульс", "Pulse"), SUI.Text("Контур", "Outline"), SUI.Text("Оба", "Both") }, { "PULSE", "BORDER", "BOTH" }, function()
                local level = LevelFor(row, line); return level and level.mode or "BOTH"
            end, function(value)
                local level = LevelFor(row, line, true); if level then level.mode = value; E:RefreshAll() end
            end)
            line.mode:SetSize(174, 24); line.mode:SetPoint("LEFT", line.effectLabel, "RIGHT", 6, 0)
            line.color = W:ColorSwatch(line, SUI.Text("Цвет", "Color"), function()
                local level = LevelFor(row, line); return RuleColor(level)
            end, function(r, g, b)
                local level = LevelFor(row, line, true); if not level then return end
                local old = RuleColor(level); level.color = { r, g, b, old.a or old[4] or .58 }; E:RefreshAll()
            end)
            line.color:SetSize(92, 24); line.color:SetPoint("LEFT", line.mode, "RIGHT", 12, 0)
            line.sound = W:Toggle(line, SUI.Text("Звук", "Sound"), function()
                local level = LevelFor(row, line); return level and level.sound == true
            end, function(value)
                local level = LevelFor(row, line, true); if not level then return end
                level.sound = value; E:RefreshAll()
            end)
            line.sound:SetSize(92, 26); line.sound:SetPoint("LEFT", line.color, "RIGHT", 12, 0)
            line.preview = W:Button(line, SUI.Text("Тест", "Test"), function()
                local ok, message = row.entry and E:PreviewRule(row.entry.cdID, line.levelIndex)
                if not ok and message then SUI:Print(message) end
            end, true)
            line.preview:SetSize(54, 22); line.preview:SetPoint("LEFT", line.sound, "RIGHT", 12, 0)
            line.delete = W:Button(line, Text("Удалить", "Remove"), function()
                local _, rule = LevelFor(row, line)
                if rule then E:RemoveRuleLevel(rule, line.levelIndex); E:RefreshAll(); page:Refresh() end
            end)
            line.delete:SetSize(66, 22); line.delete:SetPoint("RIGHT", line, "RIGHT", -10, 0)
            function line:Refresh()
                local level, rule = LevelFor(row, self)
                self.label:SetText(SUI.Text("Порог ", "Threshold ") .. self.levelIndex); self.threshold:SetText(tostring(level and level.threshold or 2))
                self.mode:Refresh(); self.color:Refresh(); self.sound:Refresh()
                self.delete:SetShown(rule and #rule.levels > 1)
            end
            row.levelRows[levelIndex] = line
            return line
        end
        row.AcquireLevel = AcquireLevel
        page.buffRows[index] = row
        return row
    end

    local procColumns = B:BeginColumns(page, "procs")
    local procState = B:AddColumnSection(page, procColumns, "left", SUI.Text("Proc-подсветка", "Proc highlight"))
    local procEnabled = W:FeatureToggle(procState, "procEffects", SUI.Text("Использовать эффект Sintezza UI", "Use Sintezza UI effect"), nil, nil, Refresh)
    B:AddRow(page, procState, procEnabled)
    local procMode = W:ChoiceRow(procState, SUI.Text("Вид эффекта", "Effect style"), {
        PULSE = SUI.Text("Заливка-пульс", "Pulsing fill"), BORDER = SUI.Text("Только контур", "Outline only"), BOTH = SUI.Text("Контур + заливка", "Outline and fill"),
    }, function() return E:ProcProfile().mode end, function(value) E:ProcProfile().mode = value; E:RefreshAll() end)
    B:AddRow(page, procState, procMode)
    local procColor = W:ColorRow(procState, SUI.Text("Цвет эффекта", "Effect color"), function() return E:ProcProfile().color end, function(value)
        E:ProcProfile().color = value; E:RefreshAll()
    end)
    B:AddRow(page, procState, procColor)
    local function ProcsEnabled()
        return SUI:GetFeature("procEffects"), SUI.Text("Включите «Использовать эффект Sintezza UI».", "Enable “Use Sintezza UI effect”.")
    end
    BindAvailable(procMode, "procEffects", ProcsEnabled)
    BindAvailable(procColor, "procEffects", ProcsEnabled)
    B:FinishCard(page, "procs", procState)

    local procMotion = B:AddColumnSection(page, procColumns, "right", SUI.Text("Анимация", "Animation"), SUI.Text("Контур сохраняет форму, выбранную в EllesmereUI.", "The outline follows the EllesmereUI shape."))
    local procSpeed = W:SliderRow(procMotion, SUI.Text("Полный цикл, сек.", "Cycle duration, sec."), .2, 2.5, .05, function() return E:ProcProfile().speed end, function(value)
        E:ProcProfile().speed = value; E:RefreshAll()
    end)
    B:AddRow(page, procMotion, procSpeed)
    local procIntensity = W:SliderRow(procMotion, SUI.Text("Глубина пульсации", "Pulse intensity"), .1, 1, .05, function() return E:ProcProfile().intensity end, function(value)
        E:ProcProfile().intensity = value; E:RefreshAll()
    end)
    B:AddRow(page, procMotion, procIntensity)
    local procScale = W:SliderRow(procMotion, SUI.Text("Размер контура", "Outline size"), 1, 1.3, .01, function() return E:ProcProfile().scale end, function(value)
        E:ProcProfile().scale = value; E:RefreshAll()
    end)
    B:AddRow(page, procMotion, procScale)
    local procPreview = W:ActionRow(procMotion, SUI.Text("Предпросмотр", "Preview"), SUI.Text("Показать", "Show"), function()
        local ok, message = E:PreviewProc(); if not ok and message then SUI:Print(message) end
    end, true)
    B:AddRow(page, procMotion, procPreview)
    BindAvailable(procSpeed, "procEffects", ProcsEnabled)
    BindAvailable(procIntensity, "procEffects", ProcsEnabled)
    BindAvailable(procScale, "procEffects", ProcsEnabled)
    BindAvailable(procPreview, "procEffects", ProcsEnabled)
    B:FinishCard(page, "procs", procMotion)
    B:FinishColumns(page, "procs", procColumns)

    function page:RefreshBuffRows()
        local available, reason = SUI:GetFeatureAvailability("buffEffects")
        local entries = available and E:GetTrackedBuffs() or {}
        self.buffEmpty:SetText(reason or SUI.Text("В Cooldown Manager не выбрано ни одного бафа.", "No buffs selected in Cooldown Manager."))
        local enabledCount, y = 0, self.buffListStart
        for index, row in ipairs(self.buffRows) do row:SetShown(index <= #entries) end
        for index, entry in ipairs(entries) do
            local row = AcquireBuffRow(index)
            row.entry, row.rule = entry, E:GetRule(entry.cdID, false, entry)
            row:ClearAllPoints(); row:SetPoint("TOPLEFT", buffTab.body, "TOPLEFT", 0, y); row:SetPoint("TOPRIGHT", buffTab.body, "TOPRIGHT", 0, y)
            row.icon:SetTexture(entry.icon or 134400); row.name:SetText(entry.name or (Text("Откат ", "Cooldown ") .. tostring(entry.cdID)))
            local levels = row.rule and row.rule.levels or nil; local levelCount = levels and #levels or 1
            row.state:SetText((entry.tracked and SUI.Text("Выбран в CD Manager", "Selected in Cooldown Manager") or SUI.Text("Сейчас не отслеживается", "Not currently tracked")) .. "  •  ID " .. tostring(entry.spellID or "—") .. SUI.Text("  •  порогов: ", "  · Thresholds: ") .. levelCount)
            local stateColor = entry.tracked and T.muted or T.danger; row.state:SetTextColor(stateColor[1], stateColor[2], stateColor[3], 1)
            row.toggle:Refresh(); row.combat:Refresh(); row.group:Refresh()
            for levelIndex, levelRow in ipairs(row.levelRows) do levelRow:SetShown(levelIndex <= levelCount) end
            for levelIndex = 1, levelCount do
                local levelRow = row.AcquireLevel(levelIndex); levelRow.levelIndex = levelIndex; levelRow:ClearAllPoints()
                local levelY = -76 - (levelIndex - 1) * 42
                levelRow:SetPoint("TOPLEFT", row, "TOPLEFT", 0, levelY); levelRow:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, levelY); levelRow:Refresh()
            end
            local rowHeight = 84 + levelCount * 42; row:SetHeight(rowHeight)
            if row.rule and row.rule.enabled ~= false then enabledCount = enabledCount + 1 end
            y = y - rowHeight - 6
        end
        self.buffEmpty:SetShown(#entries == 0)
        buffTab.body:SetHeight(math.max(buffTab.scroll:GetHeight(), -y + 2))
        SUI:After(0, M, "settings scroll", function() if buffTab.scroll.RefreshRange then buffTab.scroll:RefreshRange() end end)
        buffScope:Refresh()
    end

    page.OnRefresh = function(self) self:RefreshBuffRows() end
    B:SetPageFooter(page, {
        { title = SUI.Text("Сбросить модуль", "Reset module"), width = 132, callback = function()
            W:Confirm(SUI.Text("Сбросить настройки иконок и отката?", "Reset icon and cooldown settings?"), function() SUI:ResetModuleProfile("cooldownMasks") end)
        end },
    })
    page:Refresh()
    return page
end

SUI:RegisterSettingsPage({ key = "cooldownMasks", title = SUI.Text("Иконки и откат", "Icons and cooldowns"), group = "ЭЛЕМЕНТЫ ИНТЕРФЕЙСА", order = 30, builder = BuildPage })
