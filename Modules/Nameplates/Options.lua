local _, SUI = ...
local Text = SUI.Text
local M = SUI.Nameplates
local T, W, B = SUI.SettingsTheme, SUI.Widgets, SUI.SettingsBuilder

local function Profile() return M:Profile() end
local function RuleProfile() return M.AuraRules:Profile() end

local function SpellInfo(spellID)
    local name, icon
    if C_Spell and C_Spell.GetSpellName then name = C_Spell.GetSpellName(spellID) end
    if C_Spell and C_Spell.GetSpellTexture then icon = C_Spell.GetSpellTexture(spellID) end
    if not name and GetSpellInfo then name, _, icon = GetSpellInfo(spellID) end
    return name or Text("Заклинание %s", "Spell %s"):format(tostring(spellID)), icon or 134400
end

local function BuildPage(parent)
    local page = B:CreateTabbedPage(parent, Text("Неймплейты", "Nameplates"), nil, {
        { key = "main", title = Text("Основное", "General") },
        { key = "text", title = Text("Текст", "Text") },
        { key = "auras", title = Text("Правила аур", "Aura rules") },
    })
    local preview = M:CreateSettingsPreview(page.canvas)
    B:SetPinnedFrame(page, preview)

    local settings = B:AddSection(page, "main", Text("Модуль", "Module"))
    B:AddRow(page, settings, W:FeatureToggle(settings, "nameplates",
        Text("Включить дополнения к неймплейтам", "Enable nameplate extensions"), nil, nil, function() page:Refresh() end))
    B:FinishCard(page, "main", settings)

    local columns = B:BeginColumns(page, "main")
    local threat = B:AddColumnSection(page, columns, "left", Text("Агро в открытом мире", "Open-world threat"))
    local enabled = W:Toggle(threat, Text("Показывать агро", "Show threat"), function() return Profile().openWorldThreat end, function(value)
        Profile().openWorldThreat = value; M:RefreshAll(false); page:Refresh()
    end)
    B:AddRow(page, threat, enabled)
    local near = W:Toggle(threat, Text("Предупреждать о близком агро", "Warn when close to pulling"), function() return Profile().nearThreat end, function(value)
        Profile().nearThreat = value; M:RefreshAll(false); page:Refresh()
    end)
    B:AddRow(page, threat, near)
    local borderEnabled = W:Toggle(threat, Text("Красить рамку", "Color the border"), function()
        return Profile().threatBorderEnabled ~= false
    end, function(value)
        Profile().threatBorderEnabled = value; M:RefreshAll(false); page:Refresh()
    end)
    B:AddRow(page, threat, borderEnabled)
    local borderThickness = W:SliderRow(threat, Text("Толщина рамки агро", "Threat border thickness"),
        M.THREAT_BORDER_MIN, M.THREAT_BORDER_MAX, 1,
        function() return M:GetThreatBorderThickness() end,
        function(value)
            Profile().threatBorderThickness = value
            M:RefreshThreatBorders()
            preview:Refresh()
        end)
    B:AddRow(page, threat, borderThickness)
    local fillEnabled = W:Toggle(threat, Text("Красить панель HP", "Color the health bar"), function()
        return Profile().threatFillEnabled == true
    end, function(value)
        Profile().threatFillEnabled = value; M:RefreshAll(false); page:Refresh()
    end)
    B:AddRow(page, threat, fillEnabled)
    local aggroColor = W:ColorRow(threat, Text("Рамка: агро", "Border: aggro"), function() return Profile().aggroColor end, function(value)
        Profile().aggroColor = { r = value[1], g = value[2], b = value[3] }; M:RefreshAll(false); preview:Refresh()
    end)
    B:AddRow(page, threat, aggroColor)
    local nearColor = W:ColorRow(threat, Text("Рамка: близкое агро", "Border: near aggro"), function() return Profile().nearColor end, function(value)
        Profile().nearColor = { r = value[1], g = value[2], b = value[3] }; M:RefreshAll(false); preview:Refresh()
    end)
    B:AddRow(page, threat, nearColor)
    local aggroFillColor = W:ColorRow(threat, Text("Панель: агро", "Bar: aggro"), function() return Profile().aggroFillColor end, function(value)
        Profile().aggroFillColor = { r = value[1], g = value[2], b = value[3], a = value[4] or 1 }; M:RefreshAll(false); preview:Refresh()
    end)
    B:AddRow(page, threat, aggroFillColor)
    local nearFillColor = W:ColorRow(threat, Text("Панель: близкое агро", "Bar: near aggro"), function() return Profile().nearFillColor end, function(value)
        Profile().nearFillColor = { r = value[1], g = value[2], b = value[3], a = value[4] or 1 }; M:RefreshAll(false); preview:Refresh()
    end)
    B:AddRow(page, threat, nearFillColor)
    local function ThreatEnabled()
        return Profile().openWorldThreat == true, Text("Включите «Показывать агро».", "Turn on Show threat.")
    end
    local function ThreatBorderEnabled()
        local available, reason = ThreatEnabled()
        if not available then return false, reason end
        return Profile().threatBorderEnabled ~= false, Text("Включите «Красить рамку».", "Turn on Color the border.")
    end
    local function ThreatFillEnabled()
        local available, reason = ThreatEnabled()
        if not available then return false, reason end
        return Profile().threatFillEnabled == true, Text("Включите «Красить панель HP».", "Turn on Color the health bar.")
    end
    local function NearThreatEnabled(check)
        local available, reason = check()
        if not available then return false, reason end
        return Profile().nearThreat == true, Text("Включите «Предупреждать о близком агро».", "Turn on Warn when close to pulling.")
    end
    W:BindAvailability(near, ThreatEnabled)
    W:BindAvailability(borderEnabled, ThreatEnabled)
    W:BindAvailability(borderThickness, ThreatBorderEnabled)
    W:BindAvailability(fillEnabled, ThreatEnabled)
    W:BindAvailability(aggroColor, ThreatBorderEnabled)
    W:BindAvailability(nearColor, function()
        return NearThreatEnabled(ThreatBorderEnabled)
    end)
    W:BindAvailability(aggroFillColor, ThreatFillEnabled)
    W:BindAvailability(nearFillColor, function()
        return NearThreatEnabled(ThreatFillEnabled)
    end)
    B:FinishCard(page, "main", threat)

    local ownership = B:AddColumnSection(page, columns, "right", Text("Чужие цели", "Tapped targets"), Text("Серый цвет недоступной добычи важнее окраски агро, дебаффов и текстур выбора.", "Gray for tapped targets takes priority over threat, debuffs and selection textures."))
    local tap = W:Toggle(ownership, Text("Приоритет серого цвета", "Prioritize tapped color"), function() return Profile().respectTapDenied ~= false end, function(value)
        Profile().respectTapDenied = value; M:RefreshAll(false)
    end)
    B:AddRow(page, ownership, tap)
    B:FinishCard(page, "main", ownership)

    local target = B:AddColumnSection(page, columns, "left", Text("Выбранная цель", "Selected target"))
    local targetEnabled = W:Toggle(target, Text("Показывать текстуру цели", "Show target texture"), function()
        return Profile().targetPattern.enabled
    end, function(value)
        Profile().targetPattern.enabled = value; M:RefreshSelectionVisuals(); page:Refresh()
    end)
    B:AddRow(page, target, targetEnabled)
    local targetTexture = W:VisualChoiceRow(target, Text("Рисунок", "Pattern"), M.TargetPatternOptions, function()
        return Profile().targetPattern.texture
    end, function(value)
        Profile().targetPattern.texture = value; M:RefreshSelectionVisuals(); preview:Refresh()
    end, {
        previewOnly = true,
        previewWidth = 230,
        applyPreview = function(sample, texture, choice)
            M:ApplyTargetPatternPreview(sample, texture, choice and choice.value,
                Profile().targetPattern.scale or 1)
        end,
    })
    B:AddRow(page, target, targetTexture)
    local targetScale = W:SliderRow(target, Text("Масштаб рисунка, %", "Pattern scale, %"), 50, 200, 5, function()
        return math.floor((Profile().targetPattern.scale or 1) * 100 + .5)
    end, function(value)
        Profile().targetPattern.scale = value / 100
        M:RefreshSelectionVisuals()
        targetTexture:Refresh()
        preview:Refresh()
    end)
    B:AddRow(page, target, targetScale)
    local coverBackground = W:Toggle(target, Text("Покрывать пустую часть HP-бара", "Cover the empty part of the health bar"), function()
        return Profile().targetPattern.coverBackground == true
    end, function(value)
        Profile().targetPattern.coverBackground = value; M:RefreshSelectionVisuals(); preview:Refresh()
    end)
    B:AddRow(page, target, coverBackground)
    local targetOpacity = W:SliderRow(target, Text("Прозрачность, %", "Opacity, %"), 5, 70, 1, function()
        return math.floor((Profile().targetPattern.opacity or .28) * 100 + .5)
    end, function(value)
        Profile().targetPattern.opacity = value / 100; M:RefreshSelectionVisuals(); preview:Refresh()
    end)
    B:AddRow(page, target, targetOpacity)
    local function TargetPatternEnabled()
        return Profile().targetPattern.enabled ~= false, Text("Включите «Показывать текстуру цели».", "Turn on Show target texture.")
    end
    W:BindAvailability(targetTexture, TargetPatternEnabled)
    W:BindAvailability(targetScale, TargetPatternEnabled)
    W:BindAvailability(coverBackground, TargetPatternEnabled)
    W:BindAvailability(targetOpacity, TargetPatternEnabled)
    B:FinishCard(page, "main", target)
    B:FinishColumns(page, "main", columns)
    local buffRows = B:AddSection(page, "main", Text("Перенос баффов", "Buff rows"))
    local rowWidth = W:ChoiceRow(buffRows, Text("Иконок в ряду", "Icons per row"), {
        [0] = Text("По настройкам EllesmereUI", "Use EllesmereUI settings"), [3] = "3", [4] = "4", [5] = "5",
    }, function() return Profile().buffIconsPerRow end, function(value)
        Profile().buffIconsPerRow = value
        M:RefreshFeatureDemand()
        M:RefreshBuffRows()
        page:Refresh()
    end, { [0] = 1, [3] = 2, [4] = 3, [5] = 4 })
    local function CanWrapBuffRows()
        local loaded, reason = SUI:GetAddonAvailability("EllesmereUINameplates", "EllesmereUI Nameplates")
        if not loaded then return false, reason end
        return M:CanWrapBuffRows() == true, Text("Перенос рядов недоступен для текущих неймплейтов.", "Wrapping is unavailable for the current nameplates.")
    end
    W:BindAvailability(rowWidth, CanWrapBuffRows)
    B:AddRow(page, buffRows, rowWidth)
    local rowGap = W:SliderRow(buffRows, Text("Отступ между рядами", "Row spacing"), 0, 12, 1,
        function() return Profile().buffRowSpacing end,
        function(value)
            Profile().buffRowSpacing = value
            M:RefreshBuffRows()
        end)
    W:BindAvailability(rowGap, function()
        local available, reason = CanWrapBuffRows()
        if not available then return false, reason end
        return (tonumber(Profile().buffIconsPerRow) or 0) > 0, Text("Выберите число в настройке «Иконок в ряду».", "Choose a value for Icons per row.")
    end)
    B:AddRow(page, buffRows, rowGap)
    B:FinishCard(page, "main", buffRows)

    local choices = { native = Text("По настройкам EllesmereUI", "Use EllesmereUI settings"), outline = Text("Контур", "Outline"), shadow = Text("Тень", "Shadow"), outlineShadow = Text("Контур и тень", "Outline and shadow") }
    local choiceOrder = { native = 1, outline = 2, shadow = 3, outlineShadow = 4 }
    local function AddTextStyle(section, field, label)
        local row = W:ChoiceRow(section, label, choices, function() return Profile().textStyles[field] end, function(value)
            Profile().textStyles[field] = value
            M:RefreshAll(false)
            page:Refresh()
        end, choiceOrder)
        W:BindAvailability(row, function() return SUI:GetAddonAvailability("EllesmereUINameplates", "EllesmereUI Nameplates") end)
        B:AddRow(page, section, row)
    end

    local labels = B:AddSection(page, "text", Text("Подписи неймплейта", "Nameplate text"))
    AddTextStyle(labels, "name", Text("Имя", "Name"))
    AddTextStyle(labels, "level", Text("Уровень", "Level"))
    AddTextStyle(labels, "health", Text("Здоровье и проценты", "Health and percentage"))
    AddTextStyle(labels, "target", Text("Цель моба", "Enemy's target"))
    AddTextStyle(labels, "quest", Text("Прогресс задания", "Quest progress"))
    B:FinishCard(page, "text", labels)

    local cast = B:AddSection(page, "text", Text("Полоса заклинания", "Cast bar"))
    AddTextStyle(cast, "castName", Text("Название заклинания", "Spell name"))
    AddTextStyle(cast, "castTarget", Text("Цель заклинания", "Spell target"))
    AddTextStyle(cast, "castTime", Text("Время до завершения", "Time remaining"))
    B:FinishCard(page, "text", cast)

    local engine = B:AddSection(page, "auras", Text("Правила окраски", "Color rules"),
        Text("«Имя и уровень» также окрашивает цель моба и прогресс задания. Для окраски текста нужны доступные данные о дебаффе.",
            "Name and level also colors the enemy's target and quest progress. Text coloring requires readable debuff data."))
    local rulesEnabled = W:Toggle(engine, Text("Включить правила аур", "Enable aura rules"), function() return RuleProfile().enabled end, function(value)
        RuleProfile().enabled = value; M.AuraRules:RebuildAll(); page:Refresh()
    end)
    B:AddRow(page, engine, rulesEnabled)
    B:AddRow(page, engine, W:FeatureToggle(engine, "learnDebuffs",
        Text("Запоминать увиденные дебаффы", "Remember observed debuffs"),
        Text("Используется для подсказок при выборе аур.", "Used for suggestions in the aura picker.")))
    local scope = W:SettingRow(engine, Text("Текущий класс и специализация", "Current class and specialization"))
    scope.value = W:Label(scope, "", 9, T.accent)
    scope.value:SetPoint("RIGHT", scope, "RIGHT", -8, 0)
    function scope:Refresh() self.value:SetText(M.AuraRules:ScopeLabel()) end
    B:AddRow(page, engine, scope)
    B:FinishCard(page, "auras", engine)

    local pandemic = B:AddSection(page, "auras", Text("Окно обновления", "Refresh window"), Text("Дополнительная подсветка полосы или рамки для правила с одним дебаффом.", "Highlight the health bar or border for single-debuff rules."))
    local pandemicToggle = W:Toggle(pandemic, Text("Pandemic-подсветка", "Pandemic highlight"), function() return M.AuraRules:PandemicProfile().enabled end, function(value)
        M.AuraRules:PandemicProfile().enabled = value; M.AuraRules:RebuildAll(); page:Refresh()
    end)
    B:AddRow(page, pandemic, pandemicToggle)
    local pandemicPulse = W:Toggle(pandemic, Text("Пульсация", "Pulse"), function() return M.AuraRules:PandemicProfile().pulse end, function(value)
        M.AuraRules:PandemicProfile().pulse = value; M.AuraRules:RebuildAll()
    end)
    B:AddRow(page, pandemic, pandemicPulse)
    local pandemicColor = W:ColorRow(pandemic, Text("Цвет", "Color"), function() return M.AuraRules:PandemicProfile().color end, function(value)
        local current = M.AuraRules:PandemicProfile().color
        M.AuraRules:PandemicProfile().color = { r = value[1], g = value[2], b = value[3], a = current.a or current[4] or .45 }
        M.AuraRules:ApplyPandemicAppearance()
    end)
    B:AddRow(page, pandemic, pandemicColor)
    local function AuraRulesEnabled()
        return RuleProfile().enabled == true, Text("Сначала включите правила аур.", "Enable aura rules first.")
    end
    local function PandemicEnabled()
        local available, reason = AuraRulesEnabled()
        if not available then return false, reason end
        return M.AuraRules:PandemicProfile().enabled == true, Text("Включите «Pandemic-подсветка».", "Turn on Pandemic highlight.")
    end
    W:BindAvailability(pandemicToggle, AuraRulesEnabled)
    W:BindAvailability(pandemicPulse, PandemicEnabled)
    W:BindAvailability(pandemicColor, PandemicEnabled)
    B:FinishCard(page, "auras", pandemic)

    local addSection = B:AddSection(page, "auras", Text("Добавить правило", "Add a rule"),
        Text("Запомненные дебаффы отмечены звездой.", "Remembered debuffs have a star."))
    local addRow = CreateFrame("Frame", nil, addSection)
    addRow:SetHeight(30)
    local picker = W:SpellPicker(addRow, Text("Выбрать дебафф", "Choose a debuff"), function()
        local tracked = {}
        for _, rule in ipairs(RuleProfile().rules or {}) do
            local conditions = M.AuraRules:Conditions(rule)
            if #conditions == 1 then tracked[conditions[1].spellID] = true end
        end
        local entries = {}
        for _, aura in ipairs(M.AuraCatalog:GetAvailableAuras()) do
            entries[#entries + 1] = {
                spellID = aura.spellID, name = aura.name, icon = aura.icon,
                tracked = tracked[aura.spellID] == true, learned = aura.learned == true,
            }
        end
        return entries
    end, function(spellID)
        local ok, message = M.AuraRules:AddRule(spellID); if not ok then SUI:Print(message) end; page:Refresh()
    end)
    picker:SetSize(210, 26); picker:SetPoint("LEFT")
    local input = W:EditBox(addRow, Text("ID заклинания", "Spell ID"), function(value)
        local ok, message = M.AuraRules:AddRule(value); if not ok then SUI:Print(message) end; page:Refresh()
    end)
    input:SetSize(112, 26); input:SetPoint("LEFT", picker, "RIGHT", 8, 0)
    local add = W:Button(addRow, Text("Добавить", "Add"), function()
        local ok, message = M.AuraRules:AddRule(input:GetText()); if not ok then SUI:Print(message) end
        input:SetText(""); page:Refresh()
    end, true)
    add:SetSize(92, 26); add:SetPoint("LEFT", input, "RIGHT", 8, 0)
    B:AddRow(page, addSection, addRow)
    B:FinishCard(page, "auras", addSection)

    local auraTab = page.tabs.auras
    page.ruleListStart = auraTab.nextY
    page.rows = {}

    local function RuleEntries(row)
        local tracked = {}
        for _, condition in ipairs(M.AuraRules:Conditions(row.rule)) do tracked[condition.spellID] = true end
        local entries = {}
        for _, aura in ipairs(M.AuraCatalog:GetAvailableAuras()) do
            entries[#entries + 1] = {
                spellID = aura.spellID, name = aura.name, icon = aura.icon,
                tracked = tracked[aura.spellID] == true, learned = aura.learned == true,
            }
        end
        return entries
    end

    local function AcquireRow(index)
        local row = page.rows[index]
        if row then row:Show(); return row end
        row = W:Card(auraTab.body, "", "")
        row:SetHeight(126); row.title:Hide(); row.description:Hide(); row.icons = {}
        for iconIndex = 1, 2 do
            local icon = row:CreateTexture(nil, "ARTWORK")
            icon:SetSize(24, 24); icon:SetPoint("TOPLEFT", row, "TOPLEFT", 12 + ((iconIndex - 1) * 30), -10)
            row.icons[iconIndex] = icon
        end
        row.plus = W:Label(row, "+", 10, T.muted); row.plus:SetPoint("CENTER", row.icons[1], "RIGHT", 3, 0)
        row.name = W:Label(row, "", 11, T.text); row.name:SetPoint("TOPLEFT", row, "TOPLEFT", 76, -10); row.name:SetPoint("TOPRIGHT", row, "TOPRIGHT", -126, -10)
        row.id = W:Label(row, "", 9, T.muted); row.id:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -2)
        row.enabled = W:Toggle(row, Text("Активно", "Active"), function() return row.rule and row.rule.enabled ~= false end, function(value)
            row.rule.enabled = value; M.AuraRules:RebuildAll(); page:Refresh()
        end)
        row.enabled:SetPoint("TOPRIGHT", row, "TOPRIGHT", -8, -8); row.enabled:SetWidth(104)
        row.color = W:ColorSwatch(row, Text("Цвет", "Color"), function() return row.rule and row.rule.color or { r = 1, g = 1, b = 1 } end, function(r, g, b)
            row.rule.color = { r = r, g = g, b = b, a = 1 }; M.AuraRules:ApplyRuleAppearance(row.rule)
            if preview.rule == row.rule then preview:Refresh() end
        end)
        row.colorTarget = CreateFrame("Frame", nil, row)
        row.colorTarget:SetHeight(28)
        row.colorOptions = {}
        for index, option in ipairs({
            { "HEALTH", Text("Полоса HP", "Health bar") }, { "BORDER", Text("Рамка", "Border") },
            { "TEXT", Text("Цифры HP", "Health numbers") }, { "LABELS", Text("Имя и уровень", "Name and level") },
        }) do
            local target, label = option[1], option[2]
            local toggle = W:Toggle(row.colorTarget, label,
                function() return row.rule and M.AuraRules:HasColorTarget(row.rule, target) end,
                function(value)
                    if row.rule then M.AuraRules:SetColorTargetEnabled(row.rule, target, value) end
                    page:Refresh()
                end, nil, true, "inline")
            row.colorOptions[index] = toggle
        end
        local function ArrangeColors(frame, width)
            local gap = 8
            local step = (width + gap) / #row.colorOptions
            for index, toggle in ipairs(row.colorOptions) do
                toggle:ClearAllPoints()
                toggle:SetPoint("LEFT", frame, "LEFT", (index - 1) * step, 0)
                toggle:SetWidth(math.max(1, step - gap))
            end
        end
        row.colorTarget:HookScript("OnSizeChanged", ArrangeColors)
        row.colorTarget:SetPoint("TOPLEFT", row, "TOPLEFT", 12, -48)
        row.colorTarget:SetPoint("TOPRIGHT", row, "TOPRIGHT", -12, -48)
        local auraRules = M.AuraRules
        row.borderThickness = W:SliderRow(row, Text("Толщина рамки", "Border thickness"),
            auraRules.MIN_BORDER_THICKNESS, auraRules.MAX_BORDER_THICKNESS, 1,
            function() return auraRules:BorderThickness(row.rule) end,
            function(value)
                auraRules:SetBorderThickness(row.rule, value)
                if preview.rule == row.rule then preview:Refresh() end
            end)
        row.borderThickness:SetPoint("TOPLEFT", row.colorTarget, "BOTTOMLEFT", 0, -6)
        row.borderThickness:SetPoint("TOPRIGHT", row.colorTarget, "BOTTOMRIGHT", 0, -6)
        row.color:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 12, 8); row.color:SetWidth(122)
        row.addCondition = W:SpellPicker(row, Text("+ Добавить условие", "+ Add condition"), function() return RuleEntries(row) end, function(spellID)
            local ok, message = M.AuraRules:AddCondition(row.rule, spellID); if not ok then SUI:Print(message) end; page:Refresh()
        end)
        row.addCondition:SetSize(138, 24); row.addCondition:SetPoint("LEFT", row.color, "RIGHT", 9, 0)
        row.removeCondition = W:Button(row, Text("Убрать второй", "Remove second"), function()
            local ok, message = M.AuraRules:RemoveCondition(row.rule, 2); if not ok then SUI:Print(message) end; page:Refresh()
        end)
        row.removeCondition:SetSize(138, 24); row.removeCondition:SetPoint("LEFT", row.color, "RIGHT", 9, 0)
        row.preview = W:Button(row, Text("На образце", "Preview"), function()
            if preview.rule == row.rule then preview.rule = nil else preview.rule = row.rule end
            page:Refresh()
        end, true)
        row.preview:SetSize(116, 24); row.preview:SetPoint("LEFT", row.addCondition, "RIGHT", 8, 0)
        row.delete = W:Button(row, Text("Удалить", "Delete"), function() M.AuraRules:RemoveRule(row.index); page:Refresh() end)
        row.delete:SetSize(70, 24); row.delete:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -12, 8)
        page.rows[index] = row
        return row
    end

    function page:RefreshRules()
        M.AuraRules:SortRules()
        local rules = RuleProfile().rules or {}
        for index, row in ipairs(self.rows) do row:SetShown(index <= #rules) end
        local y, comboCount, previewLabel = self.ruleListStart, 0, nil
        for index, rule in ipairs(rules) do
            local row = AcquireRow(index)
            local conditions = M.AuraRules:Conditions(rule)
            row.index, row.rule = index, rule
            row:ClearAllPoints(); row:SetPoint("TOPLEFT", auraTab.body, "TOPLEFT", 0, y); row:SetPoint("TOPRIGHT", auraTab.body, "TOPRIGHT", 0, y)
            local names, ids = {}, {}
            for conditionIndex = 1, 2 do
                local condition = conditions[conditionIndex]
                row.icons[conditionIndex]:SetShown(condition ~= nil)
                if condition then
                    local spellName, icon = SpellInfo(condition.spellID)
                    row.icons[conditionIndex]:SetTexture(icon); names[#names + 1] = spellName; ids[#ids + 1] = tostring(condition.spellID)
                end
            end
            local combo = #conditions == 2; if combo then comboCount = comboCount + 1 end
            row.plus:SetShown(combo); row.name:SetText(table.concat(names, "  +  "))
            local selected = preview.rule == rule
            row.preview.text:SetText(selected and Text("Скрыть с образца", "Hide from preview") or Text("На образце", "Preview"))
            if selected then previewLabel = row.name:GetText() end
            local available, missingSpellID = M.AuraRules:IsRuleAvailable(rule)
            rule.autoUnavailable, rule.missingSpellID = not available, missingSpellID
            local detail = Text("ID %s · приоритет %d", "ID %s · priority %d"):format(table.concat(ids, " + "), index)
            if rule.autoUnavailable then detail = detail .. Text(" · нет данных о дебаффе", " · debuff data unavailable") end
            row.id:SetText(detail)
            row.addCondition:SetShown(not combo); row.removeCondition:SetShown(combo)
            row.enabled:SetAvailable(true); row.enabled.label:SetText(Text("Активно", "Active"))
            local c = available and T.text or T.warning; row.enabled.label:SetTextColor(c[1], c[2], c[3], 1)
            local border = M.AuraRules:HasColorTarget(rule, "BORDER")
            row.borderThickness:SetShown(border)
            row.borderThickness:Refresh()
            row:SetHeight(border and 162 or 126)
            row.enabled:Refresh(); row.color:Refresh()
            for _, toggle in ipairs(row.colorOptions) do toggle:Refresh() end
            y = y - row:GetHeight() - 6
        end
        if not previewLabel then preview.rule = nil end
        preview.ruleLabel = previewLabel
        auraTab.body:SetHeight(math.max(auraTab.scroll:GetHeight(), -y + 2))
        SUI:After(0, M, "settings scroll", function() if auraTab.scroll.RefreshRange then auraTab.scroll:RefreshRange() end end)
        scope:Refresh()
    end

    page.OnRefresh = function(self) self:RefreshRules(); preview:Refresh() end
    B:SetPageFooter(page, {
        { title = Text("Сбросить модуль", "Reset module"), width = 132, callback = function()
            W:Confirm(Text("Сбросить настройки неймплейтов?", "Reset nameplate settings?"), function() SUI:ResetModuleProfile("nameplates") end)
        end },
    })
    page:Refresh()
    return page
end

SUI:RegisterSettingsPage({ key = "nameplates", title = Text("Неймплейты", "Nameplates"), group = "ЭЛЕМЕНТЫ ИНТЕРФЕЙСА", order = 20, builder = BuildPage })
