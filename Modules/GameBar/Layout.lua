local ADDON, SUI = ...
local Text = SUI.Text
local SGB = SUI.GameBar
local G = _G
local SLOT_COUNT = 7

function SGB:CreateVisuals()
    local root = CreateFrame("Frame", "Sintezza_GameBarRoot", UIParent)
    root:SetFrameStrata("MEDIUM")
    root:SetClampedToScreen(true)
    root:SetMovable(true)
    root:EnableMouse(true)
    root:RegisterForDrag("LeftButton")
    root:SetScript("OnDragStart", function(frame)
        if not SGB.profile.locked and not SGB:InCombat() then frame:StartMoving() end
    end)
    root:SetScript("OnDragStop", function(frame)
        frame:StopMovingOrSizing()
        local point, _, relativePoint, x, y = frame:GetPoint(1)
        SGB.profile.point = point
        SGB.profile.relativePoint = relativePoint
        SGB.profile.x = math.floor(x + .5)
        SGB.profile.y = math.floor(y + .5)
        SGB:RefreshSettings()
    end)
    root:SetScript("OnEnter", function() SGB:OnPanelEnter() end)
    root:SetScript("OnLeave", function() SGB:OnPanelLeave() end)
    self.root = root

    -- Keep hit testing independent from visual alpha. The root and its hover
    -- region stay at alpha 1 while only this child fades in and out.
    self.visualRoot = CreateFrame("Frame", nil, root)
    self.visualRoot:SetAllPoints()
    self.visualRoot:SetFrameLevel(root:GetFrameLevel() + 1)

    self.hoverRegion = CreateFrame("Frame", nil, root)
    self.hoverRegion:SetAllPoints()
    self.hoverRegion:EnableMouse(true)
    self.hoverRegion:SetScript("OnEnter", function() SGB:OnPanelEnter() end)
    self.hoverRegion:SetScript("OnLeave", function() SGB:OnPanelLeave() end)

    self.leftPanel = self:CreateSegment(self.visualRoot)
    self.timePanel = self:CreateSegment(self.visualRoot)
    self.rightPanel = self:CreateSegment(self.visualRoot)

    self.timeButton = CreateFrame("Button", nil, self.timePanel)
    self.timeButton:SetAllPoints()
    self.timeButton:SetFrameLevel(self.timePanel:GetFrameLevel() + 3)
    self.timeButton:RegisterForClicks("AnyUp")
    self.timeButton:SetScript("OnEnter", function(frame)
        SGB:OnPanelEnter()
        if SUI.HoverEffects then SUI.HoverEffects:SetClockHovered(frame, true) end
    end)
    self.timeButton:SetScript("OnLeave", function(frame)
        if SUI.HoverEffects then SUI.HoverEffects:SetClockHovered(frame, false) end
        SGB:OnPanelLeave()
    end)
    self.timeButton:SetScript("OnClick", function(_, button) SGB:ClockClick(button) end)

    self.clockText = self.timePanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    self.clockText:SetPoint("CENTER")
    local clockR, clockG, clockB, clockA = self.clockText:GetTextColor()
    self.clockBaseColor = { clockR, clockG, clockB, clockA }

    self.buttons = {}
    for index = 1, SLOT_COUNT * 2 do
        self.buttons[index] = self:CreateButton(self.visualRoot)
    end
    if self.CreateMiniBar then self:CreateMiniBar() end
end

function SGB:CreateSegment(parent, name)
    local panel = CreateFrame("Frame", name, parent, "BackdropTemplate")
    panel:SetFrameLevel(parent:GetFrameLevel() + 1)
    panel:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    panel.glowBorder = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    panel.glowBorder:SetAllPoints()
    panel.glowBorder:SetFrameLevel(panel:GetFrameLevel() + 1)
    panel.glowBorder:EnableMouse(false)
    return panel
end

function SGB:CreateButton(parent)
    local button = CreateFrame("Button", nil, parent, "SecureActionButtonTemplate,SecureHandlerStateTemplate")
    button:RegisterForClicks("AnyUp")
    button:SetFrameLevel(parent:GetFrameLevel() + 4)

    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetPoint("CENTER")
    button.icon:SetTexCoord(0, 1, 0, 1)

    button.badge = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    button.badge:SetPoint("TOP", button.icon, "TOP", 0, 4)
    button.badge:SetJustifyH("CENTER")
    button.badge:SetShadowColor(0, 0, 0, 1)
    button.badge:SetShadowOffset(1, -1)

    button:SetScript("OnEnter", function(frame)
        SGB:OnPanelEnter()
        SGB:ShowTooltip(frame)
        SGB:SetButtonHovered(frame, true)
    end)
    button:SetScript("OnLeave", function(frame)
        SGB:HideTooltip()
        SGB:SetButtonHovered(frame, false)
        SGB:OnPanelLeave()
    end)
    button:SetScript("PostClick", function(frame, mouse)
        local entry = frame.entry
        if not entry then return end
        if SGB:InCombat() then
            -- The secure action has already run. Never open a panel from
            -- this Lua handler while the client is in combat lockdown.
            local action = mouse == "LeftButton" and frame:GetAttribute("type1")
            if action ~= "click" and action ~= "teleporthome" then
                local label = entry.label or Text("Действие", "Action")
                SGB:Error(Text("Недоступно в бою: %s", "Unavailable in combat: %s"):format(label))
            end
            return
        end
        if entry.secureClick then
            if not frame:GetAttribute("clickbutton1") then
                SGB:Error(Text("Кнопка «%s» недоступна. Используй кнопку Blizzard.", "“%s” is unavailable. Use the Blizzard button."):format(entry.label))
            end
            return
        end
        if entry.click then entry.click(frame, mouse) end
    end)
    return button
end

function SGB:SetButtonHovered(button, hovered)
    if SUI.HoverEffects then
        SUI.HoverEffects:SetIconHovered(button, hovered == true)
    else
        self:ColorButton(button, hovered == true)
    end
end

function SGB:ColorButton(button, hovered)
    if not button.entry then return end
    local appearance = self.profile.appearance
    local color = appearance.iconColor or { 1, 1, 1, 1 }
    local base = {
        color[1], color[2], color[3],
        (color[4] or 1) * (tonumber(appearance.iconAlpha) or 1),
    }
    local hover
    if appearance.hoverColorMode == "CLASS" then
        hover = { self:GetClassColor() }
    else
        local configured = appearance.hoverColor or { .35, .75, 1, 1 }
        hover = { configured[1], configured[2], configured[3], configured[4] or 1 }
    end
    if SUI.HoverEffects then
        SUI.HoverEffects:ConfigureIcon(button, button.icon, button.icon:GetWidth(), button.icon:GetHeight(), base, hover)
        if hovered then SUI.HoverEffects:SetIconHovered(button, true) else SUI.HoverEffects:Reset(button) end
    elseif hovered then
        button.icon:SetVertexColor(unpack(hover))
    else
        button.icon:SetVertexColor(unpack(base))
    end
end

function SGB:ApplySegmentStyle(panel, appearance)
    appearance = appearance or self.profile.appearance
    local borderSize = tonumber(appearance.borderSize) or 1
    local glowStyle = appearance.borderStyle == "GLOW" and SUI:IntegrationEnabled("panelglow")
        and EllesmereUI and type(EllesmereUI.ApplyBorderStyle) == "function"
    panel:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = math.max(1, borderSize),
    })
    panel:SetBackdropColor(
        appearance.backdropColor[1],
        appearance.backdropColor[2],
        appearance.backdropColor[3],
        appearance.backdropEnabled and appearance.backdropColor[4] or 0
    )
    panel:SetBackdropBorderColor(
        appearance.borderColor[1],
        appearance.borderColor[2],
        appearance.borderColor[3],
        borderSize > 0 and not glowStyle and appearance.borderColor[4] or 0
    )
    local glow = panel.glowBorder
    if glow then
        if glowStyle and borderSize > 0 and EllesmereUI and EllesmereUI.ApplyBorderStyle then
            glow:Show()
            EllesmereUI.ApplyBorderStyle(glow, borderSize,
                appearance.borderColor[1], appearance.borderColor[2],
                appearance.borderColor[3], appearance.borderColor[4], "glow")
        else
            if EllesmereUI and EllesmereUI.ApplyBorderStyle then
                EllesmereUI.ApplyBorderStyle(glow, 0, 0, 0, 0, 0, "glow")
            end
            glow:Hide()
        end
    end
end

function SGB:NormalizeButtonSlots()
    local profile = self.profile
    local seen = {}
    for _, list in ipairs({ profile.leftButtons, profile.rightButtons }) do
        for slot = 1, SLOT_COUNT do
            local id = list[slot]
            if not id or (id ~= "NONE" and not self:GetButtonEntry(id)) or (id ~= "NONE" and seen[id]) then
                list[slot] = "NONE"
            elseif id ~= "NONE" then
                seen[id] = true
            end
        end
        for slot = #list, SLOT_COUNT + 1, -1 do list[slot] = nil end
    end
end

function SGB:GetVisibleButtonCount(ids)
    local count = 0
    for slot = 1, SLOT_COUNT do
        local id = ids[slot]
        if id and self:IsButtonAvailable(id) and not self.profile.hiddenButtons[id] then
            count = count + 1
        end
    end
    return count
end

function SGB:GetSideWidth(ids)
    local appearance = self.profile.appearance
    local count = self:GetVisibleButtonCount(ids)
    return 2 * appearance.panelPadding
        + count * appearance.iconSize
        + math.max(0, count - 1) * appearance.buttonSpacing
end

function SGB:ApplyPosition()
    if not self.root then return false end
    if self:InCombat() then
        self.pendingSecureUpdate = true
        return false
    end
    local profile = self.profile
    self.root:ClearAllPoints()
    self.root:SetPoint(profile.point, UIParent, profile.relativePoint, profile.x, profile.y)
    self.root:SetScale(profile.scale or 1)
    return true
end

function SGB:RequestHousingData()
    if SUI.isForever then return false end
    if self.houseInfoLoaded then return true end
    if self.houseInfoRequested then return false end
    if self:InCombat() then
        self.pendingSecureUpdate = true
        return
    end
    local api = G.C_Housing and G.C_Housing.GetPlayerOwnedHouses
    if type(api) == "function" then
        self.houseInfoRequested = true
        local ok, houses = pcall(api)
        if not ok then
            self.houseInfoRequested = nil
            return false
        end
        if type(houses) == "table" then
            self.playerHouseList = houses
            self.houseInfoLoaded = true
            self.houseInfoRequested = nil
            return true
        end
    else
        self.houseInfoLoaded = true
        self.playerHouseList = {}
        return true
    end
    return false
end

function SGB:ConfigureHomeButton(button)
    button:SetAttribute("type1", nil)
    button:SetAttribute("house-neighborhood-guid", nil)
    button:SetAttribute("house-guid", nil)
    button:SetAttribute("house-plot-id", nil)

    if not self.houseInfoLoaded then self:RequestHousingData() end
    local house = self.playerHouseList and self.playerHouseList[1]
    if house and house.neighborhoodGUID and house.houseGUID and house.plotID then
        button:SetAttribute("house-neighborhood-guid", house.neighborhoodGUID)
        button:SetAttribute("house-guid", house.houseGUID)
        button:SetAttribute("house-plot-id", house.plotID)
        button:SetAttribute("type1", "teleporthome")
    end
end

function SGB:ConfigureSecureClick(button, entry)
    if self:InCombat() then self.pendingSecureUpdate = true; return false end
    -- A slot can be reassigned to HOME or any Lua action.
    -- Clear both delegates and the driver before assigning the new action.
    if button.__suiSecureClickDriver then
        UnregisterStateDriver(button, "sui-click")
        button.__suiSecureClickDriver = nil
    end
    button:SetAttribute("_onstate-sui-click", nil)
    button:SetAttribute("clickbutton1", nil)
    button:SetAttribute("clickbutton2", nil)
    button:SetAttribute("useOnKeyDown", nil)
    button:SetAttribute("sui-click-ready", nil)
    button:SetAttribute("sui-click-combat", nil)
    local targetName = entry and (entry.secureClick or entry.combatSecureClick)
    if not targetName then return true end
    local target
    if type(targetName) == "table" then
        for _, name in ipairs(targetName) do
            if name ~= "EUI_TalentsRoute" and name ~= "EUI_SpellbookRoute" or SUI:IntegrationEnabled("books") then
                target = G[name]
            end
            if target then break end
        end
    else
        target = G[targetName]
    end
    if not target or type(target.Click) ~= "function" or not RegisterStateDriver
        or not UnregisterStateDriver then return false end
    -- Respect client-side restrictions on scripted input; no insecure fallback.
    if target.IsForbidden and target:IsForbidden() then return false end
    if target.HasAccessConstraints and target:HasAccessConstraints() then return false end
    local aspect = Enum and Enum.ForbiddenAspect and Enum.ForbiddenAspect.ScriptedInput
    if aspect and target.HasAnyForbiddenAspects and target:HasAnyForbiddenAspects(aspect) then return false end
    button:SetAttribute("useOnKeyDown", false)
    button:SetAttribute("clickbutton1", target)
    button:SetAttribute("clickbutton2", target)
    local ready = entry.secureClick and "click" or nil
    button:SetAttribute("sui-click-ready", ready)
    button:SetAttribute("sui-click-combat", entry.combatSecureClick and "click" or nil)
    button:SetAttribute("_onstate-sui-click", [[
        if newstate == "ready" then
            local action = self:GetAttribute("sui-click-ready")
            self:SetAttribute("type1", action)
            self:SetAttribute("type2", action)
        else
            self:SetAttribute("type1", self:GetAttribute("sui-click-combat"))
            self:SetAttribute("type2", nil)
        end
    ]])
    button:SetAttribute("type1", ready)
    button:SetAttribute("type2", ready)
    RegisterStateDriver(button, "sui-click", "[combat] blocked; ready")
    button.__suiSecureClickDriver = true
    return true
end

function SGB:ApplyButtonAssignments()
    if self:InCombat() then
        self.pendingSecureUpdate = true
        return false
    end

    local profile = self.profile
    local appearance = profile.appearance
    local groups = {
        { profile.leftButtons, self.leftPanel },
        { profile.rightButtons, self.rightPanel },
    }
    local cursor = 1

    for _, group in ipairs(groups) do
        local ids, panel = group[1], group[2]
        local previousVisible
        for slot = 1, SLOT_COUNT do
            local button = self.buttons[cursor]
            local id = ids[slot]
            local entry = id and self:IsButtonAvailable(id) and self:GetButtonEntry(id) or nil
            cursor = cursor + 1

            button:ClearAllPoints()
            button:SetParent(panel)
            button:SetAttribute("type1", nil)
            button:SetAttribute("type2", nil)
            button:SetAttribute("house-neighborhood-guid", nil)
            button:SetAttribute("house-guid", nil)
            button:SetAttribute("house-plot-id", nil)
            self:ConfigureSecureClick(button, entry and not profile.hiddenButtons[id] and entry or nil)
            button.entry = entry
            button.entryID = id

            if entry and not profile.hiddenButtons[id] then
                button:SetSize(appearance.iconSize, appearance.iconSize)
                local iconScale = math.max(.5, math.min(1, tonumber(appearance.iconScale) or 1))
                button.icon:SetSize(appearance.iconSize * iconScale, appearance.iconSize * iconScale)
                local badgeSize = math.max(9, math.floor((tonumber(appearance.timeFontSize) or 25) * .48 + .5))
                local badgeOffset = math.max(2, math.floor(badgeSize * .3 + .5))
                button.badge:ClearAllPoints()
                button.badge:SetPoint("TOP", button.icon, "TOP", 0, badgeOffset)
                button.badge:SetWidth(appearance.iconSize * iconScale)
                button.icon:SetTexture(entry.icon)
                button:Show()
                self:ColorButton(button, false)
                if previousVisible then
                    button:SetPoint("LEFT", previousVisible, "RIGHT", appearance.buttonSpacing, 0)
                else
                    button:SetPoint("LEFT", panel, "LEFT", appearance.panelPadding, 0)
                end
                previousVisible = button
                if id == "HOME" then self:ConfigureHomeButton(button) end
            else
                if SUI.HoverEffects then SUI.HoverEffects:Reset(button) end
                button:Hide()
            end
        end
    end

    self:UpdateBadges()
    return true
end

function SGB:ApplyLayout()
    if not self.root then return false end
    if self:InCombat() then
        self.pendingSecureUpdate = true
        return false
    end

    self:NormalizeButtonSlots()
    local appearance = self.profile.appearance
    local leftWidth = self:GetSideWidth(self.profile.leftButtons)
    local rightWidth = self:GetSideWidth(self.profile.rightButtons)
    local sideHeight = appearance.iconSize + 2 * appearance.panelPadding
    local x, height, count = 0, 0, 0
    local function Place(panel, shown, width, panelHeight, y)
        panel:SetShown(shown)
        if not shown then return end
        if count > 0 then x = x + appearance.segmentGap end
        panel:ClearAllPoints()
        panel:SetSize(width, panelHeight)
        panel:SetPoint("LEFT", self.root, "LEFT", x, y)
        x, height, count = x + width, math.max(height, panelHeight), count + 1
    end
    Place(self.leftPanel, self:GetVisibleButtonCount(self.profile.leftButtons) > 0,
        leftWidth, sideHeight, appearance.verticalAlignment or 0)
    Place(self.timePanel, self.profile.clock.enabled ~= false, appearance.timeWidth, appearance.timeHeight, 0)
    Place(self.rightPanel, self:GetVisibleButtonCount(self.profile.rightButtons) > 0,
        rightWidth, sideHeight, appearance.verticalAlignment or 0)
    self.hasVisibleSegments = count > 0
    self.root:SetSize(math.max(1, x), math.max(1, height))

    self:ApplySegmentStyle(self.leftPanel)
    self:ApplySegmentStyle(self.timePanel)
    self:ApplySegmentStyle(self.rightPanel)

    local clockFont = self:GetFont()
    local timeOutline = self:GetFontFlags(appearance.timeOutline, "OUTLINE")
    self.clockText:SetFont(clockFont, appearance.timeFontSize, timeOutline)
    local baseClock = self.clockBaseColor or { 1, 1, 1, 1 }
    local clockR, clockG, clockB, clockA = unpack(baseClock)
    local hoverClock
    if appearance.hoverColorMode == "CLASS" then
        hoverClock = { self:GetClassColor() }
    else
        local configured = appearance.hoverColor or { .35, .75, 1, 1 }
        hoverClock = { configured[1], configured[2], configured[3], configured[4] or 1 }
    end
    if SUI.HoverEffects then
        SUI.HoverEffects:ConfigureClock(self.timeButton, self.clockText, baseClock, hoverClock)
        SUI.HoverEffects:Reset(self.timeButton)
    end
    local badgeSize = math.max(9, math.floor((tonumber(appearance.timeFontSize) or 25) * .48 + .5))
    for _, button in ipairs(self.buttons) do
        local badgeFont = self:GetFont()
        button.badge:SetFont(badgeFont, badgeSize, timeOutline)
        button.badge:SetTextColor(clockR, clockG, clockB, clockA)
    end
    self:ApplyPosition()
    self:ApplyButtonAssignments()
    self:UpdateClock()
    return true
end

function SGB:ApplyVisibilityDriver()
    if not self.root then return end
    if self:InCombat() then
        self.pendingSecureUpdate = true
        return
    end

    if UnregisterStateDriver then UnregisterStateDriver(self.root, "visibility") end
    local profile = self.profile
    local rule = "show"

    if not profile.enabled or self.hasVisibleSegments == false then
        rule = "hide"
    elseif self.settingsOpen then
        rule = "show"
    elseif profile.hideInPetBattle and profile.combatVisibility == "HIDE" then
        rule = "[petbattle] hide; [combat] hide; show"
    elseif profile.hideInPetBattle then
        rule = "[petbattle] hide; show"
    elseif profile.combatVisibility == "HIDE" then
        rule = "[combat] hide; show"
    end

    if RegisterStateDriver then
        RegisterStateDriver(self.root, "visibility", rule)
    else
        self.root:SetShown(rule ~= "hide")
    end
end

function SGB:ApplyAllSettings()
    if not self.root then return end
    self.settingsApplySerial = (self.settingsApplySerial or 0) + 1
    self:ApplyLayout()
    self:ApplyVisibilityDriver()
    if self.ApplyMiniBar then self:ApplyMiniBar() end
    local specBar = SUI:GetModule("specBar")
    if specBar and specBar.RefreshStyle then specBar:RefreshStyle() end
    self:RestartClockTicker()
    self:RefreshFade()
    if SUI.initialized then SUI:RefreshModuleEvents() end
end

function SGB:ResetPosition()
    local profile = self.profile
    profile.point, profile.relativePoint, profile.x, profile.y = "TOP", "TOP", 0, 0
    self:ApplyPosition()
    self:RefreshSettings()
end

function SGB:UpdateBadges(kind)
    for _, button in ipairs(self.buttons or {}) do
        local entry = button.entry
        local badge = entry and entry.badge
        if badge and (not kind or badge == kind) then
            local value = badge == "friends" and self:GetFriendCount() or self:GetGuildCount()
            local count = tonumber(value) or 0
            button.badge:SetAlpha(1)
            button.badge:SetText(count > 0 and tostring(count) or "")
        elseif not kind then
            button.badge:SetText("")
        end
    end
    if self.UpdateMiniOnline then self:UpdateMiniOnline(kind) end
end

function SGB:RestartClockTicker()
    if not self.profile or not C_Timer or not C_Timer.NewTicker then return end
    local main, mini = self:ClockDemand()
    if not main and not mini then
        if self.clockTicker and self.clockTicker.Cancel then self.clockTicker:Cancel() end
        self.clockTicker, self.clockTickerInterval = nil, nil
        return
    end
    local seconds = (main and self.profile.appearance.showSeconds) or (mini and self.profile.miniBar.showSeconds)
    local interval = seconds and 1 or math.max(1, self.profile.clock.updateInterval or 60)
    if self.clockTicker and self.clockTickerInterval == interval then
        self:UpdateClock()
        return
    end
    if self.clockTicker and self.clockTicker.Cancel then self.clockTicker:Cancel() end
    self.clockTickerInterval = interval
    self.clockTicker = C_Timer.NewTicker(interval, function()
        SUI:SafeModuleCall(SGB, "clock", SGB.UpdateClock)
    end)
    self:UpdateClock()
end

function SGB:ClockDemand()
    local p = self.profile
    return p and p.enabled and p.clock.enabled ~= false and self.clockText ~= nil,
        p and p.miniBar and p.miniBar.enabled and p.miniBar.showClock ~= false and self.miniClock ~= nil
end

function SGB:UpdateClock()
    local main, miniEnabled = self:ClockDemand()
    if not main and not miniEnabled then return end
    local clock = self.profile.clock
    local appearance = self.profile.appearance
    local format = clock.twentyFourHour
        and (appearance.showSeconds and "%H:%M:%S" or "%H:%M")
        or (appearance.showSeconds and "%I:%M:%S %p" or "%I:%M %p")
    if main then
        self.clockText:SetAlpha(1)
        self.clockText:SetText(date(format))
    end
    if miniEnabled then
        local mini = type(self.profile.miniBar) == "table" and self.profile.miniBar or {}
        local miniFormat = mini.twentyFourHour ~= false
            and (mini.showSeconds == true and "%H:%M:%S" or "%H:%M")
            or (mini.showSeconds == true and "%I:%M:%S %p" or "%I:%M %p")
        self.miniClock.text:SetAlpha(1)
        self.miniClock.text:SetText(date(miniFormat))
    end
end

function SGB:ClockClick(button)
    if IsShiftKeyDown and IsShiftKeyDown() then
        collectgarbage("collect")
        self:Info(Text("Память Lua очищена.", "Lua memory collected."))
        return
    end
    if button == "LeftButton" then
        if self:InCombat() then self:Error(Text("Календарь недоступен в бою.", "Calendar is unavailable in combat.")); return end
        if G.GameTimeFrame and G.GameTimeFrame.Click and self:SafeCall(G.GameTimeFrame.Click, G.GameTimeFrame, "LeftButton") then return end
        if not G.ToggleCalendar then self:LoadBlizzardAddon("Blizzard_Calendar") end
        if G.ToggleCalendar and self:SafeCall(G.ToggleCalendar) then return end
        self:Error(Text("Календарь Blizzard недоступен.", "Blizzard’s calendar is unavailable."))
    elseif button == "RightButton" then
        if not ToggleTimeManager then self:LoadBlizzardAddon("Blizzard_TimeManager") end
        if ToggleTimeManager then
            ToggleTimeManager()
        else
            self:Error(Text("Часы Blizzard недоступны.", "Blizzard’s clock is unavailable."))
        end
    elseif button == "MiddleButton" and not self:InCombat() then
        ReloadUI()
    end
end
