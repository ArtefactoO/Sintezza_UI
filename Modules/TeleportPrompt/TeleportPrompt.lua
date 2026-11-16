local _, SUI = ...
local Text = SUI.Text

local M = SUI:RegisterModule("teleportPrompt", {
    title = Text("Телепорт в подземелье", "Dungeon teleport"),
    autoHideSerial = 0,
})
SUI.TeleportPrompt = M

local T, W = SUI.Theme, SUI.Widgets
local Catalog = SUI.TeleportPromptCatalog

local function IsSecret(value)
    return issecretvalue and issecretvalue(value)
end

local function Clamp(value, minimum, maximum, fallback)
    return math.max(minimum, math.min(maximum, tonumber(value) or fallback))
end

local function PlayerKnows(spellID)
    if not spellID or type(IsPlayerSpell) ~= "function" then return false end
    local ok, known = pcall(IsPlayerSpell, spellID)
    return ok and not IsSecret(known) and known == true
end

local function InPartyInstance()
    if type(IsInInstance) ~= "function" then return false end
    local ok, inside, instanceType = pcall(IsInInstance)
    return ok and inside == true and instanceType == "party"
end

function M:Profile()
    return SUI:GetModuleProfile("teleportPrompt")
end

function M:HasExternalConflict()
    if not SUI:IntegrationEnabled("teleport") or not SUI:IsAddonLoaded("EllesmereUIQoL") then return false end
    local external = EllesmereUIDB and EllesmereUIDB.teleportPrompt
    return type(external) ~= "table" or external.enabled ~= false
end

function M:IsEnabled()
    if SUI.isForever then return false end
    local profile = self:Profile()
    return profile and profile.enabled ~= false and not self:HasExternalConflict()
end

function M:Status()
    if SUI.isForever then return Text("Доступно только в Retail", "Retail only"), false end
    if self:HasExternalConflict() then
        return Text("Активен LFG Reminder в EllesmereUIQoL", "EllesmereUIQoL LFG Reminder is active"), false
    end
    if not self:Profile() or self:Profile().enabled == false then return Text("Выключено", "Off"), true end
    return Text("Ожидает вступления в группу", "Waiting to join a group"), true
end

function M:ResolveDungeon(resultID)
    if not (C_LFGList and C_LFGList.GetSearchResultInfo and C_LFGList.GetActivityInfoTable) then return nil end
    local resolvedEntry, resolvedName
    pcall(function()
        local info = C_LFGList.GetSearchResultInfo(resultID)
        if IsSecret(info) or type(info) ~= "table" then return end
        local activityID = info.activityID
        if IsSecret(activityID) then return end
        if activityID == nil then
            local activityIDs = info.activityIDs
            if not IsSecret(activityIDs) and type(activityIDs) == "table" then activityID = activityIDs[1] end
        end
        if IsSecret(activityID) or activityID == nil then return end
        local activity = C_LFGList.GetActivityInfoTable(activityID)
        if IsSecret(activity) or type(activity) ~= "table" then return end
        local fullName = activity.fullName
        if IsSecret(fullName) or type(fullName) ~= "string" then return end
        local entry = Catalog and Catalog:Resolve(fullName)
        if not entry then return end
        resolvedEntry = entry
        resolvedName = fullName:gsub("%s*%b()%s*$", "")
    end)
    return resolvedEntry, resolvedName
end

function M:BuildFrames()
    if SUI.isForever then return nil end
    if self.card then return self.card end
    if InCombatLockdown and InCombatLockdown() then self.pendingBuild = true; return nil end
    self.pendingBuild = nil

    local card = CreateFrame("Frame", "Sintezza_UITeleportPrompt", UIParent, "BackdropTemplate")
    card:SetSize(378, 64)
    card:SetFrameStrata("DIALOG")
    card:SetFrameLevel(20)
    card:EnableMouse(true)
    card:Hide()
    T:Backdrop(card, { .018, .026, .032, .97 }, { .20, .27, .30, .72 })
    T:Glow(card, .78)

    local accent = card:CreateTexture(nil, "ARTWORK")
    accent:SetPoint("TOPLEFT", card, "TOPLEFT", 0, 0)
    accent:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", 0, 0)
    accent:SetWidth(3)
    accent:SetColorTexture(T.accent[1], T.accent[2], T.accent[3], .95)

    local icon = card:CreateTexture(nil, "ARTWORK")
    icon:SetSize(42, 42)
    icon:SetPoint("LEFT", card, "LEFT", 12, 0)
    icon:SetTexCoord(6 / 64, 58 / 64, 6 / 64, 58 / 64)
    self.icon = icon

    local name = card:CreateFontString(nil, "OVERLAY")
    name:SetPoint("LEFT", icon, "RIGHT", 10, 0)
    name:SetPoint("RIGHT", card, "RIGHT", -142, 0)
    name:SetJustifyH("LEFT")
    name:SetWordWrap(false)
    T:Font(name, 13, "OUTLINE", T.text)
    self.nameText = name

    local close = W:CloseButton(card, function() M:Dismiss() end, T)
    close:SetPoint("TOPRIGHT", card, "TOPRIGHT", -3, -3)

    local button = CreateFrame("Button", "Sintezza_UITeleportButton", UIParent,
        "SecureActionButtonTemplate,BackdropTemplate")
    button:SetSize(102, 38)
    button:SetPoint("RIGHT", card, "RIGHT", -28, 0)
    button:SetFrameStrata("DIALOG")
    button:SetFrameLevel(25)
    button:RegisterForClicks("AnyUp", "AnyDown")
    button:SetAttribute("type", "spell")
    T:Backdrop(button, T.accentDim, { T.accent[1], T.accent[2], T.accent[3], .55 })
    button:SetAlpha(0)
    button:EnableMouse(false)
    if RegisterStateDriver then RegisterStateDriver(button, "visibility", "[combat] hide; show") end

    local label = button:CreateFontString(nil, "OVERLAY")
    label:SetAllPoints()
    label:SetJustifyH("CENTER")
    T:Font(label, 10, "OUTLINE", T.text)
    label:SetText(Text("Телепорт", "Teleport"))
    self.buttonLabel = label

    local hover = button:CreateTexture(nil, "HIGHLIGHT")
    hover:SetAllPoints()
    hover:SetColorTexture(1, 1, 1, .10)

    local cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
    cooldown:SetAllPoints()
    cooldown:SetHideCountdownNumbers(true)
    cooldown:SetDrawSwipe(true)
    cooldown:SetDrawBling(false)
    cooldown:SetDrawEdge(false)
    self.cooldown = cooldown

    button:SetScript("PostClick", function()
        SUI:After(.1, M, "teleport prompt post click", function() M:Dismiss() end)
    end)

    self.card, self.secureButton = card, button
    self:ApplyAppearance()
    return card
end

function M:ApplyAppearance()
    if not self.card then return end
    if InCombatLockdown and InCombatLockdown() then self.pendingAppearance = true; return false end
    self.pendingAppearance = nil
    local profile = self:Profile() or {}
    self.card:ClearAllPoints()
    self.card:SetPoint("TOP", UIParent, "TOP",
        Clamp(profile.x, -700, 700, 0), Clamp(profile.y, -500, 0, -58))
    local scale = Clamp(profile.scale, .75, 1.35, 1)
    self.card:SetScale(scale)
    if self.secureButton then self.secureButton:SetScale(scale) end
end

function M:UpdateCooldown()
    if not self.cooldown then return end
    if InCombatLockdown and InCombatLockdown() then self.pendingCooldown = true; return end
    self.pendingCooldown = nil
    local profile = self:Profile() or {}
    if profile.showCooldown == false or not self.pendingKnown or not self.pendingEntry then
        self.cooldown:Clear()
        return
    end
    local ok, info = pcall(C_Spell.GetSpellCooldown, self.pendingEntry.spellID)
    if not ok or IsSecret(info) or type(info) ~= "table" then self.cooldown:Clear(); return end
    local startTime, duration = info.startTime, info.duration
    if IsSecret(startTime) or IsSecret(duration)
        or type(startTime) ~= "number" or type(duration) ~= "number" or duration <= 0 then
        self.cooldown:Clear()
        return
    end
    self.cooldown:SetCooldown(startTime, duration)
end

function M:DeactivateSecureButton()
    if not self.secureButton then return end
    if InCombatLockdown and InCombatLockdown() then self.pendingDeactivate = true; return end
    self.pendingDeactivate = nil
    self.secureButton:SetAlpha(0)
    self.secureButton:EnableMouse(false)
    self.secureButton:SetEnabled(false)
    self.secureButton:SetAttribute("spell", nil)
end

function M:ActivateSecureButton(entry, known)
    if not self.secureButton or not entry then return false end
    if InCombatLockdown and InCombatLockdown() then
        self.pendingAttributeSpellID = entry.spellID
        return false
    end
    self.pendingAttributeSpellID = nil
    self.pendingDeactivate = nil
    self.secureButton:SetAttribute("spell", entry.spellID)
    self.secureButton:SetEnabled(known)
    self.secureButton:EnableMouse(known)
    self.secureButton:SetAlpha(known and 1 or .42)
    return true
end

function M:ApplyPendingVisuals()
    if not self.card or not self.pendingEntry then return end
    local spellInfo = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(self.pendingEntry.spellID)
    if type(spellInfo) == "table" and spellInfo.iconID then self.icon:SetTexture(spellInfo.iconID) end
    self.icon:SetDesaturated(not self.pendingKnown)
    self.icon:SetAlpha(self.pendingKnown and 1 or .45)
    self.nameText:SetText(self.pendingName or self.pendingEntry.name or "")
    if InCombatLockdown and InCombatLockdown() then self.pendingButtonVisuals = true; return end
    self.pendingButtonVisuals = nil
    self.buttonLabel:SetText(self.pendingKnown and Text("Телепорт", "Teleport") or Text("Не изучен", "Not learned"))
    self:UpdateCooldown()
end

function M:IsPendingRelevant()
    return self.pendingEntry ~= nil and IsInGroup and IsInGroup() and not InPartyInstance()
end

function M:ScheduleAutoHide()
    self.autoHideSerial = self.autoHideSerial + 1
    local serial = self.autoHideSerial
    local delay = Clamp((self:Profile() or {}).autoHide, 0, 30, 0)
    if delay <= 0 then return end
    SUI:After(delay, self, "teleport prompt auto hide", function()
        if M.autoHideSerial == serial then M:Dismiss() end
    end)
end

function M:ShowPrompt()
    if not self:IsEnabled() or not self.pendingEntry then return false end
    if not self:IsPendingRelevant() then self:Dismiss(); return false end
    local profile = self:Profile() or {}
    self.pendingKnown = PlayerKnows(self.pendingEntry.spellID)
    if profile.knownOnly ~= false and not self.pendingKnown then self:Dismiss(); return false end
    self:BuildFrames()
    self:ApplyPendingVisuals()
    if InCombatLockdown and InCombatLockdown() then
        self.pendingShow = true
        self.pendingAttributeSpellID = self.pendingEntry.spellID
        return false
    end
    self.pendingShow = nil
    self:ActivateSecureButton(self.pendingEntry, self.pendingKnown)
    self.card:Show()
    self:ScheduleAutoHide()
    SUI:RefreshModuleEvents()
    return true
end

function M:HideVisual()
    self.autoHideSerial = self.autoHideSerial + 1
    if self.card then self.card:Hide() end
end

function M:Dismiss()
    self.pendingShow = nil
    self.resumeAfterCombat = nil
    self.pendingEntry, self.pendingName, self.pendingKnown = nil, nil, nil
    self:HideVisual()
    self:DeactivateSecureButton()
    if SUI.initialized then SUI:RefreshModuleEvents() end
end

function M:Preview()
    if not self:BuildFrames() then return false end
    local entry = Catalog and Catalog:First()
    if not entry then return false end
    self.pendingEntry, self.pendingName, self.pendingKnown = entry, entry.name, false
    self:ApplyPendingVisuals()
    if not (InCombatLockdown and InCombatLockdown()) then
        self.secureButton:SetEnabled(false)
        self.secureButton:EnableMouse(false)
        self.secureButton:SetAlpha(.42)
    end
    self.card:Show()
    self.autoHideSerial = self.autoHideSerial + 1
    local serial = self.autoHideSerial
    SUI:After(5, self, "teleport prompt preview", function()
        if M.autoHideSerial == serial then M:Dismiss() end
    end)
    return true
end

function M:OnEvent(event, arg1)
    if event == "LFG_LIST_JOINED_GROUP" then
        self:Dismiss()
        if not self:IsEnabled() then return end
        local entry, name = self:ResolveDungeon(arg1)
        if entry then
            self.pendingEntry, self.pendingName = entry, name
            self:ShowPrompt()
        end
    elseif event == "GROUP_ROSTER_UPDATE" then
        if not (IsInGroup and IsInGroup()) then self:Dismiss() end
    elseif event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
        if InPartyInstance() then self:Dismiss() end
    elseif event == "PLAYER_REGEN_DISABLED" then
        self.resumeAfterCombat = self.card and self.card:IsShown() and self.pendingEntry ~= nil or false
        self:HideVisual()
    elseif event == "PLAYER_REGEN_ENABLED" then
        if not self:IsEnabled() then
            self.pendingBuild, self.pendingAppearance = nil, nil
            self:Dismiss()
            return
        end
        if self.pendingBuild then self:BuildFrames() end
        if self.pendingAppearance then self:ApplyAppearance() end
        if self.pendingDeactivate then self:DeactivateSecureButton() end
        if self.pendingAttributeSpellID and self.pendingEntry then
            self:ActivateSecureButton(self.pendingEntry, self.pendingKnown == true)
        end
        if (self.pendingShow or self.resumeAfterCombat) and self:IsPendingRelevant() then
            self.pendingShow, self.resumeAfterCombat = nil, nil
            self:ShowPrompt()
        elseif not self.pendingEntry then
            self:DeactivateSecureButton()
        end
        if self.pendingButtonVisuals and self.pendingEntry then self:ApplyPendingVisuals()
        elseif self.pendingCooldown then self:UpdateCooldown() end
    elseif event == "SPELL_UPDATE_COOLDOWN" and self.card and self.card:IsShown() then
        self:UpdateCooldown()
    end
end

function M:OnProfileChanged()
    if self:IsEnabled() and not self.card then
        if Catalog then Catalog:Initialize() end
        self:BuildFrames()
    end
    self:ApplyAppearance()
    if not self:IsEnabled() then self:Dismiss() end
end

M.RefreshAll = M.OnProfileChanged

function M:Initialize()
    if SUI.isForever then return end
    if self:IsEnabled() then
        if Catalog then Catalog:Initialize() end
        self:BuildFrames()
    end
    SUI:RegisterModuleEvent(self, "LFG_LIST_JOINED_GROUP")
    SUI:RegisterModuleEvent(self, "GROUP_ROSTER_UPDATE")
    SUI:RegisterModuleEvent(self, "PLAYER_ENTERING_WORLD")
    SUI:RegisterModuleEvent(self, "ZONE_CHANGED_NEW_AREA")
    SUI:RegisterModuleEvent(self, "PLAYER_REGEN_DISABLED")
    SUI:RegisterModuleEvent(self, "PLAYER_REGEN_ENABLED")
    SUI:RegisterModuleEvent(self, "SPELL_UPDATE_COOLDOWN")
end
