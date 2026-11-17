local _, SUI = ...
local UI, T, W, Text = SUI.SettingsUI, SUI.SettingsTheme, SUI.Widgets, SUI.Text
local SearchKey = SUI.SettingsSearchKey
local MAX_RESULTS = 8

-- The page and tab are searchable before the corresponding frames are built.
local shortcuts = {
    { "gameBar", "elements", Text("Состав и порядок кнопок", "Button assignment and order"), Text("переставить таланты сумки", "move talents bags") },
    { "gameBar", "general", Text("Прозрачность игровой панели", "Game bar transparency"), Text("яркость непрозрачность", "brightness opacity"), "gameBarTransparency" },
    { "gameBar", "appearance", Text("Прозрачность фона игровой панели", "Game bar background transparency"), Text("цвет фона opacity", "background color opacity"), "gameBarBackdropTransparency" },
    { "gameBarMini", "general", Text("Прозрачность панели под миникартой", "Minimap bar transparency"), Text("яркость непрозрачность", "brightness opacity"), "miniBarTransparency" },
    { "gameBarMini", "appearance", Text("Прозрачность фона панели под миникартой", "Minimap bar background transparency"), Text("цвет фона opacity", "background color opacity"), "miniBarBackdropTransparency" },
    { "gameBarMini", "layout", Text("Размеры списков друзей и гильдии", "Friend and guild list dimensions"), Text("геометрия ширина отступ строки", "layout width padding rows") },
    { "gameBarMini", "general", Text("Показывать Zz в зоне отдыха", "Show Zz in rest areas"),
        Text("анимация отдыха таверна", "rest animation inn"), "miniResting" },
    { "gameBarMini", "layout", Text("Размер Zz", "Zz size"), Text("размер индикатора отдыха", "resting indicator size"), "miniRestingSize" },
    { "gameBarMini", "general", Text("Показывать FPS", "Show frame rate"), "FPS", "miniFPS" },
    { "gameBarMini", "general", Text("Показывать задержку", "Show latency"), Text("пинг мс", "ping ms"), "miniLatency" },
    { "gameBarMini", "general", Text("Масштаб панели", "Bar scale"), Text("размер панели под миникартой", "minimap bar size"), "miniScale" },
    { "gameBarMini", "appearance", Text("Оформление панели под миникартой", "Minimap bar appearance"),
        Text("цвет фон шрифты счетчики рамка", "color background fonts counts border") },
    { "gameBarMini", "elements", Text("Списки друзей и гильдии", "Friends and guild lists"),
        Text("группировка контекст онлайн сервер", "grouping location online realm") },
    { "gameBarMini", "advanced", Text("Точное положение панели под миникартой", "Minimap bar position"),
        Text("смещение координаты x y задержка исчезновения", "offset coordinates x y fade delay") },
    { "combatAlert", "combat", Text("Сигнал боя", "Combat alert"), Text("в бой мечи предпросмотр", "combat swords preview") },
    { "combatAlert", "stealth", Text("Сигнал скрытности", "Stealth alert"), Text("глаз следы маска дымка", "eye tracks mask mist") },
    { "combatAlert", "healthAlert", Text("Порог здоровья", "Health threshold"), Text("мало здоровья критическое", "low health critical") },
    { "combatAlert", "aggroAlert", Text("Сигнал агро", "Aggro alert"), Text("угроза подземелье рейд", "threat dungeon raid") },
    { "nameplates", "auras", Text("Правила окраски по дебаффам", "Debuff color rules"), Text("дебаффы ауры доты", "debuffs auras dots") },
    { "cooldownMasks", "swipe", Text("Форма затемнения при откате", "Cooldown swipe shape"),
        Text("свайп панели команд cd swipe opacity", "action bars cooldown opacity"), "actionBars" },
    { "cooldownMasks", "buffs", Text("Пороги стаков бафов", "Buff stack thresholds"), Text("звук пульсация", "sound pulse") },
    { "cooldownMasks", "procs", Text("Эффекты проков", "Proc effects") },
    { "fontCompatibility", "elements", Text("Рамки по элементам", "Frames by element"),
        Text("форма размеры окантовка", "shape size border") },
    { "fontCompatibility", "rounded", Text("Рамки игроков", "Unit frames"), Text("интеграции форма окантовка", "integrations shape border") },
    { "fontCompatibility", "fonts", Text("Кириллица и регистрация шрифтов", "Cyrillic font registration"), "SharedMedia" },
    { "raidTools", "audit", Text("Проверка готовности рейда", "Raid ready check"), Text("тест проверка готовность", "test raid readiness") },
    { "raidTools", "panels", Text("Рейдовые панели и метки", "Raid bars and markers"), Text("пинги таймер атаки пулл", "ping pull countdown") },
    { "mapOptions", "display", Text("Личная метка Sintezza UI", "Sintezza UI waypoint"), Text("точка ctrl лкм пкм", "pin ctrl click"), "mapWaypointControls" },
    { "mapOptions", "display", Text("Золотые точки маршрута", "Gold route dots"), Text("Shortest Path анимация", "Shortest Path animation"), "shortestPathMinimap" },
    { "mapOptions", "display", Text("Цвет точек маршрута", "Route dot color"), "Shortest Path", "routeDotColor" },
    { "mapOptions", "display", Text("Размер точек маршрута", "Route dot size"), "Shortest Path", "routeDotSize" },
    { "mapOptions", "display", Text("Таймеры транспорта", "Transport timers"), Text("причал корабль дирижабль", "dock boat zeppelin"), "transportMap" },
    { "profiles", nil, Text("Управление профилями", "Manage profiles"), Text("копия создать удалить сброс переименовать", "copy create delete reset rename") },
    { "windowAppearance", "general", Text("Анимация наведения и настройки окна", "Hover animations and window settings"),
        Text("масштаб кнопка миникарты цвет окно", "scale minimap button color window") },

}

local function RowLabel(row)
    local label = row.label or row.title
    local value = label and label.GetText and label:GetText()
    if type(value) == "string" and not (issecretvalue and issecretvalue(value)) and value ~= "" then return value end
end

function UI:FindSettings(query)
    query = SearchKey(query):match("^%s*(.-)%s*$")
    if query == "" then return {} end
    local results, seen = {}, {}
    local function Add(page, tab, label, keywords, id, row, group)
        if not label or not self.definitions[page] then return end
        local name = SearchKey(label)
        local path = self.definitions[page].title
        local searchable = name .. " " .. SearchKey((keywords or "") .. " " .. (path or ""))
        for word in query:gmatch("%S+") do
            if not searchable:find(word, 1, true) then return end
        end
        local identity = page .. "|" .. (tab or "") .. "|" .. (id or name)
        if seen[identity] then return end
        seen[identity] = true
        local score = name == query and 3 or (name:find(query, 1, true) and 2 or 1)
        results[#results + 1] = { page = page, tab = tab, label = label, path = path, id = id, row = row, group = group, score = score }
    end
    for _, definition in ipairs(self.navEntries or {}) do Add(definition.key, nil, definition.title) end
    for _, shortcut in ipairs(shortcuts) do Add(unpack(shortcut, 1, 5)) end
    for _, group in ipairs(SUI:GetIntegrationGroups()) do
        Add("integrations", "integrations", group.title, nil, nil, nil, group)
        for _, entry in ipairs(group.rows) do
            if not entry.client or (entry.client == "forever") == SUI.isForever then
                Add("integrations", "integrations", entry.label, group.title, nil, nil, group)
            end
        end
    end
    for pageKey, page in pairs(self.pages) do
        if pageKey ~= "dashboard" then
            for _, row in ipairs(page.searchRows or {}) do Add(pageKey, row.settingsTab, RowLabel(row), nil, row.settingsID, row) end
        end
    end
    table.sort(results, function(a, b)
        if a.score ~= b.score then return a.score > b.score end
        if a.label ~= b.label then return a.label < b.label end
        if a.path ~= b.path then return a.path < b.path end
        return (a.tab or "") < (b.tab or "")
    end)
    return results
end

function UI:ClearSearch()
    if self.searchResults then self.searchResults:Hide() end
    if self.searchBox then
        self.searchBox:SetText("")
        self.searchBox:ClearFocus()
    end
end

function UI:JumpTo(pageKey, tab, id, row, group)
    self:ClearSearch()
    local page = self:SelectPage(pageKey, tab)
    if group and page.OpenIntegrationGroup then page:OpenIntegrationGroup(group) end
    if id and not row then
        for _, candidate in ipairs(page.searchRows or {}) do
            if candidate.settingsID == id and candidate.settingsTab == page.selectedTab then
                row = candidate
                break
            end
        end
    end
    if not (row and row:IsVisible()) then return end
    if self.window.RevealSettingsControl then self.window:RevealSettingsControl(row) end
    local highlight = self.searchHighlight
    if not highlight then
        highlight = CreateFrame("Frame", nil, self.window, "BackdropTemplate")
        highlight:EnableMouse(false)
        self.searchHighlight = highlight
    end
    highlight:SetParent(row)
    highlight:SetFrameLevel(row:GetFrameLevel() + 2)
    highlight:ClearAllPoints()
    highlight:SetPoint("TOPLEFT", row, "TOPLEFT", -2, 1)
    highlight:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 2, -1)
    T:Backdrop(highlight, { 0, 0, 0, 0 }, T.accent)
    highlight:Show()
end

function UI:BuildSearch(header)
    local dropdown, buttons, matches
    local function Activate(index)
        local match = matches and matches[index]
        if match then self:JumpTo(match.page, match.tab, match.id, match.row, match.group) end
    end
    local box = W:EditBox(header, Text("Поиск по настройкам", "Search settings"), function() end)
    box:SetSize(292, 29)
    box:SetPoint("RIGHT", header, "RIGHT", -47, 0)
    box:SetTextInsets(30, 9, 0, 0)
    box.placeholder:SetPoint("LEFT", box, "LEFT", 30, 0)
    T:Backdrop(box, T.input, T.lineSoft)
    box:HookScript("OnEditFocusLost", function(frame)
        Sintezza_Theme:Tint(frame, "SetBackdropBorderColor", T.lineSoft)
    end)
    Sintezza_Theme:TrackAppearance(box, "state", function(frame)
        if frame:HasFocus() then
            frame:SetBackdropBorderColor(T.accent[1], T.accent[2], T.accent[3], .55)
        end
    end)
    local icon = box:CreateTexture(nil, "OVERLAY")
    icon:SetTexture("Interface\\Common\\UI-Searchbox-Icon")
    icon:SetPoint("LEFT", 9, 0)
    icon:SetSize(14, 14)
    Sintezza_Theme:Tint(icon, "SetVertexColor", T.muted)
    box:SetMaxLetters(72)
    dropdown = CreateFrame("Frame", nil, header, "BackdropTemplate")
    dropdown:SetPoint("TOPRIGHT", box, "BOTTOMRIGHT", 0, -4)
    dropdown:SetWidth(414)
    dropdown:SetFrameLevel(header:GetFrameLevel() + 35)
    dropdown:EnableMouse(true)
    T:Backdrop(dropdown, T.header, T.line)
    dropdown:Hide()
    buttons = {}
    local empty = W:Label(dropdown, Text("Ничего не найдено", "No matching settings"), 11, T.muted)
    empty:SetPoint("TOPLEFT", 11, -9)
    for index = 1, MAX_RESULTS do
        local line = index
        local button = W:Button(dropdown, "", function() Activate(line) end)
        button:SetHeight(28)
        button:SetPoint("TOPLEFT", dropdown, "TOPLEFT", 5, -5 - (index - 1) * 29)
        button:SetPoint("TOPRIGHT", dropdown, "TOPRIGHT", -5, -5 - (index - 1) * 29)
        button.text:SetJustifyH("LEFT")
        buttons[index] = button
    end
    box:HookScript("OnTextChanged", function(frame)
        local query = frame:GetText():match("^%s*(.-)%s*$")
        if query == "" then dropdown:Hide(); matches = nil; return end
        matches = self:FindSettings(query)
        local shown = math.min(MAX_RESULTS, #matches)
        for index, button in ipairs(buttons) do
            local match = index <= shown and matches[index]
            button:SetShown(index <= shown)
            if match then button.text:SetText(match.label == match.path and match.label or match.label .. "  ·  " .. match.path) end
        end
        empty:SetShown(shown == 0)
        dropdown:SetHeight(math.max(1, shown) * 29 + 8)
        dropdown:Show()
    end)
    box:SetScript("OnEnterPressed", function() Activate(1) end)
    box:SetScript("OnEscapePressed", function() self:ClearSearch() end)
    self.searchBox, self.searchResults = box, dropdown
end
