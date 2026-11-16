local ADDON, SUI = ...
local SRT = SUI.RaidTools
SRT.registry = {
    target = { 8, 7, 6, 5, 4, 3, 2, 1 },
    world = { 1, 2, 3, 4, 5, 6, 7, 8 },
}
function SRT:HookButtonHover(button)
    button:SetScript("OnEnter", function(self) SRT:SetButtonHovered(self, true) end)
    button:SetScript("OnLeave", function(self) SRT:SetButtonHovered(self, false) end)
end
