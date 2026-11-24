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
local SearchKey = SUI.SettingsSearchKey

local relog = Text("Для цифр над целью выйди до выбора персонажа и войди снова.",
    "For numbers above targets, log out to character selection and log back in.")
local statuses = {
    combat = Text("Применится после выхода из боя.", "Changes apply after combat."),
    unsupported = Text("Боевой шрифт недоступен в этой версии клиента.", "The combat font is unavailable on this client."),
    missing = Text("Выбранный файл шрифта не загрузился.", "The selected font file could not be loaded."),
    native = Text("Используется шрифт клиента.", "Using the game client font."),
    applied = Text("Шрифт сохранен", "Font saved"),
    restored = Text("Прежний шрифт восстановлен", "Previous font restored"),
}
local owners = {
    FontMagic = Text("Боевые цифры переопределяет FontMagic. Отключи его и войди в персонажа снова.",
        "FontMagic overrides combat numbers. Disable it and log back in."),
}

local onSelf = {
    { "floatingCombatTextDodgeParryMiss_v2", "Уклонения, парирования и промахи", "Dodges, parries and misses" },
    { "floatingCombatTextDamageReduction_v2", "Снижение урона", "Damage reduction",
        "Показывает блокирование, сопротивление и поглощение урона.", "Shows blocks, resists and absorbs." },
    { "floatingCombatTextFriendlyHealers_v2", "Имена лекарей", "Healer names" },
    { "floatingCombatTextCombatHealingAbsorbSelf_v2", "Щиты на себе", "Shields on you" },
    { "floatingCombatTextCombatState_v2", "Вход в бой и выход из боя", "Entering and leaving combat" },
    { "floatingCombatTextLowManaHealth_v2", "Мало здоровья или маны", "Low health or mana" },
    { "floatingCombatTextEnergyGains_v2", "Получение ресурсов", "Power gains" },
    { "floatingCombatTextPeriodicEnergyGains_v2", "Периодическое получение ресурсов", "Periodic power gains" },
    { "floatingCombatTextComboPoints_v2", "Очки серии приемов", "Combo points" },
    { "floatingCombatTextReactives_v2", "Срабатывания способностей", "Reactive abilities" },
    { "floatingCombatTextAuras_v2", "Эффекты на себе", "Auras on you" },
    { "floatingCombatTextRepChanges_v2", "Изменения репутации", "Reputation changes" },
    { "floatingCombatTextHonorGains_v2", "Получение чести", "Honor gains" },
}

local onTarget = {
    { "floatingCombatTextCombatDamage_v2", "Исходящий урон", "Outgoing damage" },
    { "floatingCombatTextCombatDamageAllAutos_v2", "Все автоатаки", "All auto-attacks" },
    { "floatingCombatTextCombatLogPeriodicSpells_v2", "Периодические эффекты", "Periodic effects" },
    { "floatingCombatTextPetMeleeDamage_v2", "Автоатаки питомца", "Pet melee damage" },
    { "floatingCombatTextPetSpellDamage_v2", "Урон способностей питомца", "Pet spell damage" },
    { "floatingCombatTextCombatHealing_v2", "Исходящее лечение", "Outgoing healing" },
    { "floatingCombatTextCombatHealingAbsorbTarget_v2", "Щиты на цели", "Shields on targets" },
    { "floatingCombatTextSpellMechanics_v2", "Эффекты на цели", "Target effects" },
    { "floatingCombatTextSpellMechanicsOther_v2", "Эффекты других игроков", "Other players’ target effects" },
    { "classicStyleWorldText", "Классический стиль цифр", "Classic-style numbers",
        "После смены стиля выполни /reload.", "Run /reload after changing the style." },
}

local function AddCombatTextToggle(page, section, key, ru, en, helpRu, helpEn)
    if not M:CanSetCombatTextCVar(key) then return end
    local row = W:Toggle(section, Text(ru, en), function()
        return C_CVar.GetCVarBool(key)
    end, function(value)
        if not M:SetCombatTextCVar(key, value) then
            SUI:Print(Text("Не удалось изменить настройку боевого текста.", "Could not change the combat text setting."))
        end
        page:Refresh()
    end, helpRu and Text(helpRu, helpEn), true)
    W:BindAvailability(row, function()
        if InCombatLockdown() then
            return false, Text("Настройка доступна вне боя.", "Available outside combat.")
        end
        return true
    end)
    B:AddRow(page, section, row)
end

local function BuildDisplay(page)
    local columns = B:BeginColumns(page, "display")
    local playerText = B:AddColumnSection(page, columns, "left", Text("Текст на себе", "Text on me"))
    AddCombatTextToggle(page, playerText, "enableFloatingCombatText", "Прокручиваемый текст для себя", "Scrolling combat text for self")
    B:AddRow(page, playerText, W:Toggle(playerText, Text("Скрывать входящее лечение", "Hide incoming healing"),
        function() return M:Profile().hideIncomingHealing == true end, function(value)
            M:Profile().hideIncomingHealing = value
            M:Update()
            page:Refresh()
        end, Text("Скрывает цифры самолечения и лечения от других игроков в стандартном тексте боя.",
            "Hides numbers from self-healing and healing received from other players in Blizzard combat text."), true))
    for _, option in ipairs(onSelf) do AddCombatTextToggle(page, playerText, unpack(option)) end
    B:FinishCard(page, "display", playerText)

    local target = B:AddColumnSection(page, columns, "right", Text("Текст на цели", "Text on target"))
    for _, option in ipairs(onTarget) do AddCombatTextToggle(page, target, unpack(option)) end
    B:FinishCard(page, "display", target)
    B:FinishColumns(page, "display", columns)
end

local function PreviewFont(label, path, size, flags)
    if path then
        local ok, result = pcall(label.SetFont, label, path, size, flags)
        if ok and (not issecretvalue or not issecretvalue(result)) and result ~= false then return end
    end
    local fallback = Sintezza_Theme.Theme:GetGameTextFont()
    if fallback and fallback ~= path then label:SetFont(fallback, size, flags) end
end

local function BuildPage(parent)
    local title = Text("Боевой текст", "Combat text")
    local tabs = { { key = "font", title = Text("Шрифт", "Font") } }
    if SUI.isForever then tabs[#tabs + 1] = { key = "display", title = Text("Отображение", "Display") } end
    local page = B:CreateTabbedPage(parent, title, nil, tabs, not SUI.isForever)
    if SUI.isForever then BuildDisplay(page) end
    local controls = B:BeginColumns(page, "font", 8)
    local enabled = W:Toggle(controls, Text("Заменять боевой шрифт", "Override combat font"),
        function() return M:Profile().enabled end, function(value)
            M:Profile().enabled = value
            M:Update()
            page:Refresh()
        end, Text("Использует выбранный шрифт для боевых цифр и текста клиента.",
            "Uses the selected font for the client’s combat numbers and text."), true, "inline")
    enabled:SetWidth(212)
    enabled:SetPoint("TOPLEFT", controls, "TOPLEFT", 14, 0)
    local alerts = W:Toggle(controls, Text("Шрифт в сигналах", "Font in alerts"),
        function() return M:Profile().useInAlerts ~= false end, function(value)
            M:Profile().useInAlerts = value
            M:Update()
            page:Refresh()
        end, Text("Использует выбранный шрифт для надписей боя, скрытности, здоровья и агро.",
            "Uses the selected font for combat, stealth, health and aggro alert captions."), true, "inline")
    alerts:SetWidth(176)
    alerts:SetPoint("LEFT", enabled, "RIGHT", 8, 0)
    for _, toggle in ipairs({ enabled, alerts }) do
        toggle.settingsTab = "font"
        page.searchRows[#page.searchRows + 1] = toggle
        page:AddRefresher(toggle)
    end
    controls.offsets.left = -enabled:GetHeight() - 10
    B:FinishColumns(page, "font", controls)

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
    B:AddRow(page, catalog, W:Help(filter,
        Text("Покрытие показывает, сколько знаков есть в файле шрифта. Для русского текста проверяются 10 цифр и 66 букв. Фильтр оставляет шрифты с полным набором русских букв.",
            "Coverage counts the characters in the font file. Russian checks include 10 digits and 66 letters. The filter shows fonts with the complete Russian alphabet.")))
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
    local native = M:NativeFont()
    local damage = sample:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    PreviewFont(damage, native, 32, "OUTLINE")
    damage:SetText("12 840")
    damage:SetPoint("TOP", 0, -16)
    Sintezza_Theme:Tint(damage, "SetTextColor", T.accent)
    local example = locale == "ruRU" and "Сопротивление · +486" or "Resist · +486"
    local effect = sample:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    PreviewFont(effect, native, 14, "OUTLINE")
    effect:SetPoint("TOP", damage, "BOTTOM", 0, -5)
    effect:SetPoint("LEFT", sample, "LEFT", 12, 0)
    effect:SetPoint("RIGHT", sample, "RIGHT", -12, 0)
    effect:SetJustifyH("CENTER")
    effect:SetWordWrap(true)
    if effect.SetNonSpaceWrap then effect:SetNonSpaceWrap(true) end
    if effect.SetMaxLines then effect:SetMaxLines(2) end
    Sintezza_Theme:Tint(effect, "SetTextColor", T.text)
    effect:SetText(example)
    B:AddRow(page, preview, sample)

    local testText = W:EditBox(preview, Text("Текст для проверки шрифта", "Type text to test the font"), function() end)
    testText:SetMaxLetters(80)
    testText:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    testText:HookScript("OnHide", function(self) self:ClearFocus() end)
    testText:HookScript("OnTextChanged", function(self)
        local value = self:GetText()
        effect:SetText(value == "" and example or (value:gsub("|", "||")))
    end)
    B:AddRow(page, preview, testText)
    local coverageText = W:Label(preview, "", 11, T.muted)
    coverageText:SetHeight(28)
    coverageText:SetJustifyH("LEFT")
    B:AddRow(page, preview, coverageText)
    local status = W:SettingRow(preview, "")
    status.label:SetPoint("RIGHT", status, "RIGHT", -10, 0)
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
        Text("Свои файлы можно положить в Sintezza_UI/Media/CombatFonts/Custom под именами 1.ttf–20.ttf. Если покрытие файла неизвестно, используй поле под предпросмотром.",
            "Add files named 1.ttf–20.ttf to Sintezza_UI/Media/CombatFonts/Custom. If coverage is unverified, try characters in the field below the preview."))
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
        local hint
        if owner and (hasOverride or pendingSelection) then
            message = Text("Шрифт задает другой аддон", "Font managed by another addon")
            hint = owners[owner]
        elseif pendingSelection then
            message = Text("Предпросмотр", "Preview")
        elseif M.status == "combat" then
            message = statuses.combat
        elseif M.status == "applied" or M.status == "restored" then
            hint = relog
        end
        status.label:SetText(message or "")
        W:Help(status, hint)
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
