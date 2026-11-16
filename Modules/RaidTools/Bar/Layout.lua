local ADDON, SUI = ...
local Text = SUI.Text
local SRT = SUI.RaidTools

local BACKDROP = {
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
}

local PANEL_NAMES = {
    TARGET = Text("ЦЕЛЬ", "TARGET"),
    WORLD = Text("МЕСТНОСТЬ", "WORLD"),
    CONTROL = Text("КОМАНДЫ", "ACTIONS"),
    PING = Text("ПИНГИ", "PINGS"),
}

local function makePanel(id)
    local panel = CreateFrame("Frame", "Sintezza_RaidTools" .. id, UIParent)
    panel.id, panel.cfg, panel.buttons = id, SRT.profile.panels[id], {}
    panel:SetClampedToScreen(true)
    panel:SetMovable(true)
    panel:EnableMouse(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetFrameStrata("MEDIUM")

    panel.visual = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    panel.visual:SetAllPoints()
    panel.visual:SetFrameLevel(panel:GetFrameLevel() + 1)
    panel.visual:SetBackdrop(BACKDROP)
    panel.visual.panelOwner = panel

    panel.glowBorder = CreateFrame("Frame", nil, panel.visual, "BackdropTemplate")
    panel.glowBorder:SetAllPoints()
    panel.glowBorder:SetFrameLevel(panel.visual:GetFrameLevel() + 1)
    panel.glowBorder:EnableMouse(false)

    panel.handle = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    panel.handle:SetFont(STANDARD_TEXT_FONT, 11, "OUTLINE")
    panel.handle:SetPoint("BOTTOM", panel, "TOP", 0, 4)
    panel.handle:SetText(PANEL_NAMES[id] or id)
    panel.handle:Hide()

    panel:SetScript("OnDragStart", function(frame)
        if (SRT.settingsOpen or not SRT.profile.locked) and not SRT:InCombat() then frame:StartMoving() end
    end)
    panel:SetScript("OnDragStop", function(frame)
        frame:StopMovingOrSizing()
        SRT:SavePanelPosition(frame)
        SRT:MoveLinkedPanels(frame)
    end)
    SRT:ConfigureFade(panel)
    return panel
end

function SRT:ApplyPanelStyle(panel)
    local appearance = self.profile.appearance
    local visual = panel.visual
    local borderSize = tonumber(appearance.borderSize) or 1
    local wantsGlow = appearance.borderStyle == "GLOW"
    local canGlow = wantsGlow and SUI:IntegrationEnabled("panelglow") and EllesmereUI and EllesmereUI.ApplyBorderStyle

    visual:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = math.max(1, borderSize),
    })
    visual:SetBackdropColor(
        appearance.backdrop[1], appearance.backdrop[2], appearance.backdrop[3],
        appearance.backdropEnabled and appearance.backdrop[4] or 0
    )
    visual:SetBackdropBorderColor(
        appearance.border[1], appearance.border[2], appearance.border[3],
        borderSize > 0 and not canGlow and appearance.border[4] or 0
    )

    local glow = panel.glowBorder
    if canGlow and borderSize > 0 then
        glow:Show()
        EllesmereUI.ApplyBorderStyle(glow, borderSize,
            appearance.border[1], appearance.border[2],
            appearance.border[3], appearance.border[4], "glow")
    else
        if EllesmereUI and EllesmereUI.ApplyBorderStyle then
            EllesmereUI.ApplyBorderStyle(glow, 0, 0, 0, 0, 0, "glow")
        end
        glow:Hide()
    end
end

function SRT:StyleBarButton(button)
    local appearance = self.profile.appearance
    button:SetBackdrop(BACKDROP)
    button:SetBackdropColor(0, 0, 0, 0)
    button:SetBackdropBorderColor(0, 0, 0, 0)

    local scale = math.max(.5, math.min(1, tonumber(appearance.iconScale) or .9))
    local size = (tonumber(appearance.iconSize) or button:GetWidth()) * scale
    button.icon:ClearAllPoints()
    button.icon:SetPoint("CENTER")
    button.icon:SetSize(size, size)
    self:ColorBarButton(button, false)
end

function SRT:ColorBarButton(button, hovered)
    if not button or not button.icon then return end
    local appearance = self.profile.appearance
    local color = appearance.iconColor or { 1, 1, 1, 1 }
    local base = {
        color[1], color[2], color[3],
        (color[4] or 1) * (tonumber(appearance.iconAlpha) or .9),
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

function SRT:SetButtonHovered(button, hovered)
    if not button then return end
    if SUI.HoverEffects then
        SUI.HoverEffects:SetIconHovered(button, hovered == true)
    else
        self:ColorBarButton(button, hovered == true)
    end
    local visual = button:GetParent()
    local panel = visual and (visual.panelOwner or visual:GetParent())
    if hovered then
        if panel and panel.cfg and panel.cfg.mouseover then self:FadePanelTo(panel, panel.cfg.hoverAlpha or 1) end
    elseif panel and panel.cfg then
        self:SchedulePanelFade(panel)
    end
end

function SRT:CreateBar()
    self.panels = {}
    for _, id in ipairs({ "TARGET", "WORLD", "CONTROL", "PING" }) do self.panels[id] = makePanel(id) end
    for _, marker in ipairs(self.registry.target) do
        table.insert(self.panels.TARGET.buttons, self:MakeTargetButton(self.panels.TARGET.visual, marker))
    end
    for _, marker in ipairs(self.registry.world) do
        table.insert(self.panels.WORLD.buttons, self:MakeWorldButton(self.panels.WORLD.visual, marker))
    end
    table.insert(self.panels.WORLD.buttons, self:MakeWorldClearButton(self.panels.WORLD.visual))

    local controls = self.panels.CONTROL
    table.insert(controls.buttons, self:MakeActionButton(controls.visual, "ready", self.media.ready, function(_, mouse)
        if mouse == "RightButton" then self:ToggleRaidCheck(true) else self:StartReadyCheck() end
    end))
    table.insert(controls.buttons, self:MakeActionButton(controls.visual, "pull", self.media.pull,
        function(_, mouse) self:DoPull(mouse == "RightButton") end))

    local pings = self.panels.PING
    for _ = 1, 3 do
        table.insert(pings.buttons, self:MakeActionButton(pings.visual, "ping", self.media.ping, function()
            if Minimap and Minimap.PingLocation then Minimap:PingLocation(.5, .5) end
        end))
    end
end

function SRT:LayoutPanel(panel)
    local cfg, appearance = panel.cfg, self.profile.appearance
    panel:ClearAllPoints()
    panel:SetPoint(cfg.point, UIParent, cfg.relativePoint, cfg.x, cfg.y)
    panel:SetScale(cfg.scale)
    self:ApplyPanelStyle(panel)

    panel.handle:SetFont(self:GetFont(), math.max(10, appearance.fontSize - 1), appearance.outline == "NONE" and "" or appearance.outline)
    panel.handle:SetTextColor(unpack(appearance.accent))
    panel.handle:SetShown(self.settingsOpen == true)

    local size, gap, previous = appearance.iconSize, appearance.spacing
    local count, actions = 0, self.profile.actions
    for _, button in ipairs(panel.buttons) do
        local shown = (button.kind ~= "ready" or actions.readyCheck ~= false or self.profile.raidCheck.enabled)
            and (button.kind ~= "pull" or actions.pullTimer ~= false)
            and (button.kind ~= "worldclear" or actions.worldClear ~= false)
        button:SetShown(shown)
        if shown then
            count = count + 1
            button:SetSize(size, size)
            button:ClearAllPoints()
            if not previous then
                button:SetPoint("TOPLEFT", panel.visual, "TOPLEFT", appearance.padding, -appearance.padding)
            elseif cfg.orientation == "VERTICAL" then
                button:SetPoint("TOP", previous, "BOTTOM", 0, -gap)
            else
                button:SetPoint("LEFT", previous, "RIGHT", gap, 0)
            end
            self:StyleBarButton(button)
            previous = button
        end
    end

    local width = cfg.orientation == "VERTICAL" and size + 2 * appearance.padding
        or count * size + math.max(0, count - 1) * gap + 2 * appearance.padding
    local height = cfg.orientation == "VERTICAL"
        and count * size + math.max(0, count - 1) * gap + 2 * appearance.padding
        or size + 2 * appearance.padding
    panel:SetSize(width, height)
    panel:SetShown(count > 0 and self:ShowPanel(panel))
    self:RefreshFade(panel)
end

function SRT:ApplyBarSettings()
    if not self.panels then return end
    if self:InCombat() then
        self.pendingSecureUpdate = true
        return false
    end
    self.settingsApplySerial = (self.settingsApplySerial or 0) + 1
    for _, panel in pairs(self.panels) do
        panel.cfg = self.profile.panels[panel.id]
        -- Movement lock and mouseover visibility are independent.  The old
        -- editMode flag used to force panels visible whenever they were
        -- unlocked, which made Text("Только при наведении", "Show on hover") appear broken.
        panel.editing = self.settingsOpen == true
        self:LayoutPanel(panel)
        for _, button in ipairs(panel.buttons) do
            if button.kind == "target" then self:ConfigureTargetButton(button) end
        end
    end
    if self.audit and self.ApplyAuditStyle then self:ApplyAuditStyle() end
    return true
end

function SRT:ApplyAllSettings()
    if self:InCombat() then
        self.pendingSecureUpdate = true
    else
        self:ApplyBarSettings()
    end
end

function SRT:SetEditMode(on)
    self.profile.locked = not on
    self.profile.editMode = false
    self:RequestSecureUpdate()
end

function SRT:SavePanelPosition(panel)
    local point, _, relativePoint, x, y = panel:GetPoint()
    local cfg = self.profile.panels[panel.id]
    cfg.point, cfg.relativePoint = point, relativePoint
    cfg.x, cfg.y = math.floor(x + .5), math.floor(y + .5)
end

function SRT:MoveLinkedPanels(origin)
    local link = origin.cfg.link
    if not link then return end
    for _, panel in pairs(self.panels or {}) do
        if panel ~= origin and panel.cfg.link == link then
            local _, _, _, ox, oy = origin:GetPoint()
            local _, _, _, px, py = panel:GetPoint()
            panel:ClearAllPoints()
            panel:SetPoint(panel.cfg.point, UIParent, panel.cfg.relativePoint,
                ox + (px - origin.cfg.x), oy + (py - origin.cfg.y))
            self:SavePanelPosition(panel)
        end
    end
end

function SRT:ShowCorePanels()
    self.profile.enabled = true
    self.profile.panels.TARGET.enabled = true
    self.profile.panels.WORLD.enabled = true
    self.profile.panels.CONTROL.enabled = true
    self:OnProfileChanged()
    SUI:RefreshModuleEvents()
end

function SRT:ResetPanelPositions()
    for id, cfg in pairs(self.defaults.panels) do
        local panel = self.profile.panels[id]
        panel.point, panel.relativePoint, panel.x, panel.y = cfg.point, cfg.relativePoint, cfg.x, cfg.y
    end
    self:RequestSecureUpdate()
end
