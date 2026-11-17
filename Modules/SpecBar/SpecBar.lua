local _, SUI = ...
if SUI.isForever then return end

local Text = SUI.Text
local M = {}
SUI:RegisterModule("specBar", M)

local issecretvalue = issecretvalue or function() return false end
local FALLBACK_ICON = 134400
local function API()
    return C_SpecializationInfo or {}
end

local function SafeValue(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, value = pcall(fn, ...)
    if ok and value ~= nil and not issecretvalue(value) then return value end
end

local function GetCurrentIndex()
    return SafeValue(API().GetSpecialization or GetSpecialization)
end

local function GetSpecCount()
    return SafeValue(API().GetNumSpecializations or GetNumSpecializations) or 0
end

local function GetSpecInfo(index)
    local fn = API().GetSpecializationInfo or GetSpecializationInfo
    if type(fn) ~= "function" then return nil end
    local ok, id, name, _, icon = pcall(fn, index)
    if not ok or issecretvalue(id) or issecretvalue(name) or issecretvalue(icon) then return nil end
    return id, name, icon
end

local function CurrentLootID()
    return SafeValue(GetLootSpecialization) or 0
end

local function ActiveInfo()
    local index = GetCurrentIndex()
    if type(index) ~= "number" then return nil end
    return GetSpecInfo(index)
end

function M:RefreshIcons()
    if not self.root then return end
    local activeID, activeName, activeIcon = ActiveInfo()
    local lootID = CurrentLootID()
    local lootName, lootIcon = activeName, activeIcon
    if lootID ~= 0 then
        lootName, lootIcon = nil, nil
        for index = 1, GetSpecCount() do
            local id, name, icon = GetSpecInfo(index)
            if id == lootID then lootName, lootIcon = name, icon; break end
        end
    end
    self.activeName = activeName or Text("Не выбрана", "None selected")
    self.lootName = lootID == 0 and Text("По текущей специализации", "Current specialization") or (lootName or Text("Неизвестна", "Unknown"))
    self.activeButton.icon:SetTexture(activeIcon or FALLBACK_ICON)
    self.lootButton.icon:SetTexture(lootIcon or FALLBACK_ICON)
    self.activeButton.icon:SetDesaturated(activeID == nil)
    self.lootButton.icon:SetDesaturated(lootIcon == nil)
    local activeShown = self.profile.showActive ~= false
    local lootEnabled = self.profile.showLoot ~= false
    self.collapsed = activeShown and lootEnabled and (lootID == 0 or (activeID ~= nil and lootID == activeID))
    local lootShown = lootEnabled and not self.collapsed
    self.activeButton:SetShown(activeShown)
    self.lootButton:SetShown(lootShown)
    self.lootButton:ClearAllPoints()
    if activeShown then self.lootButton:SetPoint("LEFT", self.activeButton, "RIGHT", 3, 0)
    else self.lootButton:SetPoint("LEFT", self.panel, "LEFT", 4, 0) end
    self.root:SetSize(activeShown and lootShown and 83 or 44, 39)
end

function M:HasActiveButtons()
    local p = self.profile
    return p and p.enabled ~= false and (p.showActive ~= false or p.showLoot ~= false)
end

local function IsSelected(kind, selected)
    if kind == "loot" then return CurrentLootID() == selected end
    return GetCurrentIndex() == selected
end

function M:Choose(kind, selected)
    if InCombatLockdown and InCombatLockdown() then
        SUI:Print(Text("Специализацию можно менять после выхода из боя.", "You can change specialization after combat."))
        return
    end
    local fn = kind == "loot" and SetLootSpecialization or API().SetSpecialization
    if type(fn) ~= "function" then
        SUI:Print(Text("Выбор специализации недоступен в этой версии клиента.", "Specialization selection is unavailable on this client."))
        return
    end
    local ok, result = pcall(fn, selected)
    if not ok or result == false then
        SUI:Print(Text("Не удалось изменить специализацию.", "Could not change specialization."))
        return
    end
    self:RefreshIcons()
end

function M:OpenMenu(owner, kind)
    if not self:HasActiveButtons() then return end
    if kind == "loot" and self.profile.showLoot == false then return end
    if not (MenuUtil and type(MenuUtil.CreateContextMenu) == "function") then
        SUI:Print(Text("Меню специализаций недоступно.", "The specialization menu is unavailable."))
        return
    end
    SUI.SettingsTheme:OpenMenu(owner, function(_, menu)
        menu:CreateTitle(kind == "loot" and Text("Специализация добычи", "Loot specialization") or Text("Специализация", "Specialization"))
        if kind == "loot" then
            menu:CreateRadio(Text("По текущей специализации", "Current specialization"), function(value) return IsSelected("loot", value) end,
                function(value) M:Choose("loot", value) end, 0)
        end
        for index = 1, GetSpecCount() do
            local id, name = GetSpecInfo(index)
            if id and name then
                local choice = kind == "loot" and id or index
                menu:CreateRadio(name, function(value) return IsSelected(kind, value) end,
                    function(value) M:Choose(kind, value) end, choice)
            end
        end
    end)
end

local function CreateButton(parent, kind)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(36, 37)
    button:SetFrameLevel(parent:GetFrameLevel() + 2)
    button:RegisterForClicks("AnyUp")
    button:RegisterForDrag("LeftButton")
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetSize(27, 27)
    button.icon:SetPoint("CENTER")
    button.icon:SetTexCoord(.08, .92, .08, .92)
    button:SetScript("OnDragStart", function() M:StartMoving() end)
    button:SetScript("OnDragStop", function() M:StopMoving() end)
    button:SetScript("OnClick", function(self, mouse) M:OpenMenu(self, mouse == "RightButton" and "loot" or kind) end)
    button:SetScript("OnEnter", function(self)
        M:OnPanelEnter()
        local appearance = SUI:GetModuleProfile("gameBar") and SUI:GetModuleProfile("gameBar").appearance
        local r, g, b = .35, .75, 1
        if appearance and appearance.hoverColorMode == "CLASS" then
            r, g, b = SUI.GameBar:GetClassColor()
        elseif appearance and appearance.hoverColor then
            r, g, b = appearance.hoverColor[1], appearance.hoverColor[2], appearance.hoverColor[3]
        end
        self.icon:SetVertexColor(r, g, b, 1)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        if M.collapsed then
            GameTooltip:SetText(Text("Специализации", "Specializations"))
            GameTooltip:AddLine(Text("ЛКМ — текущая: %s", "Left-click: current — %s"):format(M.activeName), 1, 1, 1)
            GameTooltip:AddLine(Text("ПКМ — добыча: %s", "Right-click: loot — %s"):format(M.lootName), 1, 1, 1)
        else
            GameTooltip:SetText(kind == "loot" and Text("Специализация добычи", "Loot specialization") or Text("Специализация", "Specialization"))
            GameTooltip:AddLine(kind == "loot" and M.lootName or M.activeName, 1, 1, 1)
        end
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
        M:RefreshStyle()
        M:OnPanelLeave()
    end)
    return button
end

function M:CreateVisuals()
    if self.root then return end
    local root = CreateFrame("Frame", "Sintezza_UISpecBar", UIParent)
    root:SetFrameStrata("MEDIUM")
    root:SetClampedToScreen(true)
    root:SetMovable(true)
    root:EnableMouse(true)
    root:RegisterForDrag("LeftButton")
    root:SetScript("OnDragStart", function() M:StartMoving() end)
    root:SetScript("OnDragStop", function() M:StopMoving() end)
    root:SetScript("OnEnter", function() M:OnPanelEnter() end)
    root:SetScript("OnLeave", function() M:OnPanelLeave() end)
    self.root = root
    local gameBar = SUI.GameBar
    self.panel = gameBar:CreateSegment(root)
    self.panel:SetAllPoints()
    self.activeButton = CreateButton(self.panel, "active")
    self.lootButton = CreateButton(self.panel, "loot")
    self.activeButton:SetPoint("LEFT", 4, 0)
    self.lootButton:SetPoint("LEFT", self.activeButton, "RIGHT", 3, 0)
    self.panel:SetScript("OnEnter", function() M:OnPanelEnter() end)
    self.panel:SetScript("OnLeave", function() M:OnPanelLeave() end)
end

function M:RefreshStyle()
    if not self.root then return end
    local gameBar = SUI.GameBar
    local appearance = SUI:GetModuleProfile("gameBar") and SUI:GetModuleProfile("gameBar").appearance
    if appearance then
        gameBar:ApplySegmentStyle(self.panel, appearance)
        local color = appearance.iconColor or { 1, 1, 1, 1 }
        local alpha = (color[4] or 1) * (tonumber(appearance.iconAlpha) or .9)
        for _, button in ipairs({ self.activeButton, self.lootButton }) do
            button.icon:SetVertexColor(color[1], color[2], color[3], alpha)
        end
    end
end

function M:ApplyPosition()
    if not self.root then return end
    local p = self.profile
    self.root:ClearAllPoints()
    self.root:SetPoint(p.point or "TOP", UIParent, p.relativePoint or "TOP", tonumber(p.x) or 0, tonumber(p.y) or -55)
    self.root:SetScale(tonumber(p.scale) or 1)
end

function M:FadeTo(alpha)
    if not self.panel then return end
    if not self.fadeFrame then self.fadeFrame = CreateFrame("Frame") end
    self.fadeTarget = alpha
    local frame = self.fadeFrame
    if math.abs(self.panel:GetAlpha() - alpha) < .001 then
        self.panel:SetAlpha(alpha)
        frame:SetScript("OnUpdate", nil)
        return
    end
    frame:SetScript("OnUpdate", function(controller, elapsed)
        local current, target = M.panel:GetAlpha(), M.fadeTarget
        local duration = math.max(.01, tonumber(M.profile.fadeDuration) or .11)
        local step = elapsed / duration
        if current < target then current = math.min(target, current + step)
        else current = math.max(target, current - step) end
        M.panel:SetAlpha(current)
        if current == target then controller:SetScript("OnUpdate", nil) end
    end)
end

function M:RefreshFade()
    if not self.root or not self.root:IsShown() then return end
    local p = self.profile
    local combat = InCombatLockdown and InCombatLockdown()
    if self.settingsOpen or not p.mouseover or (combat and p.combatVisibility == "SHOW")
        or self.root:IsMouseOver() then
        self:FadeTo(tonumber(p.hoverAlpha) or 1)
    else
        self:FadeTo(0)
    end
end

function M:OnPanelEnter()
    self.hoverGeneration = (self.hoverGeneration or 0) + 1
    if self.root and self.root:IsShown() then self:RefreshFade() end
end

function M:OnPanelLeave()
    self.hoverGeneration = (self.hoverGeneration or 0) + 1
    local generation = self.hoverGeneration
    SUI:After(tonumber(self.profile.fadeDelay) or .04, self, "spec bar fade", function()
        if generation == M.hoverGeneration and M.root and not M.root:IsMouseOver() then M:RefreshFade() end
    end)
end

function M:RefreshVisibility()
    if not self.root then return end
    local p = self.profile
    local combat = InCombatLockdown and InCombatLockdown()
    local petBattle = self.petBattleActive or (C_PetBattles and C_PetBattles.IsInBattle and C_PetBattles.IsInBattle())
    local show = self:HasActiveButtons() and (self.settingsOpen
        or (not (p.hideInPetBattle and petBattle) and not (combat and p.combatVisibility == "HIDE")))
    self.root:SetShown(show)
    if self.root:IsShown() then self:RefreshFade()
    elseif self.fadeFrame then self.fadeFrame:SetScript("OnUpdate", nil) end
end

function M:RefreshAll()
    if not self.root and self:HasActiveButtons() then self:CreateVisuals() end
    if not self.root then return end
    self:ApplyPosition()
    self:RefreshStyle()
    self:RefreshIcons()
    self:RefreshVisibility()
end

function M:StartMoving()
    if self.profile.locked ~= false or (InCombatLockdown and InCombatLockdown()) then return end
    self.root:StartMoving()
end

function M:StopMoving()
    if not self.root then return end
    self.root:StopMovingOrSizing()
    local point, _, relativePoint, x, y = self.root:GetPoint(1)
    if point and type(x) == "number" and type(y) == "number" then
        self.profile.point, self.profile.relativePoint = point, relativePoint
        self.profile.x, self.profile.y = math.floor(x + .5), math.floor(y + .5)
    end
    self:ApplyPosition()
    if SUI.SettingsUI then SUI.SettingsUI:Refresh() end
end

function M:Initialize()
    self.profile = SUI:GetModuleProfile("specBar")
    self:RefreshAll()
    for _, event in ipairs({
        "PLAYER_ENTERING_WORLD", "PLAYER_SPECIALIZATION_CHANGED", "PLAYER_LOOT_SPEC_UPDATED",
        "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "PET_BATTLE_OPENING_START", "PET_BATTLE_CLOSE",
    }) do
        SUI:RegisterModuleEvent(self, event)
    end
end

function M:OnProfileChanged()
    self.profile = SUI:GetModuleProfile("specBar")
    self:RefreshAll()
end

function M:WantsEvent(event)
    return self:HasActiveButtons() and event ~= "CHARACTER_POINTS_CHANGED" and event ~= "PLAYER_TALENT_UPDATE"
end

function M:OnEvent(event, unit)
    if event == "PLAYER_SPECIALIZATION_CHANGED" and unit and unit ~= "player" then return end
    if event == "PET_BATTLE_OPENING_START" then self.petBattleActive = true end
    if event == "PET_BATTLE_CLOSE" then
        self.petBattleActive = nil
        SUI:After(0, self, "pet battle visibility", function() M:RefreshVisibility() end)
    end
    if event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_SPECIALIZATION_CHANGED" or event == "PLAYER_LOOT_SPEC_UPDATED" then
        self:RefreshIcons()
    end
    self:RefreshVisibility()
end
