local _, SUI = ...
if not SUI.isForever then return end

local Text = SUI.Text
local W, B = SUI.Widgets, SUI.SettingsBuilder
local title = Text("Карта", "Map")

local function AddToggle(page, card, id, detail)
    B:AddRow(page, card, W:FeatureToggle(card, id, SUI.featureByID[id].label, detail))
end

local function BuildPage(parent)
    local page = B:CreateTabbedPage(parent, title, nil, { { key = "display" } }, true)
    local card = B:AddSection(page, "display", Text("Вкладки карты", "Map tabs"))
    AddToggle(page, card, "mapDisplay.stackTabs",
        Text("Вкладки Muddy Boots под журналом и вкладками ForeverCore.",
            "Place Muddy Boots below the quest log and ForeverCore tabs."))
    B:FinishCard(page, "display", card)

    card = B:AddSection(page, "display", Text("Маршруты и транспорт", "Routes and transport"))
    AddToggle(page, card, "mapWaypointControls",
        Text("Ctrl + ЛКМ ставит метку, Ctrl + ПКМ удаляет. Маршрут обновится после боя.",
            "Ctrl+left-click to set, Ctrl+right-click to remove. Routes update after combat."))
    AddToggle(page, card, "shortestPathMinimap")
    AddToggle(page, card, "transportMap")
    AddToggle(page, card, "transportMap.minimap",
        Text("Охра — прибытие, зеленый — отправление.", "Amber for arrival, green for departure."))
    B:FinishCard(page, "display", card)
    return page
end

SUI:RegisterSettingsPage({
    key = "mapOptions",
    title = title,
    group = "ГРУППА И КАРТА",
    order = 30,
    builder = BuildPage,
})
