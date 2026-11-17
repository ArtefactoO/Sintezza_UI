local _, SUI = ...
local T, W = SUI.SettingsTheme, SUI.Widgets

local B = {}
SUI.SettingsBuilder = B

function B:CreateTabbedPage(parent, titleText, subtitleText, tabDefinitions, hideTabBar)
    local page, canvas = W:Page(parent)
    page.tabs, page.refreshers, page.refreshErrors = {}, {}, {}
    page.searchRows = {}
    page.selectedTab = tabDefinitions[1].key
    page.headerTitle, page.headerSubtitle = titleText, subtitleText

    local tabs
    if not hideTabBar then
        local labels, values = {}, {}
        for _, definition in ipairs(tabDefinitions) do
            if not definition.hidden then
                labels[#labels + 1], values[#values + 1] = definition.title, definition.key
            end
        end
        tabs = W:Segmented(canvas, labels, values,
            function() return page.selectedTab end,
            function(value) page:SelectTab(value) end, true)
        tabs:SetPoint("TOPLEFT", canvas, "TOPLEFT", 0, -3)
        tabs:SetPoint("TOPRIGHT", canvas, "TOPRIGHT", -2, -3)
        page.tabControl = tabs
    end

    for _, definition in ipairs(tabDefinitions) do
        local scroll, body, bar = W:ScrollFrame(canvas)
        scroll:SetPoint("TOPLEFT", tabs or canvas, tabs and "BOTTOMLEFT" or "TOPLEFT", 0, tabs and -10 or -3)
        scroll:SetPoint("BOTTOMRIGHT", canvas, "BOTTOMRIGHT", -2, 0)
        bar:SetPoint("TOPRIGHT", scroll, "TOPRIGHT", 7, 0)
        bar:SetPoint("BOTTOMRIGHT", scroll, "BOTTOMRIGHT", 7, 0)
        local tab = { key = definition.key, scroll = scroll, body = body, bar = bar, nextY = -2, cards = {} }
        page.tabs[definition.key] = tab
        scroll:SetShown(definition.key == page.selectedTab)
        scroll:HookScript("OnSizeChanged", function(frame)
            body:SetWidth(math.max(1, frame:GetWidth()))
            body:SetHeight(math.max(frame:GetHeight(), -tab.nextY + 2))
            frame:RefreshRange()
        end)
    end

    function page:SelectTab(key)
        if not self.tabs[key] then return end
        self.selectedTab = key
        for tabKey, tab in pairs(self.tabs) do
            local selected = tabKey == key
            tab.scroll:SetShown(selected)
            if not selected then
                tab.bar:Hide()
                tab.bar:EnableMouse(false)
            else
                tab.scroll:RefreshRange()
            end
        end
        if self.tabControl then self.tabControl:Refresh() end
        self:Refresh()
    end

    function page:AddRefresher(widget)
        self.refreshers[#self.refreshers + 1] = widget
        return widget
    end

    local function RefreshWidget(widget, callback)
        local ok, err = pcall(callback, widget)
        local previous = page.refreshErrors[widget]
        page.refreshErrors[widget] = not ok and err or nil
        if not ok and err ~= previous then
            SUI.Diagnostics:RecordError("settings", "refresh " .. (page.pageKey or titleText) .. "/" .. page.selectedTab, err)
        end
    end

    function page:Refresh()
        for _, widget in ipairs(self.refreshers) do
            if widget.Refresh then RefreshWidget(widget, widget.Refresh) end
        end
        if self.OnRefresh then RefreshWidget(self, self.OnRefresh) end
    end

    if tabs then tabs:Refresh() end
    return page
end

function B:AddSection(page, tabKey, title, description)
    local tab = assert(page.tabs[tabKey], "unknown settings tab")
    local card = W:Section(tab.body, title, description, "settings")
    card:SetPoint("TOPLEFT", tab.body, "TOPLEFT", 0, tab.nextY)
    card:SetPoint("TOPRIGHT", tab.body, "TOPRIGHT", 0, tab.nextY)
    card.nextY, card.widgets, card.settingsTab = -(card.headerHeight + 4), {}, tabKey
    page.searchRows[#page.searchRows + 1] = card
    tab.cards[#tab.cards + 1] = card
    return card
end


function B:BeginColumns(page, tabKey, gap, leftShare)
    local tab = assert(page.tabs[tabKey], "unknown settings tab")
    local group = CreateFrame("Frame", nil, tab.body)
    group:SetPoint("TOPLEFT", tab.body, "TOPLEFT", 0, tab.nextY)
    group:SetPoint("TOPRIGHT", tab.body, "TOPRIGHT", 0, tab.nextY)
    group.left = CreateFrame("Frame", nil, group)
    group.right = CreateFrame("Frame", nil, group)
    gap = gap or 12
    group.left:SetPoint("TOPLEFT")
    group.left:SetPoint("BOTTOMLEFT")
    group.right:SetPoint("TOPRIGHT")
    group.right:SetPoint("BOTTOMRIGHT")
    if leftShare then
        local function Resize(_, width)
            group.left:SetWidth(math.max(1, (width - gap) * leftShare))
        end
        group.right:SetPoint("TOPLEFT", group.left, "TOPRIGHT", gap, 0)
        group:HookScript("OnSizeChanged", Resize)
        Resize(group, group:GetWidth())
    else
        group.left:SetPoint("TOPRIGHT", group, "TOP", -(gap * .5), 0)
        group.right:SetPoint("TOPLEFT", group, "TOP", gap * .5, 0)
    end
    group.offsets = { left = 0, right = 0 }
    group.tab = tab
    return group
end

function B:AddColumnSection(page, group, side, title, description)
    side = side == "right" and "right" or "left"
    local column = group[side]
    local section = W:Section(column, title, description, "settings")
    section:SetPoint("TOPLEFT", column, "TOPLEFT", 0, group.offsets[side])
    section:SetPoint("TOPRIGHT", column, "TOPRIGHT", 0, group.offsets[side])
    section.nextY, section.widgets, section.settingsTab = -(section.headerHeight + 4), {}, group.tab.key
    page.searchRows[#page.searchRows + 1] = section
    section.columnGroup, section.columnSide = group, side
    return section
end

function B:AddRow(page, card, row)
    row:SetPoint("TOPLEFT", card, "TOPLEFT", 14, card.nextY)
    row:SetPoint("TOPRIGHT", card, "TOPRIGHT", -14, card.nextY)
    card.nextY = card.nextY - row:GetHeight()
    card.widgets[#card.widgets + 1] = row
    if card.settingsTab and (row.label or row.settingsID) then
        row.settingsTab = card.settingsTab
        page.searchRows[#page.searchRows + 1] = row
    end
    page:AddRefresher(row)
    return row
end

function B:FinishCard(page, tabKey, card)
    local tab = page.tabs[tabKey]
    local height = math.max(card.headerHeight + 28, -card.nextY + 8)
    card:SetHeight(height)
    if card.columnGroup then
        local group, side = card.columnGroup, card.columnSide
        group.offsets[side] = group.offsets[side] - height - 10
    else
        tab.nextY = tab.nextY - height - 10
        tab.body:SetHeight(math.max(1, -tab.nextY + 2))
    end
    return card
end


function B:FinishColumns(page, tabKey, group)
    local tab = page.tabs[tabKey]
    local height = math.max(1, -math.min(group.offsets.left, group.offsets.right) - 10)
    group:SetHeight(height)
    tab.nextY = tab.nextY - height - 10
    tab.body:SetHeight(math.max(1, -tab.nextY + 2))
    return group
end

function B:AddFooter(page, tabKey, actions)
    local tab = assert(page.tabs[tabKey], "unknown settings tab")
    local footer = CreateFrame("Frame", nil, tab.body)
    footer:SetHeight(34)
    footer:SetPoint("TOPLEFT", tab.body, "TOPLEFT", 0, tab.nextY)
    footer:SetPoint("TOPRIGHT", tab.body, "TOPRIGHT", 0, tab.nextY)
    local previous
    for _, action in ipairs(actions or {}) do
        local button = W:Button(footer, action.title, action.callback, action.accent)
        button:SetSize(action.width or 132, 26)
        if previous then button:SetPoint("LEFT", previous, "RIGHT", 8, 0) else button:SetPoint("LEFT", footer, "LEFT", 0, 0) end
        previous = button
    end
    tab.nextY = tab.nextY - 44
    tab.body:SetHeight(math.max(1, -tab.nextY + 2))
    return footer
end

function B:SetPageFooter(page, actions)
    if page.pageFooter then return page.pageFooter end
    local footer = CreateFrame("Frame", nil, page.canvas)
    footer:SetPoint("BOTTOMLEFT", page.canvas, "BOTTOMLEFT", 0, 0)
    footer:SetPoint("BOTTOMRIGHT", page.canvas, "BOTTOMRIGHT", 0, 0)
    footer:SetHeight(34)
    local previous
    for _, action in ipairs(actions or {}) do
        local button = W:Button(footer, action.title, action.callback, action.accent)
        button:SetSize(action.width or 132, 26)
        if previous then button:SetPoint("LEFT", previous, "RIGHT", 8, 0) else button:SetPoint("LEFT", footer, "LEFT", 0, 0) end
        previous = button
    end
    for _, tab in pairs(page.tabs) do
        tab.scroll:ClearAllPoints()
        local topAnchor = page.pinnedFrame or page.tabControl
        tab.scroll:SetPoint("TOPLEFT", topAnchor or page.canvas,
            topAnchor and "BOTTOMLEFT" or "TOPLEFT", 0, topAnchor and -10 or -3)
        tab.scroll:SetPoint("BOTTOMRIGHT", footer, "TOPRIGHT", -2, 6)
    end
    page.pageFooter = footer
    return footer
end


function B:SetPinnedFrame(page, frame)
    page.pinnedFrame = frame
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", page.tabControl or page.canvas,
        page.tabControl and "BOTTOMLEFT" or "TOPLEFT", 0, page.tabControl and -10 or -3)
    frame:SetWidth(math.max(1, page.canvas:GetWidth()))
    page.canvas:HookScript("OnSizeChanged", function(canvas)
        frame:SetWidth(math.max(1, canvas:GetWidth()))
    end)
    for _, tab in pairs(page.tabs) do
        tab.scroll:ClearAllPoints()
        tab.scroll:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 0, -10)
        if page.pageFooter then
            tab.scroll:SetPoint("BOTTOMRIGHT", page.pageFooter, "TOPRIGHT", -2, 6)
        else
            tab.scroll:SetPoint("BOTTOMRIGHT", page.canvas, "BOTTOMRIGHT", -2, 0)
        end
    end
    return frame
end
