local ADDON, SUI = ...
local SGB = SUI.GameBar
local G = _G

function SGB:InCombat() return InCombatLockdown and InCombatLockdown() end
function SGB:SafeCall(fn, ...)
    if type(fn) ~= "function" then return false end
    local ok, result = pcall(fn, ...); return ok and result ~= false
end
function SGB:LoadBlizzardAddon(name)
    if C_AddOns and C_AddOns.LoadAddOn then return self:SafeCall(C_AddOns.LoadAddOn, name) end
    if LoadAddOn then return self:SafeCall(LoadAddOn, name) end
    return false
end
function SGB:Error(message)
    if G.UIErrorsFrame and G.UIErrorsFrame.AddMessage then G.UIErrorsFrame:AddMessage(message, 1, .2, .2) else print("|cffff5555SGB:|r " .. message) end
end
function SGB:Info(message)
    if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cff62b8ffSintezza Game Bar:|r " .. message) end
end
function SGB:GetClassColor()
    local _, class = UnitClass("player")
    local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    return c and c.r or .35, c and c.g or .75, c and c.b or 1, 1
end
function SGB:GetFont(requested)
    return SUI.Theme:ResolveTextFont(requested or self.profile.appearance.timeFont)
end
function SGB:GetFontFlags(flags, fallback)
    flags = flags or fallback or ""
    return flags == "NONE" and "" or flags
end
function SGB:GetFontChoices()
    return SUI.Theme:TextFontChoices()
end
function SGB:IsPetBattle()
    return C_PetBattles and C_PetBattles.IsInBattle and C_PetBattles.IsInBattle()
end
