local _, SUI = ...
local Text = SUI.Text
local SGB = SUI.GameBar

local MINI_ICON_PATH = Sintezza_Theme.icons.GameBar
local issecretvalue = issecretvalue or function() return false end
local MINI_MEMORY_LIMIT, MINI_MEMORY_REFRESH = 7, 30
local miniMemoryRows, miniMemoryScanTime = {}, -math.huge
local REST_STAGGER, REST_RISE, REST_FADE_AT, REST_FADE, REST_CYCLE = .32, .53, 1.54, .55, 2.24
local REST_LIFT = .10
local REST_ART = "Interface\\AddOns\\Sintezza_UI\\Media\\RestingGlyphs.png"
local REST_GLYPHS = {
    { cell = 0, x = -.27, y = -.23, height = .38, alpha = .42 },
    { cell = 0, x = -.01, y = .00, height = .47, alpha = .70 },
    { cell = 1, x = .28, y = .28, height = .58, alpha = 1 },
}

local function MiniProfile()
    local profile = SGB.profile
    if not profile then return nil end
    profile.miniBar = type(profile.miniBar) == "table" and profile.miniBar or {}
    return profile.miniBar
end

local function MiniAppearance()
    local mini = MiniProfile()
    if not mini then return {} end
    mini.appearance = type(mini.appearance) == "table" and mini.appearance or {}
    return mini.appearance
end

local function MiniTextColor()
    local appearance = MiniAppearance()
    local color = appearance.textColor or { 1, 1, 1, 1 }
    return color[1] or 1, color[2] or 1, color[3] or 1,
        (color[4] or 1) * (tonumber(appearance.textAlpha) or 1)
end

local function MiniIconColor(resting)
    local appearance = MiniAppearance()
    local color = appearance.iconColor or { 1, 1, 1, 1 }
    local alpha = (color[4] or 1) * (tonumber(appearance.iconAlpha) or .9)
    if resting then alpha = alpha * (tonumber(appearance.restingAlpha) or .62) end
    return color[1] or 1, color[2] or 1, color[3] or 1, alpha
end

local function ReadableNumber(value)
    if type(value) ~= "number" or issecretvalue(value) then return nil end
    return value
end

local function CurrentFPS()
    if type(GetFramerate) ~= "function" then return nil end
    local ok, value = pcall(GetFramerate)
    value = ok and ReadableNumber(value) or nil
    return value and math.max(0, math.floor(value + .5)) or nil
end

local function CurrentLatencies()
    if type(GetNetStats) ~= "function" then return nil end
    local ok, _, _, home, world = pcall(GetNetStats)
    if not ok then return nil end
    home, world = ReadableNumber(home), ReadableNumber(world)
    home = home and math.max(0, math.floor(home + .5)) or nil
    world = world and math.max(0, math.floor(world + .5)) or nil
    return home, world
end

local function CurrentLatency()
    local home, world = CurrentLatencies()
    return world or home
end

local function FormatAddonMemory(memory)
    if memory >= 1024 then return string.format(Text("%.1f МБ", "%.1f MB"), memory / 1024) end
    return string.format(Text("%.0f КБ", "%.0f KB"), memory)
end

local function RefreshMiniAddonMemory()
    local now = type(GetTime) == "function" and GetTime() or 0
    if now - miniMemoryScanTime < MINI_MEMORY_REFRESH then return miniMemoryRows end
    if type(UpdateAddOnMemoryUsage) ~= "function" or type(GetAddOnMemoryUsage) ~= "function" then
        return miniMemoryRows
    end
    local countGetter = C_AddOns and C_AddOns.GetNumAddOns or GetNumAddOns
    local infoGetter = C_AddOns and C_AddOns.GetAddOnInfo or GetAddOnInfo
    if type(countGetter) ~= "function" or type(infoGetter) ~= "function" then return miniMemoryRows end
    local okUpdate = pcall(UpdateAddOnMemoryUsage)
    local okCount, addonCount = pcall(countGetter)
    addonCount = okCount and ReadableNumber(addonCount) or nil
    if not okUpdate or not addonCount then return miniMemoryRows end

    miniMemoryScanTime = now
    local used = 0
    for index = 1, addonCount do
        local okMemory, memory = pcall(GetAddOnMemoryUsage, index)
        memory = okMemory and ReadableNumber(memory) or nil
        if memory and memory > 0 then
            local okInfo, name, title = pcall(infoGetter, index)
            used = used + 1
            local row = miniMemoryRows[used] or {}
            row.name = okInfo and (title or name) or (Text("Аддон ", "Add-on ") .. index)
            row.memory = memory
            miniMemoryRows[used] = row
        end
    end
    for index = #miniMemoryRows, used + 1, -1 do miniMemoryRows[index] = nil end
    table.sort(miniMemoryRows, function(left, right) return left.memory > right.memory end)
    return miniMemoryRows
end

local function HoverColor()
    local appearance = MiniAppearance()
    if appearance.hoverColorMode == "CLASS" then return SGB:GetClassColor() end
    local color = appearance.hoverColor or { .35, .75, 1, 1 }
    return color[1], color[2], color[3], color[4] or 1
end

local function PaintRestingGlyphs(button, elapsed)
    local size = button.restingSize
    local fade = 1 - math.max(0, math.min(1, (elapsed - REST_FADE_AT) / REST_FADE))
    fade = fade * fade * (3 - 2 * fade)
    for index, glyph in ipairs(button.restingGlyphs) do
        local progress = math.max(0, math.min(1, (elapsed - (index - 1) * REST_STAGGER) / REST_RISE))
        local layout = REST_GLYPHS[index]
        local rise = progress * progress * (3 - 2 * progress)
        if glyph.restProgress ~= progress or glyph.restSize ~= size then
            local side = size * layout.height * (.84 + .16 * rise)
            glyph:SetSize(side, side)
            glyph:SetPoint("CENTER", button, "CENTER",
                size * (layout.x - .07 * (1 - rise)), size * (layout.y - REST_LIFT * (1 - rise)))
            glyph.restProgress, glyph.restSize = progress, size
        end
        local alpha = rise * fade * layout.alpha
        if glyph.restAlpha ~= alpha then
            glyph:SetAlpha(alpha)
            glyph.restAlpha = alpha
        end
    end
end

local function UpdateRestingMotion(button, elapsed)
    button.restingElapsed = (button.restingElapsed + elapsed) % REST_CYCLE
    PaintRestingGlyphs(button, button.restingElapsed)
end

local function SetRestingMotion(button, active, restart)
    if not button then return end
    if not active then
        button.restingElapsed = nil
        button:SetScript("OnUpdate", nil)
    elseif restart or button.restingElapsed == nil then
        button.restingElapsed = 0
        PaintRestingGlyphs(button, 0)
        button:SetScript("OnUpdate", UpdateRestingMotion)
    end
end

local function SetRestingSize(button, size)
    if button.restingSize == size then return end
    button.restingSize = size
    button:SetSize(size, size)
    PaintRestingGlyphs(button, button.restingElapsed or 0)
end

local function ColorRestingGlyphs(button, ...)
    for _, glyph in ipairs(button.restingGlyphs) do glyph:SetVertexColor(...) end
end

function SGB:MiniBarFadeTo(alpha)
    local visual = self.miniBarVisual or self.miniBarRoot
    if not visual then return end
    if not self.miniFadeControllerFrame then self.miniFadeControllerFrame = CreateFrame("Frame") end
    local controller = self.miniFadeControllerFrame
    self.miniFadeTarget = alpha
    local resting = self.miniResting
    if alpha > 0 and resting and resting:IsVisible() then SetRestingMotion(resting, true) end
    if math.abs(visual:GetAlpha() - alpha) < .001 then
        visual:SetAlpha(alpha)
        controller:SetScript("OnUpdate", nil)
        if alpha == 0 then SetRestingMotion(resting, false) end
        return
    end
    controller:SetScript("OnUpdate", function(frame, elapsed)
        local fadeFrame = SGB.miniBarVisual or SGB.miniBarRoot
        if not fadeFrame then frame:SetScript("OnUpdate", nil); return end
        local mini = MiniProfile() or {}
        local current, target = fadeFrame:GetAlpha(), SGB.miniFadeTarget or alpha
        local duration = math.max(.01, tonumber(mini.fadeDuration) or .11)
        local step = elapsed / duration
        if current < target then current = math.min(target, current + step)
        else current = math.max(target, current - step) end
        fadeFrame:SetAlpha(current)
        if current == target then
            frame:SetScript("OnUpdate", nil)
            if target == 0 then SetRestingMotion(SGB.miniResting, false) end
        end
    end)
end

function SGB:IsMiniBarHovered()
    return self.miniBarRoot and self.miniBarRoot.IsMouseOver and self.miniBarRoot:IsMouseOver()
end

function SGB:OnMiniBarEnter()
    local mini = MiniProfile()
    if not mini or (not mini.enabled and not self.miniSettingsOpen) then return end
    self.miniHoverGeneration = (self.miniHoverGeneration or 0) + 1
    self:MiniBarFadeTo(tonumber(mini.hoverAlpha) or 1)
end

function SGB:OnMiniBarLeave()
    local mini = MiniProfile()
    if not mini then return end
    self.miniHoverGeneration = (self.miniHoverGeneration or 0) + 1
    local generation = self.miniHoverGeneration
    SUI:After(tonumber(mini.fadeDelay) or .04, self, "mini fade delay", function()
        if generation ~= SGB.miniHoverGeneration then return end
        if not SGB:IsMiniBarHovered() then SGB:RefreshMiniBarFade() end
    end)
end

function SGB:RefreshMiniBarFade()
    local mini = MiniProfile()
    if not self.miniBarRoot or not mini then return end
    if self.miniSettingsOpen then
        self:MiniBarFadeTo(tonumber(mini.hoverAlpha) or 1)
    elseif not mini.enabled then
        self:MiniBarFadeTo(0)
    elseif self:InCombat() and mini.combatVisibility == "SHOW" then
        self:MiniBarFadeTo(tonumber(mini.hoverAlpha) or 1)
    elseif not mini.mouseover then
        self:MiniBarFadeTo(tonumber(mini.hoverAlpha) or 1)
    elseif self:IsMiniBarHovered() then
        self:MiniBarFadeTo(tonumber(mini.hoverAlpha) or 1)
    else
        self:MiniBarFadeTo(0)
    end
end

function SGB:StartMiniBarMoving()
    local mini = MiniProfile()
    if not mini or mini.locked ~= false or self:InCombat() or not self.miniBarRoot then return end
    self.miniBarRoot:StartMoving()
end

function SGB:StopMiniBarMoving()
    local root, mini = self.miniBarRoot, MiniProfile()
    if not root or not mini then return end
    root:StopMovingOrSizing()
    local anchor = _G.Minimap or _G.MinimapCluster
    local right, top = root:GetRight(), root:GetTop()
    local anchorRight = anchor and anchor:GetRight()
    local anchorBottom = anchor and anchor:GetBottom()
    if type(right) == "number" and type(top) == "number"
        and type(anchorRight) == "number" and type(anchorBottom) == "number" then
        mini.x = math.max(-300, math.min(300, math.floor(right - anchorRight + .5)))
        mini.y = math.max(-200, math.min(100, math.floor(top - anchorBottom + .5)))
    end
    self:ApplyMiniBarPosition()
    self:RefreshSettings()
end

function SGB:ApplyMiniBarVisibility()
    local root, mini = self.miniBarRoot, MiniProfile()
    if not root or not mini then return end
    if self:InCombat() then
        self.pendingSecureUpdate = true
        return
    end
    if UnregisterStateDriver then UnregisterStateDriver(root, "visibility") end
    local rule = "show"
    if not mini.enabled or self.miniHasVisibleWidgets == false then
        rule = "hide"
    elseif self.miniSettingsOpen then
        rule = "show"
    elseif mini.hideInPetBattle and mini.combatVisibility == "HIDE" then
        rule = "[petbattle] hide; [combat] hide; show"
    elseif mini.hideInPetBattle then
        rule = "[petbattle] hide; show"
    elseif mini.combatVisibility == "HIDE" then
        rule = "[combat] hide; show"
    end
    if RegisterStateDriver then
        RegisterStateDriver(root, "visibility", rule)
    else
        root:SetShown(rule ~= "hide")
    end
end

function SGB:ShowMiniInfoTooltip(owner, kind)
    if not GameTooltip then return end
    GameTooltip:ClearLines()
    GameTooltip:SetOwner(owner, "ANCHOR_BOTTOM")
    if kind == "clock" then
        GameTooltip:AddLine(Text("Время", "Time"), 1, 1, 1)
        GameTooltip:AddLine(Text("ЛКМ — календарь", "Left-click: calendar"), .72, .72, .72)
        GameTooltip:AddLine(Text("ПКМ — часы и будильник", "Right-click: clock and alarm"), .72, .72, .72)
        GameTooltip:AddLine(Text("СКМ — перезагрузка интерфейса", "Middle-click: reload UI"), .72, .72, .72)
    elseif kind == "resting" then
        GameTooltip:AddLine(Text("Зона отдыха", "Rest area"), 1, 1, 1)
    elseif kind == "fps" then
        GameTooltip:AddLine(Text("Частота кадров", "Frame rate"), 1, 1, 1)
        GameTooltip:AddLine((CurrentFPS() or "—") .. Text(" кадров/с", " FPS"), .72, .72, .72)
        local rows = RefreshMiniAddonMemory()
        if #rows > 0 then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(Text("Память аддонов", "Add-on memory"), 1, 1, 1)
            for index = 1, math.min(MINI_MEMORY_LIMIT, #rows) do
                local row = rows[index]
                GameTooltip:AddDoubleLine(row.name, FormatAddonMemory(row.memory), .82, .82, .82, 1, .82, 0)
            end
        end
    elseif kind == "latency" then
        local home, world = CurrentLatencies()
        GameTooltip:AddLine(Text("Задержка", "Latency"), 1, 1, 1)
        GameTooltip:AddDoubleLine(Text("Локальная", "Home"), (home or "—") .. Text(" мс", " ms"), .72, .72, .72, 1, 1, 1)
        GameTooltip:AddDoubleLine(Text("Глобальная", "World"), (world or "—") .. Text(" мс", " ms"), .72, .72, .72, 1, 1, 1)
    end
    GameTooltip:Show()
end

function SGB:CreateMiniTextWidget(parent, kind, width)
    local button = CreateFrame("Button", nil, parent)
    button.kind = kind
    button:SetSize(width, 22)
    button:RegisterForClicks("AnyUp")
    button.text = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    button.text:SetPoint("CENTER")
    button.text:SetShadowColor(0, 0, 0, 1)
    button.text:SetShadowOffset(1, -1)
    button:SetScript("OnEnter", function(self)
        SGB:OnMiniBarEnter()
        local r, g, b, a = HoverColor()
        self.text:SetTextColor(r, g, b, a)
        SGB:ShowMiniInfoTooltip(self, self.kind)
    end)
    button:SetScript("OnLeave", function(self)
        self.text:SetTextColor(MiniTextColor())
        SGB:HideTooltip()
        SGB:OnMiniBarLeave()
    end)
    return button
end

function SGB:CreateMiniRestingWidget(parent)
    local button = CreateFrame("Button", nil, parent)
    button.kind = "resting"
    button:SetFrameLevel(parent:GetFrameLevel() + 8)
    button:Hide()
    button.restingGlyphs = {}
    for index, layout in ipairs(REST_GLYPHS) do
        local glyph = button:CreateTexture(nil, "OVERLAY", nil, index)
        glyph:SetTexture(REST_ART)
        glyph:SetTexCoord(layout.cell * .5, (layout.cell + 1) * .5, 0, 1)
        button.restingGlyphs[index] = glyph
    end
    SetRestingSize(button, 24)
    button:SetScript("OnShow", function(self)
        SetRestingMotion(self, parent:GetAlpha() > 0 or (SGB.miniFadeTarget or 0) > 0)
    end)
    button:SetScript("OnHide", function(self) SetRestingMotion(self, false) end)
    button:SetScript("OnEnter", function(self)
        SGB:OnMiniBarEnter()
        ColorRestingGlyphs(self, HoverColor())
        SGB:ShowMiniInfoTooltip(self, "resting")
    end)
    button:SetScript("OnLeave", function(self)
        ColorRestingGlyphs(self, MiniIconColor(true))
        SGB:HideTooltip()
        SGB:OnMiniBarLeave()
    end)
    return button
end

function SGB:PreviewMiniResting(button)
    button = button or self.miniResting
    if not (button and button:IsVisible()) then return end
    SetRestingMotion(button, true, true)
end

function SGB:ColorMiniSocialButton(button, hovered)
    if not button or not button.icon then return end
    local base = { MiniIconColor(false) }
    local hover = { HoverColor() }
    if SUI.HoverEffects then
        SUI.HoverEffects:ConfigureIcon(button, button.icon, button.icon:GetWidth(), button.icon:GetHeight(), base, hover)
        if hovered then SUI.HoverEffects:SetIconHovered(button, true) else SUI.HoverEffects:Reset(button) end
    elseif hovered then
        button.icon:SetVertexColor(unpack(hover))
    else
        button.icon:SetVertexColor(unpack(base))
    end
end

function SGB:SetMiniSocialButtonHovered(button, hovered)
    if SUI.HoverEffects then
        SUI.HoverEffects:SetIconHovered(button, hovered == true)
    else
        self:ColorMiniSocialButton(button, hovered == true)
    end
end

function SGB:CreateMiniSocialButton(parent, entryID)
    local entry = self:GetButtonEntry(entryID)
    local button = CreateFrame("Button", nil, parent)
    button.entryID, button.entry = entryID, entry
    button:SetSize(30, 22)
    button:RegisterForClicks("AnyUp")
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetPoint("CENTER")
    button.icon:SetSize(15, 15)
    button.icon:SetTexture(entry and entry.icon or MINI_ICON_PATH .. (entryID == "FRIENDS" and "Friends.tga" or "Guild.tga"))
    button.badge = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    button.badge:SetPoint("TOP", button.icon, "TOP", 0, 4)
    button.badge:SetJustifyH("CENTER")
    button.badge:SetShadowColor(0, 0, 0, 1)
    button.badge:SetShadowOffset(1, -1)
    button:SetScript("OnEnter", function(self)
        SGB:OnMiniBarEnter()
        SGB:ShowTooltip(self)
        SGB:SetMiniSocialButtonHovered(self, true)
    end)
    button:SetScript("OnLeave", function(self)
        SGB:HideTooltip()
        SGB:SetMiniSocialButtonHovered(self, false)
        SGB:OnMiniBarLeave()
    end)
    button:SetScript("OnClick", function(self, mouse)
        if self.entry and self.entry.click then self.entry.click(self, mouse) end
    end)
    return button
end

function SGB:CreateMiniBar()
    if self.miniBarRoot then return end
    local root = CreateFrame("Frame", "Sintezza_GameBarMiniRoot", UIParent)
    root:SetFrameStrata("MEDIUM")
    root:SetClampedToScreen(true)
    root:SetMovable(true)
    root:EnableMouse(true)
    root:RegisterForDrag("LeftButton")
    root:SetScript("OnDragStart", function() SGB:StartMiniBarMoving() end)
    root:SetScript("OnDragStop", function() SGB:StopMiniBarMoving() end)
    root:SetScript("OnEnter", function() SGB:OnMiniBarEnter() end)
    root:SetScript("OnLeave", function() SGB:OnMiniBarLeave() end)
    self.miniBarRoot = root

    local visual = self:CreateSegment(root)
    visual:SetAllPoints()
    visual:SetFrameLevel(root:GetFrameLevel() + 1)
    self.miniBarVisual = visual

    self.miniClock = self:CreateMiniTextWidget(visual, "clock", 48)
    self.miniClock:SetScript("OnClick", function(_, mouse) SGB:ClockClick(mouse) end)
    self.miniResting = self:CreateMiniRestingWidget(visual)
    self.miniFriends = self:CreateMiniSocialButton(visual, "FRIENDS")
    self.miniGuild = self:CreateMiniSocialButton(visual, "GUILD")
    self.miniFPS = self:CreateMiniTextWidget(visual, "fps", 43)
    self.miniLatency = self:CreateMiniTextWidget(visual, "latency", 48)

    for _, widget in ipairs({
        self.miniClock, self.miniResting, self.miniFriends,
        self.miniGuild, self.miniFPS, self.miniLatency,
    }) do
        widget:RegisterForDrag("LeftButton")
        widget:SetScript("OnDragStart", function() SGB:StartMiniBarMoving() end)
        widget:SetScript("OnDragStop", function() SGB:StopMiniBarMoving() end)
    end
end

function SGB:ApplyMiniBarPosition()
    local root, mini = self.miniBarRoot, MiniProfile()
    if not root or not mini then return end
    root:ClearAllPoints()
    local anchor = _G.Minimap or _G.MinimapCluster
    if anchor then
        root:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", tonumber(mini.x) or 0, tonumber(mini.y) or -4)
    else
        root:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", (tonumber(mini.x) or 0) - 20, (tonumber(mini.y) or -4) - 180)
    end
    root:SetScale(tonumber(mini.scale) or .9)
end

function SGB:ApplyMiniBarStyle(bar)
    bar = bar or self
    local root = bar.miniBarVisual or bar.miniBarRoot
    if not root then return end
    local appearance = MiniAppearance()
    self:ApplySegmentStyle(root, appearance)
    local font = self:GetFont(appearance.font)
    local outline = self:GetFontFlags(appearance.outline, "OUTLINE")
    local badgeFont = self:GetFont(appearance.badgeFont or appearance.font)
    local badgeOutline = self:GetFontFlags(appearance.badgeOutline, outline)
    local badgeColor = appearance.badgeColor or { 1, .82, 0, 1 }
    bar.miniClock.text:SetFont(font, tonumber(appearance.clockFontSize) or 14, outline)
    bar.miniFPS.text:SetFont(font, tonumber(appearance.dataFontSize) or 10, outline)
    bar.miniLatency.text:SetFont(font, tonumber(appearance.dataFontSize) or 10, outline)
    bar.miniFriends.badge:SetFont(badgeFont, tonumber(appearance.badgeFontSize) or 10, badgeOutline)
    bar.miniGuild.badge:SetFont(badgeFont, tonumber(appearance.badgeFontSize) or 10, badgeOutline)
    for _, button in ipairs({ bar.miniFriends, bar.miniGuild }) do
        button.badge:SetTextColor(badgeColor[1] or 1, badgeColor[2] or .82, badgeColor[3] or 0, badgeColor[4] or 1)
    end
    for _, widget in ipairs({ bar.miniClock, bar.miniFPS, bar.miniLatency }) do
        widget.text:SetTextColor(MiniTextColor())
    end
    ColorRestingGlyphs(bar.miniResting, MiniIconColor(true))
    self:ColorMiniSocialButton(bar.miniFriends, false)
    self:ColorMiniSocialButton(bar.miniGuild, false)
end

function SGB:ApplyMiniBarLayout(bar)
    bar = bar or self
    local root, mini = bar.miniBarRoot, MiniProfile()
    if not root or not mini then return end
    local appearance = MiniAppearance()
    local panelHeight = math.max(22, tonumber(mini.height) or 30)
    local socialIconSize = math.max(12, tonumber(mini.socialIconSize) or 18)
    local restingSize = math.max(16, tonumber(mini.restingSize) or 24)
    local clockWidth = math.max(36, tonumber(mini.clockWidth) or 48)
    local socialWidth = math.max(20, tonumber(mini.socialWidth) or 32)
    local fpsWidth = math.max(32, tonumber(mini.fpsWidth) or 43)
    local latencyWidth = math.max(32, tonumber(mini.latencyWidth) or 48)
    local contentYOffset = tonumber(mini.contentYOffset) or 0

    bar.miniClock:SetSize(clockWidth, panelHeight)
    bar.miniFriends:SetSize(socialWidth, panelHeight)
    bar.miniGuild:SetSize(socialWidth, panelHeight)
    bar.miniFPS:SetSize(fpsWidth, panelHeight)
    bar.miniLatency:SetSize(latencyWidth, panelHeight)
    bar.miniFriends.icon:SetSize(socialIconSize, socialIconSize)
    bar.miniGuild.icon:SetSize(socialIconSize, socialIconSize)
    SetRestingSize(bar.miniResting, restingSize)
    for _, button in ipairs({ bar.miniFriends, bar.miniGuild }) do
        button.badge:ClearAllPoints()
        button.badge:SetPoint(
            "TOP", button.icon, "TOP",
            tonumber(appearance.badgeX) or 0, tonumber(appearance.badgeY) or 4
        )
        button.badge:SetWidth(math.max(socialWidth, socialIconSize * 1.5))
    end
    self:ColorMiniSocialButton(bar.miniFriends, false)
    self:ColorMiniSocialButton(bar.miniGuild, false)
    for _, widget in ipairs({
        bar.miniClock, bar.miniFriends, bar.miniGuild, bar.miniFPS, bar.miniLatency,
    }) do
        widget:Hide()
    end
    local widgets = {}
    if mini.showClock ~= false then widgets[#widgets + 1] = bar.miniClock end
    if mini.showFriends ~= false then widgets[#widgets + 1] = bar.miniFriends end
    if mini.showGuild ~= false then widgets[#widgets + 1] = bar.miniGuild end
    if mini.showFPS ~= false then widgets[#widgets + 1] = bar.miniFPS end
    if mini.showLatency ~= false then widgets[#widgets + 1] = bar.miniLatency end
    local visible, contentWidth = {}, 0
    local resting = type(IsResting) == "function" and IsResting() == true
    for _, widget in ipairs(widgets) do
        if widget then
            visible[#visible + 1] = widget
            contentWidth = contentWidth + widget:GetWidth()
            widget:Show()
        end
    end
    local spacing = math.max(0, tonumber(mini.spacing) or 4)
    local padding = math.max(0, tonumber(mini.padding) or 4)
    local gaps = math.max(0, #visible - 1)
    local naturalWidth = contentWidth + gaps * spacing + padding * 2
    local width = naturalWidth
    if mini.autoWidth == false then
        width = math.max(contentWidth + padding * 2, tonumber(mini.width) or 230)
        if gaps > 0 then spacing = math.max(0, (width - contentWidth - padding * 2) / gaps) end
    end
    root:SetSize(math.max(48, width), panelHeight)
    local previous
    for _, widget in ipairs(visible) do
        widget:ClearAllPoints()
        if previous then
            widget:SetPoint("LEFT", previous, "RIGHT", spacing, contentYOffset)
        else
            widget:SetPoint("LEFT", root, "LEFT", padding, contentYOffset)
        end
        previous = widget
    end
    local restingAnchor = visible[1] or root
    local restingY = (tonumber(mini.restingY) or -4) - 4
    if restingAnchor == bar.miniClock then
        local first = REST_GLYPHS[1]
        local lowestGlyph = restingSize * (.5 + first.y - REST_LIFT - first.height * .42)
        local textHeight = math.max(tonumber(appearance.clockFontSize) or 14, bar.miniClock.text:GetStringHeight())
        restingY = math.max(restingY, (textHeight - panelHeight) * .5 + 2 - lowestGlyph)
    end
    local overlap = restingAnchor == bar.miniClock and math.max(0, -restingY) or 0
    bar.miniResting:SetHitRectInsets(0, 0, 0, overlap)
    bar.miniResting:ClearAllPoints()
    bar.miniResting:SetPoint("BOTTOMRIGHT", restingAnchor, "TOPRIGHT", tonumber(mini.restingX) or 2, restingY)
    bar.miniResting:SetShown(mini.showResting ~= false and (resting or bar.miniSettingsOpen == true))
    bar.miniHasVisibleWidgets = #visible > 0 or mini.showResting ~= false
    bar.miniRestingState = resting
end

function SGB:UpdateMiniOnline(kind, bar)
    bar = bar or self
    if not bar.miniBarRoot then return end
    local mini = MiniProfile()
    local function CountText(value)
        local count = tonumber(value) or 0
        if mini and mini.hideZeroCounts ~= false and count <= 0 then return "" end
        return tostring(count)
    end
    if mini.enabled and mini.showFriends ~= false and (not kind or kind == "friends") then
        bar.miniFriends.badge:SetText(CountText(self:GetFriendCount()))
    end
    if mini.enabled and mini.showGuild ~= false and (not kind or kind == "guild") then
        bar.miniGuild.badge:SetText(CountText(self:GetGuildCount()))
    end
end

function SGB:UpdateMiniBarData(bar)
    bar = bar or self
    local root, mini = bar.miniBarRoot, MiniProfile()
    if not root or not mini or not mini.enabled then return end
    if mini.showFPS ~= false then
        local fps = CurrentFPS()
        bar.miniFPS.text:SetText(fps and (fps .. Text(" к/с", " FPS")) or Text("— к/с", "— FPS"))
    end
    if mini.showLatency ~= false then
        local latency = CurrentLatency()
        bar.miniLatency.text:SetText(latency and (latency .. Text(" мс", " ms")) or Text("— мс", "— ms"))
    end
    local resting = type(IsResting) == "function" and IsResting() == true
    if bar == self and mini.showResting ~= false and resting ~= bar.miniRestingState then self:ApplyMiniBarLayout() end
end

function SGB:RestartMiniBarTicker()
    local mini = MiniProfile()
    local running = mini and mini.enabled == true and (mini.showFPS ~= false or mini.showLatency ~= false)
    if not running then
        if self.miniBarTicker and self.miniBarTicker.Cancel then self.miniBarTicker:Cancel() end
        self.miniBarTicker = nil
        return
    end
    if self.miniBarTicker or not C_Timer or not C_Timer.NewTicker then return end
    self.miniBarTicker = C_Timer.NewTicker(1, function()
        SUI:SafeModuleCall(SGB, "minimap info", SGB.UpdateMiniBarData)
    end)
end

function SGB:CreateMiniSettingsPreview(parent)
    local sample = CreateFrame("Frame", nil, parent)
    sample:SetHeight(128)
    local background = sample:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    Sintezza_Theme:Tint(background, "SetColorTexture", SUI.SettingsTheme.input, .62)
    local root = self:CreateSegment(sample)
    root:SetPoint("CENTER", sample, "CENTER", 0, -10)
    local bar = { miniBarRoot = root, miniBarVisual = root, miniSettingsOpen = true }
    bar.miniClock = self:CreateMiniTextWidget(root, "clock", 48)
    bar.miniFriends = self:CreateMiniSocialButton(root, "FRIENDS")
    bar.miniGuild = self:CreateMiniSocialButton(root, "GUILD")
    bar.miniFPS = self:CreateMiniTextWidget(root, "fps", 43)
    bar.miniLatency = self:CreateMiniTextWidget(root, "latency", 48)
    bar.miniResting = self:CreateMiniRestingWidget(root)
    sample.resting = bar.miniResting
    for _, widget in ipairs({ bar.miniClock, bar.miniFriends, bar.miniGuild, bar.miniFPS, bar.miniLatency, bar.miniResting }) do
        widget:EnableMouse(false)
    end
    local status = SUI.Widgets:Label(sample, "", 11, SUI.SettingsTheme.muted)
    status:SetPoint("BOTTOM", sample, "BOTTOM", 0, 6)

    local function UpdateData()
        local mini = MiniProfile()
        if not mini then return end
        bar.miniClock.text:SetText(SGB:FormatClock(mini.twentyFourHour ~= false, mini.showSeconds == true))
        SGB:UpdateMiniOnline(nil, bar)
        SGB:UpdateMiniBarData(bar)
    end
    function sample:Refresh()
        if not self:IsVisible() then return end
        local mini = MiniProfile()
        if not mini then return end
        SGB:ApplyMiniBarStyle(bar)
        SGB:ApplyMiniBarLayout(bar)
        root:SetAlpha(mini.enabled and (mini.hoverAlpha or 1) or .38)
        local width = self:GetWidth()
        local fit = width > 20 and math.max(1, width - 22) / math.max(1, root:GetWidth()) or 1
        root:SetScale(math.min(mini.scale or .9, fit, 72 / math.max(1, root:GetHeight())))
        status:SetText(not mini.enabled and Text("Панель выключена", "Bar disabled") or "")
        UpdateData()
    end
    sample:SetScript("OnSizeChanged", sample.Refresh)
    sample:SetScript("OnShow", function(frame)
        frame:Refresh()
        if C_Timer and C_Timer.NewTicker then frame.ticker = C_Timer.NewTicker(1, UpdateData) end
    end)
    sample:SetScript("OnHide", function(frame)
        if frame.ticker then frame.ticker:Cancel(); frame.ticker = nil end
    end)
    return sample
end

function SGB:ApplyMiniBar()
    if not self.miniBarRoot then self:CreateMiniBar() end
    local mini = MiniProfile()
    if not mini then return end
    local active = mini.enabled == true
    if active then
        self:ApplyMiniBarStyle()
        self:ApplyMiniBarLayout()
        self:ApplyMiniBarPosition()
        self:UpdateMiniBarData()
        self:UpdateMiniOnline()
        self:UpdateClock()
    end
    self:ApplyMiniBarVisibility()
    self:RefreshMiniBarFade()
    self:RestartMiniBarTicker()
end
