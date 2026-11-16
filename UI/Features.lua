local _, SUI = ...
local Text = SUI.Text
local T, W, B = SUI.SettingsTheme, SUI.Widgets, SUI.SettingsBuilder

local function CombatTextState()
    local module = SUI:GetModule("combatFont")
    if module and module.OtherOwner and module:OtherOwner() then
        return false, Text("Управляет другой аддон", "Managed by another addon")
    end
    local profile = SUI:GetModuleProfile("combatFont")
    return profile and profile.enabled == true
end

local function RaidCheckState()
    return SUI:GetFeature("raidTools") and SUI:GetFeature("raidCheck")
end

local function AddOverviewRow(page, card, title, detail, target, feature, tab)
    local row = W:ActionRow(card, title, Text("Открыть", "Open"), function()
        SUI.SettingsUI:SelectPage(target, tab)
    end)
    row:SetHeight(43)
    row.label:ClearAllPoints()
    row.label:SetPoint("TOPLEFT", row, "TOPLEFT", 2, -5)
    row.label:SetPoint("TOPRIGHT", row.button, "TOPLEFT", -112, 4)
    row.label:SetWordWrap(false)
    local description = W:Label(row, detail, 10, T.muted)
    description:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 2, 4)
    description:SetPoint("BOTTOMRIGHT", row.button, "BOTTOMLEFT", -8, -4)
    description:SetWordWrap(false)
    local state = W:Label(row, "", 10, T.muted)
    state:SetPoint("RIGHT", row.button, "LEFT", -8, 0)

    function row:Refresh()
        local enabled, reason
        if type(feature) == "function" then
            enabled, reason = feature()
        else
            local available
            available, reason = SUI:GetFeatureAvailability(feature)
            enabled = available and SUI:GetFeature(feature)
        end
        state:SetText(reason and Text("Недоступно", "Unavailable")
            or (enabled and Text("Включено", "On") or Text("Выключено", "Off")))
        Sintezza_Theme:Tint(state, "SetTextColor", reason and T.warning or (enabled and T.accent or T.muted))
        description:SetText(reason or detail)
    end
    B:AddRow(page, card, row)
end

local function AddIntegrationRow(page, card, definition)
    local row
    if definition.info then
        row = CreateFrame("Frame", nil, card)
        row:SetHeight(46)
        local label = W:Label(row, definition.label, 11, T.text)
        label:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -5)
        label:SetPoint("TOPRIGHT", row, "TOPRIGHT", -36, -5)
        row.detail = W:Label(row, "", 10, T.muted)
        row.detail:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -4)
        row.detail:SetPoint("RIGHT", label, "RIGHT")
        row.detail:SetWordWrap(true)
    else
        row = W:Toggle(card, definition.label, function() return SUI:GetIntegrationSetting(definition) end, function(value)
            if SUI:SetIntegrationSetting(definition, value) then page:Refresh() end
        end, " ", true)
    end
    local refresh = row.Refresh
    function row:Refresh(...)
        if page.selectedTab ~= "integrations" or not card.expanded then return end
        local available, status, detail, kind = SUI:GetIntegrationStatus(definition)
        if self.SetAvailable then self:SetAvailable(available == true) end
        self.detail:SetText(detail and (status .. " · " .. detail) or status)
        Sintezza_Theme:Tint(self.detail, "SetTextColor", kind == "warning" and T.warning
            or (kind == "active" and T.accent or T.muted))
        if refresh then return refresh(self, ...) end
    end
    B:AddRow(page, card, row)
end

local function BuildIntegrations(page)
    local tab = page.tabs.integrations
    local headerHeight = 30
    local sections = {}
    local function Layout()
        local top = -2
        for _, card in ipairs(sections) do
            card:ClearAllPoints()
            card:SetPoint("TOPLEFT", tab.body, "TOPLEFT", 0, top)
            card:SetPoint("TOPRIGHT", tab.body, "TOPRIGHT", 0, top)
            local height = card.expanded and card.openHeight or headerHeight
            card:SetHeight(height)
            for _, row in ipairs(card.widgets) do row:SetShown(card.expanded) end
            top = top - height - 10
        end
        tab.nextY = top
        tab.body:SetHeight(math.max(1, -top + 2))
        tab.scroll:RefreshRange()
    end
    for _, group in ipairs(SUI:GetIntegrationGroups()) do
        local card = CreateFrame("Frame", nil, tab.body)
        card.widgets, card.nextY = {}, -headerHeight - 6
        sections[#sections + 1] = card
        local arrow
        local button = W:Button(card, group.title, function()
            card.expanded = not card.expanded
            if card.expanded and not card.openHeight then
                for _, row in ipairs(group.rows) do AddIntegrationRow(page, card, row) end
                card.openHeight = -card.nextY + 4
            end
            arrow:SetRotation(card.expanded and -math.pi / 2 or 0)
            Layout()
            page:Refresh()
        end)
        button:SetHeight(headerHeight)
        button:SetPoint("TOPLEFT", card, "TOPLEFT", 0, 0)
        button:SetPoint("TOPRIGHT", card, "TOPRIGHT", 0, 0)
        button.text:ClearAllPoints()
        button.text:SetPoint("LEFT", button, "LEFT", 11, 0)
        button.text:SetPoint("RIGHT", button, "RIGHT", -34, 0)
        button.text:SetJustifyH("LEFT")
        arrow = T:Glyph(button, "chevron", 12, T.muted)
        arrow:SetPoint("RIGHT", button, "RIGHT", -12, 0)
    end
    Layout()
end

local function BuildPage(parent)
    local page = B:CreateTabbedPage(parent, Text("Функции", "Features"), nil, {
        { key = "overview", title = Text("Обзор", "Overview") },
        { key = "integrations", title = Text("Интеграции", "Integrations") },
    })
    local card = B:AddSection(page, "overview", Text("Модули Sintezza UI", "Sintezza UI modules"))
    AddOverviewRow(page, card, Text("Игровая панель", "Game bar"),
        Text("Системные кнопки и часы", "System buttons and clock"), "gameBar", "gameBar")
    AddOverviewRow(page, card, Text("Мини-панель", "Minimap bar"),
        Text("Часы, друзья, гильдия и показатели", "Clock, friends, guild and system stats"), "gameBarMini", "miniBar")
    AddOverviewRow(page, card, Text("Проверка рейда", "Raid check"),
        Text("Окно готовности и тест", "Ready status and test"), "raidTools", RaidCheckState, "audit")
    AddOverviewRow(page, card, Text("Рейд-инструменты", "Raid tools"),
        Text("Метки, команды и пинги", "Markers, commands and pings"), "raidTools", "raidTools", "general")
    AddOverviewRow(page, card, Text("Карта группы", "Party map"),
        Text("Метки сопартийцев", "Party markers"), "partyMap", "partyMap")
    AddOverviewRow(page, card, Text("Неймплейты", "Nameplates"),
        Text("Угроза, выбранная цель и окраска по аурам", "Threat, selected target, and aura colors"), "nameplates", "nameplates")
    AddOverviewRow(page, card, Text("Индикаторы боя", "Combat alerts"),
        Text("Вход в бой и скрытность", "Combat and stealth transitions"), "combatAlert", "combatAlert")
    AddOverviewRow(page, card, Text("Боевой текст", "Combat text"),
        Text("Шрифт цифр и надписей", "Font for numbers and labels"), "combatFont", CombatTextState)
    AddOverviewRow(page, card, Text("Иконки и откат", "Icons and cooldowns"),
        Text("Свайп, эффекты бафов и проков", "Swipe, buff and proc effects"), "cooldownMasks", "cooldownMasks")
    AddOverviewRow(page, card, SUI.isForever and Text("Панель талантов", "Talent bar") or Text("Панель специализаций", "Specialization bar"),
        SUI.isForever and Text("Быстрый доступ к талантам", "Quick access to talents")
            or Text("Специализация и добыча", "Specialization and loot"), "specBar", "specBar")
    if not SUI.isForever then
        AddOverviewRow(page, card, Text("Напоминание о телепорте", "Teleport reminder"),
            Text("Телепорт в подземелье после сбора группы", "Dungeon teleport after the group forms"),
            "teleportPrompt", "teleport")
    end
    B:FinishCard(page, "overview", card)

    BuildIntegrations(page)
    return page
end

SUI:RegisterSettingsPage({ key = "features", title = Text("Функции", "Features"), group = "ОБЩЕЕ", order = 15, builder = BuildPage })
