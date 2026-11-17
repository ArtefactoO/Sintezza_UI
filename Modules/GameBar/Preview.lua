local _, SUI = ...
local SGB, Text, T = SUI.GameBar, SUI.Text, SUI.SettingsTheme
local SLOT_COUNT = 7
local SIDES = { "left", "right" }

local function CreateSlot(panel, side, index, editable)
    local slot = CreateFrame(editable and "Button" or "Frame", nil, panel)
    slot.side, slot.index = side, index
    slot:SetFrameLevel(panel:GetFrameLevel() + 3)
    slot.icon = slot:CreateTexture(nil, "ARTWORK")
    slot.icon:SetPoint("CENTER")
    slot.icon:SetTexCoord(.08, .92, .08, .92)
    if editable then
        slot.empty = SUI.Widgets:Label(slot, "+", 14, T.muted)
        slot.empty:SetPoint("CENTER")
        slot.outline = CreateFrame("Frame", nil, slot, "BackdropTemplate")
        slot.outline:SetAllPoints()
        slot.outline:EnableMouse(false)
    end
    return slot
end

local function PaintSlot(slot, editor)
    local active = slot == editor.target or slot == editor.selection
    local color = active and T.accent or (slot.hovered and T.brass or T.lineSoft)
    T:Backdrop(slot.outline, { 0, 0, 0, 0 }, color)
end

local function ColorSlot(slot, appearance)
    local color = appearance.iconColor
    local r, g, b = color[1], color[2], color[3]
    local alpha = (color[4] or 1) * (appearance.iconAlpha or 1)
    if slot.hovered and slot.actionVisible then
        if appearance.hoverColorMode == "CLASS" then
            r, g, b, alpha = SGB:GetClassColor()
        elseif appearance.hoverColor then
            r, g, b, alpha = unpack(appearance.hoverColor)
        end
    end
    slot.icon:SetVertexColor(r, g, b, (alpha or 1) * (slot.actionVisible and 1 or .38))
end

function SGB:CreateSettingsBarPreview(parent, profile, editor)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetHeight(editor and 116 or 124)
    local canvas = CreateFrame("Frame", nil, frame)
    canvas:SetPoint("CENTER", frame, "CENTER", 0, editor and -9 or 0)
    local background = frame:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    Sintezza_Theme:Tint(background, "SetColorTexture", T.input, .62)
    local actionPanels = { left = self:CreateSegment(canvas), right = self:CreateSegment(canvas) }
    local clockPanel = self:CreateSegment(canvas)
    local clock = clockPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    clock:SetPoint("CENTER")
    local slots = { left = {}, right = {} }
    local sideLabels = {}
    local ghost
    local function UpdateClock()
        local p = profile()
        if clockPanel:IsShown() then clock:SetText(SGB:FormatClock(p.clock.twentyFourHour, p.appearance.showSeconds)) end
    end

    local function StopDrag()
        if not editor then return end
        if editor.target then
            local previous = editor.target
            editor.target = nil
            PaintSlot(previous, editor)
        end
        editor.dragging = nil
        if ghost then ghost:Hide(); ghost:SetScript("OnUpdate", nil) end
    end

    local function HoveredSlot()
        for _, side in ipairs(SIDES) do
            for _, slot in ipairs(slots[side]) do
                if slot:IsVisible() and slot:IsMouseOver() then return slot end
            end
        end
    end

    local function UpdateDrag()
        local x, y = GetCursorPosition()
        local scale = UIParent:GetEffectiveScale()
        ghost:ClearAllPoints()
        ghost:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / scale + 12, y / scale - 10)
        local target = HoveredSlot()
        if target == editor.target then return end
        local previous = editor.target
        editor.target = target
        if previous then PaintSlot(previous, editor) end
        if target then PaintSlot(target, editor) end
    end

    for _, side in ipairs(SIDES) do
        if editor then
            local label = side == "left" and Text("Левая секция", "Left section") or Text("Правая секция", "Right section")
            sideLabels[side] = SUI.Widgets:Label(frame, label, 11, T.muted)
        end
        for index = 1, SLOT_COUNT do
            local slot = CreateSlot(actionPanels[side], side, index, editor ~= nil)
            slots[side][index] = slot
            slot:EnableMouse(true)
            slot:HookScript("OnEnter", function(button)
                button.hovered = true
                ColorSlot(button, profile().appearance)
            end)
            slot:HookScript("OnLeave", function(button)
                button.hovered = nil
                ColorSlot(button, profile().appearance)
            end)
            if editor then
                slot:RegisterForClicks("LeftButtonUp")
                slot:RegisterForDrag("LeftButton")
                slot:SetScript("OnClick", function(button)
                    editor.selection = button
                    editor.Refresh()
                end)
                slot:HookScript("OnEnter", function(button)
                    PaintSlot(button, editor)
                    if not editor.dragging and GameTooltip then
                        GameTooltip:SetOwner(button, "ANCHOR_BOTTOM")
                        GameTooltip:SetText(button.label)
                        if button.hiddenAction then GameTooltip:AddLine(Text("Кнопка скрыта", "Button hidden"), .8, .8, .8) end
                        if button.unavailable then GameTooltip:AddLine(Text("Недоступно на этом клиенте", "Unavailable on this client"), .8, .8, .8) end
                        GameTooltip:Show()
                    end
                end)
                slot:HookScript("OnLeave", function(button)
                    PaintSlot(button, editor)
                    if GameTooltip and GameTooltip:IsOwned(button) then GameTooltip:Hide() end
                end)
                slot:SetScript("OnDragStart", function(button)
                    if not button.entry then return end
                    if GameTooltip and GameTooltip:IsOwned(button) then GameTooltip:Hide() end
                    editor.dragging, editor.selection = button, button
                    if not ghost then
                        ghost = CreateFrame("Frame", nil, UIParent)
                        ghost:SetSize(32, 32)
                        ghost:SetFrameStrata("TOOLTIP")
                        ghost:EnableMouse(false)
                        ghost.icon = ghost:CreateTexture(nil, "ARTWORK")
                        ghost.icon:SetAllPoints()
                    end
                    ghost.icon:SetTexture(button.entry.icon)
                    ghost:Show()
                    ghost:SetScript("OnUpdate", UpdateDrag)
                    UpdateDrag()
                    editor.Refresh()
                end)
                slot:SetScript("OnDragStop", function(button)
                    if editor.dragging ~= button then return end
                    local destination = HoveredSlot()
                    StopDrag()
                    if destination and destination ~= button then
                        editor.selection = destination
                        editor.Move(button.side, button.index, destination.side, destination.index)
                    end
                    editor.Refresh()
                end)
            end
        end
    end

    local unavailable = Text("Панель выключена", "Bar disabled")
    local empty = Text("На панели нет видимых элементов", "No visible bar elements")
    local summary = SUI.Widgets:Label(frame, "", 11, T.muted)
    summary:SetPoint("BOTTOM", frame, "BOTTOM", 0, 9)
    function frame:Refresh()
        if not self:IsVisible() then return end
        local p = profile()
        local a = p.appearance
        local x, height, count = 0, 1, 0
        local iconSize = editor and math.max(28, a.iconSize) or a.iconSize
        local iconScale = math.max(.5, math.min(1, tonumber(a.iconScale) or 1))
        local sideHeight = iconSize + 2 * a.panelPadding
        local function Place(panel, width, h, y)
            panel:SetShown(width > 0)
            if width <= 0 then return end
            if count > 0 then x = x + a.segmentGap end
            panel:ClearAllPoints()
            panel:SetPoint("LEFT", canvas, "LEFT", x, y)
            panel:SetSize(width, h)
            SGB:ApplySegmentStyle(panel, a)
            x, height, count = x + width, math.max(height, h + math.abs(y) * 2), count + 1
        end
        local function PlaceSide(side, ids)
            local visible = 0
            local panel = actionPanels[side]
            for index, slot in ipairs(slots[side]) do
                local id = ids[index]
                local entry = SGB:GetButtonEntry(id)
                local shown = entry and SGB:IsButtonAvailable(id) and not p.hiddenButtons[id]
                slot:SetShown(editor ~= nil or shown == true)
                slot.entry, slot.label = entry, entry and entry.label or Text("Пустой слот", "Empty slot")
                slot.actionVisible = shown
                slot.hiddenAction = entry and p.hiddenButtons[id]
                slot.unavailable = entry and not SGB:IsButtonAvailable(id)
                if editor or shown then
                    slot:ClearAllPoints()
                    slot:SetPoint("LEFT", panel, "LEFT", a.panelPadding + visible * (iconSize + a.buttonSpacing), 0)
                    slot:SetSize(iconSize, iconSize)
                    slot.icon:SetTexture(entry and entry.icon or nil)
                    slot.icon:SetSize(iconSize * iconScale, iconSize * iconScale)
                    ColorSlot(slot, a)
                    if editor then
                        slot.empty:SetShown(entry == nil)
                        PaintSlot(slot, editor)
                    end
                    visible = visible + 1
                end
            end
            local width = visible > 0 and (2 * a.panelPadding + visible * iconSize + (visible - 1) * a.buttonSpacing) or 0
            Place(panel, width, sideHeight, a.verticalAlignment or 0)
        end
        PlaceSide("left", p.leftButtons)
        local clockShown = p.clock.enabled ~= false
        Place(clockPanel, clockShown and a.timeWidth or 0, a.timeHeight, 0)
        if clockShown then
            clock:SetFont(SGB:GetFont(a.timeFont), a.timeFontSize, SGB:GetFontFlags(a.timeOutline, "OUTLINE"))
            UpdateClock()
        end
        PlaceSide("right", p.rightButtons)
        canvas:SetSize(math.max(x, 1), height)
        local width = self:GetWidth()
        local room = math.max(1, width - 14)
        local fit = width > 20 and room / math.max(x, 1) or 1
        canvas:SetScale(math.min(p.scale or 1, fit, (self:GetHeight() - 36) / height))
        canvas:SetAlpha(editor and 1 or (p.enabled and (p.hoverAlpha or 1) or .38))
        summary:SetText(not p.enabled and unavailable or (count == 0 and empty or ""))
        for _, side in ipairs(SIDES) do
            local label = sideLabels[side]
            if label then
                label:ClearAllPoints()
                label:SetPoint("BOTTOM", actionPanels[side], "TOP", 0, 7)
            end
        end
    end
    frame:SetScript("OnSizeChanged", frame.Refresh)
    frame:SetScript("OnShow", function(owner)
        owner:Refresh()
        if C_Timer and C_Timer.NewTicker then owner.clockTicker = C_Timer.NewTicker(1, UpdateClock) end
    end)
    frame:SetScript("OnHide", function(owner)
        StopDrag()
        if owner.clockTicker then owner.clockTicker:Cancel(); owner.clockTicker = nil end
    end)
    if editor then frame.slots = slots; editor.selection = slots.left[1] end
    return frame
end
