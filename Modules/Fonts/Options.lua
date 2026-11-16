local _, SUI = ...
local M, T, W, B = SUI:GetModule("fontCompatibility"), SUI.SettingsTheme, SUI.Widgets, SUI.SettingsBuilder

local function P() return SUI:GetModuleProfile("fontCompatibility") end
local function R()
    P().roundedFrames = type(P().roundedFrames) == "table" and P().roundedFrames or {}
    return P().roundedFrames
end

local function BuildPage(parent)
    local page = B:CreateTabbedPage(parent, SUI.Text("Рамки игроков", "Unit frames"), "", {
        { key = "rounded", title = SUI.Text("Общее", "General") },
        { key = "elements", title = SUI.Text("По элементам", "By element") },
        { key = "borders", title = "DandersFrames" },
        { key = "fonts", title = SUI.Text("Шрифты", "Fonts") },
    })
    local borderMode, element = "party", "unit:player"
    local function Refresh() page:Refresh() end

    local shapes = { AUTO = SUI.Text("Как в аддонах", "Use addon styles"), ROUND = SUI.Text("Скругленные", "Rounded"), SQUARE = SUI.Text("Прямые", "Square") }
    local shapeOrder = { AUTO = 1, ROUND = 2, SQUARE = 3 }
    local localShapes = { INHERIT = SUI.Text("Наследовать общую", "Use shared shape"), AUTO = SUI.Text("Как в аддоне", "Use addon style"), ROUND = shapes.ROUND, SQUARE = shapes.SQUARE }
    local localOrder = { INHERIT = 1, AUTO = 2, ROUND = 3, SQUARE = 4 }

    local unified = B:AddSection(page, "rounded", SUI.Text("Форма по умолчанию", "Default shape"))
    local choice = W:ChoiceRow(unified, SUI.Text("Форма рамок", "Frame shape"), shapes, function()
        return M:GetFrameShapeMode(true)
    end, function(value)
        M:SetFrameShapeValue(nil, "shapeMode", value)
        Refresh()
    end, shapeOrder)
    B:AddRow(page, unified, choice)
    local radius = W:SliderRow(unified, SUI.Text("Радиус углов · 0 — из аддона", "Corner radius · 0 uses the addon value"), 0, 16, 1,
        function() return R().radius end, function(value) M:SetFrameShapeValue(nil, "radius", value) end)
    B:AddRow(page, unified, radius)
    B:FinishCard(page, "rounded", unified)

    local outline = B:AddSection(page, "rounded", SUI.Text("Общая окантовка", "Shared border"),
        SUI.Text("Изменяет активные профили EllesmereUI и DandersFrames.", "Changes the active EllesmereUI and DandersFrames profiles."))
    local applyOutline = W:ActionRow(outline, SUI.Text("Тонкая черная", "Thin black border"), SUI.Text("Применить ко всем", "Apply to all"), function()
        W:Confirm(SUI.Text("Применить тонкую черную окантовку ко всем поддерживаемым элементам активных профилей EllesmereUI и DandersFrames?", "Apply a thin black border to all supported elements in the active EllesmereUI and DandersFrames profiles?"), function()
            SUI:SafeModuleCall(M, "apply interface outline", M.ApplyThinInterfaceEdges)
            Refresh()
        end)
    end, true)
    applyOutline.button:SetWidth(178)
    B:AddRow(page, outline, applyOutline)
    B:FinishCard(page, "rounded", outline)

    local picker = B:AddSection(page, "elements", SUI.Text("Элемент", "Element"))
    local elements, elementOrder = {}, {}
    local edgeColor
    for i, entry in ipairs(M.FrameElements) do
        elements[entry[1]], elementOrder[entry[1]] = entry[2], i
    end
    B:AddRow(page, picker, W:ChoiceRow(picker, SUI.Text("Что редактируем", "Element to edit"), elements, function() return element end,
        function(value)
            if edgeColor then W:CloseColorPicker(edgeColor) end
            element = value
            Refresh()
        end, elementOrder))
    local status = W:SettingRow(picker, SUI.Text("Применение", "Status"))
    status.value = W:Label(status, "", 9, T.muted)
    status.value:SetPoint("RIGHT", status, "RIGHT", 0, 0)
    status.value:SetPoint("LEFT", status, "LEFT", 110, 0)
    status.value:SetJustifyH("RIGHT")
    B:AddRow(page, picker, status)
    B:FinishCard(page, "elements", picker)

    local sizeCard = B:AddSection(page, "elements", SUI.Text("Размеры и форма", "Size and shape"),
        SUI.Text("Радиус 0 наследует общий радиус или радиус аддона.", "A radius of 0 uses the shared or addon's radius."))
    local function Dimension(axis)
        local surface = M:GetFrameSurface(element)
        local value = surface and surface[axis] and surface.db[surface[axis]]
        return type(value) == "number" and value + (axis == "width" and surface.shift or 0) or 0
    end
    local width = W:SliderRow(sizeCard, SUI.Text("Ширина", "Width"), 30, 1000, 1, function() return Dimension("width") end,
        function(v) M:SetFrameDimension(element, "width", v) end)
    local height = W:SliderRow(sizeCard, SUI.Text("Высота", "Height"), 4, 400, 1, function() return Dimension("height") end,
        function(v) M:SetFrameDimension(element, "height", v) end)
    B:AddRow(page, sizeCard, width)
    B:AddRow(page, sizeCard, height)
    local localShape = W:ChoiceRow(sizeCard, SUI.Text("Форма элемента", "Element shape"), localShapes, function()
        local settings = R().elements[element]
        return type(settings) == "table" and settings.mode or "INHERIT"
    end, function(value)
        M:SetFrameShapeValue(element, "mode", value)
        Refresh()
    end, localOrder)
    B:AddRow(page, sizeCard, localShape)
    local localRadius = W:SliderRow(sizeCard, SUI.Text("Радиус углов", "Corner radius"), 0, 16, 1, function()
        local settings = R().elements[element]
        return type(settings) == "table" and settings.radius or 0
    end, function(value) M:SetFrameShapeValue(element, "radius", value) end)
    B:AddRow(page, sizeCard, localRadius)
    B:FinishCard(page, "elements", sizeCard)

    local nativeEdge = B:AddSection(page, "elements", SUI.Text("Окантовка", "Border"), SUI.Text("Тип и толщина берутся из активного профиля EllesmereUI.", "Border type and width come from the active EllesmereUI profile."))
    local function Textures()
        local eui = _G.EllesmereUI
        local options = { { value = "solid", title = SUI.Text("Сплошная", "Solid"), kind = "solid" } }
        local names = { glow = SUI.Text("Свечение", "Glow"), shadow = SUI.Text("Тень", "Shadow") }
        for _, entry in ipairs(eui and eui.GetBorderTextureList and eui.GetBorderTextureList() or {}) do
            if entry.key ~= "solid" then
                options[#options + 1] = { value = entry.key, title = names[entry.key] or entry.name, kind = "border",
                    texture = eui.ResolveBorderTexture and eui.ResolveBorderTexture(entry.key) }
            end
        end
        if element == "plates" then options[#options + 1] = { value = "none", title = SUI.Text("Без рамки", "No border") } end
        return options
    end
    local function Edge()
        local surface = M:GetFrameSurface(element)
        if surface then return M:GetFrameEdge(surface) end
        return "solid", 1
    end
    local edgeType = W:VisualChoiceRow(nativeEdge, SUI.Text("Тип окантовки", "Border type"), Textures, function() return (Edge()) end, function(value)
        M:SetFrameEdge(element, value)
        Refresh()
    end)
    local edgeSize = W:SliderRow(nativeEdge, SUI.Text("Толщина в пикселях", "Thickness in pixels"), 1, 40, 1, function()
        local _, size = Edge()
        return size
    end, function(value) M:SetFrameEdge(element, nil, value) end)
    B:AddRow(page, nativeEdge, edgeType)
    B:AddRow(page, nativeEdge, edgeSize)
    edgeColor = W:ColorRow(nativeEdge, SUI.Text("Цвет и прозрачность", "Color and opacity"), function()
        return M:GetFrameEdgeColor(M:GetFrameSurface(element))
    end, function(value) M:SetFrameEdgeColor(element, value) end)
    B:AddRow(page, nativeEdge, edgeColor)
    local dandersLink = W:ActionRow(nativeEdge, SUI.Text("Окантовка DandersFrames", "DandersFrames border"), SUI.Text("Открыть", "Open"), function()
        borderMode = element == "dandersRaid" and "raid" or "party"
        page:SelectTab("borders")
    end)
    B:AddRow(page, nativeEdge, dandersLink)
    B:FinishCard(page, "elements", nativeEdge)

    local target = B:AddSection(page, "borders", SUI.Text("Область применения", "Scope"), SUI.Text("Настройки записываются прямо в активный профиль DandersFrames.", "Changes the active DandersFrames profile."))
    local modeRow = W:SettingRow(target, SUI.Text("Редактировать", "Edit"))
    local modeSelect = W:Segmented(modeRow, { SUI.Text("Группа", "Party"), SUI.Text("Рейд", "Raid") }, { "party", "raid" }, function()
        return borderMode
    end, function(value)
        borderMode = value
        page:Refresh()
    end)
    modeSelect:SetSize(230, 24)
    modeSelect:SetPoint("RIGHT", modeRow, "RIGHT", 0, 0)
    modeRow.Refresh = function() modeSelect:Refresh() end
    B:AddRow(page, target, modeRow)
    local borderStatus = W:SettingRow(target, SUI.Text("Состояние", "Status"))
    borderStatus.value = W:Label(borderStatus, "", 9, T.muted)
    borderStatus.value:SetPoint("RIGHT", borderStatus, "RIGHT", 0, 0)
    borderStatus.value:SetPoint("LEFT", borderStatus, "LEFT", 190, 0)
    borderStatus.value:SetJustifyH("RIGHT")
    B:AddRow(page, target, borderStatus)
    local showBorder = W:Toggle(target, SUI.Text("Показывать рамку", "Show border"), function()
        local db = M:GetBorderDB(borderMode)
        return db and db.frameShowBorder ~= false
    end, function(value)
        M:SetBorderValue(borderMode, "frameShowBorder", value)
        page:Refresh()
    end)
    B:AddRow(page, target, showBorder)
    B:FinishCard(page, "borders", target)

    local appearance = B:AddSection(page, "borders", SUI.Text("Оформление рамки", "Border appearance"))
    local borderChoice = W:VisualChoiceRow(appearance, SUI.Text("Тип рамки", "Border style"), function() return M:BorderChoices() end, function()
        return M:GetBorderPreset(borderMode)
    end, function(value)
        M:SetBorderPreset(borderMode, value)
        page:Refresh()
    end)
    B:AddRow(page, appearance, borderChoice)
    local thickness = W:SliderRow(appearance, SUI.Text("Толщина", "Thickness"), 1, 16, 1, function()
        local db = M:GetBorderDB(borderMode)
        return db and db.frameBorderSize or 1
    end, function(value)
        M:SetBorderSize(borderMode, value)
        page:Refresh()
    end)
    B:AddRow(page, appearance, thickness)
    local inset = W:SliderRow(appearance, SUI.Text("Вынос наружу", "Outward offset"), 0, 12, 1, function()
        return M:GetBorderOutset(borderMode)
    end, function(value)
        M:SetBorderOutset(borderMode, value)
    end)
    B:AddRow(page, appearance, inset)
    local colorSource = W:ChoiceRow(appearance, SUI.Text("Источник цвета", "Color source"), {
        STATIC = SUI.Text("Свой цвет", "Custom color"), CLASS = SUI.Text("Цвет класса", "Class color"), ROLE = SUI.Text("Цвет роли", "Role color"),
    }, function()
        local db = M:GetBorderDB(borderMode)
        return db and db.frameBorderColorSource or "STATIC"
    end, function(value)
        M:SetBorderValue(borderMode, "frameBorderColorSource", value)
        page:Refresh()
    end)
    B:AddRow(page, appearance, colorSource)
    local borderColor = W:ColorRow(appearance, SUI.Text("Цвет и прозрачность", "Color and opacity"), function()
        local db = M:GetBorderDB(borderMode)
        return db and db.frameBorderColor or { r = 0, g = 0, b = 0, a = 1 }
    end, function(value)
        M:SetBorderColor(borderMode, value)
    end)
    B:AddRow(page, appearance, borderColor)
    local gradientStart = W:ColorRow(appearance, SUI.Text("Начало градиента", "Gradient start"), function()
        local db = M:GetBorderDB(borderMode)
        return db and db.frameBorderGradientStartColor or { r = 0, g = 0, b = 0, a = 1 }
    end, function(value)
        M:SetBorderColorValue(borderMode, "frameBorderGradientStartColor", value)
    end)
    B:AddRow(page, appearance, gradientStart)
    local gradientEnd = W:ColorRow(appearance, SUI.Text("Конец градиента", "Gradient end"), function()
        local db = M:GetBorderDB(borderMode)
        return db and db.frameBorderGradientEndColor or { r = .5, g = .5, b = .5, a = 1 }
    end, function(value)
        M:SetBorderColorValue(borderMode, "frameBorderGradientEndColor", value)
    end)
    B:AddRow(page, appearance, gradientEnd)
    local gradientDirection = W:ChoiceRow(appearance, SUI.Text("Направление градиента", "Gradient direction"), {
        HORIZONTAL = SUI.Text("Горизонтально", "Horizontal"), VERTICAL = SUI.Text("Вертикально", "Vertical"),
    }, function()
        local db = M:GetBorderDB(borderMode)
        return db and db.frameBorderGradientDirection or "HORIZONTAL"
    end, function(value)
        M:SetBorderValue(borderMode, "frameBorderGradientDirection", value)
    end)
    B:AddRow(page, appearance, gradientDirection)
    B:FinishCard(page, "borders", appearance)
    local borderFooter = B:AddFooter(page, "borders", {{
        title = SUI.Text("Вернуть Solid", "Restore solid border"), width = 132,
        callback = function()
            if not SUI:GetAddonAvailability("DandersFrames") or not M:GetBorderDB(borderMode) then return end
            W:Confirm(SUI.Text("Вернуть стандартную рамку для выбранного режима DandersFrames?", "Restore the default border for this DandersFrames layout?"), function()
                M:ResetBorder(borderMode)
                page:Refresh()
            end)
        end,
    }})
    local resetBorder = borderFooter:GetChildren()

    local state = B:AddSection(page, "fonts", SUI.Text("Регистрация", "Registration"), SUI.Text("Для удаления регистрации нужен /reload.", "Removing registered fonts requires /reload."))
    local enabled = W:FeatureToggle(state, "fonts", SUI.Text("Включить регистрацию", "Register fonts"), nil, nil, Refresh)
    B:AddRow(page, state, enabled)
    local fontStatus = W:SettingRow(state, SUI.Text("Состояние", "Status"))
    fontStatus.value = W:Label(fontStatus, "", 9, T.muted)
    fontStatus.value:SetPoint("RIGHT", fontStatus, "RIGHT", 0, 0)
    fontStatus.value:SetPoint("LEFT", fontStatus, "LEFT", 190, 0)
    fontStatus.value:SetJustifyH("RIGHT")
    B:AddRow(page, state, fontStatus)
    B:FinishCard(page, "fonts", state)

    local fonts = B:AddSection(page, "fonts", SUI.Text("Доступные шрифты", "Available fonts"))
    local search = W:EditBox(fonts, SUI.Text("Поиск шрифта...", "Search fonts…"), function() end)
    B:AddRow(page, fonts, search)
    local scroll, body, bar = W:ScrollFrame(fonts)
    scroll:SetHeight(300)
    B:AddRow(page, fonts, scroll)
    bar:SetPoint("TOPRIGHT", scroll, "TOPRIGHT", 7, 0); bar:SetPoint("BOTTOMRIGHT", scroll, "BOTTOMRIGHT", 7, 0)
    local rows = {}

    local available, seen = M:AvailableFonts(), {}
    for _, entry in ipairs(available) do seen[entry.name] = true end
    for name, selected in pairs(P().fonts or {}) do
        if selected and not seen[name] then available[#available + 1] = { name = name, path = nil, missing = true } end
    end
    table.sort(available, function(a, b) return a.name:lower() < b.name:lower() end)

    local function Relayout()
        local query = search:GetText():lower(); local count = 0
        for _, row in ipairs(rows) do
            local visible = query == "" or row.fontName:lower():find(query, 1, true) ~= nil
            row:SetShown(visible)
            if visible then
                row:ClearAllPoints()
                local y = -2 - (count * 30)
                row:SetPoint("TOPLEFT", body, "TOPLEFT", 0, y); row:SetPoint("TOPRIGHT", body, "TOPRIGHT", 0, y)
                count = count + 1
            end
        end
        body:SetHeight(math.max(scroll:GetHeight(), count * 30 + 4)); scroll:RefreshRange()
    end

    for _, entry in ipairs(available) do
        local font = entry
        local text = font.name .. (font.missing and SUI.Text("  — недоступен", "  — unavailable") or SUI.Text("  •  Синтеза, Кириллица 123", "  · Синтеза, Кириллица 123"))
        local row = W:Toggle(body, text, function() return SUI:GetFeature("fonts") and P().fonts[font.name] == true end, function(value)
            M:SetFontSelected(font.name, value); page:Refresh()
        end)
        row.fontName, row.missing = font.name, font.missing
        if font.path then
            local ok = row.label:SetFont(font.path, 10, "")
            if not ok then T:Font(row.label, 10, "", T.text) end
        else
            row.label:SetTextColor(T.warning[1], T.warning[2], T.warning[3], 1)
        end
        rows[#rows + 1] = row
    end

    search:HookScript("OnTextChanged", Relayout)
    scroll:HookScript("OnSizeChanged", function() body:SetWidth(math.max(1, scroll:GetWidth())); Relayout() end)
    B:FinishCard(page, "fonts", fonts)
    B:AddFooter(page, "fonts", {{
        title = SUI.Text("Сбросить шрифты", "Reset fonts"), width = 132,
        callback = function()
            W:Confirm(SUI.Text("Сбросить настройки шрифтов DandersFrames?", "Reset DandersFrames font settings?"), function()
                SUI:ResetModuleProfile("fontCompatibility")
                page:Refresh()
            end)
        end,
    }})

    function page:OnRefresh()
        local canRound = M:CanDrawThinRoundedBorder()
        choice:SetAvailable(canRound)
        radius:SetAvailable(canRound and M:GetFrameShapeMode(true) == "ROUND")
        applyOutline:SetAvailable(canRound)
        local surface = M:GetFrameSurface(element)
        local availableElement = surface and surface.db ~= nil
        local elementMode = M:GetFrameShapeMode(true, element)
        local shapeAvailable = canRound and availableElement and not (surface.stock or surface.roundBlocked)
        local w, h = availableElement and surface.width, availableElement and surface.height
        if surface and surface.range then
            width:SetRange(surface.range[1], surface.range[2]); width:Refresh()
            height:SetRange(surface.range[3], surface.range[4]); height:Refresh()
        end
        width:SetAvailable(w and not surface.widthMatched and true or false)
        height:SetAvailable(h and not surface.heightMatched and true or false)
        localShape:SetAvailable(shapeAvailable == true)
        localRadius:SetAvailable(shapeAvailable == true and elementMode == "ROUND")
        local danders = availableElement and surface.kind == "danders"
        dandersLink:SetAvailable(danders == true)
        local edge = availableElement and surface.edge ~= nil
        edgeType:SetAvailable(edge == true)
        edgeSize:SetAvailable(edge == true and Edge() ~= "none")
        edgeColor:SetAvailable(edge == true and Edge() ~= "none")
        local reason
        if not availableElement then reason = (surface and surface.owner or SUI.Text("Аддон", "Addon")) .. SUI.Text(" недоступен", " is unavailable")
        elseif surface.stock then reason = SUI.Text("Используется классическое оформление", "Using the classic style")
        elseif surface.roundBlocked then reason = SUI.Text("Текущий стиль сохраняет свою форму", "The current style keeps its own shape")
        elseif surface.widthMatched or surface.heightMatched then reason = SUI.Text("Размер связан с другим элементом", "Size is linked to another element")
        else reason = surface.note or surface.owner end
        status.value:SetText(reason)

        local provider, dependencyReason = SUI:GetAddonAvailability("DandersFrames")
        local db = provider and M:GetBorderDB(borderMode) or nil
        local available = db ~= nil
        borderStatus.value:SetText(dependencyReason or M:BorderStatus(borderMode))
        local bc = available and T.muted or T.warning
        borderStatus.value:SetTextColor(bc[1], bc[2], bc[3], 1)
        showBorder:SetAvailable(available)
        resetBorder:SetEnabled(available)
        borderChoice:SetAvailable(available and db.frameShowBorder ~= false)
        local adjustable = available and db.frameShowBorder ~= false and M:GetBorderPreset(borderMode) ~= M.ThinRoundedBorderKey
        thickness:SetAvailable(adjustable)
        inset:SetAvailable(adjustable)
        local gradient = available and db.frameBorderStyle == "GRADIENT"
        colorSource:SetAvailable(adjustable and not gradient)
        borderColor:SetAvailable(adjustable and not gradient)
        gradientStart:SetAvailable(available and db.frameShowBorder ~= false and gradient)
        gradientEnd:SetAvailable(available and db.frameShowBorder ~= false and gradient)
        gradientDirection:SetAvailable(available and db.frameShowBorder ~= false and gradient)

        local _, fontReason = SUI:GetFeatureAvailability("fonts")
        fontStatus.value:SetText(fontReason or M:Status())
        local c = (fontReason or M.reloadRequired) and T.warning or T.muted
        fontStatus.value:SetTextColor(c[1], c[2], c[3], 1)
        for _, row in ipairs(rows) do
            row:Refresh(); row:SetAvailable(SUI:GetFeature("fonts") and (not row.missing or P().fonts[row.fontName] == true))
        end
        Relayout()
    end
    page:Refresh()
    return page
end

SUI:RegisterSettingsPage({ key = "fontCompatibility", title = SUI.Text("Рамки игроков", "Unit frames"), group = "ПАНЕЛИ", order = 25, builder = BuildPage })
