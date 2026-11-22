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

local function BuildAuraSettings(page)
    local A = M.AuraRules
    local tab = "auras"
    local start = -page.tabs[tab].nextY
    local columns = B:BeginColumns(page, tab, 14, .43)
    local sides = { left = {}, right = {} }
    local selected, color, conditionPicker
    local firstPresent, secondPresent = true, true
    local previewState = "normal"
    local RefreshPreview
    local addingRule, addingCondition = false, false
    local rows = {}
    local listedRule, listedIndex
    local ruleRowHeight, visibleRules = 36, 5

    local function Card(side, title, description)
        local card = W:QuietCard(columns[side], title)
        card.headerHeight, card.nextY, card.widgets, card.settingsTab = 29, -34, {}, tab
        card.title:ClearAllPoints()
        card.title:SetPoint("TOPLEFT", card, "TOPLEFT", 12, -8)
        card.title:SetPoint("RIGHT", card, "RIGHT", -12, 0)
        if description then W:Help(card, description, card.title) end
        sides[side][#sides[side] + 1] = card
        page.searchRows[#page.searchRows + 1] = card
        return card
    end

    local function LayoutCards()
        local height = 0
        for side, cards in pairs(sides) do
            local y = 0
            for _, card in ipairs(cards) do
                if card:IsShown() then
                    card:SetPoint("TOPLEFT", columns[side], "TOPLEFT", 0, -y)
                    card:SetPoint("TOPRIGHT", columns[side], "TOPRIGHT", 0, -y)
                    local rowY = card.headerHeight + 4
                    for _, row in ipairs(card.widgets) do
                        if row:IsShown() then
                            row:SetPoint("TOPLEFT", card, "TOPLEFT", 12, -rowY)
                            row:SetPoint("TOPRIGHT", card, "TOPRIGHT", -12, -rowY)
                            rowY = rowY + row:GetHeight() + 3
                        end
                    end
                    card:SetHeight(rowY + 7)
                    y = y + card:GetHeight() + 9
                end
            end
            height = math.max(height, y)
        end
        columns:SetHeight(math.max(1, height))
        local data = page.tabs[tab]
        data.nextY = -start - height
        data.body:SetHeight(math.max(data.scroll:GetHeight(), start + height + 2))
        data.scroll:RefreshRange()
    end

    local function HeaderToggle(card, label, getValue, setValue, width)
        local toggle = W:Toggle(card, label, getValue, setValue, nil, true)
        toggle:SetSize(width, 25)
        toggle:SetPoint("TOPRIGHT", card, "TOPRIGHT", -4, -2)
        toggle.label:SetPoint("RIGHT", toggle.track, "LEFT", -6, 0)
        toggle.label:SetJustifyH("RIGHT")
        card.title:SetPoint("RIGHT", toggle, "LEFT", -5, 0)
        page:AddRefresher(toggle)
        return toggle
    end

    local function PlainToggle(parent, label, getValue, setValue, detail)
        local toggle = W:Toggle(parent, label, getValue, setValue, nil, true)
        toggle:SetHeight(24)
        toggle.track:ClearAllPoints()
        toggle.track:SetPoint("LEFT", toggle, "LEFT", 0, 0)
        toggle.label:SetPoint("LEFT", toggle.track, "RIGHT", 1, 0)
        toggle.label:SetPoint("RIGHT", toggle, "RIGHT", -4, 0)
        toggle.label:SetWordWrap(false)
        if detail then W:Help(toggle, detail) end
        return toggle
    end

    local function SelectRule(rule)
        if selected == rule then return end
        if color then W:CloseColorPicker(color) end
        if conditionPicker then conditionPicker.popup:Hide() end
        selected = rule
        addingCondition = false
        firstPresent, secondPresent = true, true
    end

    local function RuleNames(rule)
        local conditions = A:Conditions(rule)
        local names, ids, icon = {}, {}, nil
        for _, condition in ipairs(conditions) do
            local name, texture = SpellInfo(condition.spellID)
            icon = icon or texture
            names[#names + 1] = name
            ids[#ids + 1] = tostring(condition.spellID)
        end
        return table.concat(names, " + "), table.concat(ids, " + "), icon, #conditions
    end

    local function AvailableAuras(rule)
        local tracked = {}
        if rule then
            for _, condition in ipairs(A:Conditions(rule)) do tracked[condition.spellID] = true end
        else
            for _, entry in ipairs(RuleProfile().rules or {}) do
                local conditions = A:Conditions(entry)
                if #conditions == 1 then tracked[conditions[1].spellID] = true end
            end
        end
        local entries = {}
        for _, aura in ipairs(M.AuraCatalog:GetAvailableAuras()) do
            entries[#entries + 1] = {
                spellID = aura.spellID, name = aura.name, icon = aura.icon,
                tracked = tracked[aura.spellID] == true, learned = aura.learned == true,
            }
        end
        return entries
    end

    local listSection = Card("left", Text("Правила аур", "Aura rules"))
    local rulesEnabled = HeaderToggle(listSection, Text("Включить", "Enable"),
        function() return RuleProfile().enabled end, function(value)
            RuleProfile().enabled = value
            M:RefreshFeatureDemand()
            A:RebuildAll()
            SUI:RefreshModuleEvents()
            page:Refresh()
        end, 100)
    rulesEnabled.settingsTab = tab
    page.searchRows[#page.searchRows + 1] = rulesEnabled
    local scope = W:SettingRow(listSection, Text("Класс и специализация", "Class and specialization"))
    scope.value = W:Label(scope, "", 9, T.accent)
    scope.value:SetPoint("LEFT", scope, "LEFT", 0, 0)
    scope.value:SetPoint("RIGHT", scope, "RIGHT", 0, 0)
    scope.value:SetWordWrap(false)
    scope.label:Hide()
    scope:SetHeight(19)
    local scopeHelp = Text("Правила хранятся отдельно для каждого класса и специализации.",
        "Rules are saved separately for each class and specialization.")
    function scope:Refresh()
        self.value:SetText(A:ScopeLabel())
        W:Help(self, scopeHelp, self.value)
    end
    B:AddRow(page, listSection, scope)

    local list = CreateFrame("Frame", nil, listSection)
    list:SetHeight(24)
    B:AddRow(page, listSection, list)
    local scroll, body, bar = W:ScrollFrame(list, nil, ruleRowHeight)
    scroll:SetPoint("TOPLEFT")
    scroll:SetPoint("BOTTOMRIGHT", -10, 0)
    bar:SetPoint("TOPLEFT", scroll, "TOPRIGHT", 3, 0)
    bar:SetPoint("BOTTOMLEFT", scroll, "BOTTOMRIGHT", 3, 0)
    scroll:HookScript("OnSizeChanged", function(_, width) body:SetWidth(math.max(1, width)) end)
    local empty = W:Label(body, Text("Правил пока нет", "No aura rules yet"), 10, T.muted)
    empty:SetPoint("TOPLEFT", 6, -8)

    local function AddRule(value)
        local ok, message = A:AddRule(value)
        if not ok then
            SUI:Print(message)
            return false
        end
        for _, rule in ipairs(RuleProfile().rules) do
            local conditions = A:Conditions(rule)
            if #conditions == 1 and conditions[1].spellID == tonumber(value) then
                SelectRule(rule)
                break
            end
        end
        addingRule = false
        page:Refresh()
        return true
    end
    local addAction = CreateFrame("Frame", nil, listSection)
    addAction:SetHeight(25)
    local addRule = W:Button(addAction, Text("Добавить правило", "Add rule"), function()
        addingRule = not addingRule
        page:Refresh()
    end)
    addRule:SetSize(133, 24)
    addRule:SetPoint("LEFT")
    B:AddRow(page, listSection, addAction)
    local picker = W:SpellPicker(listSection, Text("Выбрать дебафф", "Choose a debuff"),
        function() return AvailableAuras() end, AddRule)
    B:AddRow(page, listSection, W:Help(picker,
        Text("Запомненные дебаффы отмечены галочкой.", "Remembered debuffs have a check mark.")))

    local function SpellIDRow(parent, onCommit)
        local row = CreateFrame("Frame", nil, parent)
        row:SetHeight(32)
        local input = W:EditBox(row, Text("ID заклинания", "Spell ID"), function() end)
        local add = W:Button(row, Text("Добавить", "Add"), function()
            if onCommit(input:GetText()) then input:ClearFocus(); input:SetText("") end
        end, true)
        add:SetSize(108, 26)
        add:SetPoint("RIGHT")
        input:SetPoint("LEFT")
        input:SetPoint("RIGHT", add, "LEFT", -8, 0)
        input:SetScript("OnEnterPressed", function() add:Click() end)
        return row
    end

    local addByID = B:AddRow(page, listSection, SpellIDRow(listSection, AddRule))
    local tapped = W:Toggle(listSection, Text("Приоритет серого цвета", "Prioritize tapped color"),
        function() return Profile().respectTapDenied ~= false end,
        function(value)
            Profile().respectTapDenied = value
            M:RefreshAll(false)
            RefreshPreview()
        end,
        Text("Сохраняет серый цвет у целей с недоступной добычей.", "Preserves gray on targets whose loot is unavailable."))
    B:AddRow(page, listSection, tapped)
    local previewSection = Card("right", Text("Дебаффы", "Debuffs"),
        Text("Sintezza UI рисует образец с тестовой целью. Если неймплейты рисует EllesmereUI, образец берет его текстуры и скругление. Переключатели действуют только на образец.",
            "Sintezza UI draws a sample target. When EllesmereUI owns nameplates, the sample uses its textures and rounding. The debuff switches only affect the sample."))
    local sample = M:CreateSettingsPreview(previewSection)
    B:AddRow(page, previewSection, sample)
    local states = W:Segmented(previewSection,
        { Text("Обычная цель", "Normal target"), Text("Чужая цель", "Tapped target") },
        { "normal", "tapped" },
        function() return previewState end, function(value) previewState = value; RefreshPreview() end)
    B:AddRow(page, previewSection, states)
    local match = W:Label(previewSection, "", 9, T.muted)
    match:SetHeight(15)
    match:SetWordWrap(false)
    B:AddRow(page, previewSection, match)
    function RefreshPreview()
        local conditions = selected and A:Conditions(selected)
        local tapped = previewState == "tapped"
        local status = Text("Выбери правило", "Choose a rule")
        local applies = false
        if conditions then
            local active = Profile().enabled ~= false and RuleProfile().enabled and selected.enabled ~= false
            local matched = firstPresent and (#conditions == 1 or secondPresent)
            local visual = A:HasColorTarget(selected, "HEALTH") or A:HasColorTarget(selected, "BORDER")
            local text = A:HasColorTarget(selected, "TEXT") or A:HasColorTarget(selected, "LABELS")
            local paint = visual or (text and A:SupportsTextColoring())
            local protected = tapped and Profile().respectTapDenied ~= false
            applies = active and matched and paint and not protected
            if protected then
                status = Text("Серый цвет в приоритете", "Gray takes priority")
            elseif not active then
                status = Text("Правило выключено", "Rule is off")
            elseif not paint then
                status = text and Text("Окраска текста требует EllesmereUI", "Text coloring requires EllesmereUI")
                    or Text("Выбери, что красить", "Choose a color target")
            elseif not matched then
                status = Text("Условие не выполнено", "Condition not met")
            else
                status = Text("Условие выполнено", "Condition met")
            end
        end
        match:SetText(status)
        sample.rule = applies and selected or nil
        sample.tapped = tapped
        local _, firstIcon, secondIcon
        if conditions and conditions[1] and firstPresent then _, firstIcon = SpellInfo(conditions[1].spellID) end
        if conditions and conditions[2] and secondPresent then _, secondIcon = SpellInfo(conditions[2].spellID) end
        sample:SetDebuffs(firstIcon, secondIcon)
        sample:Refresh()
    end

    local simulation = CreateFrame("Frame", nil, previewSection)
    simulation:SetSize(138, 24)
    simulation:SetPoint("TOPRIGHT", previewSection, "TOPRIGHT", -9, -3)
    previewSection.title:SetPoint("RIGHT", simulation, "LEFT", -8, 0)
    local first = PlainToggle(simulation, Text("Дебафф на цели", "Debuff on target"),
        function() return firstPresent end, function(value) firstPresent = value; RefreshPreview() end)
    first:SetPoint("LEFT", simulation, "LEFT", 0, 0)
    first:SetPoint("RIGHT", simulation, "CENTER", -4, 0)
    local second = PlainToggle(simulation, Text("Второй дебафф", "Second debuff"),
        function() return secondPresent end, function(value) secondPresent = value; RefreshPreview() end)
    second:SetPoint("LEFT", simulation, "CENTER", 4, 0)
    second:SetPoint("RIGHT", simulation, "RIGHT", 0, 0)
    local editor = Card("right", Text("Выбранное правило", "Selected rule"))
    local enabled = HeaderToggle(editor, Text("Активно", "Active"), function() return selected and selected.enabled ~= false end,
        function(value)
            if not selected then return end
            selected.enabled = value
            A:RebuildAll(); page:Refresh()
        end, 96)
    local conditionRow = W:SettingRow(editor, Text("Условие", "Condition"), 25)
    local editCondition = W:Button(conditionRow, Text("+ Дебафф", "+ Debuff"), function()
        addingCondition = not addingCondition
        page:Refresh()
    end)
    editCondition:SetSize(116, 23)
    editCondition:SetPoint("RIGHT", conditionRow, "RIGHT")
    conditionRow.label:SetPoint("RIGHT", editCondition, "LEFT", -7, 0)
    conditionRow.label:SetWordWrap(false)
    B:AddRow(page, editor, conditionRow)

    local function AddCondition(value)
        if not selected then return false end
        local ok, message = A:AddCondition(selected, value)
        if not ok then SUI:Print(message); return false end
        addingCondition = false
        secondPresent = true
        page:Refresh()
        return true
    end

    conditionPicker = W:SpellPicker(editor, Text("Выбрать второй дебафф", "Choose second debuff"),
        function() return AvailableAuras(selected) end, AddCondition)
    B:AddRow(page, editor, conditionPicker)
    local removeCondition = W:Button(conditionRow, Text("Убрать второй", "Remove second"), function()
        if not selected then return end
        local ok, message = A:RemoveCondition(selected, 2)
        if not ok then SUI:Print(message) end
        page:Refresh()
    end)
    removeCondition:SetAllPoints(editCondition)
    local secondByID = B:AddRow(page, editor, SpellIDRow(editor, AddCondition))

    local targetLabel = W:Label(editor, Text("Что красить", "Color targets"), 9, T.muted)
    targetLabel:SetHeight(15)
    B:AddRow(page, editor, targetLabel)
    local targetGroup = CreateFrame("Frame", nil, editor)
    targetGroup:SetHeight(48)
    local targetControls = {}
    for index, entry in ipairs({
        { "HEALTH", Text("Полоса HP", "Health bar") }, { "BORDER", Text("Рамка", "Border") },
        { "TEXT", Text("Цифры HP", "Health numbers") }, { "LABELS", Text("Имя и уровень", "Name and level") },
    }) do
        local target, label = entry[1], entry[2]
        local detail
        if target == "LABELS" then
            detail = Text("Также окрашивает цель моба и прогресс задания.",
                "Also colors the enemy's target and quest progress.")
        end
        local toggle = PlainToggle(targetGroup, label, function() return selected and A:HasColorTarget(selected, target) end,
            function(value)
                if selected then A:SetColorTargetEnabled(selected, target, value); page:Refresh() end
            end, detail)
        if target == "TEXT" or target == "LABELS" then
            W:BindAvailability(toggle, function()
                return A:SupportsTextColoring(), Text("Окраска текста доступна на неймплейтах EllesmereUI.",
                    "Text coloring is available on EllesmereUI nameplates.")
            end)
        end
        local y = index <= 2 and 0 or -24
        if index % 2 == 1 then
            toggle:SetPoint("TOPLEFT", targetGroup, "TOPLEFT", 0, y)
            toggle:SetPoint("TOPRIGHT", targetGroup, "TOP", -4, y)
        else
            toggle:SetPoint("TOPLEFT", targetGroup, "TOP", 4, y)
            toggle:SetPoint("TOPRIGHT", targetGroup, "TOPRIGHT", 0, y)
        end
        targetControls[#targetControls + 1] = toggle
    end
    B:AddRow(page, editor, targetGroup)
    local thickness = W:SliderRow(editor, Text("Толщина рамки", "Border thickness"),
        A.MIN_BORDER_THICKNESS, A.MAX_BORDER_THICKNESS, 1, function() return A:BorderThickness(selected) end, function(value)
            if selected then A:SetBorderThickness(selected, value); page:Refresh() end
        end)
    B:AddRow(page, editor, thickness)
    local actions = CreateFrame("Frame", nil, editor)
    actions:SetHeight(32)
    color = W:ColorSwatch(actions, Text("Цвет", "Color"),
        function() return selected and selected.color or { r = 1, g = 1, b = 1 } end, function(r, g, b)
            if not selected then return end
            selected.color = { r = r, g = g, b = b, a = 1 }
            A:ApplyRuleAppearance(selected)
            RefreshPreview()
        end)
    color:SetWidth(120)
    color:SetPoint("LEFT")
    local delete = W:Button(actions, Text("Удалить правило", "Delete rule"), function()
        for index, rule in ipairs(RuleProfile().rules) do
            if rule == selected then
                SelectRule(nil)
                A:RemoveRule(index)
                local rules = RuleProfile().rules
                SelectRule(rules[index] or rules[#rules])
                page:Refresh()
                return
            end
        end
    end)
    delete:SetSize(125, 25)
    delete:SetPoint("RIGHT")
    B:AddRow(page, editor, actions)
    local function AcquireRow(index)
        if rows[index] then return rows[index] end
        local row = W:Button(body, "", function(self)
            SelectRule(self.rule)
            page:Refresh()
        end)
        row:SetHeight(ruleRowHeight - 3)
        row:SetPoint("TOPLEFT", body, "TOPLEFT", 0, -(index - 1) * ruleRowHeight)
        row:SetPoint("TOPRIGHT", body, "TOPRIGHT", 0, -(index - 1) * ruleRowHeight)
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(23, 23)
        row.icon:SetPoint("LEFT", row, "LEFT", 8, 0)
        row.text:ClearAllPoints()
        row.text:SetPoint("TOPLEFT", row, "TOPLEFT", 38, -5)
        row.text:SetPoint("TOPRIGHT", row, "TOPRIGHT", -8, -5)
        row.text:SetJustifyH("LEFT")
        row.text:SetWordWrap(false)
        row.detail = W:Label(row, "", 9, T.muted)
        row.detail:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 38, 4)
        rows[index] = row
        return row
    end

    local function Refresh()
        A:SortRules()
        local rules = RuleProfile().rules
        local found
        for _, rule in ipairs(rules) do
            if rule == selected then found = true; break end
        end
        if not found then SelectRule(rules[1]) end
        local selectedIndex
        for index, rule in ipairs(rules) do
            if rule == selected then selectedIndex = index end
            local row = AcquireRow(index)
            local name, _, icon = RuleNames(rule)
            local available, missingSpellID = A:IsRuleAvailable(rule)
            rule.autoUnavailable, rule.missingSpellID = not available, missingSpellID
            local status = not available and Text("Нет данных", "Unavailable")
                or rule.enabled == false and Text("Выключено", "Off") or Text("Активно", "Active")
            row.rule = rule
            row.icon:SetTexture(icon or 134400)
            row.text:SetText(name)
            row.detail:SetText(Text("Приоритет %d · %s", "Priority %d · %s"):format(index, status))
            T:PaintButton(row, rule == selected)
            row:Show()
        end
        for index = #rules + 1, #rows do rows[index]:Hide() end
        empty:SetShown(#rules == 0)
        local listHeight = math.max(23, math.min(visibleRules, #rules) * ruleRowHeight)
        list:SetHeight(listHeight)
        local overflows = #rules > visibleRules
        scroll:EnableMouseWheel(overflows)
        scroll:SetPoint("BOTTOMRIGHT", overflows and -10 or 0, 0)
        body:SetHeight(math.max(listHeight, #rules * ruleRowHeight))
        scroll:RefreshRange()
        if selectedIndex and (listedRule ~= selected or listedIndex ~= selectedIndex) then
            local top, bottom = (selectedIndex - 1) * ruleRowHeight, selectedIndex * ruleRowHeight
            local offset = scroll:GetVerticalScroll()
            if top < offset then
                scroll:SetVerticalScroll(top)
            elseif bottom > offset + listHeight then
                scroll:SetVerticalScroll(bottom - listHeight)
            end
        end
        listedRule, listedIndex = selected, selectedIndex

        picker:SetShown(addingRule)
        addByID:SetShown(addingRule)
        addRule.text:SetText(addingRule and Text("Свернуть добавление", "Close add rule")
            or Text("Добавить правило", "Add rule"))
        editor:SetShown(selected ~= nil)
        simulation:SetShown(selected ~= nil)
        if selected then
            local name, ids, _, count = RuleNames(selected)
            local combo = count == 2
            editor.title:SetText(name)
            conditionRow.label:SetText("ID " .. ids)
            W:Help(conditionRow, name)
            editCondition:SetShown(not combo)
            editCondition.text:SetText(addingCondition and Text("Свернуть", "Close") or Text("+ Дебафф", "+ Debuff"))
            conditionPicker:SetShown(not combo and addingCondition)
            removeCondition:SetShown(combo)
            secondByID:SetShown(not combo and addingCondition)
            thickness:SetShown(A:HasColorTarget(selected, "BORDER"))
            second:SetShown(combo)
            enabled:Refresh()
            color:Refresh()
            thickness:Refresh()
            for _, control in ipairs(targetControls) do control:Refresh() end
            simulation:SetWidth(combo and 187 or 138)
            first.label:SetText(combo and Text("Дебафф 1", "Debuff 1") or Text("Дебафф на цели", "Debuff on target"))
            second.label:SetText(Text("Дебафф 2", "Debuff 2"))
            first:SetPoint("RIGHT", simulation, combo and "CENTER" or "RIGHT", combo and -4 or 0, 0)
            first:Refresh()
            second:Refresh()
        end
        LayoutCards()
        RefreshPreview()
    end

    return Refresh
end

local function BuildPage(parent)
    local page = B:CreateTabbedPage(parent, Text("Неймплейты", "Nameplates"), nil, {
        { key = "auras" },
    }, true)
    local columns = B:BeginColumns(page, "auras", 14, .43)
    local buffRows = B:AddColumnSection(page, columns, "left", Text("Баффы", "Buffs"))
    B:AddRow(page, buffRows, W:FeatureToggle(buffRows, "nameplates",
        Text("Включить настройки аур", "Enable nameplate aura settings"), nil, nil, function() page:Refresh() end))
    local rowWidth = W:ChoiceRow(buffRows, Text("Иконок в ряду", "Icons per row"), {
        [0] = Text("Штатная раскладка", "Default layout"), [3] = "3", [4] = "4", [5] = "5",
    }, function() return M:GetBuffIconsPerRow() end, function(value)
        Profile()[M:BuffRowsProfileKey()] = value
        M:RefreshFeatureDemand()
        M:RefreshBuffRows()
        SUI:RefreshModuleEvents()
        page:Refresh()
    end, { [0] = 1, [3] = 2, [4] = 3, [5] = 4 })
    local function CanWrapBuffRows()
        if M:UsesBlizzardNameplates() then
            return M:CanWrapBlizzardBuffRows(), Text("Сетка баффов Blizzard недоступна в этом клиенте.",
                "The Blizzard buff grid is unavailable on this client.")
        end
        local loaded, reason = SUI:GetAddonAvailability("EllesmereUINameplates", "EllesmereUI Nameplates")
        if not loaded then return false, reason end
        return M:CanWrapBuffRows() == true, Text("Перенос рядов недоступен для текущих неймплейтов.", "Wrapping is unavailable for the current nameplates.")
    end
    W:BindAvailability(rowWidth, CanWrapBuffRows,
        Text("У Blizzard перенос показывает до двух рядов из баффов, разрешенных штатными фильтрами. Изменения применяются вне боя.",
            "Blizzard wrapping shows up to two rows of buffs allowed by its filters. Changes apply out of combat."))
    B:AddRow(page, buffRows, rowWidth)
    local rowGap = W:SliderRow(buffRows, Text("Отступ между рядами", "Row spacing"), 0, 12, 1,
        function() return Profile().buffRowSpacing end,
        function(value)
            Profile().buffRowSpacing = value
            M:RefreshBuffRows()
            page:Refresh()
        end)
    W:BindAvailability(rowGap, function()
        local available, reason = CanWrapBuffRows()
        if not available then return false, reason end
        return M:GetBuffIconsPerRow() > 0, Text("Выберите число в настройке «Иконок в ряду».", "Choose a value for Icons per row.")
    end)
    B:AddRow(page, buffRows, rowGap)
    B:FinishCard(page, "auras", buffRows)

    local buffCard = B:AddColumnSection(page, columns, "right", Text("Предпросмотр баффов", "Buff preview"),
        Text("Размеры и отступы отражают настройки переноса рядов. Иконки приведены для примера.",
            "Icon sizes and gaps reflect the row settings. The icons are examples."))
    local buffSample = M:CreateBuffSettingsPreview(buffCard)
    B:AddRow(page, buffCard, buffSample)
    B:FinishCard(page, "auras", buffCard)
    B:FinishColumns(page, "auras", columns)

    page.OnRefresh = BuildAuraSettings(page)
    B:SetPageFooter(page, {
        { title = Text("Сбросить модуль", "Reset module"), width = 132, callback = function()
            W:Confirm(Text("Сбросить настройки неймплейтов?", "Reset nameplate settings?"), function() SUI:ResetModuleProfile("nameplates") end)
        end },
    })
    page:Refresh()
    return page
end

SUI:RegisterSettingsPage({ key = "nameplates", title = Text("Неймплейты", "Nameplates"), group = "ЭЛЕМЕНТЫ ИНТЕРФЕЙСА", order = 20, builder = BuildPage })
