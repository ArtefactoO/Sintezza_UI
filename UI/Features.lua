local _, SUI = ...
local Text = SUI.Text
local T, W, B = SUI.SettingsTheme, SUI.Widgets, SUI.SettingsBuilder

local moduleOptions = {
    nameplates = { "nameplates", "auras" },
    actionBars = { "cooldownMasks", "swipe" },
    rangeFade = { "cooldownMasks", "swipe" },
    cdm = { "cooldownMasks", "swipe" },
    hideSpark = { "cooldownMasks", "swipe" },
    buffEffects = { "cooldownMasks", "buffs" },
    procEffects = { "cooldownMasks", "procs" },
    combatFont = { "combatFont", "font" },
    fonts = { "fontCompatibility", "fonts" },
    ["partyMap.markers"] = { "partyMap", "display" },
    mapWaypointControls = { "mapOptions", "display" },
    shortestPathMinimap = { "mapOptions", "display" },
    transportMap = { "mapOptions", "display" },
    ["transportMap.minimap"] = { "mapOptions", "display" },
}

local function AddIntegrationRow(page, card, definition)
    local destination = definition.destination or moduleOptions[definition.feature]
    local row
    if destination then
        row = W:NavigationRow(card, definition.label, "", Text("К настройке", "Open setting"), function()
            SUI.SettingsUI:JumpTo(destination[1], destination[2], destination[3] or definition.feature)
        end)
    elseif definition.info then
        row = W:SettingRow(card, definition.label)
    else
        row = W:Toggle(card, definition.label, function() return SUI:GetIntegrationSetting(definition) end, function(value)
            if SUI:SetIntegrationSetting(definition, value) then page:Refresh() end
        end, nil, true)
    end
    W:WithStatus(row)
    local refresh = row.Refresh
    function row:Refresh(...)
        if not card.expanded or not card:IsShown() then return end
        local available, status, detail, kind = SUI:GetIntegrationStatus(definition)
        if not destination and self.SetAvailable then self:SetAvailable(available == true) end
        if definition.description and definition.description ~= detail then
            detail = detail and (detail .. "\n\n" .. definition.description) or definition.description
        end
        if not available and kind == "warning" then
            detail = status .. (detail and ("\n\n" .. detail) or "")
            status = Text("Недоступно", "Unavailable")
        end
        W:Help(self, detail)
        self.status:SetText(status)
        Sintezza_Theme:Tint(self.status, "SetTextColor", kind == "warning" and T.warning
            or (kind == "active" and T.accent or T.muted))
        if refresh then refresh(self, ...) end
    end
    B:AddRow(page, card, row)
end

local function BuildPage(parent)
    local tabKey, headerHeight = "integrations", 31
    local page = B:CreateTabbedPage(parent, Text("Интеграции", "Integrations"),
        Text("Проверь состояние подключений и открой нужную настройку.",
            "Check which addons are connected and open their settings."), { { key = tabKey } }, true)
    local tab = page.tabs[tabKey]
    local sections, byGroup = {}, {}
    local showUnavailable, unavailableHeader
    local function Layout()
        local top = -2
        local function Place(card, inset, height)
            card:ClearAllPoints()
            card:SetPoint("TOPLEFT", tab.body, "TOPLEFT", inset, top)
            card:SetPoint("TOPRIGHT", tab.body, "TOPRIGHT", 0, top)
            card:SetHeight(height)
            card:Show()
            top = top - height - 8
        end
        local unavailable = 0
        for _, card in ipairs(sections) do
            card.available = SUI:IsIntegrationGroupAvailable(card.group)
            if card.available then
                Place(card, 0, card.expanded and card.openHeight or headerHeight)
            else
                unavailable = unavailable + 1
                card:Hide()
            end
        end
        if unavailable > 0 then
            Place(unavailableHeader, 0, headerHeight)
            unavailableHeader.arrow:SetExpanded(showUnavailable)
            if showUnavailable then
                for _, card in ipairs(sections) do
                    if not card.available then Place(card, 12, card.expanded and card.openHeight or headerHeight) end
                end
            end
        else
            unavailableHeader:Hide()
        end
        for _, card in ipairs(sections) do
            for _, row in ipairs(card.widgets) do row:SetShown(card:IsShown() and card.expanded == true) end
        end
        tab.nextY = top
        tab.body:SetHeight(math.max(tab.scroll:GetHeight(), -top + 2))
        tab.scroll:RefreshRange()
    end
    local function Disclosure(parentFrame, title, callback)
        local button = W:Button(parentFrame, title, callback)
        button:SetHeight(headerHeight)
        button.text:ClearAllPoints()
        button.text:SetPoint("LEFT", button, "LEFT", 11, 0)
        button.text:SetPoint("RIGHT", button, "RIGHT", -34, 0)
        button.text:SetJustifyH("LEFT")
        button.arrow = T:DisclosureArrow(button, 12)
        button.arrow:SetPoint("RIGHT", button, "RIGHT", -12, 0)
        return button
    end
    unavailableHeader = Disclosure(tab.body, Text("Недоступные подключения", "Unavailable connections"), function()
        showUnavailable = not showUnavailable
        page:Refresh()
    end)
    local function SetExpanded(card, expanded)
        card.expanded = expanded
        if expanded and not card.openHeight then
            for _, row in ipairs(card.group.rows) do AddIntegrationRow(page, card, row) end
            card.openHeight = -card.nextY + 4
        end
        card.button.arrow:SetExpanded(expanded)
    end
    for _, group in ipairs(SUI:GetIntegrationGroups()) do
        local card = CreateFrame("Frame", nil, tab.body)
        card.group, card.widgets, card.nextY = group, {}, -headerHeight - 6
        sections[#sections + 1], byGroup[group] = card, card
        card.button = Disclosure(card, group.title, function()
            SetExpanded(card, not card.expanded)
            page:Refresh()
        end)
        card.button:SetPoint("TOPLEFT")
        card.button:SetPoint("TOPRIGHT")
        local topics = {}
        for _, option in ipairs(group.rows) do topics[#topics + 1] = option.label end
        local description = #topics == 1 and group.rows[1].description or table.concat(topics, "\n")
        W:Help(card.button, description, card.button.text)
    end
    function page:OpenIntegrationGroup(group)
        local card = byGroup[group]
        if not card then return end
        if not SUI:IsIntegrationGroupAvailable(group) then showUnavailable = true end
        SetExpanded(card, true)
        self:Refresh()
        local window = SUI.SettingsUI.window
        if window and window.RevealSettingsControl then window:RevealSettingsControl(card.button) end
    end
    local refresh = page.Refresh
    function page:Refresh()
        Layout()
        refresh(self)
    end
    Layout()
    return page
end

SUI:RegisterSettingsPage({ key = "integrations", title = Text("Интеграции", "Integrations"), group = "СИСТЕМА", order = 10, builder = BuildPage })
