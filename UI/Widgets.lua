local _, SUI = ...
local Text, T = SUI.Text, SUI.SettingsTheme
local W = Sintezza_Theme:CreateWidgets(SUI.SettingsTheme)
SUI.Widgets = W

function W.onToggle()
    if SUI.initialized then SUI:RefreshModuleEvents() end
end

local AttachHelp, Toggle, Section, BindAvailability, EditBox = W.Help, W.Toggle, W.Section, W.BindAvailability, W.EditBox

local function RefreshHelp(row)
    local hint, reason = row.settingsHelpText, row.unavailableReason
    local note = reason or hint
    if reason and hint and reason ~= hint then note = reason .. "\n\n" .. hint end
    local button = row.helpButton
    if note then
        local label = row.settingsHelpLabel or row.label
        AttachHelp(W, row, note, label)
        if button and label then
            button:ClearAllPoints()
            button:SetPoint("LEFT", label, "LEFT", math.min(label:GetWidth(), label:GetStringWidth()) + 4, 0)
        end
    end
    if row.helpButton then row.helpButton:SetShown(note ~= nil) end
end

function W:Help(row, description, label)
    row.settingsHelpText = type(description) == "string" and description:find("%S") and description or nil
    row.settingsHelpLabel = label or row.settingsHelpLabel
    RefreshHelp(row)
    return row
end

function W:EditBox(parent, placeholder, onCommit)
    local box = EditBox(self, parent, placeholder, onCommit)
    box.placeholder:SetPoint("RIGHT", box, "RIGHT", -10, 0)
    box.placeholder:SetWordWrap(false)
    return box
end

function W:Toggle(parent, label, getValue, setValue, description, setterRefreshesEvents, layout)
    local row = Toggle(self, parent, label, getValue, setValue, nil, setterRefreshesEvents, layout)
    if description then self:Help(row, description) end
    return row
end

function W:QuietCard(parent, title)
    local card = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    T:Backdrop(card, T.input, T.lineSoft)
    Sintezza_Theme:Tint(card, "SetBackdropColor", T.input, .34)
    Sintezza_Theme:Tint(card, "SetBackdropBorderColor", T.lineSoft, .65)
    card.title = self:Label(card, title, 13, T.text, "display")
    card.title:SetPoint("TOPLEFT", 14, -12)
    card.title:SetPoint("RIGHT", -32, 0)
    card.title:SetWordWrap(false)
    return card
end

function W:Section(parent, title, description, style)
    local section = Section(self, parent, title, nil, style)
    if description then self:Help(section, description, section.title) end
    return section
end

function W:BindAvailability(row, check, description)
    if description then self:Help(row, description) end
    BindAvailability(self, row, check)
    local refresh = row.Refresh
    function row:Refresh(...)
        local result = refresh(self, ...)
        RefreshHelp(self)
        return result
    end
    RefreshHelp(row)
    return row
end

function W:FeatureToggle(parent, id, label, description, guard, changed)
    local dependency = SUI:GetFeatureRequirementLabel(id)
    local row = self:Toggle(parent, label, function() return SUI:GetFeature(id) end, function(value)
        if SUI:SetFeature(id, value) and changed then changed() end
    end, description or (dependency and (Text("Требуется ", "Requires ") .. dependency)), true)
    row.settingsID = id
    return self:BindAvailability(row, function()
        local available, reason = SUI:GetFeatureAvailability(id)
        if not available then return false, reason end
        if guard then return guard() end
        return true
    end)
end

function W:NavigationRow(parent, title, description, action, callback)
    local row = self:ActionRow(parent, title, action, callback)
    row.button:SetWidth(122)
    row.label:SetPoint("RIGHT", row.button, "LEFT", -10, 0)
    return self:Help(row, description)
end

function W:WithStatus(row)
    local control = row.button or row.track
    row:SetHeight(42)
    row.label:ClearAllPoints()
    row.label:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -6)
    row.label:SetPoint("TOPRIGHT", row, "TOPRIGHT", -(control and control:GetWidth() or 0) - 10, -6)
    row.label:SetWordWrap(false)
    row.status = self:Label(row, "", 10, T.muted)
    row.status:SetPoint("TOPLEFT", row.label, "BOTTOMLEFT", 0, -3)
    row.status:SetPoint("RIGHT", row.label, "RIGHT")
    row.status:SetWordWrap(false)
    return row
end

function W:TransparencySlider(parent, label, maximum, getOpacity, setOpacity)
    return self:SliderRow(parent, label, 0, maximum, 1, function()
        return 100 - math.floor((getOpacity() or 1) * 100 + .5)
    end, function(value)
        setOpacity((100 - value) / 100)
    end, "%")
end

function W:BackdropControls(parent, appearance, apply)
    local swatch = self:ColorRow(parent, Text("Цвет фона", "Background color"), function()
        local color = appearance().backdropColor
        return { color[1], color[2], color[3], 1 }
    end, function() end)
    swatch.swatch:SetScript("OnClick", function()
        local style = appearance()
        local r, g, b = unpack(style.backdropColor)
        local function SetRGB(red, green, blue)
            if appearance() ~= style then return end
            style.backdropColor = { red, green, blue, style.backdropColor[4] }
            apply()
            swatch:Refresh()
        end
        self:OpenColorPicker(swatch, { r = r, g = g, b = b, a = 1 }, false, function(color)
            SetRGB(color.r, color.g, color.b)
        end, function() SetRGB(r, g, b) end)
    end)
    local transparency = self:TransparencySlider(parent, Text("Прозрачность фона", "Background transparency"), 100,
        function() return appearance().backdropColor[4] end, function(opacity)
            appearance().backdropColor[4] = opacity
            apply()
        end)
    self:Help(transparency, Text("Меняет только фон. 0% — непрозрачный фон, 100% — полностью прозрачный.",
        "Changes the background only. 0% is opaque and 100% is fully transparent."))
    local function BackgroundShown()
        return appearance().backdropEnabled == true, Text("Включи показ фона.", "Enable the background.")
    end
    return self:BindAvailability(swatch, BackgroundShown), self:BindAvailability(transparency, BackgroundShown)
end
