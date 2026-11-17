local _, SUI = ...
local M, T, W, B, Text = SUI:GetModule("fontCompatibility"), SUI.SettingsTheme, SUI.Widgets, SUI.SettingsBuilder, SUI.Text

local function P() return SUI:GetModuleProfile("fontCompatibility") end
local function R()
    P().roundedFrames = type(P().roundedFrames) == "table" and P().roundedFrames or {}
    return P().roundedFrames
end

local function AddFramePreview(page, columns, tab, selection)
    local section = B:AddColumnSection(page, columns, "right", Text("Предпросмотр", "Preview"),
        Text("Размеры взяты из профиля аддона. Образец уменьшен под ширину окна, а заполнение полосы условное.",
            "Dimensions come from the addon profile. The sample is scaled to fit the window and its fill is illustrative."))
    local sample = CreateFrame("Frame", nil, section, "BackdropTemplate")
    sample:SetHeight(158)
    T:Backdrop(sample, T.input, T.lineSoft)

    local frame = CreateFrame("Frame", nil, sample)
    frame:SetPoint("CENTER", sample, "CENTER", 0, 8)
    frame.unit = "player"
    local background = frame:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(.064, .055, .052, 1)
    local fill = frame:CreateTexture(nil, "ARTWORK")
    fill:SetPoint("TOPLEFT")
    fill:SetColorTexture(.31, .53, .34, 1)
    local caption = W:Label(frame, "", 10, T.text)
    caption:SetPoint("CENTER")
    caption:SetWordWrap(false)
    caption:SetPoint("LEFT", frame, "LEFT", 5, 0)
    caption:SetPoint("RIGHT", frame, "RIGHT", -5, 0)
    caption:SetJustifyH("CENTER")
    local dimensions = W:Label(sample, "", 10, T.muted)
    dimensions:SetPoint("BOTTOM", sample, "BOTTOM", 0, 10)
    local empty = W:Label(sample, Text("Рамка недоступна", "Frame unavailable"), 10, T.muted)
    empty:SetPoint("CENTER")

    local euiBorder = CreateFrame("Frame", nil, frame)
    euiBorder:SetAllPoints()
    local rounding = { textures = { background, fill }, border = euiBorder }
    local fallback = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    fallback:SetAllPoints()
    T:Backdrop(fallback, { 0, 0, 0, 0 }, T.lineSoft)
    fallback:Hide()

    function sample:Refresh()
        if not self:IsVisible() then return end
        local key, shared = selection()
        local surface
        if shared then
            for _, candidate in ipairs({ "unit:player", "unit:target", "dandersParty", "dandersRaid" }) do
                local found = M:GetFrameSurface(candidate)
                if found and found.db and not found.stock and not found.roundBlocked then
                    key, surface = candidate, found
                    break
                end
            end
        else
            surface = M:GetFrameSurface(key)
        end
        local available = surface and surface.db and not surface.stock
        frame:SetShown(available == true)
        empty:SetShown(not available)
        dimensions:Hide()
        if not available then return end

        local db, eui = surface.db, _G.EllesmereUI
        local width = M:GetConfiguredFrameDimension(surface, "width") or tonumber(surface.previewWidth)
        local height = M:GetConfiguredFrameDimension(surface, "height") or tonumber(surface.previewHeight)
        local hasDimensions = width ~= nil and height ~= nil
        width, height = width or 156, height or 38
        local maxWidth = surface.range and math.max(width, surface.range[2]) or width
        local maxHeight = surface.range and math.max(height, surface.range[4]) or height
        local scale = math.min(1, math.max(32, self:GetWidth() - 44) / math.max(1, maxWidth),
            (self:GetHeight() - 38) / math.max(1, maxHeight))
        frame:SetSize(math.max(1, width * scale), math.max(1, height * scale))
        fill:SetSize(frame:GetWidth() * .73, frame:GetHeight())
        for _, entry in ipairs(M.FrameElements) do
            if entry[1] == key then caption:SetText(entry[2]); break end
        end

        local shapeKey = not shared and key or nil
        local mode = M:GetFrameShapeMode(true, shapeKey)
        local edgeSurface = surface.previewBorder or surface
        local edgeDB = edgeSurface.db
        local radius, corners = M:ResolveFrameShape(edgeDB.cornerRadius, edgeDB.cornerMask, 8, shapeKey, true)
        if surface.roundBlocked then radius = 0 end
        local style, size = M:GetFrameEdge(edgeSurface)
        local r, g, b, a = unpack(M:GetFrameEdgeColor(edgeSurface))
        local nativeDanders, roundedDanders, borderBlend = false, false, nil
        if surface.kind == "danders" then
            frame.isRaidFrame = surface.sub == "raid"
            local danders = M:GetDanders()
            local border = danders and danders.Border
            local thin = not db.frameBorderGradientEnabled and db.frameBorderStyle == "TEXTURE"
                and db.frameBorderTexture == M.ThinRoundedBorderKey
            local solid = not db.frameBorderGradientEnabled and (not db.frameBorderStyle or db.frameBorderStyle == "SOLID")
            if border and border.New and border.BuildSpec and border.Apply then
                self.dandersBorder = self.dandersBorder or border:New(frame, { frameLevelOffset = 2 })
                local spec = border:BuildSpec(db, "frame", { unit = "player", frame = frame })
                for _, field in ipairs({ "size", "inset", "offsetX", "offsetY" }) do
                    local value = spec[field]
                    if (issecretvalue and issecretvalue(value)) or (canaccessvalue and not canaccessvalue(value)) then
                        frame:Hide()
                        empty:Show()
                        return
                    end
                    if type(value) == "number" then spec[field] = value * scale end
                end
                border:Apply(self.dandersBorder, spec)
                local round = eui and eui.RoundCorners and (thin or mode == "ROUND" and (solid or db.frameShowBorder == false))
                if round then
                    roundedDanders, borderBlend = M:ApplyDandersSolidBorder(euiBorder, self.dandersBorder, spec, thin)
                end
                if roundedDanders then
                    radius = mode == "SQUARE" and 0 or (radius > 0 and radius or 8)
                else
                    nativeDanders, radius = true, 0
                end
            end
        end
        if self.dandersBorder and not nativeDanders then self.dandersBorder:Hide() end
        if nativeDanders then size = 0 end
        if style == "none" then size = 0 end
        if not roundedDanders and eui and eui.ApplyBorderStyle then
            local edge = edgeSurface.edge
            local prefix = surface.kind == "plates" and "customBorder" or "borderTexture"
            eui.ApplyBorderStyle(euiBorder, size, r or 0, g or 0, b or 0, a or 1, size > 0 and style or "solid",
                edgeDB[prefix .. "Offset"], edgeDB[prefix .. "OffsetY"],
                edgeDB[prefix .. "ShiftX"], edgeDB[prefix .. "ShiftY"], edge and edge.addon,
                edge and edgeDB[edge.size], nil, size * scale)
        end
        fallback:SetShown(not nativeDanders and not (eui and eui.ApplyBorderStyle) and size > 0)
        if eui and eui.RoundCorners then
            rounding.style = style == "none" and "solid" or style
            rounding.corners = corners
            rounding.rect = roundedDanders and euiBorder or nil
            local scaledRadius = radius > 0 and math.max(1, math.floor(radius * scale + .5)) or 0
            eui.RoundCorners(frame, scaledRadius, rounding)
            if roundedDanders then M:ApplyDandersBorderBlend(euiBorder, borderBlend) end
        end
        if hasDimensions then
            dimensions:SetText(("%g × %g · R %g"):format(width, height, radius))
            dimensions:Show()
        end
    end
    sample:SetScript("OnShow", sample.Refresh)
    sample:SetScript("OnSizeChanged", sample.Refresh)
    B:AddRow(page, section, sample)
    B:FinishCard(page, tab, section)
end

local function BuildPage(parent)
    local page = B:CreateTabbedPage(parent, SUI.Text("Рамки игроков", "Unit frames"), "", {
        { key = "rounded", title = SUI.Text("Общее", "General") },
        { key = "elements", title = SUI.Text("По элементам", "By element") },
        { key = "borderDetails", hidden = true },
        { key = "fonts", title = SUI.Text("Шрифты", "Fonts") },
    })
    local borderMode, element = "party", "unit:player"
    local function Refresh() page:Refresh() end

    local shapes = { AUTO = SUI.Text("Как в аддонах", "Use addon styles"), ROUND = SUI.Text("Скругленные", "Rounded"), SQUARE = SUI.Text("Прямые", "Square") }
    local shapeOrder = { AUTO = 1, ROUND = 2, SQUARE = 3 }
    local localShapes = { INHERIT = SUI.Text("Наследовать общую", "Use shared shape"), AUTO = SUI.Text("Как в аддоне", "Use addon style"), ROUND = shapes.ROUND, SQUARE = shapes.SQUARE }
    local localOrder = { INHERIT = 1, AUTO = 2, ROUND = 3, SQUARE = 4 }

    local generalColumns = B:BeginColumns(page, "rounded")
    local unified = B:AddColumnSection(page, generalColumns, "left", Text("Форма по умолчанию", "Default shape"))
    local choice = W:ChoiceRow(unified, SUI.Text("Форма рамок", "Frame shape"), shapes, function()
        return M:GetFrameShapeMode(true)
    end, function(value)
        M:SetFrameShapeValue(nil, "shapeMode", value)
        Refresh()
    end, shapeOrder)
    B:AddRow(page, unified, choice)
    local radius = W:SliderRow(unified, Text("Радиус углов", "Corner radius"), 0, 16, 1,
        function() return R().radius end, function(value) M:SetFrameShapeValue(nil, "radius", value); Refresh() end)
    B:AddRow(page, unified, W:Help(radius, Text("Значение 0 использует радиус из профиля аддона.",
        "A value of 0 uses the radius from the addon profile.")))
    B:FinishCard(page, "rounded", unified)

    local outline = B:AddColumnSection(page, generalColumns, "left", Text("Общая окантовка", "Shared border"),
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
    AddFramePreview(page, generalColumns, "rounded", function() return nil, true end)
    B:FinishColumns(page, "rounded", generalColumns)

    local elementColumns = B:BeginColumns(page, "elements")
    local picker = B:AddColumnSection(page, elementColumns, "left", Text("Элемент", "Element"))
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

    local sizeCard = B:AddColumnSection(page, elementColumns, "left", Text("Размеры и форма", "Size and shape"))
    local function Dimension(axis)
        return M:GetConfiguredFrameDimension(M:GetFrameSurface(element), axis) or 0
    end
    local width = W:SliderRow(sizeCard, SUI.Text("Ширина", "Width"), 30, 1000, 1, function() return Dimension("width") end,
        function(v) M:SetFrameDimension(element, "width", v); Refresh() end)
    local height = W:SliderRow(sizeCard, SUI.Text("Высота", "Height"), 4, 400, 1, function() return Dimension("height") end,
        function(v) M:SetFrameDimension(element, "height", v); Refresh() end)
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
    end, function(value) M:SetFrameShapeValue(element, "radius", value); Refresh() end)
    B:AddRow(page, sizeCard, W:Help(localRadius, Text("Значение 0 наследует общий радиус или радиус аддона.",
        "A value of 0 inherits the shared radius or the addon's radius.")))
    B:FinishCard(page, "elements", sizeCard)

    local nativeEdge = B:AddColumnSection(page, elementColumns, "left", Text("Окантовка", "Border"), SUI.Text("Тип и толщина берутся из активного профиля EllesmereUI.", "Border type and width come from the active EllesmereUI profile."))
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
    end, function(value) M:SetFrameEdge(element, nil, value); Refresh() end)
    B:AddRow(page, nativeEdge, edgeType)
    B:AddRow(page, nativeEdge, edgeSize)
    edgeColor = W:ColorRow(nativeEdge, SUI.Text("Цвет и прозрачность", "Color and opacity"), function()
        return M:GetFrameEdgeColor(M:GetFrameSurface(element))
    end, function(value) M:SetFrameEdgeColor(element, value); Refresh() end)
    B:AddRow(page, nativeEdge, edgeColor)
    local dandersLink = W:ActionRow(nativeEdge, SUI.Text("Окантовка DandersFrames", "DandersFrames border"), SUI.Text("Открыть", "Open"), function()
        borderMode = element == "dandersRaid" and "raid" or "party"
        page:SelectTab("borderDetails")
    end)
    B:AddRow(page, nativeEdge, dandersLink)
    B:FinishCard(page, "elements", nativeEdge)
    AddFramePreview(page, elementColumns, "elements", function() return element end)
    B:FinishColumns(page, "elements", elementColumns)

    local borderColumns = B:BeginColumns(page, "borderDetails")
    local target = B:AddColumnSection(page, borderColumns, "left", Text("Окантовка DandersFrames", "DandersFrames border"),
        SUI.Text("Настройки записываются в активный профиль DandersFrames для выбранного элемента.",
            "Changes the active DandersFrames profile for the selected element."))
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
    B:FinishCard(page, "borderDetails", target)

    local appearance = B:AddColumnSection(page, borderColumns, "left", Text("Оформление рамки", "Border appearance"))
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
        Refresh()
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
        Refresh()
    end)
    B:AddRow(page, appearance, borderColor)
    local gradientStart = W:ColorRow(appearance, SUI.Text("Начало градиента", "Gradient start"), function()
        local db = M:GetBorderDB(borderMode)
        return db and db.frameBorderGradientStartColor or { r = 0, g = 0, b = 0, a = 1 }
    end, function(value)
        M:SetBorderColorValue(borderMode, "frameBorderGradientStartColor", value)
        Refresh()
    end)
    B:AddRow(page, appearance, gradientStart)
    local gradientEnd = W:ColorRow(appearance, SUI.Text("Конец градиента", "Gradient end"), function()
        local db = M:GetBorderDB(borderMode)
        return db and db.frameBorderGradientEndColor or { r = .5, g = .5, b = .5, a = 1 }
    end, function(value)
        M:SetBorderColorValue(borderMode, "frameBorderGradientEndColor", value)
        Refresh()
    end)
    B:AddRow(page, appearance, gradientEnd)
    local gradientDirection = W:ChoiceRow(appearance, SUI.Text("Направление градиента", "Gradient direction"), {
        HORIZONTAL = SUI.Text("Горизонтально", "Horizontal"), VERTICAL = SUI.Text("Вертикально", "Vertical"),
    }, function()
        local db = M:GetBorderDB(borderMode)
        return db and db.frameBorderGradientDirection or "HORIZONTAL"
    end, function(value)
        M:SetBorderValue(borderMode, "frameBorderGradientDirection", value)
        Refresh()
    end)
    B:AddRow(page, appearance, gradientDirection)
    B:FinishCard(page, "borderDetails", appearance)
    AddFramePreview(page, borderColumns, "borderDetails", function()
        return borderMode == "raid" and "dandersRaid" or "dandersParty"
    end)
    B:FinishColumns(page, "borderDetails", borderColumns)
    local borderFooter = B:AddFooter(page, "borderDetails", {{
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

    local fontColumns = B:BeginColumns(page, "fonts")
    local fonts = B:AddColumnSection(page, fontColumns, "left", Text("Шрифты", "Fonts"))
    local search = W:EditBox(fonts, Text("Поиск по шрифтам", "Search fonts"), function() end)
    search:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    search:HookScript("OnHide", function(self) self:ClearFocus() end)
    B:AddRow(page, fonts, search)
    local coverage = "all"
    local filter = W:ChoiceRow(fonts, Text("Покрытие", "Coverage"), {
        all = Text("Все шрифты", "All fonts"), russian = Text("С покрытием ruRU", "Russian coverage"),
    }, function() return coverage end, function(value) coverage = value; Refresh() end, { all = 1, russian = 2 })
    B:AddRow(page, fonts, W:Help(filter, Text("Фильтр оставляет шрифты, для которых подтверждены все 66 русских букв.",
        "The filter shows fonts verified to contain all 66 Russian letters.")))

    local listHost = CreateFrame("Frame", nil, fonts)
    listHost:SetHeight(252)
    B:AddRow(page, fonts, listHost)
    local scroll, body, bar = W:ScrollFrame(listHost, nil, 42)
    scroll:SetPoint("TOPLEFT", 0, -4)
    scroll:SetPoint("BOTTOMRIGHT", -10, 0)
    bar:SetPoint("TOPLEFT", scroll, "TOPRIGHT", 3, 0)
    bar:SetPoint("BOTTOMLEFT", scroll, "BOTTOMRIGHT", 3, 0)
    scroll:HookScript("OnSizeChanged", function(_, width) body:SetWidth(math.max(1, width)) end)
    local empty = W:Label(body, Text("Шрифты не найдены.", "No matching fonts."), 10, T.muted)
    empty:SetPoint("TOPLEFT", 4, -8)
    B:FinishCard(page, "fonts", fonts)

    local preview = B:AddColumnSection(page, fontColumns, "right", Text("Предпросмотр", "Preview"))
    local specimen = CreateFrame("Frame", nil, preview, "BackdropTemplate")
    specimen:SetHeight(111)
    T:Backdrop(specimen, T.input, T.lineSoft)
    local sampleText = specimen:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    local gameFont = Sintezza_Theme.Theme:GetGameTextFont()
    if gameFont then sampleText:SetFont(gameFont, 19, "OUTLINE") end
    sampleText:SetPoint("LEFT", specimen, "LEFT", 12, 0)
    sampleText:SetPoint("RIGHT", specimen, "RIGHT", -12, 0)
    sampleText:SetJustifyH("CENTER")
    sampleText:SetWordWrap(true)
    if sampleText.SetMaxLines then sampleText:SetMaxLines(2) end
    Sintezza_Theme:Tint(sampleText, "SetTextColor", T.text)
    B:AddRow(page, preview, specimen)
    local defaultSample = Text("Синтецца · Кириллица 123", "Sintezza · Sample 123")
    local sampleInput = W:EditBox(preview, Text("Текст для проверки шрифта", "Type text to test the font"), function() end)
    sampleInput:SetMaxLetters(80)
    sampleInput:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    sampleInput:HookScript("OnHide", function(self) self:ClearFocus() end)
    sampleInput:HookScript("OnTextChanged", function(self)
        local value = self:GetText()
        sampleText:SetText(value == "" and defaultSample or (value:gsub("|", "||")))
    end)
    sampleText:SetText(defaultSample)
    B:AddRow(page, preview, sampleInput)

    local rows, selected = {}, nil
    local selectedFont
    local meta = W:SettingRow(preview, Text("Покрытие", "Coverage"))
    meta.value = W:Label(meta, "", 9, T.muted)
    meta.value:SetPoint("RIGHT")
    B:AddRow(page, preview, meta)
    local register = W:Toggle(preview, Text("Регистрировать этот шрифт", "Register this font"),
        function() return selected and P().fonts[selected] == true end,
        function(value)
            if not selected then return end
            M:SetFontSelected(selected, value)
            Refresh()
        end, Text("Добавляет выбранный шрифт в список кириллических шрифтов DandersFrames.",
            "Adds the selected font to the DandersFrames Cyrillic font list."))
    B:AddRow(page, preview, register)
    B:FinishCard(page, "fonts", preview)
    B:FinishColumns(page, "fonts", fontColumns)

    local SearchKey = SUI.SettingsSearchKey
    local function FontCatalog()
        local available, seen = M:AvailableFonts(), {}
        for _, entry in ipairs(available) do
            seen[entry.name] = true
        end
        for name, picked in pairs(P().fonts or {}) do
            if picked and not seen[name] then available[#available + 1] = { name = name, missing = true } end
        end
        table.sort(available, function(a, b) return SearchKey(a.name) < SearchKey(b.name) end)
        return available
    end

    local function RefreshCatalog()
        local catalog = FontCatalog()
        local query = SearchKey(search:GetText()):match("^%s*(.-)%s*$")
        local visible = {}
        selectedFont = nil
        for _, font in ipairs(catalog) do
            if font.name == selected then selectedFont = font end
            if (coverage == "all" or font.coverage and font.coverage.russian == 66)
                and SearchKey(font.name):find(query, 1, true) then
                visible[#visible + 1] = font
            end
        end
        if not selectedFont then selectedFont = visible[1] end
        selected = selectedFont and selectedFont.name
        empty:SetShown(#visible == 0)
        for index, font in ipairs(visible) do
            local row = rows[index]
            if not row then
                row = W:Button(body, "", function(self) selected = self.fontName; Refresh() end)
                row:SetHeight(36)
                row:SetPoint("TOPLEFT", 0, -(index - 1) * 39)
                row:SetPoint("TOPRIGHT", 0, -(index - 1) * 39)
                row.text:SetPoint("LEFT", 8, 6)
                row.text:SetJustifyH("LEFT")
                row.state = W:Label(row, "", 9, T.muted)
                row.state:SetPoint("BOTTOMLEFT", 8, 3)
                rows[index] = row
            end
            row.fontName = font.name
            row.text:SetText(font.name)
            local safe = M:CanRegisterFont(font.coverage)
            row.state:SetText(font.missing and Text("Недоступен", "Unavailable")
                or (not safe and Text("Регистрация заблокирована", "Registration blocked"))
                or P().fonts[font.name] and Text("В списке регистрации", "In registration list")
                or "LibSharedMedia")
            T:PaintButton(row, font.name == selected)
            row:Show()
        end
        for index = #visible + 1, #rows do rows[index]:Hide() end
        body:SetHeight(math.max(scroll:GetHeight(), #visible * 39))
        scroll:RefreshRange()

        local font = selectedFont
        local coverageInfo = font and font.coverage
        local russian = coverageInfo and coverageInfo.russian
        local digits = coverageInfo and coverageInfo.digits
        meta.value:SetText(russian and Text("%d/66 букв", "%d/66 letters"):format(russian) or Text("Не проверено", "Unverified"))
        W:Help(meta, digits and russian
            and Text("Цифры %d/10. Русские буквы %d/66.", "Digits %d/10. Russian letters %d/66."):format(digits, russian)
            or Text("Для этого шрифта нет данных о покрытии. Проверь нужные знаки в поле выше.",
                "Coverage data is unavailable for this font. Try the characters you need in the field above."))
        local path = font and font.path
        local ok, applied
        if path then ok, applied = pcall(sampleText.SetFont, sampleText, path, 19, "OUTLINE") end
        if not ok or applied == false then
            if gameFont then sampleText:SetFont(gameFont, 19, "OUTLINE")
            else sampleText:SetFontObject(GameFontHighlight) end
        end
        local safe, reason = M:CanRegisterFont(coverageInfo)
        register:SetAvailable(SUI:GetFeature("fonts") and font ~= nil
            and ((path ~= nil and safe) or P().fonts[font.name] == true))
        W:Help(register, reason or Text("Добавляет подтвержденное покрытие кириллицы в реестр DandersFrames.",
            "Adds verified Cyrillic coverage to the DandersFrames registry."))
        register:Refresh()
    end

    search:HookScript("OnTextChanged", function() scroll:SetVerticalScroll(0); RefreshCatalog() end)
    B:AddFooter(page, "fonts", {{
        title = Text("Сбросить шрифты", "Reset fonts"), width = 132,
        callback = function()
            W:Confirm(Text("Сбросить настройки регистрации шрифтов DandersFrames?", "Reset DandersFrames font registration?"), function()
                local defaults = SUI.defaults.modules.fontCompatibility
                for name in pairs(P().fonts) do
                    if not defaults.fonts[name] then M:SetFontSelected(name, false) end
                end
                for name, value in pairs(defaults.fonts) do
                    if value and not P().fonts[name] then M:SetFontSelected(name, true) end
                end
                SUI:SetFeature("fonts", defaults.enabled)
                Refresh()
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
        status.value:SetText(surface and surface.owner or Text("Недоступно", "Unavailable"))
        W:Help(status, reason)

        local provider, dependencyReason = SUI:GetAddonAvailability("DandersFrames")
        local db = provider and M:GetBorderDB(borderMode) or nil
        local available = db ~= nil
        borderStatus.value:SetText(not available and Text("Недоступно", "Unavailable")
            or M.pendingBorders and M.pendingBorders[borderMode] and Text("Ожидает применения", "Pending")
            or Text("Готово", "Ready"))
        W:Help(borderStatus, dependencyReason or M:BorderStatus(borderMode))
        local bc = available and T.muted or T.warning
        borderStatus.value:SetTextColor(bc[1], bc[2], bc[3], 1)
        showBorder:SetAvailable(available)
        resetBorder:SetEnabled(available)
        borderChoice:SetAvailable(available and db.frameShowBorder ~= false)
        local adjustable = available and db.frameShowBorder ~= false and M:GetBorderPreset(borderMode) ~= M.ThinRoundedBorderKey
        thickness:SetAvailable(adjustable)
        inset:SetAvailable(adjustable)
        local gradient = available and M:GetBorderPreset(borderMode) == "GRADIENT"
        colorSource:SetAvailable(adjustable and not gradient)
        borderColor:SetAvailable(adjustable and not gradient)
        gradientStart:SetAvailable(available and db.frameShowBorder ~= false and gradient)
        gradientEnd:SetAvailable(available and db.frameShowBorder ~= false and gradient)
        gradientDirection:SetAvailable(available and db.frameShowBorder ~= false and gradient)

        local _, fontReason = SUI:GetFeatureAvailability("fonts")
        fontStatus.value:SetText(fontReason and Text("Недоступно", "Unavailable")
            or M.reloadRequired and Text("Нужен /reload", "Reload required") or Text("Готово", "Ready"))
        W:Help(fontStatus, fontReason or M:Status())
        local c = (fontReason or M.reloadRequired) and T.warning or T.muted
        fontStatus.value:SetTextColor(c[1], c[2], c[3], 1)
        if page.selectedTab == "fonts" then RefreshCatalog() end
    end
    B:SetPageFooter(page, {{
        title = Text("К интеграциям", "Back to integrations"), width = 132,
        callback = function() SUI.SettingsUI:SelectPage("integrations") end,
    }})
    page:Refresh()
    return page
end

SUI:RegisterSettingsPage({ key = "fontCompatibility", title = SUI.Text("Рамки игроков", "Unit frames"), group = "СИСТЕМА", showInNav = false,
    navKey = "integrations", builder = BuildPage })
