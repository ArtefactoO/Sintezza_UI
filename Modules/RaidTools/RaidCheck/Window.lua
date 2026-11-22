local ADDON, SUI = ...
local Text = SUI.Text
local SRT = SUI.RaidTools
local AUDIT_TITLE = Text("Проверка рейда", "Raid check")

local BACKDROP = {
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
}

local STATUS = {
    ready = { Text("ДА", "READY"), .22, .9, .48 },
    notready = { Text("НЕТ", "NO"), 1, .25, .25 },
    PENDING = { "...", .85, .7, .2 },
    offline = { Text("ОФЛАЙН", "OFF"), .55, .55, .55 },
    UNKNOWN = { "?", .55, .55, .55 },
    PRESENT = { Text("ЕСТЬ", "OK"), .22, .9, .48 },
    MISSING = { "X", 1, .25, .25 },
}

local ROLE_LABELS = {
    TANK = Text("Т", "T"),
    HEALER = Text("Л", "H"),
    DAMAGER = Text("ДД", "D"),
}

local COLUMN_LAYOUT = {
    name = { x = 10, width = 176, label = Text("Игрок / роль", "Player / role"), justify = "LEFT" },
    ready = { x = 188, width = 52, label = Text("Готов", "Ready") },
    food = { x = 242, width = 42, label = Text("Еда", "Food") },
    flask = { x = 284, width = 50, label = Text("Фласка", "Flask") },
    rune = { x = 334, width = 44, label = Text("Руна", "Rune") },
    buffs = { x = 378, width = 44, label = Text("Баф", "Buff") },
}

local function setColumnAnchor(fontString, layout, y)
    fontString:ClearAllPoints()
    fontString:SetPoint("TOPLEFT", fontString:GetParent(), "TOPLEFT", layout.x, y)
    fontString:SetWidth(layout.width)
    fontString:SetJustifyH(layout.justify or "CENTER")
end

local function makeText(audit, parent, size)
    local fontString = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fontString:SetFont(SRT:GetFont() or STANDARD_TEXT_FONT, size or 11, "OUTLINE")
    audit.fontStrings[#audit.fontStrings + 1] = { fontString = fontString, size = size or 11 }
    return fontString
end

local function put(fontString, value)
    local state = STATUS[value] or STATUS.UNKNOWN
    fontString:SetAlpha(1)
    fontString:SetText(state[1])
    fontString:SetTextColor(state[2], state[3], state[4])
end

local function makeButton(audit, width, height, label, onClick)
    local button = CreateFrame("Button", nil, audit, "BackdropTemplate")
    button:SetSize(width, height)
    button:SetBackdrop(BACKDROP)
    button:RegisterForClicks("AnyUp")
    button.text = makeText(audit, button, 11)
    button.text:SetPoint("CENTER", 0, 0)
    button.text:SetText(label)
    button:SetScript("OnClick", onClick)
    button:SetScript("OnEnter", function(self) SRT:StyleAuditButton(self, true) end)
    button:SetScript("OnLeave", function(self) SRT:StyleAuditButton(self, false) end)
    return button
end

function SRT:StyleAuditButton(button, hovered)
    if not button then return end
    local appearance = self.profile.appearance
    if hovered then
        local r, g, b = unpack(appearance.accent)
        button:SetBackdropColor(r * .18, g * .18, b * .18, .98)
        button:SetBackdropBorderColor(r, g, b, 1)
        button.text:SetTextColor(1, 1, 1, 1)
    else
        button:SetBackdropColor(unpack(appearance.buttonBackdrop))
        button:SetBackdropBorderColor(unpack(appearance.buttonBorder))
        button.text:SetTextColor(.95, .95, .95, 1)
    end
    if button.paintGlyph then
        button.paintGlyph(hovered and { 1, 1, 1, 1 } or { .95, .95, .95, 1 })
    end
end

function SRT:ApplyAuditStyle()
    local audit = self.audit
    if not audit then return end
    local appearance = self.profile.appearance
    local borderSize = tonumber(appearance.borderSize) or 1
    local wantsGlow = appearance.borderStyle == "GLOW"
    local canGlow = wantsGlow and SUI:IntegrationEnabled("panelglow") and EllesmereUI and EllesmereUI.ApplyBorderStyle

    audit:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = math.max(1, borderSize),
    })
    audit:SetBackdropColor(
        appearance.backdrop[1], appearance.backdrop[2], appearance.backdrop[3],
        appearance.backdropEnabled and appearance.backdrop[4] or 0
    )
    audit:SetBackdropBorderColor(
        appearance.border[1], appearance.border[2], appearance.border[3],
        borderSize > 0 and not canGlow and appearance.border[4] or 0
    )
    if canGlow and borderSize > 0 then
        audit.glowBorder:Show()
        EllesmereUI.ApplyBorderStyle(audit.glowBorder, borderSize,
            appearance.border[1], appearance.border[2],
            appearance.border[3], appearance.border[4], "glow")
    else
        if EllesmereUI and EllesmereUI.ApplyBorderStyle then
            EllesmereUI.ApplyBorderStyle(audit.glowBorder, 0, 0, 0, 0, 0, "glow")
        end
        audit.glowBorder:Hide()
    end

    local outline = appearance.outline == "NONE" and "" or appearance.outline
    for _, entry in ipairs(audit.fontStrings) do
        entry.fontString:SetFont(self:GetFont(), entry.size, outline)
    end
    self:StyleAuditButton(audit.refresh, false)
    self:StyleAuditButton(audit.close, false)
end

function SRT:CreateAuditWindow()
    local audit = CreateFrame("Frame", "Sintezza_RaidToolsAudit", UIParent, "BackdropTemplate")
    self.audit = audit
    audit:SetSize(430, 68)
    audit:SetClampedToScreen(true)
    audit:SetMovable(true)
    audit:EnableMouse(true)
    audit:RegisterForDrag("LeftButton")
    audit:SetFrameStrata("MEDIUM")
    audit.fontStrings = {}

    audit.glowBorder = CreateFrame("Frame", nil, audit, "BackdropTemplate")
    audit.glowBorder:SetAllPoints()
    audit.glowBorder:SetFrameLevel(audit:GetFrameLevel() + 1)
    audit.glowBorder:EnableMouse(false)

    audit:SetScript("OnDragStart", function(frame)
        if not self.profile.raidCheck.locked and not self:InCombat() then frame:StartMoving() end
    end)
    audit:SetScript("OnDragStop", function(frame)
        frame:StopMovingOrSizing()
        local point, _, relativePoint, x, y = frame:GetPoint()
        local cfg = self.profile.raidCheck
        cfg.point, cfg.relativePoint, cfg.x, cfg.y = point, relativePoint, x, y
    end)
    audit:SetScript("OnEnter", function() self.auditHover = true end)
    audit:SetScript("OnLeave", function() self.auditHover = false end)

    local icon = audit:CreateTexture(nil, "ARTWORK")
    icon:SetSize(16, 16)
    icon:SetPoint("TOPLEFT", 9, -5)
    icon:SetTexture(SUI.icon)
    audit.title = makeText(audit, audit, 12)
    audit.title:SetPoint("LEFT", icon, "RIGHT", 6, 0)
    audit.title:SetText(AUDIT_TITLE)

    audit.close = makeButton(audit, 20, 20, "", function() self:HideAudit() end)
    audit.close.paintGlyph = Sintezza_Theme.Settings:CloseGlyph(audit.close)
    audit.close:SetPoint("TOPRIGHT", -5, -5)
    audit.fontStrings[#audit.fontStrings].size = 16

    audit.refresh = makeButton(audit, 76, 18, Text("Обновить", "Refresh"), function() self:RefreshAudit(true) end)
    audit.refresh:SetPoint("RIGHT", audit.close, "LEFT", -5, 0)

    audit.headers = {}
    for key, layout in pairs(COLUMN_LAYOUT) do
        local header = makeText(audit, audit, 9)
        header:SetText(layout.label)
        setColumnAnchor(header, layout, -27)
        audit.headers[key] = header
    end
    audit.header = audit.headers.name

    audit.rows = {}
    for index = 1, 40 do
        local row = CreateFrame("Frame", nil, audit)
        row:SetSize(430, 16)
        row:SetPoint("TOPLEFT", audit, "TOPLEFT", 0, -38 - (index - 1) * 16)
        for key, layout in pairs(COLUMN_LAYOUT) do
            local field = makeText(audit, row, 10)
            field:SetPoint("LEFT", row, "LEFT", layout.x, 0)
            field:SetWidth(layout.width)
            field:SetJustifyH(layout.justify or "CENTER")
            row[key] = field
        end
        row:Hide()
        audit.rows[index] = row
    end

    self:ApplyAuditStyle()
end

function SRT:RefreshAudit(forceAuraScan)
    if not self.audit then return end
    local rows = self:SortRoster(self:GetRoster())
    if not self.testMode then self:ScanAuras(rows, forceAuraScan == true) end
    self.audit.title:SetText(AUDIT_TITLE .. " — " .. #rows)

    local columns = self.profile.raidCheck.columns
    self.audit.headers.food:SetShown(columns.food)
    self.audit.headers.flask:SetShown(columns.flask)
    self.audit.headers.rune:SetShown(columns.rune)
    self.audit.headers.buffs:SetShown(columns.buffs)

    for index, uiRow in ipairs(self.audit.rows) do
        local row = rows[index]
        if row then
            uiRow:Show()
            local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[row.class] or { r = 1, g = 1, b = 1 }
            local role = ROLE_LABELS[row.role]
            uiRow.name:SetText(role and (row.name .. "  " .. role) or row.name)
            uiRow.name:SetTextColor(color.r, color.g, color.b)
            uiRow.food:SetShown(columns.food)
            uiRow.flask:SetShown(columns.flask)
            uiRow.rune:SetShown(columns.rune)
            uiRow.buffs:SetShown(columns.buffs)
            put(uiRow.ready, row.online == false and "offline" or row.ready)
            put(uiRow.food, row.aura.food)
            put(uiRow.flask, row.aura.flask)
            put(uiRow.rune, row.aura.rune)
            put(uiRow.buffs, row.aura.buffs)
        else
            uiRow:Hide()
        end
    end
    self.audit:SetHeight(math.max(68, 43 + #rows * 16))
end

function SRT:ShowAudit(manual)
    if not self.profile.enabled or not self.profile.raidCheck.enabled then return end
    if not self.audit then self:CreateAuditWindow() end
    if manual and not self.readyCheckActive then self:ResetReadyState() end
    self.auditManual = manual
    local cfg = self.profile.raidCheck
    self.audit:ClearAllPoints()
    self.audit:SetPoint(cfg.point, UIParent, cfg.relativePoint, cfg.x, cfg.y)
    self.audit:SetScale(cfg.scale)
    self:ApplyAuditStyle()
    self.audit:Show()
    self:RefreshAudit(true)
    SUI:RefreshModuleEvents()
end

function SRT:HideAudit()
    if self.autoHideTimer then self.autoHideTimer:Cancel(); self.autoHideTimer = nil end
    if self.audit then self.audit:Hide() end
    self:ResetReadyState()
    self.testMode, self.auditManual = false, nil
    SUI:RefreshModuleEvents()
end

function SRT:ToggleRaidCheck(manual)
    if self.audit and self.audit:IsShown() then
        self:HideAudit()
    else
        self.testMode = false
        self:ShowAudit(manual)
    end
end

function SRT:ScheduleAuditHide()
    if self.auditManual or not self.profile.raidCheck.autoHide then return end
    if self.autoHideTimer then self.autoHideTimer:Cancel() end
    local attemptHide
    local function schedule(delay)
        self.autoHideTimer = C_Timer.NewTimer(delay, function()
            SUI:SafeModuleCall(self, "audit auto hide", attemptHide)
        end)
    end
    attemptHide = function()
        self.autoHideTimer = nil
        if not self.audit or not self.audit:IsShown() then return end
        if self.auditHover then
            schedule(.5)
        else
            self:HideAudit()
        end
    end
    schedule(self.profile.raidCheck.autoHideDelay)
end
