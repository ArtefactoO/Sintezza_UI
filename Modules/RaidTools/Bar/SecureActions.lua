local ADDON, SUI = ...
local Text = SUI.Text
local SRT = SUI.RaidTools

local function prepareSecureButton(button)
    button:RegisterForClicks("AnyUp")
    button:SetAttribute("useOnKeyDown", false)
end

function SRT:MakeTargetButton(parent, index)
    local b = CreateFrame("Button", nil, parent, "SecureActionButtonTemplate,BackdropTemplate")
    prepareSecureButton(b)
    b.kind, b.marker = "target", index
    b.icon = b:CreateTexture(nil, "ARTWORK")
    self:SetRaidIcon(b.icon, index)
    self:HookButtonHover(b)
    return b
end

function SRT:ConfigureTargetButton(b)
    local index = b.marker
    b:SetAttribute("type1", "raidtarget")
    b:SetAttribute("type2", "raidtarget")
    b:SetAttribute("marker", index)
    b:SetAttribute("action1", "set")
    b:SetAttribute("action2", "clear")
    b:SetAttribute("unit", "target")
    local mouseover = self.profile.actions.useMouseover and "mouseover" or nil
    b:SetAttribute("shift-unit1", mouseover)
    b:SetAttribute("shift-unit2", mouseover)
end

function SRT:MakeWorldButton(parent, index)
    local b = CreateFrame("Button", nil, parent, "SecureActionButtonTemplate,BackdropTemplate")
    prepareSecureButton(b)
    b.kind, b.marker = "world", index
    b.icon = b:CreateTexture(nil, "ARTWORK")
    self:SetWorldIcon(b.icon, index)
    self:HookButtonHover(b)
    b:SetAttribute("type1", "worldmarker")
    b:SetAttribute("type2", "worldmarker")
    b:SetAttribute("marker", index)
    b:SetAttribute("action1", "set")
    b:SetAttribute("action2", "clear")
    return b
end

function SRT:MakeWorldClearButton(parent)
    local b = CreateFrame("Button", nil, parent, "SecureActionButtonTemplate,BackdropTemplate")
    prepareSecureButton(b)
    b.kind = "worldclear"
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetTexture(self.media.clear)
    b:SetAttribute("type1", "macro")
    b:SetAttribute("macrotext1", string.format("%s %s", SLASH_CLEAR_WORLD_MARKER1 or "/cwm", ALL or "All"))
    self:HookButtonHover(b)
    return b
end

function SRT:MakeActionButton(parent, kind, texture, click)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:RegisterForClicks("AnyUp")
    b.kind = kind
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetTexture(texture)
    b:SetScript("OnClick", click)
    self:HookButtonHover(b)
    return b
end

function SRT:StartReadyCheck()
    if not self.profile.enabled or self.profile.actions.readyCheck == false then return end
    if not self:CanLeadAction() then return self:Error(Text("Нужны права лидера группы или помощника.", "Requires leader or assistant permissions.")) end
    if self:ChatLocked() then return self:Error(Text("Проверка готовности сейчас недоступна.", "Ready check is unavailable.")) end
    local fn = C_PartyInfo and C_PartyInfo.DoReadyCheck or DoReadyCheck
    if not self:SafeCall(fn) then self:Error(Text("Не удалось запустить проверку готовности.", "Could not start the ready check.")) end
end

function SRT:DoPull(cancel)
    if not self.profile.enabled or self.profile.actions.pullTimer == false then return end
    if not self:CanLeadAction() then return self:Error(Text("Нужны права лидера группы или помощника.", "Requires leader or assistant permissions.")) end
    if self:ChatLocked() then return self:Error(Text("Отсчет сейчас недоступен.", "Countdown is unavailable.")) end
    if not (C_PartyInfo and C_PartyInfo.DoCountdown) then return self:Error(Text("API отсчета недоступен.", "Countdown is unavailable on this client.")) end
    local seconds = cancel and 0 or math.max(3, math.min(20, math.floor(tonumber(self.profile.actions.pullSeconds) or 10)))
    if not self:SafeCall(C_PartyInfo.DoCountdown, seconds) then self:Error(Text("Не удалось запустить отсчет.", "Could not start the countdown.")) end
end
