local _, SUI = ...
local M, T, W, B, Text = SUI:GetModule("combatFont"), SUI.SettingsTheme, SUI.Widgets, SUI.SettingsBuilder, SUI.Text

local sources = {
    game = Text("Клиент", "Game client"),
    bundled = Text("Встроенный", "Bundled"),
    shared = "SharedMedia",
    custom = Text("Свой", "Custom"),
}
local unknown = Text("Покрытие не проверено", "Coverage unverified")
local locale = GetLocale()
local alphabetKey = locale == "ruRU" and "russian" or (locale == "enUS" or locale == "enGB") and "latin"
local alphabetSize = locale == "ruRU" and 66 or 52
local cyrillic = {}
do
    local lower = "абвгде\209\145жзийклмнопрстуфхцчшщъыьэюя"
    local upper = "АБВГДЕ\208\129ЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯ"
    for index = 1, #upper, 2 do cyrillic[upper:sub(index, index + 1)] = lower:sub(index, index + 1) end
end

local function SearchKey(value)
    return (value:lower():gsub("[\208\209][\128-\191]", cyrillic)):gsub("\209\145", "е")
end

local relog = Text("Для цифр над целью выйди до выбора персонажа и войди снова.",
    "For numbers above targets, log out to character selection and log back in.")
local statuses = {
    combat = Text("Применится после выхода из боя.", "Changes apply after combat."),
    unsupported = Text("Боевой шрифт недоступен в этой версии клиента.", "The combat font is unavailable on this client."),
    missing = Text("Выбранный файл шрифта не загрузился.", "The selected font file could not be loaded."),
    native = Text("Используется шрифт клиента.", "Using the game client font."),
    applied = Text("Шрифт сохранен. ", "Font saved. ") .. relog,
    restored = Text("Прежний шрифт восстановлен. ", "Previous font restored. ") .. relog,
}
local owners = {
    FontMagic = Text("Боевые цифры переопределяет FontMagic. Отключи его и войди в персонажа снова.",
        "FontMagic overrides combat numbers. Disable it and log back in."),
}

local function PreviewFont(label, path, size, flags)
    if path then
        local ok, result = pcall(label.SetFont, label, path, size, flags)
        if ok and (not issecretvalue or not issecretvalue(result)) and result ~= false then return end
    end
    T:Font(label, size, flags)
end

local function BuildPage(parent)
    local title = Text("Боевой текст", "Combat text")
    local page = B:CreateTabbedPage(parent, title, nil, {
        { key = "font", title = Text("Шрифт", "Font") },
    })
    local toggleCard = B:AddSection(page, "font", title)
    local enabled = W:Toggle(toggleCard, Text("Переопределять боевой шрифт", "Override combat text font"),
        function() return M:Profile().enabled end, function(value)
            M:Profile().enabled = value
            M:Update()
            page:Refresh()
        end)
    B:AddRow(page, toggleCard, enabled)
    local alerts = W:Toggle(toggleCard, Text("Использовать шрифт в сигналах Sintezza", "Use font in Sintezza alerts"),
        function() return M:Profile().useInAlerts ~= false end, function(value)
            M:Profile().useInAlerts = value
            M:Update()
            page:Refresh()
        end)
    B:AddRow(page, toggleCard, alerts)
    B:FinishCard(page, "font", toggleCard)

    local columns = B:BeginColumns(page, "font")
    local catalog = B:AddColumnSection(page, columns, "left", Text("Шрифты", "Fonts"))
    local search = W:EditBox(catalog, Text("Поиск по шрифтам", "Search fonts"), function() end)
    search:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    search:HookScript("OnHide", function(self) self:ClearFocus() end)
    B:AddRow(page, catalog, search)
    local coverage = "all"
    local filter = W:ChoiceRow(catalog, Text("Покрытие", "Coverage"), {
        all = Text("Все шрифты", "All fonts"), russian = Text("С покрытием ruRU", "Russian coverage"),
    }, function() return coverage end, function(value)
        coverage = value
        page:Refresh()
    end, { all = 1, russian = 2 })
    B:AddRow(page, catalog, filter)
    local resultFrame = CreateFrame("Frame", nil, catalog)
    resultFrame:SetHeight(226)
    B:AddRow(page, catalog, resultFrame)
    local list, listBody, scrollBar = W:ScrollFrame(resultFrame, nil, 44)
    list:SetPoint("TOPLEFT", 0, -4)
    list:SetPoint("BOTTOMRIGHT", -10, 0)
    scrollBar:SetPoint("TOPLEFT", list, "TOPRIGHT", 3, 0)
    scrollBar:SetPoint("BOTTOMLEFT", list, "BOTTOMRIGHT", 3, 0)
    list:HookScript("OnSizeChanged", function(_, width) listBody:SetWidth(math.max(width, 1)) end)
    local empty = W:Label(listBody, Text("Шрифты не найдены.", "No matching fonts."), 11, T.muted)
    empty:SetPoint("TOPLEFT", 4, -8)
    B:FinishCard(page, "font", catalog)

    local preview = B:AddColumnSection(page, columns, "right", Text("Предпросмотр", "Preview"))
    local sample = CreateFrame("Frame", nil, preview, "BackdropTemplate")
    sample:SetHeight(113)
    T:Backdrop(sample, T.input, T.lineSoft)
    local damage = W:Label(sample, "12 840", 32, T.accent)
    damage:SetPoint("TOP", 0, -16)
    local effect = W:Label(sample, locale == "ruRU" and "Сопротивление · +486" or "Resist · +486", 14, T.text)
    effect:SetPoint("TOP", damage, "BOTTOM", 0, -5)
    B:AddRow(page, preview, sample)
    local coverageText = W:Label(preview, "", 11, T.muted)
    coverageText:SetHeight(28)
    coverageText:SetJustifyH("LEFT")
    B:AddRow(page, preview, coverageText)
    local status = W:Label(preview, "", 11, T.muted)
    status:SetHeight(49)
    status:SetJustifyH("LEFT")
    status:SetWordWrap(true)
    B:AddRow(page, preview, status)

    local selected, saved = "DEFAULT", nil
    local function ApplySelection(id)
        local profile = M:Profile()
        profile.font = id
        profile.enabled = id ~= "DEFAULT"
        saved, selected = id, id
        M:Update()
        page:Refresh()
    end
    local apply = W:Button(preview, Text("Применить", "Apply"), function() ApplySelection(selected) end, true)
    B:AddRow(page, preview, apply)
    local reset = W:Button(preview, Text("Вернуть прежний шрифт", "Restore previous font"), function() ApplySelection("DEFAULT") end)
    B:AddRow(page, preview, reset)
    B:FinishCard(page, "font", preview)
    B:FinishColumns(page, "font", columns)

    local custom = B:AddSection(page, "font", Text("Свои шрифты", "Custom fonts"),
        Text("Слоты 1.ttf–20.ttf в Sintezza_UI/Media/CombatFonts/Custom. Проверка покрытия описана в README.",
            "Slots 1.ttf–20.ttf in Sintezza_UI/Media/CombatFonts/Custom. See the README for coverage checks."))
    B:FinishCard(page, "font", custom)
    local shared = B:AddSection(page, "font", Text("Шрифты интерфейса и заголовков", "Interface and heading fonts"))
    B:AddRow(page, shared, W:ActionRow(shared, "Sintezza Theme", Text("Открыть", "Open"),
        function() Sintezza_Theme:OpenSettings() end))
    B:FinishCard(page, "font", shared)

    local rows = {}
    local displayed
    local function Count(count, maximum)
        if type(count) ~= "number" then return Text("не проверено", "unverified") end
        local result = ("%d/%d"):format(count, maximum)
        if count < maximum then return result .. Text(" (неполное)", " (incomplete)") end
        return result
    end
    local function Details(font)
        local letters = alphabetKey and font[alphabetKey]
        return Text("Цифры ", "Digits ") .. Count(font.digits, 10) .. " · "
            .. Text("Буквы ", "Letters ") .. Count(letters, alphabetSize)
    end
    function page:OnRefresh()
        local profile, owner = M:Profile(), M:OtherOwner()
        local currentID = M:CanonicalID(profile.font)
        if currentID ~= saved then saved, selected = currentID, currentID end
        local words = SearchKey(search:GetText()):match("^%s*(.-)%s*$")
        local available, current = {}, nil
        for _, font in ipairs(M:ListFonts()) do
            if font.id == selected then current = font end
            if (coverage == "all" or font.russian == 66 or font.id == "DEFAULT") and SearchKey(font.label):find(words, 1, true) then
                available[#available + 1] = font
            end
        end
        for index, font in ipairs(available) do
            local row = rows[index]
            if not row then
                row = W:Button(listBody, "", function(self)
                    selected = self.fontID
                    page:Refresh()
                end)
                row:SetHeight(39)
                row:SetPoint("TOPLEFT", 0, -(index - 1) * 42)
                row:SetPoint("TOPRIGHT", 0, -(index - 1) * 42)
                row.text:SetJustifyH("LEFT")
                row.text:SetPoint("LEFT", 8, 8)
                row.meta = W:Label(row, "", 9, T.muted)
                row.meta:SetPoint("BOTTOMLEFT", 8, 4)
                rows[index] = row
            end
            row.fontID = font.id
            row.text:SetText(font.label)
            row.meta:SetText(sources[font.source] .. " · " .. Details(font))
            T:PaintButton(row, font.id == selected)
            row:Show()
        end
        for index = #available + 1, #rows do rows[index]:Hide() end
        listBody:SetHeight(math.max(26, #available * 42))
        list:RefreshRange()
        empty:SetShown(#available == 0)
        if displayed ~= current or current and current.source == "game" then
            local path = current and current.path or M:NativeFont()
            PreviewFont(damage, path, 32, "OUTLINE")
            PreviewFont(effect, path, 14, "OUTLINE")
            displayed = current
        end
        coverageText:SetText(current and Details(current) or unknown)
        local pendingSelection = current ~= nil and selected ~= "DEFAULT" and (not profile.enabled or selected ~= currentID)
        local hasOverride = profile.enabled and currentID ~= "DEFAULT"
        alerts:SetAvailable(not not hasOverride)
        apply:SetEnabled(current ~= nil and selected ~= "DEFAULT")
        reset:SetEnabled(not not hasOverride)
        local message = statuses[M.status] or statuses.native
        if owner and (hasOverride or pendingSelection) then
            message = owners[owner]
        elseif pendingSelection then
            message = Text("Предпросмотр", "Preview")
        elseif M.status == "combat" then
            message = statuses.combat
        end
        status:SetText(message or "")
    end
    search:HookScript("OnTextChanged", function()
        list:SetVerticalScroll(0)
        page:Refresh()
    end)
    page:Refresh()
    return page
end

SUI:RegisterSettingsPage({
    key = "combatFont", title = Text("Боевой текст", "Combat text"),
    group = "ЭЛЕМЕНТЫ ИНТЕРФЕЙСА", order = 15, builder = BuildPage,
})
