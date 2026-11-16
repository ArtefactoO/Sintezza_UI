local ADDON, SUI = ...
local Text = SUI.Text
local SRT = SUI.RaidTools

function SRT:GetClassColor()
    local _, class = UnitClass("player")
    local color = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    return color and color.r or .35, color and color.g or .75, color and color.b or 1, 1
end
local G = _G
function SRT:InCombat() return InCombatLockdown and InCombatLockdown() end
function SRT:SafeCall(fn, ...) if type(fn) ~= "function" then return false end local ok, result = pcall(fn, ...); return ok and result ~= false end
function SRT:Info(msg) if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cff30b7aaSRT:|r " .. msg) end end
function SRT:Error(msg) if G.UIErrorsFrame and G.UIErrorsFrame.AddMessage then G.UIErrorsFrame:AddMessage(msg, 1, .22, .22) else self:Info(msg) end end
function SRT:CanLeadAction()
    if IsInGroup and not IsInGroup() then return true end
    return UnitIsGroupLeader and (UnitIsGroupLeader("player") or UnitIsGroupAssistant("player"))
end
function SRT:ChatLocked() return C_ChatInfo and C_ChatInfo.InChatMessagingLockdown and C_ChatInfo.InChatMessagingLockdown() end
function SRT:GetFont()
    if self.profile and self.profile.appearance.font ~= "DEFAULT" and LibStub then local lsm = LibStub("LibSharedMedia-3.0", true); local path = lsm and lsm:Fetch("font", self.profile.appearance.font, true); if path then return path end end
    return STANDARD_TEXT_FONT
end
function SRT:GetFontChoices()
    local choices = { DEFAULT = Text("Шрифт Blizzard (кириллица)", "Blizzard font") }
    if LibStub then
        local lsm = LibStub("LibSharedMedia-3.0", true)
        if lsm and lsm.List then
            for _, name in ipairs(lsm:List("font")) do choices[name] = name end
        end
    end
    return choices
end
function SRT:CanPlaceWorldMarkers()
    if not (IsInGroup and IsInGroup()) then return false end
    if IsInRaid and IsInRaid() then
        return UnitIsGroupLeader and (UnitIsGroupLeader("player") or UnitIsGroupAssistant("player"))
    end
    return true
end
function SRT:ShouldShowPanelVisual(panel)
    if not self.profile.enabled or not panel.cfg.enabled then return false end
    if C_PetBattles and C_PetBattles.IsInBattle and C_PetBattles.IsInBattle() then return false end
    if panel.id == "WORLD" and panel.cfg.hideWhenUnavailable and not self:CanPlaceWorldMarkers() then return false end
    return true
end
function SRT:ShowPanel(panel)
    return self:ShouldShowPanelVisual(panel)
end
