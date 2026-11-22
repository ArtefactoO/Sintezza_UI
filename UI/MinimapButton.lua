local _, SUI = ...
local Text = SUI.Text

local MinimapButton = {}
SUI.MinimapButton = MinimapButton

local ICON = SUI.icon
local DEFAULT_ANGLE = 225
local BUTTON_SIZE = 31

local function AddCheck(root, label, getValue, setValue)
    if root.CreateCheckbox then
        root:CreateCheckbox(label, function() return getValue() == true end, function() setValue(not getValue()) end)
    else
        local state = getValue() and Text("Вкл.", "On") or Text("Выкл.", "Off")
        root:CreateButton(label .. " (" .. state .. ")", function() setValue(not getValue()) end)
    end
end

function MinimapButton:OpenQuickMenu(owner)
    if not MenuUtil or not MenuUtil.CreateContextMenu then SUI:OpenSettings("dashboard"); return end
    SUI.SettingsTheme:OpenMenu(owner, function(_, root)
        root:CreateTitle("Sintezza UI")
        root:CreateButton(Text("Открыть настройки", "Open settings"), function() SUI:OpenSettings("dashboard") end)
        root:CreateButton(Text("Игровая панель", "Game bar"), function() SUI:OpenSettings("gameBar") end)
        root:CreateButton(Text("Рейд-инструменты", "Raid tools"), function() SUI:OpenSettings("raidTools") end)
        root:CreateButton(Text("Неймплейты", "Nameplates"), function() SUI:OpenSettings("nameplates") end)
        root:CreateButton(Text("Иконки и откат", "Icons and cooldowns"), function() SUI:OpenSettings("cooldownMasks") end)
        if root.CreateDivider then root:CreateDivider() end

        local gameBar = SUI:GetModule("gameBar")
        local raidTools = SUI:GetModule("raidTools")
        AddCheck(root, Text("Показывать игровую панель", "Show game bar"),
            function() return gameBar and gameBar.profile and gameBar.profile.enabled end,
            function(value)
                if not (gameBar and gameBar.profile) then return end
                gameBar.profile.enabled = value
                gameBar:RequestButtonUpdate()
            end)
        AddCheck(root, Text("Показывать рейд-инструменты", "Show raid tools"),
            function() return raidTools and raidTools.profile and raidTools.profile.enabled end,
            function(value)
                if not (raidTools and raidTools.profile) then return end
                raidTools.profile.enabled = value
                raidTools:RequestSecureUpdate()
            end)
        AddCheck(root, Text("Режим перемещения", "Move panels"),
            function()
                return (gameBar and gameBar.profile and not gameBar.profile.locked)
                    or (raidTools and raidTools.profile and not raidTools.profile.locked) or false
            end,
            function(value)
                if gameBar and gameBar.profile then gameBar.profile.locked = not value; gameBar:RefreshSettings() end
                if raidTools and raidTools.profile then raidTools:SetEditMode(value); raidTools:RefreshSettings() end
            end)
        if raidTools and raidTools.ToggleRaidCheck then
            root:CreateButton(Text("Открыть проверку рейда", "Open raid check"), function() raidTools:ToggleRaidCheck(true) end)
        end
        if root.CreateDivider then root:CreateDivider() end
        root:CreateButton(Text("Переподключить EllesmereUI", "Reconnect EllesmereUI"), function()
            local _, message = SUI.Diagnostics:ReconnectEUI()
            SUI:Print(message)
        end)
        root:CreateButton(Text("Диагностика", "Diagnostics"), function() SUI:OpenSettings("diagnostics") end)
    end)
end

local function Atan2(y, x)
    if math.atan2 then return math.atan2(y, x) end
    if x > 0 then return math.atan(y / x) end
    if x < 0 and y >= 0 then return math.atan(y / x) + math.pi end
    if x < 0 then return math.atan(y / x) - math.pi end
    if y > 0 then return math.pi * .5 end
    if y < 0 then return -math.pi * .5 end
    return 0
end

function MinimapButton:GetSettings()
    if not SUI.db then return nil end
    SUI.db.minimap = type(SUI.db.minimap) == "table" and SUI.db.minimap or {}
    if type(SUI.db.minimap.hidden) ~= "boolean" then SUI.db.minimap.hidden = false end
    if type(SUI.db.minimap.angle) ~= "number" then SUI.db.minimap.angle = DEFAULT_ANGLE end
    return SUI.db.minimap
end

function MinimapButton:PlaceLauncher(button, parent, angle)
    if not button or not Minimap or button:GetParent() ~= parent then return end
    angle = math.rad(angle)
    local radius = math.max(Minimap:GetWidth() or 140, Minimap:GetHeight() or 140) * .5 + 5
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

function MinimapButton:UpdatePosition()
    local settings = self:GetSettings()
    if settings then self:PlaceLauncher(self.button, Minimap, settings.angle or DEFAULT_ANGLE) end
end

function MinimapButton:RefreshVisibility()
    local button = self.button
    local settings = self:GetSettings()
    if not button or not settings then return end
    button:SetShown(not settings.hidden)
end

function MinimapButton:CreateLauncher(name, parent, texture)
    local button = CreateFrame("Button", name, parent)
    button:SetSize(BUTTON_SIZE, BUTTON_SIZE)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel((Minimap:GetFrameLevel() or 0) + 8)
    button:SetClampedToScreen(true)
    button:RegisterForDrag("LeftButton")

    -- Use Blizzard's conventional minimap regions instead of a frame
    -- backdrop. EllesmereUI recognises and strips these when it moves the
    -- button into its addon flyout, then supplies the same round ring as for
    -- every other collected button. Without EUI they remain a native circle.
    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetSize(25, 25)
    background:SetPoint("CENTER")
    background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    background:SetVertexColor(0, 0, 0, 1)
    button.background = background

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetTexture(texture)
    icon:SetSize(21, 21)
    icon:SetPoint("CENTER")
    button.icon = icon

    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetSize(53, 53)
    border:SetPoint("TOPLEFT", button, "TOPLEFT")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    button.border = border
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    local hover = button:CreateTexture(nil, "OVERLAY")
    hover:SetTexture(texture)
    hover:SetAllPoints(icon)
    hover:SetAlpha(.16)
    hover:SetBlendMode("ADD")
    hover:Hide()
    button.hover = hover
    return button
end

function MinimapButton:EnableLauncherDrag(button, parent, onAngle)
    button:SetScript("OnDragStart", function(self)
        if self:GetParent() ~= parent then return end
        self.__suiDragging = true
        self.__suiDragged = true
        self:SetScript("OnUpdate", function()
            local scale = Minimap:GetEffectiveScale()
            local cursorX, cursorY = GetCursorPosition()
            local centerX, centerY = Minimap:GetCenter()
            if not scale or scale == 0 or not centerX or not centerY then return end
            cursorX, cursorY = cursorX / scale, cursorY / scale
            onAngle(math.deg(Atan2(cursorY - centerY, cursorX - centerX)))
        end)
    end)
    button:SetScript("OnDragStop", function(self)
        self.__suiDragging = nil
        self:SetScript("OnUpdate", nil)
    end)
    button:HookScript("OnHide", function(self)
        if self.__suiDragging then
            self.__suiDragging = nil
            self:SetScript("OnUpdate", nil)
        end
    end)
end

function MinimapButton:CreateButton()
    if self.button or not Minimap then return self.button end

    -- EllesmereUI collects this named, direct child into its addon flyout.
    local button = self:CreateLauncher("Sintezza_UI_MinimapButton", Minimap, ICON)

    button:SetScript("OnEnter", function(self)
        self.hover:Show()
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("Sintezza UI", .047, .824, .624)
        Sintezza_Theme:AddMinimapToggleHint(GameTooltip)
        if self:GetParent() == Minimap then
            GameTooltip:AddLine(Text("Перетащите — изменить положение", "Drag to move"), .50, .55, .59)
        end
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function(self)
        self.hover:Hide()
        GameTooltip:Hide()
    end)
    Sintezza_Theme:BindMinimapToggle(button, {
        window = function() return SUI.SettingsUI and SUI.SettingsUI.window end,
        open = function() SUI:OpenSettings("dashboard") end,
        canToggle = function(self)
            if not self.__suiDragged then return true end
            self.__suiDragged = nil
            return false
        end,
    })
    self:EnableLauncherDrag(button, Minimap, function(angle)
        local settings = self:GetSettings()
        if not settings then return end
        settings.angle = angle
        self:UpdatePosition()
    end)

    self.button = button
    self:UpdatePosition()
    self:RefreshVisibility()
    return button
end

function MinimapButton:Initialize()
    if self.initialized then return end
    self.initialized = true
    self:CreateButton()
end
