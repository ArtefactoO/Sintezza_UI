local _, SUI = ...
local Text = SUI.Text
local W, B = SUI.Widgets, SUI.SettingsBuilder
local title = Text("Группа на карте", "Party on the map")

local function BuildPage(parent)
    local page = B:CreateTabbedPage(parent, title, nil, { { key = "display" } }, true)
    local card = B:AddSection(page, "display", Text("Сопартийцы", "Party members"))
    B:AddRow(page, card, W:FeatureToggle(card, "partyMap", title))
    B:AddRow(page, card, W:FeatureToggle(card, "partyMap.markers", Text("Метки сопартийцев", "Party markers")))
    B:FinishCard(page, "display", card)
    return page
end

SUI:RegisterSettingsPage({
    key = "partyMap",
    title = title,
    group = "ГРУППА И КАРТА",
    order = 20,
    builder = BuildPage,
})
