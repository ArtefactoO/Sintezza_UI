local _, SUI = ...
local M, W, B = SUI:GetModule("specBar"), SUI.Widgets, SUI.SettingsBuilder
local Text = SUI.Text

local function P() return SUI:GetModuleProfile("specBar") end
local function Add(page, card, widget) return B:AddRow(page, card, widget) end

local function BuildPage(parent)
    local title = SUI.isForever and Text("Панель талантов", "Talent bar") or Text("Панель специализаций", "Specialization bar")
    local page = B:CreateTabbedPage(parent, title, nil, {
        { key = "general", title = Text("Основное", "General") },
        { key = "behavior", title = Text("Поведение", "Behavior") },
    })
    local columns = B:BeginColumns(page, "general")
    local card = B:AddColumnSection(page, columns, "left", Text("Панель", "Bar"))
    Add(page, card, W:Toggle(card, Text("Включить панель", "Enable bar"), function() return P().enabled ~= false end, function(value)
        P().enabled = value
        M:RefreshAll()
    end))
    Add(page, card, W:Toggle(card, Text("Блокировать положение", "Lock position"), function() return P().locked ~= false end, function(value)
        P().locked = value
    end))
    local activeLabel = SUI.isForever and Text("Кнопка талантов", "Talent button") or Text("Кнопка специализации", "Specialization button")
    Add(page, card, W:FeatureToggle(card, "specActive", activeLabel))
    if not SUI.isForever then
        Add(page, card, W:FeatureToggle(card, "specLoot", Text("Кнопка специализации добычи", "Loot specialization button")))
    end
    B:FinishCard(page, "general", card)

    card = B:AddColumnSection(page, columns, "right", Text("Размер и положение", "Size and position"))
    Add(page, card, W:SliderRow(card, Text("Масштаб", "Scale"), .6, 1.6, .05, function() return P().scale or 1 end, function(value)
        P().scale = value
        M:ApplyPosition()
    end))
    Add(page, card, W:ActionRow(card, Text("Положение", "Position"), Text("Сбросить", "Reset"), function()
        P().point, P().relativePoint, P().x, P().y = "TOP", "TOP", 0, -55
        M:ApplyPosition()
        page:Refresh()
    end, true))
    B:FinishCard(page, "general", card)
    B:FinishColumns(page, "general", columns)

    columns = B:BeginColumns(page, "behavior")
    card = B:AddColumnSection(page, columns, "left", Text("Наведение", "Hover"))
    Add(page, card, W:Toggle(card, Text("Только при наведении", "Show on hover"), function() return P().mouseover == true end, function(value)
        P().mouseover = value
        M:RefreshFade()
        page:Refresh()
    end))
    local hoverAlpha = Add(page, card, W:SliderRow(card, Text("Яркость при наведении", "Hover opacity"), .1, 1, .05,
        function() return P().hoverAlpha or 1 end, function(value)
            P().hoverAlpha = value
            M:RefreshFade()
        end))
    local originalRefresh = hoverAlpha.Refresh
    function hoverAlpha:Refresh(...)
        if originalRefresh then originalRefresh(self, ...) end
        self:SetAvailable(P().mouseover == true)
    end
    hoverAlpha:Refresh()
    B:FinishCard(page, "behavior", card)

    card = B:AddColumnSection(page, columns, "right", Text("Видимость", "Visibility"))
    Add(page, card, W:ChoiceRow(card, Text("В бою", "In combat"), {
        SHOW = Text("Показывать", "Show"), HIDE = Text("Скрывать", "Hide"), SHOW_ON_HOVER = Text("По общему режиму", "Use normal visibility"),
    }, function() return P().combatVisibility end, function(value)
        P().combatVisibility = value
        M:RefreshVisibility()
    end))
    Add(page, card, W:Toggle(card, Text("Скрывать в битве питомцев", "Hide during pet battles"), function() return P().hideInPetBattle == true end, function(value)
        P().hideInPetBattle = value
        M:RefreshVisibility()
    end))
    B:FinishCard(page, "behavior", card)
    B:FinishColumns(page, "behavior", columns)

    page.OnSelected = function()
        M.settingsOpen = true
        M:RefreshAll()
    end
    page.OnDeselected = function()
        M.settingsOpen = false
        M:RefreshAll()
    end
    return page
end

SUI:RegisterSettingsPage({ key = "specBar", title = Text("Панель специализаций", "Specialization bar"), group = "ПАНЕЛИ", order = 30, builder = BuildPage })
