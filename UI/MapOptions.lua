local _, SUI = ...
if not SUI.isForever then return end

local Text = SUI.Text
local W, B = SUI.Widgets, SUI.SettingsBuilder
local title = Text("Карта и маршруты", "Map and routes")

local minimapPoints = {
    { 65.5, 6 }, { 70.5, 22.5 }, { 75, 38.5 }, { 80, 54.5 },
    { 85, 71 }, { 90, 87 }, { 95, 103 }, { 99.5, 119.5 },
}
local worldPoints = {
    { 73.5, 4.5 }, { 73, 21.5 }, { 71, 38 }, { 61.5, 52.5 },
    { 58.5, 67.5 }, { 62.5, 83.5 }, { 66.5, 100 },
}

local function AddToggle(page, card, id, detail)
    B:AddRow(page, card, W:FeatureToggle(card, id, SUI.featureByID[id].label, detail))
end

local function BuildPage(parent)
    local page = B:CreateTabbedPage(parent, title,
        Text("Личная метка, внешний вид маршрута и таймеры транспорта.", "Personal waypoints, route appearance and transport timers."),
        { { key = "display" } }, true)
    local route = SUI:GetModule("shortestPathMinimap")
    local transport = SUI:GetModule("transportMap")
    local function RouteProfile() return SUI:GetModuleProfile("shortestPathMinimap") end
    local function Changed()
        SUI:SafeModuleCall(route, "route appearance", route.OnProfileChanged)
        page:Refresh()
    end
    local columns = B:BeginColumns(page, "display", 14)
    local card = B:AddColumnSection(page, columns, "left", Text("Маршрут", "Route"))
    AddToggle(page, card, "mapWaypointControls",
        Text("Ctrl + ЛКМ ставит метку, Ctrl + ПКМ удаляет. Маршрут обновится после боя.",
            "Ctrl+left-click to set, Ctrl+right-click to remove. Routes update after combat."))
    AddToggle(page, card, "shortestPathMinimap",
        Text("Заменяет штатные точки Shortest Path плавными точками выбранного цвета и размера.",
            "Replaces the default Shortest Path dots with smooth dots of the selected color and size."))
    local dotColor = W:ColorRow(card, Text("Цвет точек маршрута", "Route dot color"), function()
        local _, color = route:GetDotStyle()
        return color
    end, function(value) RouteProfile().dotColor = value; Changed() end)
    dotColor.settingsID = "routeDotColor"
    B:AddRow(page, card, dotColor)
    local dotSize = W:SliderRow(card, Text("Размер точек маршрута", "Route dot size"), 4, 16, .5,
        function() return route:GetDotStyle() end,
        function(value) RouteProfile().dotSize = value; Changed() end, " px")
    dotSize.settingsID = "routeDotSize"
    B:AddRow(page, card, dotSize)
    B:FinishCard(page, "display", card)

    local function AddMapPair(parentCard, mini, world)
        local sample = CreateFrame("Frame", nil, parentCard)
        local maps = { mini, world }
        sample:SetHeight(178)
        for index, name in ipairs({ Text("Миникарта", "Minimap"), Text("Карта мира", "World map") }) do
            local map = maps[index]
            map:SetParent(sample)
            map:SetPoint("TOP", sample, "TOP", index == 1 and -78 or 78, -4)
            local label = W:Label(sample, name, 10, SUI.SettingsTheme.muted)
            label:SetPoint("TOP", map, "BOTTOM", 0, -6)
        end
        B:AddRow(page, parentCard, sample)
        return sample
    end

    card = B:AddColumnSection(page, columns, "right", Text("Предпросмотр маршрута", "Route preview"),
        Text("Цвет, размер и анимация точек такие же, как на игровых картах.",
            "The dot color, size, and animation match the in-game maps."), true)
    local mini = route:CreateRoutePreview(card, "Mini", minimapPoints, 104, 136)
    local world = route:CreateRoutePreview(card, "World", worldPoints, 78, 130)
    local routeSample = AddMapPair(card, mini, world)
    function routeSample:Refresh()
        mini:Refresh()
        world:Refresh()
    end
    local play = W:ActionRow(card, Text("Движение по маршруту", "Route motion"),
        Text("Проиграть", "Play"), function()
            mini:Play()
            world:Play()
        end)
    B:AddRow(page, card, W:BindAvailability(play, function()
        return SUI:GetFeatureSetting("shortestPathMinimap"), Text("Включи золотые точки, чтобы проверить движение.",
            "Enable gold route dots to preview the motion.")
    end, Text("Персонаж проходит маршрут. Точки появляются, смещаются и исчезают, как в игре.",
        "The player follows the route. Dots appear, slide, and fade as they do in game.")))
    B:FinishCard(page, "display", card)
    B:FinishColumns(page, "display", columns)

    columns = B:BeginColumns(page, "display", 14)
    card = B:AddColumnSection(page, columns, "left", Text("Транспорт", "Transport"))
    AddToggle(page, card, "transportMap",
        Text("Время до прибытия или отправления рядом с причалом.",
            "Time until arrival or departure beside the dock."))
    AddToggle(page, card, "transportMap.minimap",
        Text("Охра — прибытие, зеленый — отправление.", "Amber for arrival, green for departure."))
    B:FinishCard(page, "display", card)

    card = B:AddColumnSection(page, columns, "right", Text("Предпросмотр транспорта", "Transport preview"),
        Text("Значок корабля в Кабестане и таймеры прибытия и отправления на обеих картах.",
            "The ferry pin in Ratchet and its arrival and departure timers on both maps."), true)
    local miniDock = transport:CreateTransportPreview(card, true)
    local worldDock = transport:CreateTransportPreview(card, false)
    local transportSample = AddMapPair(card, miniDock, worldDock)
    local status = W:Label(card, "", 10, SUI.SettingsTheme.muted)
    status:SetHeight(19)
    B:AddRow(page, card, status)

    local function ExampleVisit(elapsed)
        local docked = elapsed >= 6
        return {
            age = 0, docked = docked, arriveIn = math.max(0, 6 - elapsed) * 1000,
            departIn = (11 - elapsed) * 1000, fraction = docked and (11 - elapsed) / 5 or (6 - elapsed) / 6,
        }
    end
    function transportSample:Refresh()
        if not self:IsVisible() then return end
        local showMini, showWorld = SUI:GetFeature("transportMap.minimap"), SUI:GetFeature("transportMap")
        local elapsed = GetTime() - (self.started or GetTime())
        if self.playing and elapsed >= 11 then self.playing = nil end
        local observed = not self.playing and (showMini or showWorld) and transport:GetPreviewVisit()
        local visit = observed or ExampleVisit(elapsed % 11)
        miniDock:Refresh(visit, showMini)
        worldDock:Refresh(visit, showWorld)
        status:SetText(observed and Text("По наблюдениям Shortest Path", "Shortest Path observations")
            or (showMini or showWorld) and Text("Пробный таймер", "Sample countdown")
            or Text("Таймеры выключены", "Timers are off"))
    end
    transportSample:SetScript("OnShow", function(frame)
        frame.started = GetTime()
        frame:Refresh()
        if C_Timer and C_Timer.NewTicker then
            frame.ticker = C_Timer.NewTicker(.2, function() frame:Refresh() end)
        end
    end)
    transportSample:SetScript("OnHide", function(frame)
        if frame.ticker then frame.ticker:Cancel(); frame.ticker = nil end
        frame.playing = nil
    end)
    local playTransport = W:ActionRow(card, Text("Прибытие и отправление", "Arrival and departure"),
        Text("Проиграть", "Play"), function()
            transportSample.started, transportSample.playing = GetTime(), true
            transportSample:Refresh()
        end)
    B:AddRow(page, card, W:BindAvailability(playTransport, function()
        return SUI:GetFeature("transportMap.minimap") or SUI:GetFeature("transportMap"),
            Text("Включи таймер хотя бы на одной карте.", "Enable the timer on at least one map.")
    end, Text("Проигрывает короткий пробный цикл таймера причала.",
        "Plays a short sample dock countdown.")))
    B:FinishCard(page, "display", card)
    B:FinishColumns(page, "display", columns)
    return page
end

SUI:RegisterSettingsPage({
    key = "mapOptions",
    title = title,
    group = "ГРУППА И КАРТА",
    order = 30,
    builder = BuildPage,
})
