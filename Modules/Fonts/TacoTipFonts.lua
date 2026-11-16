local _, SUI = ...
if not SUI.isForever then return end

local M = {}
SUI:RegisterModule("tacoTipFonts", M)

local fontFields = { "ilvlLabel", "ilvlValue", "gsLabel", "gsValue" }
local styled = setmetatable({}, { __mode = "k" })
local isSecret = issecretvalue

local function CanAccess(region)
    return not (isSecret and isSecret(region)) and region
        and not (region.IsForbidden and region:IsForbidden())
        and (not region.CanBeAccessedInContext or region:CanBeAccessedInContext())
end

function M:ApplyFonts()
    if InCombatLockdown and InCombatLockdown() then
        self.pending = true
        return
    end
    self.pending = nil

    local footer = self.tacoTip.foreverStatsFooter
    if not CanAccess(footer) then return end
    for _, key in ipairs(fontFields) do
        local region = footer[key]
        if CanAccess(region) and not styled[region] and region.GetFont and region.SetFont then
            local _, size, flags = region:GetFont()
            if not (isSecret and (isSecret(size) or isSecret(flags))) and type(size) == "number" then
                SUI.InterfaceFonts:ApplyTheme(region, size, flags)
                styled[region] = true
            end
        end
    end
end

function M:Attach()
    if self.tacoTip or not SUI:IntegrationEnabled("tacotip") then return end
    local tacoTip = _G.TacoTip
    if type(tacoTip) ~= "table" or type(tacoTip.RefreshForeverCharacterStatsFooter) ~= "function"
        or not hooksecurefunc then return end

    hooksecurefunc(tacoTip, "RefreshForeverCharacterStatsFooter", function()
        SUI:SafeModuleCall(self, "TacoTip character fonts", self.ApplyFonts)
    end)
    self.tacoTip = tacoTip
    SUI:RegisterModuleEvent(self, "PLAYER_REGEN_ENABLED")
    self:ApplyFonts()
end

function M:Initialize()
    self:Attach()
    if not self.tacoTip then SUI:RegisterModuleEvent(self, "ADDON_LOADED") end
end

function M:WantsEvent(event)
    if event == "PLAYER_REGEN_ENABLED" then return self.tacoTip ~= nil end
    return not self.tacoTip and SUI:IntegrationEnabled("tacotip")
end

function M:OnEvent(event, addon)
    if event == "ADDON_LOADED" and addon == "TacoTip" then
        self:Attach()
    elseif event == "PLAYER_REGEN_ENABLED" and self.pending then
        self:ApplyFonts()
    end
end
