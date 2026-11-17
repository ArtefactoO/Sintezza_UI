local _, SUI = ...
local W, T = SUI.Widgets, SUI.SettingsTheme

local function IsFocusable(frame)
    if not frame or frame.skipSettingsFocus or not frame:IsVisible() or (frame.IsEnabled and not frame:IsEnabled()) then return false end
    local kind = frame:GetObjectType()
    return (kind == "Button" and frame:GetScript("OnClick"))
        or (kind == "Slider" and frame.stepFromKeyboard)
        or kind == "EditBox"
end

local function Collect(parent, controls)
    if not parent or not parent:IsVisible() then return end
    if IsFocusable(parent) then controls[#controls + 1] = parent end
    for _, child in ipairs({ parent:GetChildren() }) do Collect(child, controls) end
end

local function AppendInVisualOrder(parent, result)
    local controls, order = {}, {}
    Collect(parent, controls)
    for index, control in ipairs(controls) do order[control] = index end
    table.sort(controls, function(a, b)
        local ay, by = a:GetTop() or 0, b:GetTop() or 0
        if ay ~= by then return ay > by end
        local ax, bx = a:GetLeft() or 0, b:GetLeft() or 0
        if ax ~= bx then return ax < bx end
        return order[a] < order[b]
    end)
    for _, control in ipairs(controls) do result[#result + 1] = control end
end

local function Reveal(control, window)
    local scroll = control:GetParent()
    while scroll and scroll ~= window do
        if scroll.bar and scroll.body then
            local top, bottom = scroll:GetTop(), scroll:GetBottom()
            local controlTop, controlBottom = control:GetTop(), control:GetBottom()
            if top and bottom and controlTop and controlBottom then
                local offset = scroll:GetVerticalScroll()
                if controlTop > top then scroll.bar:SetValue(offset + top - controlTop - 3) end
                if controlBottom < bottom then scroll.bar:SetValue(offset + bottom - controlBottom + 3) end
            end
        end
        scroll = scroll:GetParent()
    end
end

function W:InstallSettingsKeyboard(ui, window, close)
    if not window.SetPropagateKeyboardInput or not window.EnableKeyboard then return end
    local ring = CreateFrame("Frame", nil, window, "BackdropTemplate")
    ring:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 2 })
    Sintezza_Theme:Tint(ring, "SetBackdropBorderColor", T.accent)
    ring:Hide()

    local focused
    local function Clear(keepEdit)
        local previous = focused
        focused = nil
        ring:Hide()
        if previous and previous.settingsOnBlur then previous:settingsOnBlur() end
        if not keepEdit and previous and previous:GetObjectType() == "EditBox" and previous:HasFocus() then
            previous:ClearFocus()
        end
    end

    local function Focus(control)
        if control ~= focused then Clear() end
        focused = control
        Reveal(control, window)
        ring:SetParent(control)
        ring:SetFrameLevel(control:GetFrameLevel() + 4)
        ring:ClearAllPoints()
        ring:SetPoint("TOPLEFT", control, "TOPLEFT", -2, 2)
        ring:SetPoint("BOTTOMRIGHT", control, "BOTTOMRIGHT", 2, -2)
        ring:Show()
        if control:GetObjectType() == "EditBox" then control:SetFocus() end
    end

    local function Move(current, direction)
        local controls = {}
        AppendInVisualOrder(ui.searchBox, controls)
        AppendInVisualOrder(ui.searchResults, controls)
        AppendInVisualOrder(ui.navScroll and ui.navScroll.body, controls)
        AppendInVisualOrder(ui.heading, controls)
        AppendInVisualOrder(ui.pages[ui.currentPage], controls)
        controls[#controls + 1] = close
        local index = direction > 0 and 0 or 1
        for i, control in ipairs(controls) do
            if control == current then index = i; break end
        end
        Focus(controls[(index + direction - 1) % #controls + 1])
    end

    local function Direction()
        return IsShiftKeyDown and IsShiftKeyDown() and -1 or 1
    end

    local function HasShortcutModifier()
        return (IsControlKeyDown and IsControlKeyDown())
            or (IsAltKeyDown and IsAltKeyDown())
            or (IsMetaKeyDown and IsMetaKeyDown())
    end

    local function IsInWindow(frame)
        while frame do
            if frame == window then return true end
            frame = frame:GetParent()
        end
        return false
    end

    function window:MoveSettingsFocus(edit)
        if InCombatLockdown() or not self:IsShown() or HasShortcutModifier() then return end
        edit:ClearFocus()
        Move(edit, Direction())
    end
    function window:ClearSettingsFocus() Clear(true) end
    function window:RevealSettingsControl(control) Reveal(control, self) end

    local function HasModal()
        return (W.IsColorPickerOpen and W:IsColorPickerOpen())
            or (W.choiceMenu and W.choiceMenu.IsShown and W.choiceMenu:IsShown())
            or (StaticPopup_Visible and StaticPopup_Visible("SINTEZZA_UI_CONFIRM"))
    end

    window:SetScript("OnKeyDown", function(self, key)
        if InCombatLockdown() then return end
        self:SetPropagateKeyboardInput(true)
        local edit = GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus()
        if HasModal() or edit or HasShortcutModifier() then return end
        local picker = W.openSpellPicker
        if picker and picker:HandleSettingsKey(key, Direction()) then
            self:SetPropagateKeyboardInput(false)
            return
        end
        if picker then return end
        if key == "ESCAPE" and Sintezza_Theme.DismissHelp and Sintezza_Theme:DismissHelp(self) then
            self:SetPropagateKeyboardInput(false)
            return
        end
        if key == "TAB" then
            self:SetPropagateKeyboardInput(false)
            Move(focused, Direction())
            return
        end
        if not IsFocusable(focused) or not IsInWindow(focused) then Clear(); return end
        if key == "ESCAPE" then Clear(); return end
        if key == "LEFT" or key == "RIGHT" or key == "UP" or key == "DOWN" then
            local step = focused.stepFromKeyboard
            if not step then return end
            self:SetPropagateKeyboardInput(false)
            step((key == "LEFT" or key == "DOWN") and -1 or 1)
        elseif key == "ENTER" or key == "SPACE" then
            if focused:GetObjectType() ~= "Button" then return end
            self:SetPropagateKeyboardInput(false)
            if focused.stepFromKeyboard then
                focused.stepFromKeyboard(Direction())
            else
                focused:Click()
            end
        end
    end)

    function window:RefreshSettingsKeyboard()
        local enabled = self:IsShown() and not InCombatLockdown()
        if enabled then self:SetPropagateKeyboardInput(true) else Clear() end
        self:EnableKeyboard(enabled)
    end
    window:HookScript("OnShow", window.RefreshSettingsKeyboard)
    window:HookScript("OnHide", window.RefreshSettingsKeyboard)
end

